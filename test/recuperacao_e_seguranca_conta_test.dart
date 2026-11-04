import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cifras_app/componentes/dialogo_login_desktop.dart';
import 'package:cifras_app/dados/controlador_conta.dart';
import 'package:cifras_app/dados/repositorio_listas.dart';
import 'package:cifras_app/dados/repositorio_musicas.dart';
import 'package:cifras_app/modelos/lista_repertorio.dart';
import 'package:cifras_app/modelos/musica.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Segurança de Conta e Proteção por Senha', () {
    late SharedPreferences prefs;
    late AccountController account;

    setUp(() async {
      SharedPreferences.setMockInitialValues({
        'supabase_sync_code': 'MC-TEST01',
      });
      prefs = await SharedPreferences.getInstance();
      account = await AccountController.open();
    });

    test('configura e remove senha com hash sha256', () async {
      expect(account.isPasswordProtected, isFalse);
      expect(account.passwordHash, isNull);

      const pass = 'segredo123';
      final expectedHash = sha256.convert(utf8.encode(pass)).toString();

      await account.setPassword(pass);
      expect(account.isPasswordProtected, isTrue);
      expect(account.passwordHash, equals(expectedHash));
      expect(prefs.getString('supabase_sync_password_hash'), equals(expectedHash));

      await account.removePassword();
      expect(account.isPasswordProtected, isFalse);
      expect(account.passwordHash, isNull);
      expect(prefs.getString('supabase_sync_password_hash'), isNull);
    });

    test('resetToNewAccount gera nova chave e remove senha', () async {
      await account.setPassword('senha123');
      expect(account.isPasswordProtected, isTrue);
      expect(account.syncCode, 'MC-TEST01');

      final newCode = await account.resetToNewAccount();
      expect(newCode, startsWith('MC-'));
      expect(newCode, isNot(equals('MC-TEST01')));
      expect(account.syncCode, equals(newCode));
      expect(account.isPasswordProtected, isFalse);
      expect(account.passwordHash, isNull);
    });
  });

  group('Limpeza de Repertório ao Deslogar', () {
    late SongRepository songRepo;
    late SetlistRepository setlistRepo;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      songRepo = await SongRepository.open();
      setlistRepo = await SetlistRepository.open();

      await songRepo.upsertAll([
        Song(id: 's1', title: 'Música 1', artist: 'Artista 1', content: 'G C D'),
        Song(id: 's2', title: 'Música 2', artist: 'Artista 2', content: 'Em C D'),
      ]);
      await setlistRepo.saveSetlist(
        Setlist(id: 'l1', name: 'Repertório Domingo'),
      );
    });

    test('clearAll limpa músicas e setlists locais', () async {
      expect(songRepo.songs.length, 2);
      expect(setlistRepo.setlists.length, 1);

      await songRepo.clearAll();
      await setlistRepo.clearAll();

      expect(songRepo.songs, isEmpty);
      expect(setlistRepo.setlists, isEmpty);
      expect(setlistRepo.items, isEmpty);
    });
  });

  group('DesktopLoginDialog UI de Segurança e Recuperação', () {
    late AccountController account;
    late SongRepository songRepo;
    late SetlistRepository setlistRepo;

    setUp(() async {
      SharedPreferences.setMockInitialValues({
        'supabase_sync_code': 'MC-TEST99',
      });
      account = await AccountController.open();
      songRepo = await SongRepository.open();
      setlistRepo = await SetlistRepository.open();

      await songRepo.upsertAll([
        Song(id: 's1', title: 'Música 1', artist: 'Artista 1', content: 'C G Am F'),
      ]);
    });

    testWidgets('exibe bloco de senha, botão de PDF e botão de sair da conta',
        (tester) async {
      tester.view.physicalSize = const Size(600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DesktopLoginDialog(
              account: account,
              songs: songRepo,
              setlists: setlistRepo,
            ),
          ),
        ),
      );

      expect(find.text('Proteção por Senha'), findsOneWidget);
      expect(find.text('Baixar Cartão de Recuperação (PDF)'), findsOneWidget);
      expect(find.text('Sair desta conta / Começar do Zero'), findsOneWidget);

      // Clica em "Definir" senha e abre diálogo de configuração de senha
      await tester.tap(find.text('Definir'));
      await tester.pumpAndSettle();

      expect(find.text('Definir Senha de Proteção'), findsOneWidget);
      expect(find.text('Nova Senha'), findsOneWidget);
      expect(find.text('Confirmar Senha'), findsOneWidget);

      // Cancela o diálogo de senha
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(find.text('Definir Senha de Proteção'), findsNothing);
    });

    testWidgets('fluxo de sair da conta limpa músicas e gera novo código',
        (tester) async {
      tester.view.physicalSize = const Size(600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      expect(songRepo.songs.length, 1);
      expect(account.syncCode, 'MC-TEST99');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DesktopLoginDialog(
              account: account,
              songs: songRepo,
              setlists: setlistRepo,
            ),
          ),
        ),
      );

      // Rola até o botão de sair se necessário e clica
      final signOutFinder = find.text('Sair desta conta / Começar do Zero');
      await tester.ensureVisible(signOutFinder);
      await tester.pumpAndSettle();
      await tester.tap(signOutFinder);
      await tester.pumpAndSettle();

      // Confirmação do diálogo
      expect(find.text('Sair deste Repertório?'), findsOneWidget);
      expect(find.text('Sim, Sair e Limpar'), findsOneWidget);

      await tester.tap(find.text('Sim, Sair e Limpar'));
      await tester.pumpAndSettle();

      // Após confirmar: repositório local zerado e nova chave gerada
      expect(songRepo.songs, isEmpty);
      expect(account.syncCode, isNot(equals('MC-TEST99')));
      expect(account.syncCode, startsWith('MC-'));
    });
  });
}
