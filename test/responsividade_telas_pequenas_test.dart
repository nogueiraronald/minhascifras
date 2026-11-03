import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cifras_app/componentes/dialogo_nome.dart';
import 'package:cifras_app/componentes/dialogo_importar_link.dart';
import 'package:cifras_app/telas/tela_edicao_cifra.dart';
import 'package:cifras_app/dados/repositorio_musicas.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('askName (Novo Tema / Estilo) renders on small device (320px) without overflow', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () {
                  askName(
                    context,
                    title: 'Novo Tema / Estilo',
                    hint: 'Ex: Adoração, Louvor...',
                    actionLabel: 'Criar Tema',
                    icon: Icons.folder_rounded,
                  );
                },
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open Dialog'));
    await tester.pumpAndSettle();

    // Verify dialog rendered and action buttons fit without overflow
    expect(find.text('Novo Tema / Estilo'), findsOneWidget);
    expect(find.text('Criar Tema'), findsOneWidget);
    expect(find.text('Cancelar'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('askName (Nova Lista) renders on small device (320px) without overflow', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () {
                  askName(
                    context,
                    title: 'Nova Lista',
                    hint: 'Ex: Culto de Domingo...',
                    actionLabel: 'Criar Lista',
                    icon: Icons.queue_music_rounded,
                  );
                },
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open Dialog'));
    await tester.pumpAndSettle();

    expect(find.text('Nova Lista'), findsOneWidget);
    expect(find.text('Criar Lista'), findsOneWidget);
    expect(find.text('Cancelar'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ImportLinkDialog renders on small device (320px) without overflow', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ImportLinkDialog(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Importar Cifra da Internet'), findsOneWidget);
    expect(find.text('Importar Cifra'), findsOneWidget);
    expect(find.text('Cancelar'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('SongEditScreen renders on small device (320px) without overflow', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final repo = await SongRepository.open();

    tester.view.physicalSize = const Size(320, 520);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    FlutterErrorDetails? caughtDetails;
    final originalOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      caughtDetails = details;
    };

    await tester.pumpWidget(
      MaterialApp(
        home: SongEditScreen(repository: repo),
      ),
    );
    await tester.pumpAndSettle();

    FlutterError.onError = originalOnError;

    expect(caughtDetails, isNull);
    expect(find.text('Naturais'), findsOneWidget);
    expect(find.byType(TextField), findsWidgets);
  });
}
