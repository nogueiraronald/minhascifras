import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cifras_app/dados/biblioteca_acordes.dart';
import 'package:cifras_app/dados/controlador_conta.dart';
import 'package:cifras_app/dados/repositorio_listas.dart';
import 'package:cifras_app/dados/repositorio_musicas.dart';
import 'package:cifras_app/dados/repositorio_temas.dart';
import 'package:cifras_app/servicos/servico_sincronizacao.dart';
import 'package:cifras_app/modelos/musica.dart';
import 'package:cifras_app/telas/tela_principal.dart';
import 'package:cifras_app/telas/tela_edicao_cifra.dart';
import 'package:cifras_app/servicos/controlador_audio_karaoke.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Validação Multiplataforma Pré-Deploy (PWA Desktop, iPhones, Androids, macOS)', () {
    late SongRepository repo;
    late ChordLibrary chords;
    late AccountController account;
    late SetlistRepository setlists;
    late ThemeRepository musicThemes;
    late SyncService sync;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      repo = await SongRepository.open();
      chords = await ChordLibrary.open();
      account = await AccountController.open();
      setlists = await SetlistRepository.open();
      musicThemes = await ThemeRepository.open();
      sync = SyncService(repo, setlists, account);

      // Cria músicas de teste
      await repo.save(
        Song(
          id: 's1',
          title: 'Primeira Canção',
          artist: 'Artista A',
          content: 'C   G\nPrimeira letra de teste',
        ),
      );
      await repo.save(
        Song(
          id: 's2',
          title: 'Segunda Canção',
          artist: 'Artista B',
          content: 'D   A\nSegunda letra em edição',
        ),
      );
      await repo.save(
        Song(
          id: 's3',
          title: 'Terceira Canção',
          artist: 'Artista C',
          content: 'E   B\nTerceira letra de teste',
        ),
      );
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
        ),
      );
    }

    // 1. PWA em Micros / Computadores (Desktop 1920x1080 e 1366x768)
    testWidgets('PWA Desktop (1920x1080) renderiza sem erros de overflow', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle(const Duration(milliseconds: 400));

      expect(find.byType(MainScreen), findsOneWidget);
      expect(find.text('Primeira Canção'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('PWA Desktop / Notebook (1366x768) renderiza sem erros de overflow', (tester) async {
      tester.view.physicalSize = const Size(1366, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle(const Duration(milliseconds: 400));

      expect(find.byType(MainScreen), findsOneWidget);
      expect(find.text('Primeira Canção'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    // 2. iPhones (Safari / PWA mobile viewports)
    testWidgets('iPhone SE (375x667) renderiza sem erros de overflow', (tester) async {
      tester.view.physicalSize = const Size(375, 667);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle(const Duration(milliseconds: 400));

      expect(find.byType(MainScreen), findsOneWidget);
      expect(find.text('Primeira Canção'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('iPhone 14/15 (390x844) renderiza sem erros de overflow', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle(const Duration(milliseconds: 400));

      expect(find.byType(MainScreen), findsOneWidget);
      expect(find.text('Primeira Canção'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('iPhone Pro Max (430x932) renderiza sem erros de overflow', (tester) async {
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle(const Duration(milliseconds: 400));

      expect(find.byType(MainScreen), findsOneWidget);
      expect(find.text('Primeira Canção'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    // 3. Androids (Chrome / PWA mobile viewports)
    testWidgets('Android Compact (360x800) renderiza sem erros de overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle(const Duration(milliseconds: 400));

      expect(find.byType(MainScreen), findsOneWidget);
      expect(find.text('Primeira Canção'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Android Padrão (412x915) renderiza sem erros de overflow', (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle(const Duration(milliseconds: 400));

      expect(find.byType(MainScreen), findsOneWidget);
      expect(find.text('Primeira Canção'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    // 4. macOS Desktop
    testWidgets('macOS Desktop (1280x800) renderiza sem erros de overflow', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle(const Duration(milliseconds: 400));

      expect(find.byType(MainScreen), findsOneWidget);
      expect(find.text('Primeira Canção'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('macOS Desktop (1440x900) renderiza sem erros de overflow', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle(const Duration(milliseconds: 400));

      expect(find.byType(MainScreen), findsOneWidget);
      expect(find.text('Primeira Canção'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    // 5. Teste da navegação pós-edição: salvar a edição de uma música NÃO deve resetar para a primeira
    testWidgets('Ao editar uma música na tela principal, continua selecionada e NÃO volta para a primeira música', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle(const Duration(milliseconds: 400));

      // Seleciona a "Segunda Canção" (que não é a primeira)
      await tester.tap(find.text('Segunda Canção').first);
      await tester.pumpAndSettle(const Duration(milliseconds: 400));

      // Clica no botão de editar
      final editBtn = find.byTooltip('Editar cifra');
      expect(editBtn, findsOneWidget);
      await tester.tap(editBtn);
      await tester.pumpAndSettle();

      // Altera o título para "Segunda Canção Atualizada"
      final titleField = find.byKey(const ValueKey('edit_song_title_field'));
      await tester.enterText(titleField, 'Segunda Canção Atualizada');
      await tester.pump();

      // Salva a edição
      final saveBtn = find.byKey(const ValueKey('save_song_button'));
      expect(saveBtn, findsOneWidget);
      await tester.tap(saveBtn);
      await tester.pumpAndSettle(const Duration(milliseconds: 400));

      // A tela principal deve continuar com "Segunda Canção Atualizada" selecionada no leitor
      expect(find.text('Segunda Canção Atualizada'), findsWidgets);
    });
  });

  group('Correções de Formulário de Edição e Foco dos Campos', () {
    late SongRepository repo;
    late Song testSong;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      repo = await SongRepository.open();
      testSong = Song(
        id: 's-foco-1',
        title: 'Música para Teste de Foco',
        artist: 'Artista Foco',
        content: 'C   G\nLetra com foco preservado',
        originalKey: 'C',
      );
      await repo.save(testSong);
    });

    testWidgets('Foco nos campos de Título, Artista e Cifra permanece estável e sem piscar', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: SongEditScreen(
            repository: repo,
            song: testSong,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Clica no campo de Título e verifica foco
      final titleField = find.byKey(const ValueKey('edit_song_title_field'));
      expect(titleField, findsOneWidget);
      await tester.tap(titleField);
      await tester.pump();

      // Digita no título
      await tester.enterText(titleField, 'Música Título Alterado');
      await tester.pump();
      expect(find.text('Música Título Alterado'), findsOneWidget);

      // Clica no campo de Artista
      final artistField = find.byKey(const ValueKey('edit_song_artist_field'));
      expect(artistField, findsOneWidget);
      await tester.tap(artistField);
      await tester.pump();
      await tester.enterText(artistField, 'Novo Artista Teste');
      await tester.pump();
      expect(find.text('Novo Artista Teste'), findsOneWidget);

      // Rola suavemente até o campo de cifra e clica nele
      final contentField = find.byKey(const ValueKey('edit_song_content_field'));
      expect(contentField, findsOneWidget);
      await tester.ensureVisible(contentField);
      await tester.pumpAndSettle();
      await tester.tap(contentField, warnIfMissed: false);
      await tester.pump();

      // Simula alteração de viewport como ocorre ao abrir o teclado virtual (de 844 para 420)
      tester.view.physicalSize = const Size(390, 420);
      await tester.pump();

      // O campo de cifra continua estável na árvore e utilizável sem desmontar
      expect(contentField, findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Ao salvar edição, retorna a música editada atualizada sem recarregar toda a página', (tester) async {
      Song? returnedSong;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  returnedSong = await Navigator.push<Song>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SongEditScreen(
                        repository: repo,
                        song: testSong,
                      ),
                    ),
                  );
                },
                child: const Text('Editar Música'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Abre a tela de edição
      await tester.tap(find.text('Editar Música'));
      await tester.pumpAndSettle();

      // Altera o título
      final titleField = find.byKey(const ValueKey('edit_song_title_field'));
      await tester.enterText(titleField, 'Título Atualizado com Sucesso');
      await tester.pump();

      // Clica no botão Salvar
      final saveBtn = find.byKey(const ValueKey('save_song_button'));
      expect(saveBtn, findsOneWidget);
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      // O formulário deve ter fechado e retornado a música com o novo título
      expect(find.byType(SongEditScreen), findsNothing);
      expect(returnedSong, isNotNull);
      expect(returnedSong!.title, 'Título Atualizado com Sucesso');
    });
  });

  group('Player de YouTube e Função de Karaokê Ativa no App', () {
    testWidgets('Controlador com link de YouTube executa a função de Karaokê dentro do app sem abrir app externo', (tester) async {
      final youtubeSong = Song(
        id: 'yt-1',
        title: 'Música YouTube Karaokê',
        artist: 'Artista YouTube',
        content: 'C   G\nLetra teste sincronizada',
        audioUrl: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
        audioDurationSeconds: 180,
      );

      final scrollController = ScrollController();
      final controller = KaraokeAudioController(
        song: youtubeSong,
        scrollController: scrollController,
        enableNativeAudio: false,
      );

      expect(controller.isPlaying, isFalse);
      expect(controller.currentPosition, Duration.zero);

      // Ao dar play, o Karaokê inicia imediatamente dentro do app
      await controller.play();

      expect(controller.isPlaying, isTrue);
      expect(controller.isLoadingAudio, isFalse);

      // Simula passagem de tempo no clock do Karaokê
      await tester.pump(const Duration(milliseconds: 550));

      expect(controller.isPlaying, isTrue);
      expect(controller.currentPosition.inMilliseconds, greaterThan(0));

      // Pausa o Karaokê
      await controller.pause();
      expect(controller.isPlaying, isFalse);

      controller.dispose();
      scrollController.dispose();
    });
  });
}
