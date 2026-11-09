import 'package:cifras_app/componentes/indicador_pedal.dart';
import 'package:cifras_app/dados/biblioteca_acordes.dart';
import 'package:cifras_app/dados/controlador_conta.dart';
import 'package:cifras_app/dados/repositorio_listas.dart';
import 'package:cifras_app/dados/repositorio_musicas.dart';
import 'package:cifras_app/dados/repositorio_temas.dart';
import 'package:cifras_app/modelos/musica.dart';
import 'package:cifras_app/servicos/servico_comunidade.dart';
import 'package:cifras_app/servicos/servico_sincronizacao.dart';
import 'package:cifras_app/servicos/servico_supabase_sync.dart';
import 'package:cifras_app/telas/tela_principal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SongRepository repo;
  late SetlistRepository setlists;
  late AccountController account;
  late ThemeRepository musicThemes;
  late ChordLibrary chords;
  late SyncService sync;

  setUp(() async {
    MainScreen.resetNavDebounce();
    SharedPreferences.setMockInitialValues({});
    repo = await SongRepository.open();
    setlists = await SetlistRepository.open();
    account = await AccountController.open();
    musicThemes = await ThemeRepository.open();
    chords = await ChordLibrary.open();
    sync = SyncService(repo, setlists, account,
        musicThemes: musicThemes, supabaseSync: SupabaseSyncService());

    // Cadastra 3 músicas de teste
    await repo.save(Song(
      id: 's1',
      title: 'Música 1 Alpha',
      artist: 'Artista A',
      content: 'C G Am F\nLetra da musica 1 linha 1\nLetra linha 2',
    ));
    await repo.save(Song(
      id: 's2',
      title: 'Música 2 Beta',
      artist: 'Artista B',
      content: 'D A Bm G\nLetra da musica 2 linha 1\nLetra linha 2',
    ));
    await repo.save(Song(
      id: 's3',
      title: 'Música 3 Gamma',
      artist: 'Artista C',
      content: 'E B C#m A\nLetra da musica 3 linha 1\nLetra linha 2',
    ));
  });

  Widget buildApp() {
    return MaterialApp(
      home: MainScreen(
        repository: repo,
        chords: chords,
        account: account,
        sync: sync,
        setlists: setlists,
        musicThemes: musicThemes,
        communityService: CommunityService(),
      ),
    );
  }

  testWidgets('Pedal M-Vave Modo 2 (Setas Laterais): avança e retrocede músicas',
      (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    // Começa na primeira música (Música 1 Alpha)
    expect(find.text('Música 1 Alpha'), findsWidgets);

    // Envia seta para a direita (Pedal direito / avançar)
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    MainScreen.resetNavDebounce();

    // Deve ter avançado para Música 2 Beta
    expect(find.text('Música 2 Beta'), findsWidgets);

    // Envia numpad6 (modo teclado numérico)
    await tester.sendKeyEvent(LogicalKeyboardKey.numpad6);
    await tester.pumpAndSettle();
    MainScreen.resetNavDebounce();

    // Deve ter avançado para Música 3 Gamma
    expect(find.text('Música 3 Gamma'), findsWidgets);

    // Envia seta para a esquerda (Pedal esquerdo / retroceder)
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    MainScreen.resetNavDebounce();

    // Deve ter voltado para Música 2 Beta
    expect(find.text('Música 2 Beta'), findsWidgets);

    // Envia numpad4 (modo teclado numérico)
    await tester.sendKeyEvent(LogicalKeyboardKey.numpad4);
    await tester.pumpAndSettle();
    MainScreen.resetNavDebounce();

    // Deve ter voltado para Música 1 Alpha
    expect(find.text('Música 1 Alpha'), findsWidgets);
  });

  testWidgets('Pedal M-Vave Modo 1 e 3 (PageDown/ArrowDown): avança música quando atinge o fim ou sem scroll',
      (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    expect(find.text('Música 1 Alpha'), findsWidgets);

    // Música curta (sem scroll suficiente): pisar no PageDown avança diretamente de música
    await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
    await tester.pumpAndSettle();

    expect(find.text('Música 2 Beta'), findsWidgets);

    // Pressionar seta para baixo (ArrowDown / Modo 3)
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();

    expect(find.text('Música 3 Gamma'), findsWidgets);

    // Pressionar seta para cima (ArrowUp / Modo 3)
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();

    expect(find.text('Música 2 Beta'), findsWidgets);

    // Pressionar PageUp (Modo 1)
    await tester.sendKeyEvent(LogicalKeyboardKey.pageUp);
    await tester.pumpAndSettle();

    expect(find.text('Música 1 Alpha'), findsWidgets);
  });

  testWidgets('Pedal M-Vave Modo 4 (Espaço e Enter): avança e retrocede músicas',
      (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    expect(find.text('Música 1 Alpha'), findsWidgets);

    // Pedal direito (Space no modo 4): avança
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();

    expect(find.text('Música 2 Beta'), findsWidgets);

    // Pedal esquerdo (Enter no modo 4): retrocede
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(find.text('Música 1 Alpha'), findsWidgets);
  });

  testWidgets('Digitação em campo de pesquisa NÃO dispara navegação de pedal',
      (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    expect(find.text('Música 1 Alpha'), findsWidgets);

    // Clica no campo de busca para dar foco no TextField
    final searchFinder = find.byType(TextField).first;
    await tester.tap(searchFinder);
    await tester.pumpAndSettle();

    // Pressiona seta para a direita enquanto está digitando
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();

    // Não deve mudar de música pois o usuário está editando texto
    expect(find.text('Música 1 Alpha'), findsWidgets);
  });

  testWidgets('Pedal exibe feedback visual na tela (indicador com seta de direção grande)',
      (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    expect(find.byType(IndicadorPedalOverlay), findsOneWidget);

    // Envia comando de avançar
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    // Dá um pump curto (sem settle para não esperar o timer de 650ms sumir)
    await tester.pump(const Duration(milliseconds: 50));

    // O ícone de seta para a direita deve estar presente no HUD
    expect(find.byIcon(Icons.arrow_forward_rounded), findsOneWidget);

    // Espera o HUD desaparecer após 650ms e aguarda a janela de debounce
    await tester.pumpAndSettle();
    MainScreen.resetNavDebounce();

    // Envia comando de retroceder
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump(const Duration(milliseconds: 50));

    // O ícone de seta para a esquerda deve estar presente no HUD
    expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
    await tester.pumpAndSettle();
  });

  testWidgets('Proteção contra saltos múltiplos: disparos rápidos seguidos avançam apenas 1 música por vez',
      (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    // Começa na primeira música (Música 1 Alpha)
    expect(find.text('Letra da musica 1 linha 1'), findsOneWidget);

    // Dispara 3 vezes rapidamente em sucessão imediata (simulando bounce de pedal ou múltiplos listeners)
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();

    // Deve avançar rigorosamente apenas 1 música (Música 2 Beta), e NÃO pular para a 3
    expect(find.text('Letra da musica 2 linha 1'), findsOneWidget);
    expect(find.text('Letra da musica 3 linha 1'), findsNothing);
  });
}

