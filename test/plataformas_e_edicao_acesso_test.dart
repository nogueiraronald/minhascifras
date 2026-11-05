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
import 'package:cifras_app/servicos/servico_wakelock.dart';
import 'package:cifras_app/componentes/player_youtube_embutido.dart';
import 'package:cifras_app/componentes/barra_player_karaoke.dart';
import 'package:cifras_app/servicos/dados_nuvem.dart';
import 'package:cifras_app/servicos/servico_supabase_sync.dart';

class _FakeSupabaseSync extends SupabaseSyncService {
  CloudData remoteData = const CloudData();
  CloudData? lastWrittenData;

  @override
  Future<CloudData> readAll(String syncCode) async => remoteData;

  @override
  Future<void> writeAll(String syncCode, CloudData data) async {
    remoteData = data;
    lastWrittenData = data;
  }
}

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
      await tester.pump();
      await controller.pause();
      expect(controller.isPlaying, isFalse);

      controller.dispose();
      scrollController.dispose();
    });

    testWidgets('Mini player pode ser redimensionado e alterado de local (arrastado ou trocado de canto)', (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                PlayerYoutubeEmbutido(
                  videoId: 'dQw4w9WgXcQ',
                  initialRight: 12,
                  initialBottom: 8,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final cardFinder = find.byKey(const ValueKey('mini_player_card'));
      expect(cardFinder, findsOneWidget);

      final initialRect = tester.getRect(cardFinder);
      expect(initialRect.width, closeTo(290.0, 1.0));

      // 1. Redimensionar pelo botão (+)
      final expandBtn = find.byKey(const ValueKey('mini_player_expand_btn'));
      await tester.tap(expandBtn);
      await tester.pumpAndSettle();

      final expandedRect = tester.getRect(cardFinder);
      expect(expandedRect.width, closeTo(330.0, 1.0));

      // 2. Redimensionar pelo botão (-)
      final shrinkBtn = find.byKey(const ValueKey('mini_player_shrink_btn'));
      await tester.tap(shrinkBtn);
      await tester.tap(shrinkBtn);
      await tester.pumpAndSettle();

      final shrunkRect = tester.getRect(cardFinder);
      expect(shrunkRect.width, closeTo(250.0, 1.0));

      // 3. Alterar de local arrastando a barra superior
      final headerFinder = find.byKey(const ValueKey('mini_player_drag_header'));
      final beforeDragCenter = tester.getCenter(cardFinder);
      await tester.drag(headerFinder, const Offset(-150, -120));
      await tester.pumpAndSettle();

      final afterDragCenter = tester.getCenter(cardFinder);
      expect(afterDragCenter.dx, lessThan(beforeDragCenter.dx - 100));
      expect(afterDragCenter.dy, lessThan(beforeDragCenter.dy - 80));

      // 4. Alterar de canto pelo botão de mudar local
      final moveCornerBtn = find.byKey(const ValueKey('mini_player_move_corner_btn'));
      await tester.tap(moveCornerBtn);
      await tester.pumpAndSettle();

      final afterCornerCenter = tester.getCenter(cardFinder);
      expect(afterCornerCenter, isNot(equals(afterDragCenter)));
    });

    testWidgets('Proteção de bloqueio de tela (WakeLock) fica ativa durante exibição das cifras', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final repo = await SongRepository.open();
      final chords = await ChordLibrary.open();
      final account = await AccountController.open();
      final setlists = await SetlistRepository.open();
      final musicThemes = await ThemeRepository.open();
      final sync = SyncService(repo, setlists, account);

      await repo.save(
        Song(
          id: 'wake-1',
          title: 'Música Tela Ativa',
          artist: 'Artista',
          content: 'C G Am F\nLetra da cifra exibida',
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: MainScreen(
            repository: repo,
            chords: chords,
            account: account,
            sync: sync,
            setlists: setlists,
            musicThemes: musicThemes,
          ),
        ),
      );
      await tester.pumpAndSettle(const Duration(milliseconds: 400));

      expect(ServicoWakeLock.estaAtivo, isTrue);
    });

    testWidgets('Linha com os acordes na edição de cifras não perde foco nem função ao arrastar para o lado no celular', (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final repo = await SongRepository.open();
      final song = Song(
        id: 'edit-chord-drag-1',
        title: 'Música Edição Mobile',
        artist: 'Artista Mobile',
        content: 'Primeira linha\nSegunda linha',
      );
      await repo.save(song);

      await tester.pumpWidget(
        MaterialApp(
          home: SongEditScreen(
            repository: repo,
            song: song,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final contentFieldFinder = find.byKey(const ValueKey('edit_song_content_field'));
      await tester.ensureVisible(contentFieldFinder);
      await tester.pumpAndSettle();
      await tester.tap(contentFieldFinder);
      await tester.pump();

      // Posiciona o cursor no início do texto (offset 0)
      final textField = tester.widget<TextField>(contentFieldFinder);
      textField.controller!.selection = const TextSelection.collapsed(offset: 0);
      await tester.pump();

      // Muda para a categoria "Com 7ª" e arrasta a linha de acordes para o lado no celular
      await tester.tap(find.text('Com 7ª'));
      await tester.pumpAndSettle();

      final chordScrollFinder = find.byKey(const ValueKey('chord_buttons_scroll'));
      expect(chordScrollFinder, findsOneWidget);

      // Arrasta para o lado (esquerda) na linha de acordes
      await tester.drag(chordScrollFinder, const Offset(-140, 0));
      await tester.pumpAndSettle();

      // Toca em um acorde após ter arrastado para o lado
      final chordChip = find.byKey(const ValueKey('chord_chip_Am7'));
      expect(chordChip, findsOneWidget);
      await tester.tap(chordChip);
      await tester.pump();

      // Verifica que o acorde foi inserido exatamente na posição do cursor (início do texto), sem perder o uso!
      expect(textField.controller!.text.startsWith('Am7 '), isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Remoção do link salva com sucesso, remove o player da exibição e sincroniza null no Supabase', (tester) async {
      SharedPreferences.setMockInitialValues({
        'supabase_sync_code': 'MC-LINKRM1',
      });
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final repo = await SongRepository.open();
      final chords = await ChordLibrary.open();
      final account = await AccountController.open();
      final setlists = await SetlistRepository.open();
      final musicThemes = await ThemeRepository.open();
      final fakeSupabase = _FakeSupabaseSync();

      final initialSong = Song(
        id: 'barca-1',
        title: 'A Barca',
        artist: 'Padre Zezinho',
        originalKey: 'D',
        content: 'D A/C# Bm\nTu, te abeiraste da praia',
        audioUrl: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
        audioDurationSeconds: 210,
      );
      fakeSupabase.remoteData = CloudData(songs: [initialSong]);
      await repo.save(initialSong);

      final sync = SyncService(repo, setlists, account, supabaseSync: fakeSupabase);

      await tester.pumpWidget(
        MaterialApp(
          home: MainScreen(
            repository: repo,
            chords: chords,
            account: account,
            sync: sync,
            setlists: setlists,
            musicThemes: musicThemes,
          ),
        ),
      );
      await tester.pumpAndSettle(const Duration(milliseconds: 500));

      // Confirma que inicialmente o mini player e a barra de karaokê estão visíveis na exibição
      expect(find.byType(PlayerYoutubeEmbutido), findsOneWidget);
      expect(find.byType(BarraPlayerKaraoke), findsOneWidget);

      // Abre a tela de edição da cifra atual
      await tester.tap(find.byTooltip('Editar cifra'));
      await tester.pumpAndSettle();

      expect(find.byType(SongEditScreen), findsOneWidget);

      // Remove o link clicando no botão de limpar/remover link
      final removeLinkBtn = find.byKey(const ValueKey('remove_audio_link_btn'));
      await tester.ensureVisible(removeLinkBtn);
      await tester.pumpAndSettle();
      await tester.tap(removeLinkBtn);
      await tester.pumpAndSettle();

      // Salva a cifra
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle(const Duration(milliseconds: 600));

      // 1. Verifica que o link foi removido do repositório local
      final updatedInRepo = repo.songs.firstWhere((s) => s.id == 'barca-1');
      expect(updatedInRepo.audioUrl, isNull);
      expect(updatedInRepo.audioDurationSeconds, isNull);
      expect(updatedInRepo.hasAudio, isFalse);

      // 2. Verifica que o mini player e a barra de áudio sumiram imediatamente da exibição
      expect(find.byType(PlayerYoutubeEmbutido), findsNothing);
      expect(find.byType(BarraPlayerKaraoke), findsNothing);

      // 3. Verifica que a remoção foi enviada ao Supabase com audioUrl == null
      expect(fakeSupabase.lastWrittenData, isNotNull);
      final syncedSong = fakeSupabase.lastWrittenData!.songs.firstWhere((s) => s.id == 'barca-1');
      expect(syncedSong.audioUrl, isNull);
      expect(syncedSong.audioDurationSeconds, isNull);
      expect(syncedSong.toJson()['audioUrl'], isNull);
    });
  });
}
