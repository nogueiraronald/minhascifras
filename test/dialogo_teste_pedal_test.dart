import 'package:cifras_app/componentes/dialogo_teste_pedal.dart';
import 'package:cifras_app/dados/biblioteca_acordes.dart';
import 'package:cifras_app/dados/controlador_conta.dart';
import 'package:cifras_app/dados/repositorio_listas.dart';
import 'package:cifras_app/dados/repositorio_musicas.dart';
import 'package:cifras_app/dados/repositorio_temas.dart';
import 'package:cifras_app/modelos/musica.dart';
import 'package:cifras_app/servicos/servico_sincronizacao.dart';
import 'package:cifras_app/servicos/servico_supabase_sync.dart';
import 'package:cifras_app/telas/tela_principal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    MainScreen.resetNavDebounce();
  });

  testWidgets(
      'Botão "Testar pedal Bluetooth" abre o diálogo, responde aos botões e o pedal navega continuamente sem focar a busca',
      (tester) async {
    final repo = await SongRepository.open();
    final setlists = await SetlistRepository.open();
    final account = await AccountController.open();
    final themes = await ThemeRepository.open();
    final chords = await ChordLibrary.open();
    final sync = SyncService(repo, setlists, account,
        musicThemes: themes, supabaseSync: SupabaseSyncService());
    await repo.save(Song(
      id: 's1',
      title: 'A Barca',
      artist: 'Padre Zezinho',
      content: 'C G Am F\nLetra 1',
    ));
    await repo.save(Song(
      id: 's2',
      title: 'Bela Canção',
      artist: 'Artista 2',
      content: 'D A Bm G\nLetra 2',
    ));
    await repo.save(Song(
      id: 's3',
      title: 'Canto Novo',
      artist: 'Artista 3',
      content: 'E B C#m A\nLetra 3',
    ));

    await tester.binding.setSurfaceSize(const Size(1366, 768));
    await tester.pumpWidget(MaterialApp(
      home: MainScreen(
        repository: repo,
        musicThemes: themes,
        setlists: setlists,
        chords: chords,
        account: account,
        sync: sync,
      ),
    ));
    await tester.pumpAndSettle();

    // 1. Verifica que o diálogo de teste do pedal abre e responde aos toques
    final botao = find.byTooltip('Testar pedal Bluetooth');
    expect(botao, findsOneWidget);
    await tester.tap(botao);
    await tester.pumpAndSettle();

    expect(find.byType(DialogoTestePedal), findsOneWidget);
    expect(find.text('Aguardando pisada no pedal…'), findsOneWidget);

    await tester.tap(find.text('Próxima ▶'));
    await tester.pumpAndSettle();
    expect(find.text('PRÓXIMA CIFRA ▶'), findsOneWidget);
    expect(find.text('Ações reconhecidas: 1'), findsOneWidget);

    await tester.tap(find.text('Fechar'));
    await tester.pumpAndSettle();
    expect(find.byType(DialogoTestePedal), findsNothing);

    // 2. Verifica navegação contínua (1ª, 2ª e 3ª pisada) sem que o foco caia no campo de busca
    expect(find.text('1/3'), findsOneWidget);

    MainScreen.resetNavDebounce();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(find.text('2/3'), findsOneWidget);

    MainScreen.resetNavDebounce();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(find.text('3/3'), findsOneWidget);

    MainScreen.resetNavDebounce();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(find.text('2/3'), findsOneWidget);
  });
}
