import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cifras_app/componentes/dialogo_login_desktop.dart';
import 'package:cifras_app/dados/controlador_conta.dart';
import 'package:cifras_app/dados/repositorio_listas.dart';
import 'package:cifras_app/dados/repositorio_musicas.dart';
import 'package:cifras_app/dados/repositorio_temas.dart';
import 'package:cifras_app/modelos/lista_repertorio.dart';
import 'package:cifras_app/modelos/musica.dart';
import 'package:cifras_app/servicos/dados_nuvem.dart';
import 'package:cifras_app/servicos/servico_supabase_sync.dart';

class FakeSupabaseSyncEmail extends SupabaseSyncService {
  FakeSupabaseSyncEmail({this.remoteData = const CloudData()});

  CloudData remoteData;

  @override
  Future<CloudData> readAll(String syncCode) async {
    return remoteData;
  }

  @override
  Future<String?> checkPasswordHash(String syncCode) async {
    return remoteData.passwordHash;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AccountController - Login com E-mail e Senha', () {
    late SharedPreferences prefs;
    late AccountController account;
    late FakeSupabaseSyncEmail fakeSupabase;

    const testEmail = 'ronald@musicas.com';
    const testPassword = 'senha-secreta-123';
    final testHash = sha256.convert(utf8.encode(testPassword)).toString();

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      fakeSupabase = FakeSupabaseSyncEmail(
        remoteData: CloudData(
          songs: [
            Song(id: 's1', title: 'Como Zaqueu', artist: 'Regis Danese', content: 'C G Am F'),
          ],
          passwordHash: testHash,
        ),
      );
      account = await AccountController.open(supabaseSync: fakeSupabase);
    });

    test('emailToSyncCode gera código determinístico e normalizado', () {
      final code1 = AccountController.emailToSyncCode('ronald@musicas.com');
      final code2 = AccountController.emailToSyncCode('  RONALD@MUSICAS.COM  ');
      expect(code1, startsWith('USR_'));
      expect(code1, equals(code2));
    });

    test('rejeita e-mail inválido ou senha vazia', () async {
      expect(
        () => account.loginWithEmailAndPassword(
          emailInput: 'invalido',
          passwordInput: '123',
        ),
        throwsA(isA<FormatException>()),
      );

      expect(
        () => account.loginWithEmailAndPassword(
          emailInput: 'teste@email.com',
          passwordInput: '',
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('login com senha incorreta lança exceção amigável', () async {
      expect(
        () => account.loginWithEmailAndPassword(
          emailInput: testEmail,
          passwordInput: 'senha-errada',
        ),
        throwsA(isA<Exception>()),
      );
      expect(account.isLoggedIn, isFalse);
    });

    test('login com sucesso salva e-mail, código e hash nas preferências', () async {
      bool synced = false;
      final count = await account.loginWithEmailAndPassword(
        emailInput: testEmail,
        passwordInput: testPassword,
        onSync: () async => synced = true,
      );

      expect(count, 1);
      expect(synced, isTrue);
      expect(account.isLoggedIn, isTrue);
      expect(account.userEmail, testEmail);
      expect(account.syncCode, startsWith('USR_'));
      expect(account.passwordHash, testHash);

      expect(prefs.getString('user_account_email'), testEmail);
      expect(prefs.getString('supabase_sync_password_hash'), testHash);
    });

    test('restore recupera sessão salva por e-mail', () async {
      final expectedCode = AccountController.emailToSyncCode(testEmail);
      SharedPreferences.setMockInitialValues({
        'user_account_email': testEmail,
        'supabase_sync_password_hash': testHash,
      });

      final restored = await AccountController.open();
      expect(restored.isLoggedIn, isTrue);
      expect(restored.userEmail, testEmail);
      expect(restored.syncCode, expectedCode);
    });

    test('signOutUser limpa dados de login e dispara limpeza local', () async {
      await account.loginWithEmailAndPassword(
        emailInput: testEmail,
        passwordInput: testPassword,
      );
      expect(account.isLoggedIn, isTrue);

      bool cleared = false;
      await account.signOutUser(onClearLocalData: () async => cleared = true);

      expect(cleared, isTrue);
      expect(account.isLoggedIn, isFalse);
      expect(account.userEmail, isNull);
      expect(prefs.getString('user_account_email'), isNull);
      expect(prefs.getString('supabase_sync_password_hash'), isNull);
    });
  });

  group('DesktopLoginDialog - Telas de E-mail e Conexão', () {
    late AccountController account;
    late SongRepository songRepo;
    late SetlistRepository setlistRepo;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      account = await AccountController.open();
      songRepo = await SongRepository.open();
      setlistRepo = await SetlistRepository.open();
    });

    testWidgets('abre diretamente no formulário de e-mail com initialShowEmailLogin', (tester) async {
      tester.view.physicalSize = const Size(500, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DesktopLoginDialog(
              account: account,
              songs: songRepo,
              setlists: setlistRepo,
              initialShowEmailLogin: true,
            ),
          ),
        ),
      );

      expect(find.text('Acessar com E-mail'), findsOneWidget);
      expect(find.text('Seu E-mail'), findsOneWidget);
      expect(find.text('Sua Senha de Acesso'), findsOneWidget);
      expect(find.text('Acessar e Baixar Músicas'), findsOneWidget);
    });

    testWidgets('exibe tela de conta conectada quando account.isLoggedIn é verdadeiro', (tester) async {
      tester.view.physicalSize = const Size(500, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      SharedPreferences.setMockInitialValues({
        'user_account_email': 'usuario@musicas.com',
      });
      final loggedAccount = await AccountController.open();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DesktopLoginDialog(
              account: loggedAccount,
              songs: songRepo,
              setlists: setlistRepo,
            ),
          ),
        ),
      );

      expect(find.text('Repertório em Nuvem'), findsOneWidget);
      expect(find.text('usuario@musicas.com'), findsOneWidget);
      expect(find.text('Backup Conectado e Ativo'), findsOneWidget);
      expect(find.text('Sincronizar Agora'), findsOneWidget);
      expect(find.text('Sair desta conta / Desconectar aparelho'), findsOneWidget);
    });

    testWidgets('ao deslogar completamente, limpa temas personalizados e listas do usuário', (tester) async {
      tester.view.physicalSize = const Size(500, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      SharedPreferences.setMockInitialValues({
        'user_account_email': 'usuario@musicas.com',
      });
      final loggedAccount = await AccountController.open();
      final themeRepo = await ThemeRepository.open();

      // Adiciona lista e tema customizado
      await setlistRepo.saveSetlist(Setlist(id: 'set-test-1', name: 'Lista Especial'));
      await themeRepo.addTheme('Tema Exclusivo do Usuário');
      expect(setlistRepo.setlists, isNotEmpty);
      expect(themeRepo.themes, contains('Tema Exclusivo do Usuário'));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DesktopLoginDialog(
              account: loggedAccount,
              songs: songRepo,
              setlists: setlistRepo,
              musicThemes: themeRepo,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Toca em sair da conta
      await tester.tap(find.text('Sair desta conta / Desconectar aparelho'));
      await tester.pumpAndSettle();

      // Confirma no diálogo de confirmação
      expect(find.text('Sim, Sair e Limpar'), findsOneWidget);
      await tester.tap(find.text('Sim, Sair e Limpar'));
      await tester.pumpAndSettle();

      // Verifica se as listas e os temas customizados foram limpos
      expect(setlistRepo.setlists, isEmpty);
      expect(themeRepo.themes.contains('Tema Exclusivo do Usuário'), isFalse);
      expect(loggedAccount.isLoggedIn, isFalse);
    });
  });
}
