import 'package:cifras_app/componentes/dialogo_login_desktop.dart';
import 'package:cifras_app/dados/controlador_conta.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AccountController.extractCode', () {
    test('extrai código puro e converte para maiúsculo', () {
      expect(AccountController.extractCode('mc-nzkd9a'), 'MC-NZKD9A');
      expect(AccountController.extractCode('  MC-8492  '), 'MC-8492');
    });

    test('extrai código de link do QR Code / URL com ?sync=', () {
      expect(
        AccountController.extractCode(
            'https://nogueiraronald.github.io/minhascifras-web/?sync=MC-NZKD9A'),
        'MC-NZKD9A',
      );
      expect(
        AccountController.extractCode(
            'http://localhost:8080/#/?sync=mc-test12'),
        'MC-TEST12',
      );
    });
  });

  group('DesktopLoginDialog UI', () {
    late AccountController account;

    setUp(() async {
      SharedPreferences.setMockInitialValues({
        'supabase_sync_code': 'MC-TEST99',
      });
      account = await AccountController.open();
    });

    testWidgets('exibe QR Code e mantém código em texto oculto por padrão',
        (tester) async {
      tester.view.physicalSize = const Size(375, 667);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DesktopLoginDialog(account: account),
          ),
        ),
      );

      // Deve exibir o QR Code
      expect(find.byType(QrImageView), findsOneWidget);

      // O texto da chave NÃO deve estar visível como SelectableText por padrão
      expect(find.text('MC-TEST99'), findsNothing);

      // Botão para ver a chave está presente
      expect(find.text('Ver chave deste aparelho em texto'), findsOneWidget);

      // Ao clicar, a chave é revelada
      await tester.tap(find.text('Ver chave deste aparelho em texto'));
      await tester.pumpAndSettle();
      expect(find.text('MC-TEST99'), findsOneWidget);
      expect(find.text('Ocultar chave em texto'), findsOneWidget);
    });

    testWidgets(
        'permite alternar para digitação manual sem o QR Code para caber no teclado',
        (tester) async {
      tester.view.physicalSize = const Size(375, 667);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DesktopLoginDialog(account: account),
          ),
        ),
      );

      // Clica no botão de digitação manual
      final manualFinder = find.text('Não pode usar a câmera? Digitar chave');
      await tester.ensureVisible(manualFinder);
      await tester.pumpAndSettle();
      await tester.tap(manualFinder);
      await tester.pumpAndSettle();

      // Agora NÃO deve exibir o QR Code para economizar espaço de tela
      expect(find.byType(QrImageView), findsNothing);

      // Deve exibir o campo de digitação e botão de colar chave
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Colar Chave'), findsOneWidget);
      expect(find.text('Conectar'), findsOneWidget);

      // Deve permitir voltar para o QR Code
      await tester.tap(find.text('← Voltar para o QR Code'));
      await tester.pumpAndSettle();

      expect(find.byType(QrImageView), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
    });
  });
}
