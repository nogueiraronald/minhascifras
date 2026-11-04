import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cifras_app/componentes/dialogo_desbloqueio_conta.dart';
import 'package:cifras_app/componentes/dialogo_login_desktop.dart';
import 'package:cifras_app/dados/controlador_conta.dart';
import 'package:cifras_app/dados/repositorio_listas.dart';
import 'package:cifras_app/dados/repositorio_musicas.dart';
import 'package:cifras_app/modelos/lista_repertorio.dart';
import 'package:cifras_app/modelos/musica.dart';
import 'package:cifras_app/servicos/dados_nuvem.dart';
import 'package:cifras_app/servicos/servico_sincronizacao.dart';
import 'package:cifras_app/servicos/servico_supabase_sync.dart';

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

  group('Proteção Estrita por Senha no SyncService e Desbloqueio', () {
    late SongRepository songRepo;
    late SetlistRepository setlistRepo;
    late AccountController account;
    late FakeSupabaseSync fakeSupabase;
    late SyncService syncService;

    const correctPassword = 'senha-mestra-123';
    final passwordHash =
        sha256.convert(utf8.encode(correctPassword)).toString();

    setUp(() async {
      SharedPreferences.setMockInitialValues({
        'supabase_sync_code': 'MC-PROTEGIDO',
      });
      songRepo = await SongRepository.open();
      setlistRepo = await SetlistRepository.open();
      account = await AccountController.open();

      fakeSupabase = FakeSupabaseSync(
        remoteData: CloudData(
          songs: [
            Song(
              id: 'remota1',
              title: 'Música Secreta',
              artist: 'Artista Protegido',
              content: 'C G Am F',
            ),
          ],
          passwordHash: passwordHash,
        ),
      );

      syncService = SyncService(
        songRepo,
        setlistRepo,
        account,
        supabaseSync: fakeSupabase,
      );
    });

    test('SyncService bloqueia download quando aparelho não possui a senha',
        () async {
      expect(account.isPasswordProtected, isFalse);
      expect(songRepo.songs, isEmpty);

      // Tenta sincronizar sem ter a senha
      await syncService.sync();

      // Músicas NÃO devem ter sido baixadas
      expect(songRepo.songs, isEmpty);
      expect(account.isLocked, isTrue);
      expect(syncService.error, contains('protegido por senha'));
    });

    test('unlockPendingSync desbloqueia com senha correta e rejeita incorreta',
        () async {
      account.lockWithRemoteHash(passwordHash);
      expect(account.isLocked, isTrue);

      // Senha incorreta
      final wrongResult = await account.unlockPendingSync('senha-errada');
      expect(wrongResult, isFalse);
      expect(account.isLocked, isTrue);

      // Senha correta
      final okResult = await account.unlockPendingSync(correctPassword);
      expect(okResult, isTrue);
      expect(account.isLocked, isFalse);
      expect(account.isPasswordProtected, isTrue);

      // Agora o sync baixa as músicas normalmente
      await syncService.sync();
      expect(songRepo.songs.length, 1);
      expect(songRepo.songs.first.title, 'Música Secreta');
    });

    testWidgets('DialogoDesbloqueioConta permite digitar senha e desbloquear',
        (tester) async {
      account.lockWithRemoteHash(passwordHash);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => DialogoDesbloqueioConta.show(
                    ctx, account, syncService),
                child: const Text('Abrir Desbloqueio'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Abrir Desbloqueio'));
      await tester.pumpAndSettle();

      expect(find.text('Repertório Protegido por Senha'), findsOneWidget);
      expect(find.text('Desbloquear e Baixar'), findsOneWidget);

      // Digita senha errada
      await tester.enterText(find.byType(TextField), 'errada');
      await tester.tap(find.text('Desbloquear e Baixar'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Senha incorreta'), findsOneWidget);
      expect(account.isLocked, isTrue);

      // Digita senha certa
      await tester.enterText(find.byType(TextField), correctPassword);
      await tester.tap(find.text('Desbloquear e Baixar'));
      await tester.pumpAndSettle();

      expect(account.isLocked, isFalse);
      expect(songRepo.songs.length, 1);
    });
  });
}

class FakeSupabaseSync extends SupabaseSyncService {
  FakeSupabaseSync({this.remoteData = const CloudData()});
  CloudData remoteData;

  @override
  Future<CloudData> readAll(String syncCode) async => remoteData;

  @override
  Future<void> writeAll(String syncCode, CloudData data) async {
    remoteData = data;
  }

  @override
  Future<String?> checkPasswordHash(String syncCode) async =>
      remoteData.passwordHash;
}

