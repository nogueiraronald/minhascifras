import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../servicos/recarregador_pagina.dart';

import '../dados/controlador_conta.dart';
import '../dados/biblioteca_acordes.dart';
import '../dados/repositorio_listas.dart';
import '../dados/repositorio_musicas.dart';
import '../modelos/lista_repertorio.dart';
import '../modelos/item_lista_repertorio.dart';
import '../modelos/musica.dart';
import '../modelos/musica_comunidade.dart';
import '../servicos/transpositor_acordes.dart';
import '../dados/controlador_tema.dart';
import '../dados/repositorio_temas.dart';
import '../servicos/servico_exportacao.dart';
import '../servicos/servico_sincronizacao.dart';
import '../componentes/botao_conta.dart';
import '../componentes/logo_aplicativo.dart';
import '../componentes/dialogo_acordes.dart';
import '../componentes/visualizador_cifra.dart';
import '../componentes/dialogo_nome.dart';
import '../componentes/seletor_musicas.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../componentes/dialogo_login_desktop.dart';
import '../componentes/dialogo_desbloqueio_conta.dart';
import '../componentes/visualizador_letra.dart';
import '../componentes/visualizador_partitura.dart';
import 'tela_edicao_cifra.dart';
import '../componentes/estilo_app.dart';
import '../servicos/controlador_audio_karaoke.dart';
import '../componentes/barra_player_karaoke.dart';
import '../componentes/player_youtube_embutido.dart';
import '../servicos/servico_atualizacao_pwa.dart';
import '../servicos/servico_comunidade.dart';
import '../servicos/servico_wakelock.dart';
import '../componentes/indicador_pedal.dart';
import '../servicos/servico_pedal_bridge.dart';
import 'tela_comunidade.dart';

/// Modos de exibição da música: Cifra completa, Letra pura ou Partitura musical.
enum SongDisplayMode {
  chords,
  lyrics,
  score,
}

class MainScreen extends StatefulWidget {
  const MainScreen({
    super.key,
    required this.repository,
    required this.chords,
    required this.account,
    required this.sync,
    required this.setlists,
    required this.musicThemes,
    this.theme,
    this.communityService,
  });

  final SongRepository repository;
  final ChordLibrary chords;
  final AccountController account;
  final SyncService sync;
  final SetlistRepository setlists;
  final ThemeRepository musicThemes;
  final ThemeController? theme;
  final CommunityService? communityService;

  /// Utilizado em testes automatizados para resetar o debounce entre asserções
  @visibleForTesting
  static void resetNavDebounce() {
    _MainScreenState.resetNavDebounce();
  }

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  // 0 = Todas as Músicas, 1 = Favoritas, 2 = Setlists, 3 = Temas
  int _tabIndex = 0;
  Setlist? _selectedSetlist;
  String? _selectedTheme;

  // Busca de Músicas
  final _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode(
    debugLabel: 'SearchFieldFocus',
    skipTraversal: true,
  );
  String _searchQuery = '';

  // Busca de Temas
  final _themeSearchController = TextEditingController();
  final FocusNode _themeSearchFocusNode = FocusNode(
    debugLabel: 'ThemeSearchFieldFocus',
    skipTraversal: true,
  );
  String _themeSearchQuery = '';
  final ScrollController _themesListController = ScrollController();

  // Busca de Listas
  final _setlistSearchController = TextEditingController();
  final FocusNode _setlistSearchFocusNode = FocusNode(
    debugLabel: 'SetlistSearchFieldFocus',
    skipTraversal: true,
  );
  String _setlistSearchQuery = '';
  final ScrollController _setlistsListController = ScrollController();

  // Comunidade: Cifras compartilhadas pelo usuário atual
  late final CommunityService _communityService =
      widget.communityService ?? CommunityService();
  List<CommunitySong> _mySharedSongs = [];
  bool _isLoadingSharedSongs = false;
  bool _isSharedSectionExpanded = true;
  final ScrollController _mySharedScrollCtrl = ScrollController();

  // Seleção e visualização da cifra
  Song? _currentSong;
  SetlistItem? _currentSetlistItem;
  int _transpose = 0;

  // Modo de visualização: Cifra (padrão), Letra (pura) ou Partitura (pauta musical)
  SongDisplayMode _displayMode = SongDisplayMode.chords;

  // Chaves de persistência offline (SharedPreferences)
  static const String _prefKeyFontSize = 'user_reader_font_size_v1';
  static const String _prefKeySpeed = 'user_reader_scroll_speed_v1';
  static const String _prefKeyDisplayMode = 'user_reader_display_mode_v1';

  // Leitor
  final FocusNode _mainFocusNode =
      FocusNode(debugLabel: 'MainScreenReaderFocus');
  ScrollController _scrollController = ScrollController();
  final List<ScrollController> _retiredControllers = [];
  final List<Timer> _retireTimers = [];
  final FocusNode _sliderFocusNode =
      FocusNode(canRequestFocus: false, skipTraversal: true);
  final ControladorIndicadorPedal _pedalHudController =
      ControladorIndicadorPedal();
  Timer? _scrollTimer;
  double _fontSize = 17;
  double _speed = 20; // pixels por segundo
  bool _isPlaying = false;

  // Player de Áudio & Karaokê Sincronizado
  KaraokeAudioController? _karaokeController;
  bool _showKaraokePlayer = true;
  bool _showYoutubeVideo = true;

  void _initKaraokeController(Song? song) {
    _karaokeController?.dispose();
    _karaokeController = null;
    if (song != null && song.hasAudio) {
      _showYoutubeVideo = true;
      _showKaraokePlayer = true;
      _karaokeController = KaraokeAudioController(
        song: song,
        scrollController: _scrollController,
      );
    } else {
      _showYoutubeVideo = false;
      _showKaraokePlayer = false;
    }
  }

  // Barra Lateral: Scroll da lista e índice alfabético
  final ScrollController _sidebarSongListController = ScrollController();
  String? _activeInitialBubble;
  Timer? _bubbleTimer;

  // Modo Limpo / Barra Lateral
  bool _showSidebar = true;

  // Transição ao arrastar para os lados
  int _navDirection = 1;
  double _horizontalDragDistance = 0;

  bool _isUnlockDialogShowing = false;

  void _checkAccountLock() {
    if (widget.account.isLocked && mounted && !_isUnlockDialogShowing) {
      _isUnlockDialogShowing = true;
      DialogoDesbloqueioConta.show(context, widget.account, widget.sync)
          .then((_) {
        _isUnlockDialogShowing = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleGlobalKeyEvent);
    ServicoPedalBridge.registrar(_handleBridgePedalAction);
    ServicoWakeLock.manterTelaAtiva(true);
    _loadUserPreferences();
    widget.account.addListener(_checkAccountLock);
    widget.account.addListener(_loadMySharedSongs);
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
    _themeSearchController.addListener(() {
      setState(() {
        _themeSearchQuery = _themeSearchController.text.trim().toLowerCase();
      });
    });
    _setlistSearchController.addListener(() {
      setState(() {
        _setlistSearchQuery = _setlistSearchController.text.trim().toLowerCase();
      });
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await widget.repository.sanitizeSongMetadata();
      final activeSongIds = widget.repository.songs.map((s) => s.id);
      widget.setlists.cleanupOrphanedItems(activeSongIds);
      _ensureFirstSongSelected();
      _checkAccountLock();
      _loadMySharedSongs();
      ServicoAtualizacaoPwa.verificarEForcarAtualizacaoAoIniciar();
    });
  }

  @override
  void dispose() {
    ServicoPedalBridge.desregistrar(_handleBridgePedalAction);
    _pedalHudController.dispose();
    HardwareKeyboard.instance.removeHandler(_handleGlobalKeyEvent);
    ServicoWakeLock.manterTelaAtiva(false);
    widget.account.removeListener(_checkAccountLock);
    widget.account.removeListener(_loadMySharedSongs);
    _karaokeController?.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _themeSearchController.dispose();
    _themeSearchFocusNode.dispose();
    _themesListController.dispose();
    _setlistSearchController.dispose();
    _setlistSearchFocusNode.dispose();
    _setlistsListController.dispose();
    _mySharedScrollCtrl.dispose();
    _scrollTimer?.cancel();
    _bubbleTimer?.cancel();
    _sidebarSongListController.dispose();
    for (final t in _retireTimers) {
      t.cancel();
    }
    _retireTimers.clear();
    for (final c in _retiredControllers) {
      c.dispose();
    }
    _retiredControllers.clear();
    _scrollController.dispose();
    _sliderFocusNode.dispose();
    _mainFocusNode.dispose();
    super.dispose();
  }

  /// Garante que o app abra na primeira música disponível
  void _ensureFirstSongSelected() {
    final songs = _getVisibleSongs();
    if (songs.isNotEmpty) {
      if (_currentSong == null || !songs.any((s) => s.id == _currentSong!.id)) {
        _selectSong(songs.first);
      } else {
        ServicoWakeLock.manterTelaAtiva(true);
      }
    } else {
      setState(() {
        _currentSong = null;
        _currentSetlistItem = null;
        _transpose = 0;
      });
      _initKaraokeController(null);
      ServicoWakeLock.manterTelaAtiva(false);
    }
  }

  List<Song> _getVisibleSongs() {
    final all = widget.repository.songs;

    List<Song> baseList;
    if (_tabIndex == 2 && _selectedSetlist != null) {
      final items = widget.setlists.itemsFor(_selectedSetlist!.id);
      final songMap = {for (final s in all) s.id: s};
      baseList = [
        for (final item in items)
          if (songMap[item.songId] != null) songMap[item.songId]!,
      ];
    } else if (_tabIndex == 1) {
      // Modo Favoritas
      baseList = all.where((s) => s.isFavorite).toList();
    } else if (_tabIndex == 3 && _selectedTheme != null) {
      // Modo Temas com tema selecionado
      final tLower = _selectedTheme!.toLowerCase().trim();
      baseList = all
          .where((s) => s.tags.any((t) => t.toLowerCase().trim() == tLower))
          .toList();
    } else {
      baseList = all; // Já vem em ordem alfabética do repository
    }

    if (_searchQuery.isEmpty) {
      return baseList;
    }

    // Busca por Nome da música, Artista, Letra/Cifra e Temas
    return baseList.where((s) {
      final titleMatch = s.title.toLowerCase().contains(_searchQuery);
      final artistMatch = s.artist.toLowerCase().contains(_searchQuery);
      final contentMatch = s.content.toLowerCase().contains(_searchQuery);
      final themeMatch =
          s.tags.any((t) => t.toLowerCase().contains(_searchQuery));
      return titleMatch || artistMatch || contentMatch || themeMatch;
    }).toList();
  }

  void _selectSong(Song song) {
    _stopScroll();

    SetlistItem? item;
    int songTranspose = 0;

    if (_tabIndex == 2 && _selectedSetlist != null) {
      final items = widget.setlists.itemsFor(_selectedSetlist!.id);
      final found = items.where((it) => it.songId == song.id);
      if (found.isNotEmpty) {
        item = found.first;
        songTranspose = item.transpose;
      }
    }

    if (_currentSong?.id != song.id) {
      final oldController = _scrollController;
      _retiredControllers.add(oldController);
      _scrollController = ScrollController();
      Timer? retireTimer;
      retireTimer = Timer(const Duration(milliseconds: 350), () {
        _retireTimers.remove(retireTimer);
        if (_retiredControllers.remove(oldController)) {
          oldController.dispose();
        }
      });
      _retireTimers.add(retireTimer);
    }

    setState(() {
      _currentSong = song;
      _currentSetlistItem = item;
      _transpose = songTranspose;
    });

    ServicoWakeLock.manterTelaAtiva(true);
    _initKaraokeController(song);

    // Garante que nenhuma caixa de busca retenha o foco ao selecionar cifra
    _searchFocusNode.unfocus();
    _themeSearchFocusNode.unfocus();
    _setlistSearchFocusNode.unfocus();
    _mainFocusNode.requestFocus();
    ServicoPedalBridge.reassumirFoco();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients &&
          _scrollController.positions.length == 1) {
        _scrollController.jumpTo(0);
      }
      _scrollToSelectedSongInSidebar(song.id);
    });
  }

  void _scrollToSelectedSongInSidebar(String songId) {
    if (!_sidebarSongListController.hasClients) return;
    final visible = _getVisibleSongs();
    final idx = visible.indexWhere((s) => s.id == songId);
    if (idx < 0) return;
    final targetOffset = (idx * 48.0).clamp(
      0.0,
      _sidebarSongListController.position.maxScrollExtent,
    );
    _sidebarSongListController.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _editCurrentSong() async {
    if (_currentSong == null) return;
    final savedSong = await Navigator.push<Song>(
      context,
      MaterialPageRoute(
        builder: (_) => SongEditScreen(
          repository: widget.repository,
          musicThemes: widget.musicThemes,
          song: _currentSong,
        ),
      ),
    );
    final targetId = savedSong?.id ?? _currentSong?.id;
    if (targetId != null && mounted) {
      final fresh =
          widget.repository.allSongs.where((s) => s.id == targetId);
      if (fresh.isNotEmpty) {
        final updated = fresh.first;
        setState(() {
          _currentSong = updated;
          _initKaraokeController(updated);
        });
      }
      if (savedSong != null) {
        unawaited(widget.sync.sync());
      }
    }
  }

  void _showSpeedDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          return CartaoDialogoModerno(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const BadgeIconeGradiente(
                      icon: Icons.speed_rounded,
                      size: 44,
                      iconSize: 22,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Velocidade da Rolagem',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Ajuste o ritmo do rolamento automático',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Center(
                  child: ShaderMask(
                    shaderCallback: (bounds) =>
                        AppCores.gradienteBotao.createShader(bounds),
                    child: Text(
                      '${_speed.toInt()} px/s',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Slider(
                  activeColor: AppCores.roxo,
                  inactiveColor: AppCores.roxo.withValues(alpha: 0.2),
                  focusNode: FocusNode(canRequestFocus: false),
                  value: _speed,
                  min: 5,
                  max: 120,
                  onChanged: (v) {
                    setDialogState(() {});
                    _updateSpeed(v);
                  },
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    ChoiceChip(
                      label: const Text('Lenta (15)'),
                      selected: (_speed.toInt() == 15),
                      selectedColor: AppCores.roxo.withValues(alpha: 0.18),
                      onSelected: (_) {
                        setDialogState(() {});
                        _updateSpeed(15);
                      },
                    ),
                    ChoiceChip(
                      label: const Text('Média (35)'),
                      selected: (_speed.toInt() == 35),
                      selectedColor: AppCores.roxo.withValues(alpha: 0.18),
                      onSelected: (_) {
                        setDialogState(() {});
                        _updateSpeed(35);
                      },
                    ),
                    ChoiceChip(
                      label: const Text('Rápida (65)'),
                      selected: (_speed.toInt() == 65),
                      selectedColor: AppCores.roxo.withValues(alpha: 0.18),
                      onSelected: (_) {
                        setDialogState(() {});
                        _updateSpeed(65);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    BotaoGradiente(
                      onPressed: () => Navigator.pop(ctx),
                      label: 'Concluir',
                      icon: Icons.check_rounded,
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Altera o tom da música.
  /// - Se estiver em uma Setlist: altera APENAS na setlist específica, mantendo o original intacto.
  /// - Se estiver na Lista Geral (ou Favoritas/Temas): altera a música permanentemente e salva local e na nuvem.
  Future<void> _changeTranspose(int delta) async {
    if (_currentSetlistItem != null) {
      final newTranspose = _transpose + delta;
      setState(() {
        _transpose = newTranspose;
      });
      widget.setlists.setTranspose(_currentSetlistItem!.id, newTranspose);
      return;
    }

    if (_currentSong == null || delta == 0) return;

    final song = _currentSong!;
    final newContent = ChordTransposer.transposeContent(song.content, delta);
    final newKey = ChordTransposer.detectKey(newContent) ??
        (song.originalKey.isNotEmpty
            ? ChordTransposer.transposeChord(song.originalKey, delta)
            : '');

    final updated = song.copyWith(
      content: newContent,
      originalKey: newKey.isNotEmpty ? newKey : null,
    );

    setState(() {
      _currentSong = updated;
      _transpose = 0;
    });

    await widget.repository.save(updated);
  }

  void _resetTranspose() {
    setState(() {
      _transpose = 0;
    });
    if (_currentSetlistItem != null) {
      widget.setlists.setTranspose(_currentSetlistItem!.id, 0);
    }
  }

  // --- Auto-Scroll ---
  void _startScroll() {
    _scrollTimer?.cancel();
    _scrollTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (!_scrollController.hasClients ||
          _scrollController.positions.length != 1) {
        return;
      }
      final max = _scrollController.position.maxScrollExtent;
      final next = _scrollController.offset + _speed * 0.05;
      if (next >= max) {
        _scrollController.jumpTo(max);
        _stopScroll();
      } else {
        _scrollController.jumpTo(next);
      }
    });
    setState(() => _isPlaying = true);
  }

  void _stopScroll() {
    _scrollTimer?.cancel();
    if (mounted && _isPlaying) {
      setState(() => _isPlaying = false);
    }
  }

  void _scrollBy(double delta) {
    if (!_scrollController.hasClients ||
        _scrollController.positions.length != 1) {
      return;
    }
    final pos = _scrollController.position;
    final target = (pos.pixels + delta).clamp(0.0, pos.maxScrollExtent);
    _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
    );
  }

  bool _isTextEditingFocused() {
    if (_searchFocusNode.hasFocus ||
        _themeSearchFocusNode.hasFocus ||
        _setlistSearchFocusNode.hasFocus) {
      return true;
    }
    final focus = FocusManager.instance.primaryFocus;
    if (focus == null) return false;
    final context = focus.context;
    if (context == null) return false;
    if (context.widget is EditableText) return true;
    if (context.findAncestorWidgetOfExactType<EditableText>() != null) {
      return true;
    }
    return false;
  }

  /// Carrega as preferências locais do usuário offline (tamanho da fonte, velocidade e modo de exibição)
  Future<void> _loadUserPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedFontSize = prefs.getDouble(_prefKeyFontSize);
      final savedSpeed = prefs.getDouble(_prefKeySpeed);
      final savedMode = prefs.getString(_prefKeyDisplayMode);
      if (!mounted) return;
      setState(() {
        if (savedFontSize != null &&
            savedFontSize >= 10 &&
            savedFontSize <= 40) {
          _fontSize = savedFontSize;
        }
        if (savedSpeed != null && savedSpeed >= 5 && savedSpeed <= 120) {
          _speed = savedSpeed;
        }
        if (savedMode != null) {
          _displayMode = SongDisplayMode.values.firstWhere(
            (m) => m.name == savedMode,
            orElse: () => SongDisplayMode.chords,
          );
        }
      });
    } catch (_) {}
  }

  /// Altera o tamanho da fonte e persiste offline no dispositivo do usuário
  void _updateFontSize(double newSize) {
    final clamped = newSize.clamp(10.0, 36.0);
    setState(() => _fontSize = clamped);
    SharedPreferences.getInstance().then((prefs) {
      prefs.setDouble(_prefKeyFontSize, clamped);
    }).catchError((_) {});
  }

  /// Altera a velocidade de rolagem e persiste offline
  void _updateSpeed(double newSpeed) {
    final clamped = newSpeed.clamp(5.0, 120.0);
    setState(() => _speed = clamped);
    SharedPreferences.getInstance().then((prefs) {
      prefs.setDouble(_prefKeySpeed, clamped);
    }).catchError((_) {});
  }

  /// Altera o modo de exibição (Cifra, Letra ou Partitura) e salva a escolha offline
  void _setDisplayMode(SongDisplayMode mode) {
    setState(() => _displayMode = mode);
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString(_prefKeyDisplayMode, mode.name);
    }).catchError((_) {});
  }

  /// Constrói o corpo da música de acordo com o modo escolhido: Cifra, Letra pura ou Partitura
  Widget _buildSongView() {
    if (_currentSong == null) return const SizedBox.shrink();

    // Se houver controlador de áudio & Karaokê, escuta mudanças de posição em tempo real
    if (_karaokeController != null) {
      return ListenableBuilder(
        listenable: _karaokeController!,
        builder: (context, _) {
          final isPlayingOrStarted = _karaokeController!.isPlaying ||
              _karaokeController!.currentPosition > Duration.zero;
          final progress = isPlayingOrStarted ? _karaokeController!.progress : null;
          final activeChordIndex = isPlayingOrStarted ? _karaokeController!.activeChordLineIndex : null;
          final activeLyricsIndex = isPlayingOrStarted ? _karaokeController!.activeLyricsLineIndex : null;

          return _buildModeContent(
            progress: progress,
            activeChordIndex: activeChordIndex,
            activeLyricsIndex: activeLyricsIndex,
            onSeekProgress: (p) => _karaokeController?.seekProgress(p),
          );
        },
      );
    }

    return _buildModeContent();
  }

  Widget _buildModeContent({
    double? progress,
    int? activeChordIndex,
    int? activeLyricsIndex,
    void Function(double progress)? onSeekProgress,
  }) {
    switch (_displayMode) {
      case SongDisplayMode.chords:
        return ChordSheetView(
          content: _currentSong!.content,
          transpose: _transpose,
          fontSize: _fontSize,
          controller: _scrollController,
          playbackProgress: progress,
          activeLineIndex: activeChordIndex,
          autoScroll: _karaokeController?.isAutoScrollEnabled ?? true,
          onSeekProgress: onSeekProgress,
          onChordTap: (chord) => showChordDialog(context, widget.chords, chord),
        );
      case SongDisplayMode.lyrics:
        return LyricsView(
          content: _currentSong!.content,
          fontSize: _fontSize,
          controller: _scrollController,
          playbackProgress: progress,
          activeLineIndex: activeLyricsIndex,
          autoScroll: _karaokeController?.isAutoScrollEnabled ?? true,
          onSeekProgress: onSeekProgress,
        );
      case SongDisplayMode.score:
        return ScoreSheetView(
          content: _currentSong!.content,
          transpose: _transpose,
          fontSize: _fontSize,
          controller: _scrollController,
          onChordTap: (chord) => showChordDialog(context, widget.chords, chord),
        );
    }
  }

  /// Barra com seletor elegante de modos: [ 🎸 Cifra ] [ 📝 Letra ] [ 🎼 Partitura ]
  Widget _buildDisplayModeBar(bool isMobile) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 8 : 16,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(
            bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.15))),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: isMobile ? Alignment.center : Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 30,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildModeButton(
                      SongDisplayMode.chords, 'Cifra', Icons.music_note),
                  _buildModeButton(SongDisplayMode.lyrics, 'Letra',
                      Icons.text_snippet_outlined),
                  _buildModeButton(SongDisplayMode.score, 'Partitura',
                      Icons.auto_stories_outlined),
                ],
              ),
            ),
            if (!isMobile) ...[
              const SizedBox(width: 14),
              Text(
                _displayMode == SongDisplayMode.chords
                    ? ''
                    : _displayMode == SongDisplayMode.lyrics
                        ? ' '
                        : ' ',
                style: TextStyle(
                  fontSize: 11,
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.75),
                  fontStyle: FontStyle.italic,
                ),
                maxLines: 1,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildModeButton(SongDisplayMode mode, String label, IconData icon) {
    final isSelected = _displayMode == mode;
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(13),
      onTap: () => _setDisplayMode(mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: isSelected ? scheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(13),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: isSelected ? scheme.onPrimary : scheme.onSurfaceVariant,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? scheme.onPrimary : scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleBridgePedalAction(String action) {
    // O filtro de campos de texto reais já é feito no JavaScript (index.html).
    // Não consultar o foco do Flutter aqui: um FocusNode "preso" da busca silenciava o pedal.
    if (!mounted) return;
    switch (action) {
      case 'next':
        _navigateSong(1);
        break;
      case 'prev':
        _navigateSong(-1);
        break;
      case 'down':
        _handlePedalScrollDown(280);
        break;
      case 'up':
        _handlePedalScrollUp(280);
        break;
      case 'space':
        if (_isPlaying) {
          _stopScroll();
        } else {
          _handlePedalScrollDown(280);
        }
        break;
      case 'enter':
        if (_isPlaying) {
          _stopScroll();
        } else {
          _handlePedalScrollUp(280);
        }
        break;
    }
  }

  bool _handleGlobalKeyEvent(KeyEvent event) {
    if (!mounted) return false;

    // Se o usuário estiver digitando em um campo de texto, não intercepta
    if (_isTextEditingFocused()) {
      return false;
    }

    // Apenas eventos de tecla pressionada (KeyDown) ou repetição (KeyRepeat)
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return false;
    }

    final key = event.logicalKey;

    // --- MODO 2: SETAS LATERAIS (Avançar / Retroceder Música Diretamente) ---
    // M-Vave Modo 2, teclados e controladores de palco
    if (key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.numpad6 ||
        key == LogicalKeyboardKey.bracketRight) {
      if (event is KeyDownEvent) {
        _navigateSong(1);
      }
      return true;
    }

    if (key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.numpad4 ||
        key == LogicalKeyboardKey.bracketLeft) {
      if (event is KeyDownEvent) {
        _navigateSong(-1);
      }
      return true;
    }

    // --- MODO 1, 3, 5: AVANÇAR / ROLAR PARA BAIXO ---
    // PageDown, Seta Baixo, Numpad 2, Numpad 3, tecla 'b' (Modo iOS M-Vave)
    final isDownAction = key == LogicalKeyboardKey.pageDown ||
        key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.numpad2 ||
        key == LogicalKeyboardKey.numpad3 ||
        key == LogicalKeyboardKey.keyB;

    if (isDownAction) {
      if (event is KeyDownEvent) {
        _handlePedalScrollDown(key == LogicalKeyboardKey.pageDown ? 350 : 250);
      }
      return true;
    }

    // --- MODO 1, 3, 5: RETROCEDER / ROLAR PARA CIMA ---
    // PageUp, Seta Cima, Numpad 8, Numpad 9, tecla 'w' (Modo iOS M-Vave)
    final isUpAction = key == LogicalKeyboardKey.pageUp ||
        key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.numpad8 ||
        key == LogicalKeyboardKey.numpad9 ||
        key == LogicalKeyboardKey.keyW;

    if (isUpAction) {
      if (event is KeyDownEvent) {
        _handlePedalScrollUp(key == LogicalKeyboardKey.pageUp ? 350 : 250);
      }
      return true;
    }

    // --- MODO 4: ESPAÇO E ENTER (M-Vave Modo 4) ---
    // Pedal 1 (Space): Rola para baixo / Avança música
    // Pedal 2 (Enter / Return): Rola para cima / Retrocede música ou Pausa rolagem
    if (key == LogicalKeyboardKey.space) {
      if (event is KeyDownEvent) {
        if (_isPlaying) {
          _stopScroll();
        } else {
          _handlePedalScrollDown(280);
        }
      }
      return true;
    }

    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      if (event is KeyDownEvent) {
        if (_isPlaying) {
          _stopScroll();
        } else {
          _handlePedalScrollUp(280);
        }
      }
      return true;
    }

    return false;
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (_isTextEditingFocused()) {
      return KeyEventResult.ignored;
    }
    if (_handleGlobalKeyEvent(event)) {
      return KeyEventResult.handled;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.pageDown ||
        key == LogicalKeyboardKey.pageUp) {
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  static DateTime _globalLastScrollTime = DateTime.fromMillisecondsSinceEpoch(0);
  static DateTime _globalLastNavTime = DateTime.fromMillisecondsSinceEpoch(0);

  /// Utilizado em testes automatizados para resetar o debounce entre asserções
  @visibleForTesting
  static void resetNavDebounce() {
    _globalLastNavTime = DateTime.fromMillisecondsSinceEpoch(0);
    _globalLastScrollTime = DateTime.fromMillisecondsSinceEpoch(0);
  }

  void _handlePedalScrollDown(double delta) {
    if (_currentSong == null) return;

    final now = DateTime.now();
    if (now.difference(_globalLastScrollTime).inMilliseconds < 200) {
      return;
    }
    _globalLastScrollTime = now;

    if (!_scrollController.hasClients ||
        _scrollController.positions.length != 1) {
      return;
    }

    final pos = _scrollController.position;
    // Rola para baixo até o fim do conteúdo. NUNCA muda de música automaticamente!
    if (pos.pixels < pos.maxScrollExtent) {
      _pedalHudController.mostrar(TipoAcaoPedal.descer);
      _scrollBy(delta);
    }
  }

  void _handlePedalScrollUp(double delta) {
    if (_currentSong == null) return;

    final now = DateTime.now();
    if (now.difference(_globalLastScrollTime).inMilliseconds < 200) {
      return;
    }
    _globalLastScrollTime = now;

    if (!_scrollController.hasClients ||
        _scrollController.positions.length != 1) {
      return;
    }

    final pos = _scrollController.position;
    // Rola para cima até o início do conteúdo. NUNCA volta de música automaticamente!
    if (pos.pixels > 0) {
      _pedalHudController.mostrar(TipoAcaoPedal.subir);
      _scrollBy(-delta);
    }
  }

  void _navigateSong(int delta) {
    final now = DateTime.now();
    // Proteção rigorosa contra saltos múltiplos e modo CS (Continue Sending) do M-VAVE:
    // Garante avanço e retrocesso estritamente de 1 em 1 música!
    if (now.difference(_globalLastNavTime).inMilliseconds < 500) {
      return;
    }
    _globalLastNavTime = now;

    final songs = _getVisibleSongs();
    if (songs.isEmpty || _currentSong == null) return;
    final currentIndex = songs.indexWhere((s) => s.id == _currentSong!.id);
    if (currentIndex < 0) return;
    final nextIndex = currentIndex + delta;
    if (nextIndex >= 0 && nextIndex < songs.length) {
      _pedalHudController.mostrar(
          delta > 0 ? TipoAcaoPedal.proxima : TipoAcaoPedal.anterior);
      _navDirection = delta;
      _selectSong(songs[nextIndex]);
    }
  }

  /// Diálogo de confirmação para exclusões (músicas, setlists ou itens)
  Future<bool?> _confirmDeletion({
    required String title,
    required String message,
    String confirmText = 'Excluir',
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return CartaoDialogoModerno(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.withValues(alpha: 0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.delete_forever_rounded,
                        color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Esta ação não poderá ser desfeita.',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.grey.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark ? Colors.white10 : Colors.black12,
                  ),
                ),
                child: Text(
                  message,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.45,
                    color: isDark ? Colors.grey[300] : Colors.grey[800],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Wrap(
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    style: TextButton.styleFrom(
                      foregroundColor:
                          isDark ? Colors.grey[400] : Colors.grey[700],
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                    ),
                    child: const Text('Cancelar',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.withValues(alpha: 0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => Navigator.pop(ctx, true),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 11),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.delete_outline_rounded,
                                  size: 18, color: Colors.white),
                              const SizedBox(width: 8),
                              Text(
                                confirmText,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // --- Ações de Criação, Comunidade e Setlists ---
  Future<void> _loadMySharedSongs({bool force = false}) async {
    final email = widget.account.email?.trim().toLowerCase() ?? '';
    if (email.isEmpty) {
      if (mounted) {
        setState(() {
          _mySharedSongs = [];
          _isLoadingSharedSongs = false;
        });
      }
      return;
    }
    if (_isLoadingSharedSongs && !force) return;
    if (mounted) {
      setState(() => _isLoadingSharedSongs = true);
    }
    try {
      final all = await _communityService.fetchCommunitySongs();
      if (mounted) {
        setState(() {
          _mySharedSongs = all
              .where((item) => item.sharedByEmail.trim().toLowerCase() == email)
              .toList();
        });
      }
    } catch (_) {
      // Ignora erro de rede temporário
    } finally {
      if (mounted) {
        setState(() => _isLoadingSharedSongs = false);
      }
    }
  }

  Future<void> _shareToCommunity([List<Song>? initialSongs]) async {
    await TelaComunidade.compartilharMusicas(
      context: context,
      account: widget.account,
      repository: widget.repository,
      sync: widget.sync,
      communityService: widget.communityService,
      initialSelectedSongIds:
          initialSongs?.map((s) => s.id).toList() ?? const [],
    );
    await _loadMySharedSongs();
  }

  Future<void> _confirmUnpublishSharedSong(CommunitySong item) async {
    final email = widget.account.email?.trim() ?? '';
    if (email.isEmpty) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remover da Comunidade'),
        content: Text(
          'Deseja remover "${item.song.title}" da comunidade?\n\n'
          'Os usuários que já importaram a cifra continuarão com a cópia deles, mas ela não ficará mais visível para novos usuários.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remover'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _communityService.unpublishSong(
          target: item,
          userEmail: email,
        );
        await _loadMySharedSongs();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Cifra "${item.song.title}" removida da comunidade com sucesso.'),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao remover da comunidade: $e'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    }
  }

  Future<void> _confirmUnpublishAllSharedSongs() async {
    final email = widget.account.email?.trim() ?? '';
    if (email.isEmpty || _mySharedSongs.isEmpty) return;

    final total = _mySharedSongs.length;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 24),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Remover Todas da Comunidade?',
                style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Text(
          'Deseja remover todas as $total cifra(s) que você compartilhou na comunidade?\n\n'
          '• As cifras continuarão salvas normalmente na sua lista pessoal ("Minhas Cifras").\n'
          '• Os usuários que já as importaram continuarão com elas.\n'
          '• Todas deixarão de aparecer publicamente na aba Comunidade.',
          style: const TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: Colors.red[700]),
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.delete_sweep_rounded, size: 18),
            label: Text('Sim, Remover Todas ($total)'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        setState(() {
          _isLoadingSharedSongs = true;
          _mySharedSongs = [];
        });
        await _communityService.unpublishAllSongsByUser(userEmail: email);
        await _loadMySharedSongs(force: true);
        if (mounted) {
          setState(() {
            _isLoadingSharedSongs = false;
            _mySharedSongs = [];
          });
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              duration: const Duration(seconds: 4),
              behavior: SnackBarBehavior.floating,
              content: Text(
                'Todas as $total cifra(s) foram removidas da Comunidade com sucesso.',
              ),
              backgroundColor: Colors.green[800],
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoadingSharedSongs = false);
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              duration: const Duration(seconds: 4),
              behavior: SnackBarBehavior.floating,
              content: Text('Erro ao remover da comunidade: $e'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoadingSharedSongs = false);
        }
      }
    }
  }

  void _voltarParaInicio() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  Future<void> _abrirComunidadeDireto() async {
    if (Scaffold.maybeOf(context)?.isDrawerOpen == true) {
      Navigator.of(context).pop();
    }
    final importedSongId = await Navigator.push<String?>(
      context,
      MaterialPageRoute(
        builder: (_) => TelaComunidade(
          repository: widget.repository,
          chords: widget.chords,
          account: widget.account,
          sync: widget.sync,
          setlists: widget.setlists,
          theme: widget.theme,
          musicThemes: widget.musicThemes,
          communityService: widget.communityService,
        ),
      ),
    );
    if (mounted) {
      ServicoPedalBridge.registrar(_handleBridgePedalAction);
      if (importedSongId != null && importedSongId.isNotEmpty) {
        final importedSong = widget.repository.songs
            .where((s) => s.id == importedSongId)
            .firstOrNull;
        if (importedSong != null) {
          _tabIndex = 0;
          _selectSong(importedSong);
        }
      } else {
        _ensureFirstSongSelected();
      }
      _loadMySharedSongs();
      setState(() {});
    }
  }

  Future<void> _createManualSong() async {
    final created = await Navigator.push<Song>(
      context,
      MaterialPageRoute(
        builder: (_) => SongEditScreen(
          repository: widget.repository,
          musicThemes: widget.musicThemes,
        ),
      ),
    );
    if (created != null && mounted) {
      final fresh =
          widget.repository.allSongs.where((s) => s.id == created.id);
      if (fresh.isNotEmpty) {
        final updated = fresh.first;
        setState(() => _currentSong = updated);
        _initKaraokeController(updated);
        return;
      }
    }
    _ensureFirstSongSelected();
  }

  Future<void> _createNewSetlist() async {
    final name = await askName(context, title: 'Nova Lista');
    if (name == null || name.trim().isEmpty) return;

    final newList = Setlist(id: UniqueKey().toString(), name: name.trim());
    await widget.setlists.saveSetlist(newList);
    setState(() {
      _tabIndex = 2;
      _selectedSetlist = newList;
    });
    _ensureFirstSongSelected();
  }

  Future<void> _renameSetlistDialog(Setlist setlist) async {
    final newName = await askName(context,
        title: 'Renomear Lista',
        initial: setlist.name);
    if (newName != null && newName.trim().isNotEmpty) {
      final updated = setlist.copyWith(name: newName.trim());
      await widget.setlists.saveSetlist(updated);
      if (_selectedSetlist?.id == setlist.id) {
        setState(() => _selectedSetlist = updated);
      } else {
        setState(() {});
      }
    }
  }

  Future<void> _deleteSetlistDialog(Setlist setlist) async {
    final confirm = await _confirmDeletion(
      title: 'Excluir Lista',
      message: 'Deseja excluir a lista "${setlist.name}"?',
    );
    if (confirm == true) {
      await widget.setlists.removeSetlist(setlist.id);
      if (_selectedSetlist?.id == setlist.id) {
        setState(() => _selectedSetlist = null);
        _ensureFirstSongSelected();
      } else {
        setState(() {});
      }
    }
  }

  Future<void> _exportSetlist(Setlist setlist) async {
    final items = widget.setlists.itemsFor(setlist.id);
    final allSongs = {
      for (final s in widget.repository.songs) s.id: s
    };
    final listSongs = [
      for (final it in items)
        if (allSongs[it.songId] != null)
          (allSongs[it.songId]!, it.transpose)
    ];
    final ok = await ExportService.exportSetlist(setlist.name, listSongs);
    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lista "${setlist.name}" exportada em ZIP.')),
      );
    }
  }

  Future<void> _exportAllSongs() async {
    final songs = widget.repository.songs;
    if (songs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nenhuma cifra para exportar.')),
      );
      return;
    }
    final ok = await ExportService.exportSongs(songs);
    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'ZIP com ${songs.length} cifra(s) exportado com sucesso.')),
      );
    }
  }

  Future<void> _exportFavorites() async {
    final favs = widget.repository.songs.where((s) => s.isFavorite).toList();
    if (favs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Nenhuma música favoritada para exportar.')),
      );
      return;
    }
    final ok = await ExportService.exportSongs(favs);
    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'ZIP com ${favs.length} favorita(s) exportado com sucesso.')),
      );
    }
  }

  Future<void> _deleteAllSongs() async {
    final count = widget.repository.songs.length;
    if (count == 0) return;

    final confirm = await _confirmDeletion(
      title: 'Excluir TODAS as Cifras',
      message:
          'Tem certeza que deseja excluir TODAS as $count cifra(s) da biblioteca?\n\n'
          'Esta ação removerá todas as músicas locais e da sincronização com a nuvem.',
      confirmText: 'Excluir Tudo',
    );

    if (confirm == true) {
      // 1. Apaga do repositório local e das listas de repertório
      await widget.repository.removeAll();
      await widget.setlists.removeAllItems();

      // 2. Limpa o leitor de cifras, descarrega áudio e reseta buscas
      if (mounted) {
        setState(() {
          _currentSong = null;
          _currentSetlistItem = null;
          _transpose = 0;
          _searchController.clear();
          _themeSearchController.clear();
          _setlistSearchController.clear();
        });
        _initKaraokeController(null);
      }

      // 3. Sincroniza a exclusão com a nuvem imediatamente
      try {
        await widget.sync.sync();
      } catch (_) {}

      // 4. Na Web, recarrega a página para reiniciar a aplicação limpa
      if (kIsWeb) {
        reloadWebPage();
        return;
      }

      // 5. Em dispositivos nativos, fecha drawer se aberto e exibe confirmação
      if (mounted) {
        final scaffoldState = Scaffold.maybeOf(context);
        if (scaffoldState?.isDrawerOpen ?? false) {
          scaffoldState?.closeDrawer();
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Todas as músicas foram excluídas da biblioteca.'),
          ),
        );
      }
    }
  }

  void _showAddToSetlistDialog(Song song) {
    final allLists = widget.setlists.setlists;

    showDialog<void>(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;

        return CartaoDialogoModerno(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const BadgeIconeGradiente(icon: Icons.playlist_add_rounded),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Adicionar à Lista de Repertório',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Selecione uma lista para incluir "${song.title}":',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              allLists.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.queue_music_rounded,
                              size: 48,
                              color: isDark
                                  ? Colors.grey[700]
                                  : Colors.grey[300]),
                          const SizedBox(height: 12),
                          const Text(
                            'Nenhuma lista criada ainda.',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Crie sua primeira lista para organizar seu repertório.',
                            style: TextStyle(
                                fontSize: 12.5,
                                color: isDark
                                    ? Colors.grey[400]
                                    : Colors.grey[600]),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 18),
                          BotaoGradiente(
                            onPressed: () {
                              Navigator.pop(ctx);
                              _createNewSetlist();
                            },
                            icon: Icons.add_rounded,
                            label: 'Criar Nova Lista',
                          ),
                        ],
                      ),
                    )
                  : ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 300),
                      child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: allLists.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 6),
                          itemBuilder: (_, i) {
                            final list = allLists[i];
                            final count = widget.setlists.countFor(
                                list.id,
                                widget.repository.songs.map((e) => e.id));
                            final alreadyIn = widget.setlists
                                .itemsFor(list.id)
                                .any((it) => it.songId == song.id);

                            return Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: alreadyIn
                                      ? Colors.green.withValues(alpha: 0.35)
                                      : (isDark
                                          ? Colors.white12
                                          : AppCores.roxo
                                              .withValues(alpha: 0.15)),
                                ),
                                color: alreadyIn
                                    ? Colors.green.withValues(alpha: 0.06)
                                    : (isDark
                                        ? Colors.white.withValues(alpha: 0.04)
                                        : Colors.grey.withValues(alpha: 0.03)),
                              ),
                              child: ListTile(
                                dense: true,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                leading: Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: (alreadyIn
                                            ? Colors.green
                                            : AppCores.roxo)
                                        .withValues(alpha: 0.14),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    alreadyIn
                                        ? Icons.check_circle_rounded
                                        : Icons.queue_music_rounded,
                                    color: alreadyIn
                                        ? Colors.green
                                        : AppCores.roxo,
                                    size: 20,
                                  ),
                                ),
                                title: Text(
                                  list.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14),
                                ),
                                subtitle: Text(
                                  count == 1 ? '1 música' : '$count músicas',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: isDark
                                          ? Colors.grey[400]
                                          : Colors.grey[600]),
                                ),
                                trailing: alreadyIn
                                    ? Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.green
                                              .withValues(alpha: 0.15),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: const Text(
                                          'Já adicionada',
                                          style: TextStyle(
                                              color: Colors.green,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700),
                                        ),
                                      )
                                    : const Icon(
                                        Icons.add_circle_outline_rounded,
                                        color: AppCores.roxo,
                                        size: 22),
                                onTap: () async {
                                  Navigator.pop(ctx);
                                  if (!alreadyIn) {
                                    await widget.setlists
                                        .addSongs(list.id, [song.id]);
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                              'Música incluída na lista "${list.name}".'),
                                        ),
                                      );
                                    }
                                  }
                                },
                              ),
                            );
                          },
                        ),
                    ),
              const SizedBox(height: 20),
              Wrap(
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: TextButton.styleFrom(
                      foregroundColor:
                          isDark ? Colors.grey[400] : Colors.grey[700],
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                    ),
                    child: const Text('Fechar',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  if (allLists.isNotEmpty)
                    BotaoGradiente(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _createNewSetlist();
                      },
                      icon: Icons.add_rounded,
                      label: 'Criar Nova Lista',
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // --- Ações de Temas e Estilos ---
  Future<void> _showSongThemesDialog(Song song) async {
    final availableThemes = widget.musicThemes.themes;
    final selected = Set<String>.from(song.tags);
    final newThemeCtrl = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;

        return StatefulBuilder(
          builder: (context, setModalState) {
            return CartaoDialogoModerno(
              width: 460,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const BadgeIconeGradiente(
                          icon: Icons.folder_rounded),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Temas e Estilos da Música',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Selecione os temas ou crie novos para "${song.title}":',
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark
                                    ? Colors.grey[400]
                                    : Colors.grey[600],
                                height: 1.3,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.05)
                                : Colors.grey.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: TextField(
                            controller: newThemeCtrl,
                            decoration: InputDecoration(
                              hintText: 'Novo tema / estilo...',
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 12),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: AppCores.roxo.withValues(alpha: 0.25),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: AppCores.roxo.withValues(alpha: 0.2),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: AppCores.roxo,
                                  width: 2,
                                ),
                              ),
                              prefixIcon: const Icon(
                                  Icons.label_outline_rounded,
                                  size: 18,
                                  color: AppCores.roxo),
                            ),
                            onSubmitted: (text) async {
                              final trimmed = text.trim();
                              if (trimmed.isNotEmpty) {
                                await widget.musicThemes.addTheme(trimmed);
                                setModalState(() {
                                  selected.add(trimmed);
                                  newThemeCtrl.clear();
                                });
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      BotaoGradiente(
                        icon: Icons.add_rounded,
                        label: 'Adicionar',
                        onPressed: () async {
                          final text = newThemeCtrl.text.trim();
                          if (text.isNotEmpty) {
                            await widget.musicThemes.addTheme(text);
                            setModalState(() {
                              selected.add(text);
                              newThemeCtrl.clear();
                            });
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 280),
                    child: availableThemes.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            child: Text(
                              'Nenhum tema cadastrado ainda.\nDigite acima para criar o primeiro.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark
                                    ? Colors.grey[400]
                                    : Colors.grey[600],
                              ),
                            ),
                          )
                        : ListView.separated(
                              shrinkWrap: true,
                              itemCount: availableThemes.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 4),
                              itemBuilder: (context, index) {
                                final theme = availableThemes[index];
                                final isChecked = selected.any((t) =>
                                    t.toLowerCase() == theme.toLowerCase());
                                return CheckboxListTile(
                                  dense: true,
                                  visualDensity: VisualDensity.compact,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  secondary: Icon(
                                    Icons.folder_outlined,
                                    size: 20,
                                    color: isChecked
                                        ? AppCores.roxo
                                        : Colors.grey,
                                  ),
                                  title: Text(
                                    theme,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: isChecked
                                          ? FontWeight.w700
                                          : FontWeight.normal,
                                    ),
                                  ),
                                  value: isChecked,
                                  onChanged: (val) {
                                    setModalState(() {
                                      if (val == true) {
                                        selected.add(theme);
                                      } else {
                                        selected.removeWhere((t) =>
                                            t.toLowerCase() ==
                                            theme.toLowerCase());
                                      }
                                    });
                                  },
                                );
                              },
                            ),
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    alignment: WrapAlignment.end,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: TextButton.styleFrom(
                          foregroundColor: isDark
                              ? Colors.grey[400]
                              : Colors.grey[700],
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                        ),
                        child: const Text('Cancelar',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                      BotaoGradiente(
                        onPressed: () async {
                          Navigator.pop(ctx);
                          await widget.repository
                              .setSongTags(song.id, selected.toList());
                          final updated = widget.repository.songs
                              .where((s) => s.id == song.id)
                              .firstOrNull;
                          if (updated != null && mounted) {
                            setState(() {
                              if (_currentSong?.id == song.id) {
                                _currentSong = updated;
                              }
                            });
                          }
                        },
                        icon: Icons.check_rounded,
                        label: 'Salvar Temas',
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _createNewThemeDialog() async {
    final name = await askName(context,
        title: 'Novo Tema / Estilo', hint: 'Ex: Adoração, Louvor, Baião');
    if (name == null || name.trim().isEmpty) return;
    await widget.musicThemes.addTheme(name.trim());
  }

  Future<void> _renameThemeDialog(String oldName) async {
    final newName = await askName(
      context,
      title: 'Renomear Tema',
      initial: oldName,
      hint: 'Novo nome do tema',
    );
    if (newName == null || newName.trim().isEmpty) return;
    await widget.musicThemes
        .renameTheme(oldName, newName.trim(), widget.repository);
    if (_selectedTheme == oldName) {
      setState(() => _selectedTheme = newName.trim());
    }
  }

  Future<void> _deleteThemeDialog(String themeName) async {
    final confirm = await _confirmDeletion(
      title: 'Excluir Tema',
      message: 'Tem certeza que deseja excluir o tema "$themeName"?\n'
          'As músicas associadas não serão apagadas, apenas desvinculadas deste tema.',
      confirmText: 'Excluir Tema',
    );
    if (confirm == true) {
      await widget.musicThemes.removeTheme(themeName, widget.repository);
      if (_selectedTheme == themeName) {
        setState(() => _selectedTheme = null);
        _ensureFirstSongSelected();
      }
    }
  }

  Future<void> _deleteAllThemesDialog() async {
    final confirm = await _confirmDeletion(
      title: 'Excluir Todos os Temas',
      message:
          'Tem certeza que deseja excluir permanentemente todos os temas cadastrados?\n'
          'As músicas associadas não serão apagadas, apenas desvinculadas dos temas.\n'
          'Esta alteração será salva localmente e sincronizada em definitivo na nuvem.',
      confirmText: 'Excluir Todos',
    );
    if (confirm == true) {
      await widget.musicThemes.clearAll(widget.repository);
      if (mounted) {
        setState(() => _selectedTheme = null);
        _ensureFirstSongSelected();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Todos os temas foram excluídos com sucesso.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _exportTheme(String themeName) async {
    final songs =
        widget.musicThemes.songsFor(themeName, widget.repository.songs);
    if (songs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Nenhuma música encontrada no tema "$themeName".')),
      );
      return;
    }
    final ok = await ExportService.exportSongs(songs);
    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'ZIP do tema "$themeName" com ${songs.length} música(s) salvo com sucesso.')),
      );
    }
  }

  // --- Interface do Músico (Reader) ---
  Widget _buildMusicianReader(bool isMobile) {
    // Validação reativa: mantém _currentSong sincronizada com o repositório ou descarrega se foi apagada
    if (_currentSong != null) {
      final latestInRepo = widget.repository.songs
          .where((s) => s.id == _currentSong!.id)
          .firstOrNull;
      if (latestInRepo == null) {
        final available = _getVisibleSongs();
        if (available.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _selectSong(available.first);
          });
        } else {
          _currentSong = null;
          _currentSetlistItem = null;
          _transpose = 0;
          _initKaraokeController(null);
        }
      } else if (!identical(latestInRepo, _currentSong)) {
        final audioChanged = latestInRepo.audioUrl != _currentSong!.audioUrl ||
            latestInRepo.audioDurationSeconds != _currentSong!.audioDurationSeconds;
        _currentSong = latestInRepo;
        if (audioChanged) {
          _initKaraokeController(latestInRepo);
        }
      }
    }

    // Se nenhuma música estiver selecionada, mas existirem músicas no repertório, seleciona a primeira automaticamente
    if (_currentSong == null) {
      final available = _getVisibleSongs();
      if (available.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _currentSong == null) {
            final fresh = _getVisibleSongs();
            if (fresh.isNotEmpty) {
              _selectSong(fresh.first);
            }
          }
        });
      }
    }

    if (_currentSong == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AppLogo(iconSize: 42),
              const SizedBox(height: 16),
              const Text(
                'Nenhuma música selecionada.',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Toque em "Nova Cifra" ou explore a Comunidade para enriquecer seu repertório.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 20),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                runSpacing: 10,
                children: [
                  FilledButton.icon(
                    onPressed: _createManualSong,
                    icon: const Icon(Icons.add),
                    label: const Text('Nova Cifra'),
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppCores.roxo, width: 1.2),
                    ),
                    onPressed: _abrirComunidadeDireto,
                    icon: const Icon(Icons.public_rounded,
                        color: AppCores.roxo, size: 18),
                    label: const Text(
                      'Comunidade',
                      style: TextStyle(
                        color: AppCores.roxo,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    final visibleSongs = _getVisibleSongs();
    final currentIndex =
        visibleSongs.indexWhere((s) => s.id == _currentSong!.id);
    final inSetlist = _tabIndex == 2 && _selectedSetlist != null;

    // Detecta o tom musical real da cifra e transpõe
    final detectedKey = ChordTransposer.detectKey(_currentSong!.content) ??
        (_currentSong!.originalKey.isNotEmpty
            ? _currentSong!.originalKey
            : null);
    final displayKey = detectedKey != null
        ? ChordTransposer.transposeChord(detectedKey, _transpose)
        : 'Tom';

    return Column(
      children: [
        // Topo Limpo do Músico (Apenas Título, Artista, Badge e Editar no Desktop)
        // No celular, esse conteúdo fica diretamente na AppBar superior única, sem duplicar cabeçalhos!
        if (!isMobile)
          Focus(
            canRequestFocus: false,
            descendantsAreFocusable: false,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest
                    .withValues(alpha: 0.3),
                border: Border(
                    bottom:
                        BorderSide(color: Colors.grey.withValues(alpha: 0.2))),
              ),
              child: Row(
                children: [
                  IconButton(
                    tooltip: _showSidebar
                        ? 'Modo Limpo (Recolher barra lateral)'
                        : 'Expandir barra lateral',
                    icon: Icon(_showSidebar
                        ? Icons.view_sidebar_outlined
                        : Icons.menu),
                    onPressed: () =>
                        setState(() => _showSidebar = !_showSidebar),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _currentSong!.title,
                          style: const TextStyle(
                              fontSize: 17, fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (_currentSong!.artist.isNotEmpty)
                          Text(
                            _currentSong!.artist,
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey[700]),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  if (inSetlist)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: Colors.indigo.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Lista: ${_selectedSetlist!.name}',
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.indigo),
                      ),
                    ),
                  if (_currentSong!.tags.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Wrap(
                        spacing: 4,
                        children: _currentSong!.tags.take(3).map((tag) {
                          return InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () {
                              setState(() {
                                _tabIndex = 3;
                                _selectedTheme = tag;
                              });
                              _ensureFirstSongSelected();
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .primaryContainer
                                    .withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                tag,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  IconButton(
                    tooltip: 'Temas / Estilos da música',
                    icon: const Icon(Icons.folder_outlined, size: 20),
                    onPressed: () => _showSongThemesDialog(_currentSong!),
                  ),
                  if (widget.theme != null && !_showSidebar)
                    IconButton(
                      tooltip: widget.theme!.isDark(context)
                          ? 'Mudar para Modo Claro'
                          : 'Mudar para Modo Escuro',
                      icon: Icon(
                        widget.theme!.isDark(context)
                            ? Icons.light_mode
                            : Icons.dark_mode_outlined,
                        size: 20,
                      ),
                      onPressed: () => widget.theme!.toggle(context),
                    ),
                  // Favoritar música atual
                  IconButton(
                    tooltip: _currentSong!.isFavorite
                        ? 'Remover dos favoritos'
                        : 'Adicionar aos favoritos',
                    icon: Icon(
                      _currentSong!.isFavorite ? Icons.star : Icons.star_border,
                      color:
                          _currentSong!.isFavorite ? Colors.amber[700] : null,
                      size: 22,
                    ),
                    onPressed: () async {
                      await widget.repository.toggleFavorite(_currentSong!.id);
                      final updated = widget.repository.songs
                          .where((s) => s.id == _currentSong!.id)
                          .firstOrNull;
                      if (updated != null && mounted) {
                        setState(() => _currentSong = updated);
                      }
                    },
                  ),
                  // Símbolo Karaokê / Áudio na AppBar
                  if (_currentSong!.hasAudio)
                    IconButton(
                      tooltip: _showKaraokePlayer
                          ? 'Ocultar Player de Karaokê'
                          : 'Exibir Player de Karaokê',
                      icon: Icon(
                        _showKaraokePlayer ? Icons.mic_rounded : Icons.mic_none_rounded,
                        size: 20,
                        color: _showKaraokePlayer ? AppCores.roxo : null,
                      ),
                      onPressed: () => setState(
                          () => _showKaraokePlayer = !_showKaraokePlayer),
                    ),
                  // Editar música
                  IconButton(
                    tooltip: 'Editar cifra',
                    icon: const Icon(Icons.edit_outlined, size: 20),
                    onPressed: _editCurrentSong,
                  ),
                ],
              ),
            ),
          ),

        // Barra de Modos de Visualização: [ 🎸 Cifra | 📝 Letra | 🎼 Partitura ]
        _buildDisplayModeBar(isMobile),

        // Área de Leitura Central com transição ao arrastar para os lados
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: () {
                    _searchFocusNode.unfocus();
                    _themeSearchFocusNode.unfocus();
                    _setlistSearchFocusNode.unfocus();
                    FocusManager.instance.primaryFocus?.unfocus();
                    _mainFocusNode.requestFocus();
                    ServicoPedalBridge.reassumirFoco();
                  },
                  onHorizontalDragStart: (_) {
                    _horizontalDragDistance = 0;
                  },
                  onHorizontalDragUpdate: (details) {
                    _horizontalDragDistance += details.primaryDelta ?? 0;
                  },
                  onHorizontalDragEnd: (details) {
                    final velocity = details.primaryVelocity ?? 0;
                    // Arrastou para a esquerda -> Próxima música
                    if (_horizontalDragDistance < -50 || velocity < -250) {
                      _navigateSong(1);
                    }
                    // Arrastou para a direita -> Música anterior
                    else if (_horizontalDragDistance > 50 || velocity > 250) {
                      _navigateSong(-1);
                    }
                    _horizontalDragDistance = 0;
                  },
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    layoutBuilder: (currentChild, previousChildren) {
                      return Stack(
                        fit: StackFit.expand,
                        children: [
                          ...previousChildren,
                          if (currentChild != null) currentChild,
                        ],
                      );
                    },
                    transitionBuilder: (child, animation) {
                      final offset = Tween<Offset>(
                        begin: Offset(_navDirection >= 0 ? 0.08 : -0.08, 0),
                        end: Offset.zero,
                      ).animate(CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOutCubic,
                      ));
                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: offset,
                          child: child,
                        ),
                      );
                    },
                    child: KeyedSubtree(
                      key: ValueKey('${_currentSong!.id}_${_displayMode.name}'),
                      child: _buildSongView(),
                    ),
                  ),
                ),
              ),

              // Player de vídeo do YouTube embutido (Picture-in-Picture) integrado à cifra com persistência de áudio
              if (_currentSong?.hasAudio == true &&
                  _currentSong?.audioType == 'youtube' &&
                  Song.extractYoutubeVideoId(_currentSong!.audioUrl!) != null)
                PlayerYoutubeEmbutido(
                  videoId: Song.extractYoutubeVideoId(_currentSong!.audioUrl!)!,
                  controller: _karaokeController,
                  visible: _showYoutubeVideo,
                  initialRight: 12,
                  initialBottom: 8,
                  onClose: () => setState(() => _showYoutubeVideo = false),
                ),

              // Indicador Visual Flutuante do Pedal (Cursor HUD de Próxima/Anterior/Rolagem)
              IndicadorPedalOverlay(controller: _pedalHudController),
            ],
          ),
        ),

        // Barra flutuante de áudio & karaokê sincronizado com a cifra
        if (_karaokeController != null &&
            _currentSong?.hasAudio == true &&
            _showKaraokePlayer)
          BarraPlayerKaraoke(
            controller: _karaokeController!,
            onClose: () => setState(() => _showKaraokePlayer = false),
            onToggleVideo: () => setState(() => _showYoutubeVideo = !_showYoutubeVideo),
            isVideoVisible: _showYoutubeVideo,
          ),

        // Barra inferior focada no músico (Rolagem, Tom, Fonte, Navegação)
        // 100% responsiva: tudo fica visível mesmo em celulares estreitos
        Focus(
          canRequestFocus: false,
          descendantsAreFocusable: false,
          skipTraversal: true,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(
                  top: BorderSide(color: Colors.grey.withValues(alpha: 0.2))),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 650;

                  // Widget do Controle de Tom
                  Widget buildToneControl({bool isExpanded = false}) {
                    final content = Row(
                      mainAxisSize:
                          isExpanded ? MainAxisSize.max : MainAxisSize.min,
                      mainAxisAlignment: isExpanded
                          ? MainAxisAlignment.spaceBetween
                          : MainAxisAlignment.center,
                      children: [
                        IconButton(
                          tooltip: 'Diminuir meio tom',
                          icon: const Icon(Icons.remove_rounded, size: 20),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                              minWidth: 38, minHeight: 38),
                          onPressed: () => _changeTranspose(-1),
                        ),
                        InkWell(
                          onTap: _transpose != 0 ? _resetTranspose : null,
                          borderRadius: BorderRadius.circular(6),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 4),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (displayKey != 'Tom') ...[
                                  Text(
                                    'Tom ',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant
                                          .withValues(alpha: 0.8),
                                    ),
                                  ),
                                ],
                                Text(
                                  displayKey,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                    color: _transpose != 0
                                        ? Theme.of(context).colorScheme.primary
                                        : null,
                                  ),
                                ),
                                if (_transpose != 0) ...[
                                  const SizedBox(width: 3),
                                  Text(
                                    _transpose > 0
                                        ? '(+$_transpose)'
                                        : '($_transpose)',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Aumentar meio tom',
                          icon: const Icon(Icons.add_rounded, size: 20),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                              minWidth: 38, minHeight: 38),
                          onPressed: () => _changeTranspose(1),
                        ),
                      ],
                    );

                    return Container(
                      height: 38,
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest
                            .withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(19),
                        border: Border.all(
                            color: Colors.grey.withValues(alpha: 0.25)),
                      ),
                      child: isExpanded
                          ? content
                          : Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 2),
                              child: content,
                            ),
                    );
                  }

                  // Widget do Controle de Fonte
                  Widget buildFontControl({bool isExpanded = false}) {
                    final content = Row(
                      mainAxisSize:
                          isExpanded ? MainAxisSize.max : MainAxisSize.min,
                      mainAxisAlignment: isExpanded
                          ? MainAxisAlignment.spaceBetween
                          : MainAxisAlignment.center,
                      children: [
                        IconButton(
                          tooltip: 'Diminuir fonte',
                          icon: const Icon(Icons.remove_rounded, size: 20),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                              minWidth: 38, minHeight: 38),
                          onPressed: () => _updateFontSize(_fontSize - 1),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.format_size_rounded,
                                size: 16,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant
                                    .withValues(alpha: 0.8),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${_fontSize.toInt()}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Aumentar fonte',
                          icon: const Icon(Icons.add_rounded, size: 20),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                              minWidth: 38, minHeight: 38),
                          onPressed: () => _updateFontSize(_fontSize + 1),
                        ),
                      ],
                    );

                    return Container(
                      height: 38,
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest
                            .withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(19),
                        border: Border.all(
                            color: Colors.grey.withValues(alpha: 0.25)),
                      ),
                      child: isExpanded
                          ? content
                          : Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 2),
                              child: content,
                            ),
                    );
                  }

                  // Widget de Navegação de Músicas e Passador de Cifras
                  final songNav = Container(
                    height: 38,
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest
                          .withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(19),
                      border: Border.all(
                          color: Colors.grey.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Música anterior (Seta ← ou Pedal)',
                          icon: const Icon(Icons.skip_previous_rounded,
                              size: 22),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                              minWidth: 38, minHeight: 38),
                          onPressed:
                              currentIndex > 0 ? () => _navigateSong(-1) : null,
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            '${currentIndex >= 0 ? currentIndex + 1 : 1}/${visibleSongs.length}',
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Próxima música (Seta → ou Pedal)',
                          icon:
                              const Icon(Icons.skip_next_rounded, size: 22),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                              minWidth: 38, minHeight: 38),
                          onPressed: currentIndex < visibleSongs.length - 1
                              ? () => _navigateSong(1)
                              : null,
                        ),
                      ],
                    ),
                  );

                  // Widget de Rolagem (Play/Pause, Scroll Manual e Velocidade)
                  Widget buildAutoScroll({bool showSlider = true}) {
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton.filled(
                          tooltip: _isPlaying
                              ? 'Pausar rolagem'
                              : 'Iniciar rolagem automática',
                          icon: Icon(
                            _isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            size: 22,
                          ),
                          style: IconButton.styleFrom(
                            minimumSize: const Size(40, 40),
                            padding: EdgeInsets.zero,
                          ),
                          onPressed: _isPlaying ? _stopScroll : _startScroll,
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          tooltip: 'Rolar para cima (Seta ↑ ou Pedal)',
                          icon: const Icon(Icons.keyboard_arrow_up_rounded,
                              size: 24),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                              minWidth: 36, minHeight: 38),
                          onPressed: () => _scrollBy(-180),
                        ),
                        IconButton(
                          tooltip: 'Rolar para baixo (Seta ↓ ou Pedal)',
                          icon: const Icon(Icons.keyboard_arrow_down_rounded,
                              size: 24),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                              minWidth: 36, minHeight: 38),
                          onPressed: () => _scrollBy(180),
                        ),
                        const SizedBox(width: 4),
                        // Pílula/Botão de velocidade
                        Tooltip(
                          message:
                              'Velocidade da rolagem (${_speed.toInt()} px/s) - Toque para ajustar',
                          child: InkWell(
                            borderRadius: BorderRadius.circular(19),
                            onTap: _showSpeedDialog,
                            child: Container(
                              height: 38,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest
                                    .withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(19),
                                border: Border.all(
                                    color: Colors.grey.withValues(alpha: 0.25)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.speed_rounded,
                                      size: 16, color: Colors.indigo),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${_speed.toInt()}',
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        if (showSlider) ...[
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 90,
                            child: Focus(
                              canRequestFocus: false,
                              descendantsAreFocusable: false,
                              skipTraversal: true,
                              child: Slider(
                                focusNode: _sliderFocusNode,
                                value: _speed,
                                min: 5,
                                max: 120,
                                onChanged: (v) => _updateSpeed(v),
                              ),
                            ),
                          ),
                        ],
                      ],
                    );
                  }

                  if (isNarrow) {
                    // LAYOUT DISPOSITIVO MOBILE: 2 LINHAS ESPAÇOSAS, NÍTIDAS E ERGONÔMICAS
                    // Linha 1: Navegação de Músicas + Play/Pause & Rolagem Manual/Velocidade
                    // Linha 2: Tom e Tamanho da Fonte com botões grandes e confortáveis
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: songNav,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerRight,
                                child: buildAutoScroll(showSlider: false),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.center,
                                child: buildToneControl(isExpanded: true),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.center,
                                child: buildFontControl(isExpanded: true),
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  }

                  // LAYOUT DESKTOP / TELAS LARGAS: 1 linha espaçosa com todos os controles
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              songNav,
                              const SizedBox(width: 12),
                              buildAutoScroll(showSlider: true),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          buildToneControl(isExpanded: false),
                          const SizedBox(width: 12),
                          buildFontControl(isExpanded: false),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSharedToCommunitySection(bool isDark) {
    final email = widget.account.email?.trim() ?? '';
    if (email.isEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF1E293B)
              : Colors.purple.shade50.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppCores.roxo.withValues(alpha: 0.25),
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.public, color: AppCores.roxo, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Faça login com e-mail para ver suas cifras compartilhadas na comunidade.',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.grey[300] : Colors.grey[700],
                ),
              ),
            ),
          ],
        ),
      );
    }

    final totalImports = _mySharedSongs.fold<int>(
      0,
      (sum, item) => sum + item.importCount,
    );

    return Container(
      key: const ValueKey('section_my_community_shares'),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppCores.roxo.withValues(alpha: isDark ? 0.35 : 0.25),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppCores.roxo.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: _isSharedSectionExpanded,
          onExpansionChanged: (expanded) {
            setState(() => _isSharedSectionExpanded = expanded);
          },
          tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          leading: Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              gradient: AppCores.gradienteBotao,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.public_rounded,
              color: Colors.white,
              size: 18,
            ),
          ),
          title: const Text(
            'Compartilhadas na Comunidade',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          subtitle: Text(
            _isLoadingSharedSongs
                ? 'Atualizando...'
                : '${_mySharedSongs.length} cifra(s) • $totalImports import(s)',
            style: TextStyle(
              fontSize: 11.5,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.refresh_rounded, size: 18),
                tooltip: 'Atualizar imports',
                visualDensity: VisualDensity.compact,
                onPressed: _loadMySharedSongs,
              ),
              if (_mySharedSongs.isNotEmpty)
                IconButton(
                  key: const ValueKey('btn_unshare_all_shared_songs'),
                  icon: const Icon(
                    Icons.delete_sweep_rounded,
                    size: 19,
                    color: Colors.redAccent,
                  ),
                  tooltip: 'Remover todas da comunidade',
                  visualDensity: VisualDensity.compact,
                  onPressed: _confirmUnpublishAllSharedSongs,
                ),
              Icon(
                _isSharedSectionExpanded
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                color: AppCores.roxo,
              ),
            ],
          ),
          children: [
            if (_mySharedSongs.isEmpty)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  'Você ainda não compartilhou cifras com a comunidade.\nToque no menu (⋮) de qualquer cifra na sua lista para compartilhar.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              )
            else
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.44,
                ),
                child: Scrollbar(
                  controller: _mySharedScrollCtrl,
                  thumbVisibility: true,
                  child: ListView.separated(
                    controller: _mySharedScrollCtrl,
                    shrinkWrap: true,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                    itemCount: _mySharedSongs.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, idx) {
                      final item = _mySharedSongs[idx];
                      return ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        leading: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            gradient: AppCores.gradienteBotao,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.music_note_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                        title: Text(
                          item.song.title,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          item.song.artist.isNotEmpty
                              ? item.song.artist
                              : 'Compartilhada em ${item.formattedDate}',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Badge de Imports elegante
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: AppCores.roxo
                                    .withValues(alpha: isDark ? 0.25 : 0.12),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppCores.roxo.withValues(alpha: 0.4),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.download_rounded,
                                    size: 12,
                                    color: AppCores.roxo,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    '${item.importCount} import(s)',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: AppCores.roxo,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              tooltip: 'Remover da comunidade',
                              icon: const Icon(
                                Icons.delete_outline_rounded,
                                size: 18,
                                color: Colors.redAccent,
                              ),
                              visualDensity: VisualDensity.compact,
                              onPressed: () => _confirmUnpublishSharedSong(item),
                            ),
                          ],
                        ),
                        onTap: () {
                          final local = widget.repository.songs
                              .where((s) => s.id == item.song.id)
                              .firstOrNull;
                          if (local != null) {
                            _selectSong(local);
                          } else {
                            _selectSong(item.song);
                          }
                        },
                      );
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // --- Catálogo e Navegação de Listas (mesmo padrão dos Temas) ---
  Widget _buildSetlistsView() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final allSetlists = widget.setlists.setlists;
    final filteredSetlists = _setlistSearchQuery.isEmpty
        ? allSetlists
        : allSetlists
            .where((s) => s.name.toLowerCase().contains(_setlistSearchQuery))
            .toList();

    // Agrupa por inicial alfabética (A, B, C...)
    final Map<String, List<Setlist>> grouped = {};
    for (final s in filteredSetlists) {
      final initial = _normalizeInitial(s.name);
      grouped.putIfAbsent(initial, () => []).add(s);
    }
    final sortedLetters = grouped.keys.toList()
      ..sort((a, b) {
        if (a == '#') return 1;
        if (b == '#') return -1;
        return a.compareTo(b);
      });

    // Mapeamento de posição para salto alfabético rápido
    final Map<String, double> letterOffsets = {};
    double accumulatedOffset = 0;
    for (final letter in sortedLetters) {
      letterOffsets[letter] = accumulatedOffset;
      accumulatedOffset += 40.0;
      accumulatedOffset += (grouped[letter]?.length ?? 0) * 58.0;
    }

    return Column(
      children: [
        // Cabeçalho da Lista de Setlists
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 8, 4),
          child: Row(
            children: [
              const Icon(Icons.queue_music,
                  color: Colors.indigo, size: 22),
              const SizedBox(width: 8),
              const Text(
                'Listas',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Nova Lista',
                icon: const Icon(Icons.add_circle_outline,
                    color: Colors.indigo, size: 22),
                onPressed: _createNewSetlist,
              ),
            ],
          ),
        ),

        // Campo de Pesquisa de Listas
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
          child: TextField(
            focusNode: _setlistSearchFocusNode,
            controller: _setlistSearchController,
            onTapOutside: (_) {
              _setlistSearchFocusNode.unfocus();
              _mainFocusNode.requestFocus();
              ServicoPedalBridge.reassumirFoco();
            },
            decoration: InputDecoration(
              hintText: 'Pesquisar lista...',
              hintStyle: const TextStyle(fontSize: 13),
              prefixIcon: const Icon(Icons.search, size: 18),
              suffixIcon: _setlistSearchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 16),
                      onPressed: () => _setlistSearchController.clear(),
                    )
                  : null,
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ),

        // Cifras Compartilhadas na Comunidade pelo Usuário
        if (_setlistSearchQuery.isEmpty) _buildSharedToCommunitySection(isDark),

        // Lista de Setlists Agrupada por Letra com Barra Alfabética à Direita
        Expanded(
          child: filteredSetlists.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      _setlistSearchQuery.isNotEmpty
                          ? 'Nenhuma lista encontrada para "$_setlistSearchQuery".'
                          : 'Nenhuma lista cadastrada.\nToque no botão "+" acima para criar.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ),
                )
              : Stack(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: ListView.builder(
                            controller: _setlistsListController,
                            itemCount: sortedLetters.length,
                            itemBuilder: (context, sectionIndex) {
                              final letter = sortedLetters[sectionIndex];
                              final setlistsInLetter = grouped[letter] ?? [];

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                        16, 12, 16, 4),
                                    child: Text(
                                      letter,
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w900,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                      ),
                                    ),
                                  ),
                                  ...setlistsInLetter.map((setlist) {
                                    final count = widget.setlists.countFor(
                                      setlist.id,
                                      widget.repository.songs.map((e) => e.id),
                                    );
                                    return Container(
                                      margin: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: ListTile(
                                        dense: true,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 8),
                                        leading: Icon(
                                          Icons.queue_music,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary,
                                          size: 24,
                                        ),
                                        title: Text(
                                          setlist.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        subtitle: Text(
                                          count == 0
                                              ? 'Nenhuma música ainda'
                                              : (count == 1
                                                  ? '1 música'
                                                  : '$count músicas'),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                        trailing: PopupMenuButton<String>(
                                          icon: const Icon(Icons.more_vert,
                                              size: 18),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(
                                              minWidth: 24, minHeight: 28),
                                          onSelected: (action) async {
                                            if (action == 'open') {
                                              setState(() =>
                                                  _selectedSetlist = setlist);
                                              _ensureFirstSongSelected();
                                            } else if (action == 'add_songs') {
                                              final ids = await pickSongs(
                                                  context,
                                                  widget.repository.songs);
                                              if (ids != null &&
                                                  ids.isNotEmpty) {
                                                await widget.setlists
                                                    .addSongs(setlist.id, ids);
                                                _ensureFirstSongSelected();
                                              }
                                            } else if (action == 'rename') {
                                              _renameSetlistDialog(setlist);
                                            } else if (action == 'export') {
                                              _exportSetlist(setlist);
                                            } else if (action == 'delete') {
                                              _deleteSetlistDialog(setlist);
                                            }
                                          },
                                          itemBuilder: (_) => const [
                                            PopupMenuItem(
                                              value: 'open',
                                              child: Row(
                                                children: [
                                                  Icon(Icons.queue_music,
                                                      size: 18),
                                                  SizedBox(width: 8),
                                                  Text('Abrir lista de repertório'),
                                                ],
                                              ),
                                            ),
                                            PopupMenuItem(
                                              value: 'add_songs',
                                              child: Row(
                                                children: [
                                                  Icon(Icons.playlist_add,
                                                      size: 18),
                                                  SizedBox(width: 8),
                                                  Text('Adicionar músicas à lista'),
                                                ],
                                              ),
                                            ),
                                            PopupMenuItem(
                                              value: 'rename',
                                              child: Row(
                                                children: [
                                                  Icon(Icons.edit, size: 18),
                                                  SizedBox(width: 8),
                                                  Text('Renomear lista'),
                                                ],
                                              ),
                                            ),
                                            PopupMenuItem(
                                              value: 'export',
                                              child: Row(
                                                children: [
                                                  Icon(Icons.archive_outlined,
                                                      size: 18),
                                                  SizedBox(width: 8),
                                                  Text('Exportar lista em ZIP'),
                                                ],
                                              ),
                                            ),
                                            PopupMenuItem(
                                              value: 'delete',
                                              child: Row(
                                                children: [
                                                  Icon(Icons.delete,
                                                      color: Colors.red,
                                                      size: 18),
                                                  SizedBox(width: 8),
                                                  Text('Excluir lista',
                                                      style: TextStyle(
                                                          color: Colors.red)),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                        onTap: () {
                                          setState(() =>
                                              _selectedSetlist = setlist);
                                          _ensureFirstSongSelected();
                                        },
                                      ),
                                    );
                                  }),
                                ],
                              );
                            },
                          ),
                        ),
                        if (sortedLetters.length > 1)
                          SizedBox(
                            width: 24,
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                return Column(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: sortedLetters.map((letter) {
                                    return InkWell(
                                      onTap: () {
                                        final target =
                                            letterOffsets[letter] ?? 0;
                                        if (_setlistsListController.hasClients) {
                                          final max = _setlistsListController
                                              .position.maxScrollExtent;
                                          _setlistsListController.animateTo(
                                            target.clamp(0.0, max),
                                            duration: const Duration(
                                                milliseconds: 250),
                                            curve: Curves.easeOutCubic,
                                          );
                                        }
                                      },
                                      child: SizedBox(
                                        width: 24,
                                        child: Center(
                                          child: Text(
                                            letter,
                                            style: TextStyle(
                                              fontSize:
                                                  sortedLetters.length > 20
                                                      ? 9
                                                      : 11,
                                              fontWeight: FontWeight.bold,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .primary,
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  // --- Catálogo e Navegação de Temas e Estilos (conforme Screenshot de referência) ---
  Widget _buildThemesView() {
    final allThemes = widget.musicThemes.themes;
    final filteredThemes = _themeSearchQuery.isEmpty
        ? allThemes
        : allThemes
            .where((t) => t.toLowerCase().contains(_themeSearchQuery))
            .toList();

    // Agrupa por inicial alfabética (A, B, C...)
    final Map<String, List<String>> grouped = {};
    for (final theme in filteredThemes) {
      final initial = _normalizeInitial(theme);
      grouped.putIfAbsent(initial, () => []).add(theme);
    }
    final sortedLetters = grouped.keys.toList()
      ..sort((a, b) {
        if (a == '#') return 1;
        if (b == '#') return -1;
        return a.compareTo(b);
      });

    // Mapeamento de posição para salto alfabético rápido
    final Map<String, double> letterOffsets = {};
    double accumulatedOffset = 0;
    for (final letter in sortedLetters) {
      letterOffsets[letter] = accumulatedOffset;
      accumulatedOffset += 40.0;
      accumulatedOffset += (grouped[letter]?.length ?? 0) * 58.0;
    }

    return Column(
      children: [
        // Cabeçalho da Lista de Temas
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 8, 4),
          child: Row(
            children: [
              const Icon(Icons.folder_copy_outlined,
                  color: Colors.indigo, size: 22),
              const SizedBox(width: 8),
              const Text(
                'Temas',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              if (widget.musicThemes.themes.isNotEmpty)
                IconButton(
                  tooltip: 'Excluir Todos os Temas',
                  icon: const Icon(Icons.delete_sweep_outlined,
                      color: Colors.redAccent, size: 22),
                  onPressed: _deleteAllThemesDialog,
                ),
              IconButton(
                tooltip: 'Novo Tema',
                icon: const Icon(Icons.create_new_folder_outlined,
                    color: Colors.indigo, size: 22),
                onPressed: _createNewThemeDialog,
              ),
            ],
          ),
        ),

        // Campo de Pesquisa de Temas
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
          child: TextField(
            focusNode: _themeSearchFocusNode,
            controller: _themeSearchController,
            onTapOutside: (_) {
              _themeSearchFocusNode.unfocus();
              _mainFocusNode.requestFocus();
              ServicoPedalBridge.reassumirFoco();
            },
            decoration: InputDecoration(
              hintText: 'Pesquisar tema...',
              hintStyle: const TextStyle(fontSize: 13),
              prefixIcon: const Icon(Icons.search, size: 18),
              suffixIcon: _themeSearchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 16),
                      onPressed: () => _themeSearchController.clear(),
                    )
                  : null,
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ),

        // Lista de Temas Agrupada por Letra com Barra Alfabética à Direita
        Expanded(
          child: filteredThemes.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      _themeSearchQuery.isNotEmpty
                          ? 'Nenhum tema encontrado para "$_themeSearchQuery".'
                          : 'Nenhum tema cadastrado.',
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ),
                )
              : Stack(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: ListView.builder(
                            controller: _themesListController,
                            itemCount: sortedLetters.length,
                            itemBuilder: (context, sectionIndex) {
                              final letter = sortedLetters[sectionIndex];
                              final themesInLetter = grouped[letter] ?? [];

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                        16, 12, 16, 4),
                                    child: Text(
                                      letter,
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w900,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                      ),
                                    ),
                                  ),
                                  ...themesInLetter.map((theme) {
                                    final count = widget.musicThemes.countFor(
                                        theme, widget.repository.songs);
                                    return Container(
                                      margin: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: ListTile(
                                        dense: true,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 8),
                                        leading: Icon(
                                          Icons.folder_outlined,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary,
                                          size: 24,
                                        ),
                                        title: Text(
                                          theme,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        subtitle: Text(
                                          count == 0
                                              ? 'Nenhuma música ainda'
                                              : (count == 1
                                                  ? '1 música'
                                                  : '$count músicas'),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                        trailing: PopupMenuButton<String>(
                                          icon: const Icon(Icons.more_vert,
                                              size: 18),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(
                                              minWidth: 24, minHeight: 28),
                                          onSelected: (action) async {
                                            if (action == 'open') {
                                              setState(
                                                  () => _selectedTheme = theme);
                                              _ensureFirstSongSelected();
                                            } else if (action == 'add_songs') {
                                              final ids = await pickSongs(
                                                  context,
                                                  widget.repository.songs);
                                              if (ids != null &&
                                                  ids.isNotEmpty) {
                                                await widget.repository
                                                    .addSongsToTheme(
                                                        ids, theme);
                                                _ensureFirstSongSelected();
                                              }
                                            } else if (action == 'rename') {
                                              _renameThemeDialog(theme);
                                            } else if (action == 'export') {
                                              _exportTheme(theme);
                                            } else if (action == 'delete') {
                                              _deleteThemeDialog(theme);
                                            }
                                          },
                                          itemBuilder: (_) => const [
                                            PopupMenuItem(
                                              value: 'open',
                                              child: Row(
                                                children: [
                                                  Icon(Icons.folder_open,
                                                      size: 18),
                                                  SizedBox(width: 8),
                                                  Text('Filtrar músicas deste tema'),
                                                ],
                                              ),
                                            ),
                                            PopupMenuItem(
                                              value: 'add_songs',
                                              child: Row(
                                                children: [
                                                  Icon(Icons.playlist_add,
                                                      size: 18),
                                                  SizedBox(width: 8),
                                                  Text('Adicionar músicas ao tema'),
                                                ],
                                              ),
                                            ),
                                            PopupMenuItem(
                                              value: 'rename',
                                              child: Row(
                                                children: [
                                                  Icon(Icons.edit, size: 18),
                                                  SizedBox(width: 8),
                                                  Text('Renomear tema'),
                                                ],
                                              ),
                                            ),
                                            PopupMenuItem(
                                              value: 'export',
                                              child: Row(
                                                children: [
                                                  Icon(Icons.archive_outlined,
                                                      size: 18),
                                                  SizedBox(width: 8),
                                                  Text('Exportar músicas em ZIP'),
                                                ],
                                              ),
                                            ),
                                            PopupMenuItem(
                                              value: 'delete',
                                              child: Row(
                                                children: [
                                                  Icon(Icons.delete,
                                                      color: Colors.red,
                                                      size: 18),
                                                  SizedBox(width: 8),
                                                  Text('Excluir tema',
                                                      style: TextStyle(
                                                          color: Colors.red)),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                        onTap: () {
                                          setState(
                                              () => _selectedTheme = theme);
                                          _ensureFirstSongSelected();
                                        },
                                      ),
                                    );
                                  }),
                                ],
                              );
                            },
                          ),
                        ),
                        if (sortedLetters.length > 1)
                          SizedBox(
                            width: 24,
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                return Column(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: sortedLetters.map((letter) {
                                    return InkWell(
                                      onTap: () {
                                        final target =
                                            letterOffsets[letter] ?? 0;
                                        if (_themesListController.hasClients) {
                                          final max = _themesListController
                                              .position.maxScrollExtent;
                                          _themesListController.animateTo(
                                            target.clamp(0.0, max),
                                            duration: const Duration(
                                                milliseconds: 250),
                                            curve: Curves.easeOutCubic,
                                          );
                                        }
                                      },
                                      child: SizedBox(
                                        width: 24,
                                        child: Center(
                                          child: Text(
                                            letter,
                                            style: TextStyle(
                                              fontSize:
                                                  sortedLetters.length > 20
                                                      ? 9
                                                      : 11,
                                              fontWeight: FontWeight.bold,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .primary,
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
        ),

        // Barra inferior de status de temas
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context)
                .colorScheme
                .surfaceContainerHighest
                .withValues(alpha: 0.3),
            border: Border(
                top: BorderSide(color: Colors.grey.withValues(alpha: 0.2))),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${filteredThemes.length} tema(s) cadastrado(s)',
                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (widget.musicThemes.themes.isNotEmpty) ...[
                IconButton(
                  tooltip: 'Excluir Todos os Temas',
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
                  icon: const Icon(Icons.delete_sweep_outlined,
                      color: Colors.redAccent, size: 18),
                  onPressed: _deleteAllThemesDialog,
                ),
                const SizedBox(width: 4),
              ],
              TextButton(
                style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: _createNewThemeDialog,
                child:
                    const Text('+ Novo Tema', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- Barra Lateral (Músicas, Setlists e Temas) ---
  Widget _buildSidebarContent() {
    final visibleSongs = _getVisibleSongs();
    final allSetlists = widget.setlists.setlists;

    return Column(
      children: [
        // Cabeçalho da Barra Lateral
        Focus(
          canRequestFocus: false,
          descendantsAreFocusable: false,
          skipTraversal: true,
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .surfaceContainerHighest
                  .withValues(alpha: 0.25),
              border: Border(
                  bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.2))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                children: [
                  if (Navigator.canPop(context)) ...[
                    BotaoVoltarInicio(
                      iconSize: 24,
                      onTap: _voltarParaInicio,
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: AppLogo(
                      iconSize: 24,
                      onTap: Navigator.canPop(context)
                          ? _voltarParaInicio
                          : null,
                    ),
                  ),
                  if (widget.theme != null)
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 32, minHeight: 32),
                      tooltip: widget.theme!.isDark(context)
                          ? 'Mudar para Modo Claro'
                          : 'Mudar para Modo Escuro',
                      icon: Icon(
                        widget.theme!.isDark(context)
                            ? Icons.light_mode
                            : Icons.dark_mode_outlined,
                        size: 20,
                      ),
                      onPressed: () => widget.theme!.toggle(context),
                    ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 32, minHeight: 32),
                    tooltip: 'Verificar Atualizações do App',
                    icon: const Icon(
                      Icons.system_update_rounded,
                      size: 20,
                      color: Colors.purpleAccent,
                    ),
                    onPressed: () async {
                      await ServicoAtualizacaoPwa.verificarAtualizacao(context);
                    },
                  ),
                  AccountButton(
                    account: widget.account,
                    songs: widget.repository,
                    setlists: widget.setlists,
                    musicThemes: widget.musicThemes,
                    chords: widget.chords,
                    sync: widget.sync,
                    compact: true,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Ações Principais: Nova Cifra e Acesso Rápido à Comunidade
              Row(
                children: [
                  Expanded(
                    child: BotaoGradiente(
                      onPressed: _createManualSong,
                      icon: Icons.add_rounded,
                      label: 'Nova Cifra',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Tooltip(
                    message: 'Acessar a Comunidade',
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        key: const ValueKey('btn_sidebar_ir_comunidade'),
                        borderRadius: BorderRadius.circular(10),
                        onTap: _abrirComunidadeDireto,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 11),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: AppCores.roxo.withValues(alpha: 0.4),
                              width: 1.2,
                            ),
                            color: AppCores.roxo.withValues(alpha: 0.08),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.public_rounded,
                                  size: 17, color: AppCores.roxo),
                              SizedBox(width: 5),
                              Text(
                                'Comunidade',
                                style: TextStyle(
                                  color: AppCores.roxo,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        ),

        // Abas: "Todas", "Favoritas", "Listas" e "Temas"
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
          child: Focus(
            canRequestFocus: false,
            descendantsAreFocusable: false,
            child: SegmentedButton<int>(
              showSelectedIcon: false,
              style: ButtonStyle(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: WidgetStateProperty.all(
                    const EdgeInsets.symmetric(horizontal: 2)),
                alignment: Alignment.center,
              ),
              segments: [
                ButtonSegment<int>(
                  value: 0,
                  label: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.center,
                      child: Text(
                        'Todas (${widget.repository.songs.length})',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 10),
                        maxLines: 1,
                        softWrap: false,
                      ),
                    ),
                  ),
                ),
                ButtonSegment<int>(
                  value: 1,
                  label: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.center,
                      child: Text(
                        'Favoritas (${widget.repository.songs.where((s) => s.isFavorite).length})',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 10),
                        maxLines: 1,
                        softWrap: false,
                      ),
                    ),
                  ),
                ),
                ButtonSegment<int>(
                  value: 2,
                  label: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.center,
                      child: Text(
                        'Listas (${allSetlists.length})',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 10),
                        maxLines: 1,
                        softWrap: false,
                      ),
                    ),
                  ),
                ),
                ButtonSegment<int>(
                  value: 3,
                  label: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.center,
                      child: Text(
                        'Temas (${widget.musicThemes.themes.length})',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 10),
                        maxLines: 1,
                        softWrap: false,
                      ),
                    ),
                  ),
                ),
              ],
              selected: {_tabIndex},
              onSelectionChanged: (val) {
                setState(() {
                  _tabIndex = val.first;
                });
                _ensureFirstSongSelected();
              },
            ),
          ),
        ),

        // Se estiver na aba Listas e nenhuma lista estiver selecionada, exibe o catálogo de listas
        if (_tabIndex == 2 && _selectedSetlist == null)
          Expanded(child: _buildSetlistsView())
        // Se estiver na aba Temas e nenhum tema estiver selecionado, exibe o catálogo de temas
        else if (_tabIndex == 3 && _selectedTheme == null)
          Expanded(child: _buildThemesView())
        else ...[
          // Se estiver na aba Listas com lista selecionada: Banner da Lista (mesmo padrão do Banner do Tema)
          if (_tabIndex == 2 && _selectedSetlist != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .primaryContainer
                    .withValues(alpha: 0.35),
                border: Border(
                    bottom:
                        BorderSide(color: Colors.grey.withValues(alpha: 0.2))),
              ),
              child: Row(
                children: [
                  Icon(Icons.queue_music,
                      color: Theme.of(context).colorScheme.primary, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedSetlist!.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${visibleSongs.length} música(s)',
                          style:
                              TextStyle(fontSize: 11, color: Colors.grey[700]),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Adicionar músicas à lista',
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.playlist_add,
                        color: Colors.indigo, size: 20),
                    onPressed: () async {
                      final ids =
                          await pickSongs(context, widget.repository.songs);
                      if (ids != null && ids.isNotEmpty) {
                        await widget.setlists
                            .addSongs(_selectedSetlist!.id, ids);
                        _ensureFirstSongSelected();
                      }
                    },
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Opções da Lista',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    icon: const Icon(Icons.more_vert, size: 20),
                    onSelected: (action) async {
                      if (action == 'add_songs') {
                        final ids =
                            await pickSongs(context, widget.repository.songs);
                        if (ids != null && ids.isNotEmpty) {
                          await widget.setlists
                              .addSongs(_selectedSetlist!.id, ids);
                          _ensureFirstSongSelected();
                        }
                      } else if (action == 'rename') {
                        _renameSetlistDialog(_selectedSetlist!);
                      } else if (action == 'export') {
                        _exportSetlist(_selectedSetlist!);
                      } else if (action == 'delete') {
                        _deleteSetlistDialog(_selectedSetlist!);
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'add_songs',
                        child: Row(
                          children: [
                            Icon(Icons.playlist_add, size: 18),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Adicionar músicas à lista',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'rename',
                        child: Row(
                          children: [
                            Icon(Icons.edit, size: 18),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Renomear lista',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'export',
                        child: Row(
                          children: [
                            Icon(Icons.archive_outlined, size: 18),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Exportar lista em ZIP',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, color: Colors.red, size: 18),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Excluir lista',
                                style: TextStyle(color: Colors.red),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    tooltip: 'Ver todas as listas',
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () {
                      setState(() => _selectedSetlist = null);
                    },
                  ),
                ],
              ),
            ),
          ],
          // Se estiver na aba Temas com tema selecionado: Banner do Tema
          if (_tabIndex == 3 && _selectedTheme != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .primaryContainer
                    .withValues(alpha: 0.35),
                border: Border(
                    bottom:
                        BorderSide(color: Colors.grey.withValues(alpha: 0.2))),
              ),
              child: Row(
                children: [
                  Icon(Icons.folder_open,
                      color: Theme.of(context).colorScheme.primary, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedTheme!,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${visibleSongs.length} música(s)',
                          style:
                              TextStyle(fontSize: 11, color: Colors.grey[700]),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Adicionar músicas ao tema',
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.playlist_add,
                        color: Colors.indigo, size: 20),
                    onPressed: () async {
                      final ids =
                          await pickSongs(context, widget.repository.songs);
                      if (ids != null && ids.isNotEmpty) {
                        await widget.repository
                            .addSongsToTheme(ids, _selectedTheme!);
                        _ensureFirstSongSelected();
                      }
                    },
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Opções do Tema',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    icon: const Icon(Icons.more_vert, size: 20),
                    onSelected: (action) async {
                      if (action == 'add_songs') {
                        final ids =
                            await pickSongs(context, widget.repository.songs);
                        if (ids != null && ids.isNotEmpty) {
                          await widget.repository
                              .addSongsToTheme(ids, _selectedTheme!);
                          _ensureFirstSongSelected();
                        }
                      } else if (action == 'rename') {
                        _renameThemeDialog(_selectedTheme!);
                      } else if (action == 'export') {
                        _exportTheme(_selectedTheme!);
                      } else if (action == 'delete') {
                        _deleteThemeDialog(_selectedTheme!);
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'add_songs',
                        child: Row(
                          children: [
                            Icon(Icons.playlist_add, size: 18),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Adicionar músicas ao tema',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'rename',
                        child: Row(
                          children: [
                            Icon(Icons.edit, size: 18),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Renomear tema',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'export',
                        child: Row(
                          children: [
                            Icon(Icons.archive_outlined, size: 18),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Exportar músicas em ZIP',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, color: Colors.red, size: 18),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Excluir tema',
                                style: TextStyle(color: Colors.red),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    tooltip: 'Ver todos os temas',
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () {
                      setState(() => _selectedTheme = null);
                    },
                  ),
                ],
              ),
            ),
          ],



          // Campo de Pesquisa Inteligente com Menu de Opções
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    focusNode: _searchFocusNode,
                    controller: _searchController,
                    onTapOutside: (_) {
                      _searchFocusNode.unfocus();
                      _mainFocusNode.requestFocus();
                      ServicoPedalBridge.reassumirFoco();
                    },
                    decoration: InputDecoration(
                      hintText: 'Buscar por música, letra ou artista...',
                      hintStyle: const TextStyle(fontSize: 12),
                      prefixIcon: const Icon(Icons.search, size: 18),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 16),
                              onPressed: () => _searchController.clear(),
                            )
                          : null,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                if (_tabIndex == 0) ...[
                  const SizedBox(width: 4),
                  PopupMenuButton<String>(
                    tooltip: 'Opções da Biblioteca',
                    icon: const Icon(Icons.more_vert, size: 20),
                    constraints: const BoxConstraints(minWidth: 240, maxWidth: 300),
                    onSelected: (action) async {
                      if (action == 'export_all') {
                        _exportAllSongs();
                      } else if (action == 'sanitize_titles') {
                        final count =
                            await widget.repository.sanitizeSongMetadata();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(count > 0
                                  ? '$count cifras tiveram nomes e artistas corrigidos!'
                                  : 'Todas as cifras já estão no padrão correto.'),
                            ),
                          );
                        }
                      } else if (action == 'delete_all') {
                        _deleteAllSongs();
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'sanitize_titles',
                        child: Row(
                          children: [
                            Icon(Icons.auto_fix_high_rounded,
                                size: 18, color: AppCores.roxo),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text('Organizar títulos e artistas'),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'export_all',
                        child: Row(
                          children: [
                            Icon(Icons.archive_outlined,
                                size: 18, color: AppCores.indigo),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text('Fazer backup em ZIP'),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete_all',
                        child: Row(
                          children: [
                            Icon(Icons.delete_sweep_rounded,
                                color: Colors.red, size: 18),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text('Apagar todas as cifras',
                                  style: TextStyle(color: Colors.red)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ] else if (_tabIndex == 1) ...[
                  const SizedBox(width: 4),
                  IconButton(
                    tooltip: 'Exportar favoritas (.zip)',
                    icon: const Icon(Icons.archive_outlined, size: 20),
                    onPressed: _exportFavorites,
                  ),
                ] else if (_tabIndex == 3 && _selectedTheme != null) ...[
                  const SizedBox(width: 4),
                  IconButton(
                    tooltip: 'Exportar tema (.zip)',
                    icon: const Icon(Icons.archive_outlined, size: 20),
                    onPressed: () => _exportTheme(_selectedTheme!),
                  ),
                ],
              ],
            ),
          ),

          // Lista de Músicas
          Expanded(
            child: visibleSongs.isEmpty
                ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _searchQuery.isNotEmpty
                                ? 'Nenhuma música encontrada para "$_searchQuery".'
                                : (_tabIndex == 3
                                    ? 'Nenhuma música vinculada ao tema "$_selectedTheme".\nToque no botão "+" acima para adicionar músicas a este tema.'
                                    : (_tabIndex == 2
                                        ? 'Nenhuma música nesta setlist.\nToque no menu para adicionar.'
                                        : (_tabIndex == 1
                                            ? 'Nenhuma música favoritada ainda.\nToque na estrela de qualquer cifra para favoritar.'
                                            : 'Nenhuma música na biblioteca.\nToque em "Nova Cifra" para adicionar.'))),
                            textAlign: TextAlign.center,
                            style:
                                const TextStyle(color: Colors.grey, fontSize: 13),
                          ),
                          if (_tabIndex == 0 &&
                              _searchQuery.isEmpty &&
                              !widget.account.isLoggedIn) ...[
                            const SizedBox(height: 16),
                            FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: AppCores.roxo,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 10),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: () {
                                DesktopLoginDialog.show(
                                  context,
                                  widget.account,
                                  songs: widget.repository,
                                  setlists: widget.setlists,
                                  musicThemes: widget.musicThemes,
                                  chords: widget.chords,
                                  sync: widget.sync,
                                );
                              },
                              icon: const Icon(Icons.cloud_download_rounded,
                                  size: 18),
                              label: const Text(
                                  'Já tem músicas? Entrar com E-mail'),
                            ),
                          ],
                        ],
                      ),
                  )
                : (_tabIndex == 2 &&
                        _selectedSetlist != null &&
                        _searchQuery.isEmpty)
                    // MODO SETLIST: Suporta Reordenar com Drag & Drop (ReorderableListView)
                    ? Focus(
                        canRequestFocus: false,
                        descendantsAreFocusable: false,
                        child: ReorderableListView.builder(
                          buildDefaultDragHandles: false,
                          itemCount: visibleSongs.length,
                          onReorder: (oldIndex, newIndex) {
                            if (newIndex > oldIndex) newIndex -= 1;
                            final activeIds = {
                              for (final s in widget.repository.songs) s.id
                            };
                            final items = widget.setlists
                                .itemsFor(_selectedSetlist!.id)
                                .where((it) => activeIds.contains(it.songId))
                                .toList();
                            if (oldIndex < items.length &&
                                newIndex < items.length) {
                              final moved = items.removeAt(oldIndex);
                              items.insert(newIndex, moved);
                              setState(() {
                                widget.setlists.reorderSync(
                                  _selectedSetlist!.id,
                                  items.map((e) => e.id).toList(),
                                );
                              });
                            }
                          },
                          itemBuilder: (context, index) {
                            final song = visibleSongs[index];
                            final isSelected = _currentSong?.id == song.id;
                            final items =
                                widget.setlists.itemsFor(_selectedSetlist!.id);
                            final item = items
                                .where((it) => it.songId == song.id)
                                .firstOrNull;
                            final transposeVal = item?.transpose ?? 0;

                            return Container(
                              key: ValueKey(item?.id ?? '${song.id}_$index'),
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Theme.of(context)
                                        .colorScheme
                                        .primaryContainer
                                        .withValues(alpha: 0.6)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: ListTile(
                                dense: true,
                                contentPadding:
                                    const EdgeInsets.symmetric(horizontal: 8),
                                leading: ReorderableDragStartListener(
                                  index: index,
                                  child: MouseRegion(
                                    cursor: SystemMouseCursors.grab,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 4, vertical: 6),
                                      child: Icon(
                                        Icons.drag_indicator,
                                        color: isSelected
                                            ? Theme.of(context)
                                                .colorScheme
                                                .primary
                                            : Colors.grey[600],
                                        size: 22,
                                      ),
                                    ),
                                  ),
                                ),
                                title: Text(
                                  '${index + 1}. ${song.title}',
                                  style: TextStyle(
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.w500,
                                    fontSize: 14,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  '${song.artist.isEmpty ? 'Sem artista' : song.artist} • ${transposeVal == 0 ? 'Tom original' : (transposeVal > 0 ? '+$transposeVal' : '$transposeVal')}',
                                  style: const TextStyle(fontSize: 11),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      tooltip: song.isFavorite
                                          ? 'Remover dos favoritos'
                                          : 'Favoritar',
                                      icon: Icon(
                                        song.isFavorite
                                            ? Icons.star
                                            : Icons.star_border,
                                        size: 19,
                                        color: song.isFavorite
                                            ? Colors.amber[700]
                                            : Colors.grey[400],
                                      ),
                                      onPressed: () => widget.repository
                                          .toggleFavorite(song.id),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                          Icons.remove_circle_outline,
                                          color: Colors.redAccent,
                                          size: 18),
                                      tooltip: 'Remover da setlist',
                                      onPressed: () async {
                                        if (item != null) {
                                          final confirm =
                                              await _confirmDeletion(
                                            title: 'Remover da Setlist',
                                            message:
                                                'Deseja remover "${song.title}" da setlist "${_selectedSetlist?.name}"?',
                                            confirmText: 'Remover',
                                          );
                                          if (confirm == true) {
                                            await widget.setlists
                                                .removeItem(item.id);
                                            _ensureFirstSongSelected();
                                          }
                                        }
                                      },
                                    ),
                                  ],
                                ),
                                onTap: () => _selectSong(song),
                              ),
                            );
                          },
                        ),
                      )
                    // MODO TODAS AS MÚSICAS / FAVORITAS / TEMAS: Ordem alfabética com Coluna de Iniciais
                    : _buildAlphabetIndexedSongList(visibleSongs),
          ),
        ],
      ],
    );
  }

  // --- Coluna de Iniciais e Salto Alfabético ---

  String _normalizeInitial(String title) {
    if (title.isEmpty) return '#';
    final trimmed = title.trim();
    if (trimmed.isEmpty) return '#';

    String char = trimmed[0].toUpperCase();

    const diacritics = {
      'Á': 'A',
      'À': 'A',
      'Â': 'A',
      'Ã': 'A',
      'Ä': 'A',
      'É': 'E',
      'È': 'E',
      'Ê': 'E',
      'Ë': 'E',
      'Í': 'I',
      'Ì': 'I',
      'Î': 'I',
      'Ï': 'I',
      'Ó': 'O',
      'Ò': 'O',
      'Ô': 'O',
      'Õ': 'O',
      'Ö': 'O',
      'Ú': 'U',
      'Ù': 'U',
      'Û': 'U',
      'Ü': 'U',
      'Ç': 'C',
      'Ñ': 'N',
    };

    if (diacritics.containsKey(char)) {
      char = diacritics[char]!;
    }

    if (RegExp(r'^[A-Z]$').hasMatch(char)) {
      return char;
    }
    return '#';
  }

  List<String> _getAvailableInitials(List<Song> songs) {
    final set = <String>{};
    for (final s in songs) {
      set.add(_normalizeInitial(s.title));
    }
    final list = set.toList();
    list.sort((a, b) {
      if (a == '#') return 1;
      if (b == '#') return -1;
      return a.compareTo(b);
    });
    return list;
  }

  void _scrollToInitial(String letter, List<Song> songs) {
    final targetIndex =
        songs.indexWhere((s) => _normalizeInitial(s.title) == letter);
    if (targetIndex < 0) return;

    if (_sidebarSongListController.hasClients) {
      final max = _sidebarSongListController.position.maxScrollExtent;
      final targetOffset = (targetIndex * 56.0).clamp(0.0, max);
      _sidebarSongListController.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    }

    // Abre e seleciona imediatamente a primeira música iniciada com a letra clicada
    _selectSong(songs[targetIndex]);

    _bubbleTimer?.cancel();
    setState(() => _activeInitialBubble = letter);
    _bubbleTimer = Timer(const Duration(milliseconds: 700), () {
      if (mounted) {
        setState(() => _activeInitialBubble = null);
      }
    });
  }

  void _handleInitialGesture(
    double dy,
    double totalHeight,
    List<String> initials,
    List<Song> songs,
  ) {
    if (initials.isEmpty || totalHeight <= 0) return;
    final itemHeight = totalHeight / initials.length;
    final index = (dy / itemHeight).floor().clamp(0, initials.length - 1);
    final letter = initials[index];
    if (_activeInitialBubble != letter) {
      _scrollToInitial(letter, songs);
    }
  }

  Widget _buildAlphabetColumn(List<String> initials, List<Song> songs) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalHeight = constraints.maxHeight;

        return Container(
          width: 24,
          margin: const EdgeInsets.only(right: 2, top: 4, bottom: 4),
          decoration: BoxDecoration(
            color: Theme.of(context)
                .colorScheme
                .surfaceContainerHighest
                .withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onVerticalDragUpdate: (details) {
              _handleInitialGesture(
                  details.localPosition.dy, totalHeight, initials, songs);
            },
            onVerticalDragStart: (details) {
              _handleInitialGesture(
                  details.localPosition.dy, totalHeight, initials, songs);
            },
            onTapDown: (details) {
              _handleInitialGesture(
                  details.localPosition.dy, totalHeight, initials, songs);
            },
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: initials.map((letter) {
                final isCurrent = _activeInitialBubble == letter;
                return SizedBox(
                  width: 24,
                  child: Center(
                    child: Text(
                      letter,
                      style: TextStyle(
                        fontSize: initials.length > 20 ? 9 : 11,
                        fontWeight: FontWeight.bold,
                        color: isCurrent
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant
                                .withValues(alpha: 0.85),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAlphabetIndexedSongList(List<Song> songs) {
    final initials = _getAvailableInitials(songs);
    final showAlphabet = initials.length > 1;

    return Stack(
      children: [
        Row(
          children: [
            Expanded(
              child: Focus(
                canRequestFocus: false,
                descendantsAreFocusable: false,
                child: ListView.builder(
                  controller: _sidebarSongListController,
                  itemCount: songs.length,
                  itemBuilder: (context, index) {
                    final song = songs[index];
                    final isSelected = _currentSong?.id == song.id;

                    return Container(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Theme.of(context)
                                .colorScheme
                                .primaryContainer
                                .withValues(alpha: 0.6)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => _selectSong(song),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 7),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              CircleAvatar(
                                radius: 13,
                                backgroundColor: isSelected
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context)
                                        .colorScheme
                                        .surfaceContainerHighest,
                                child: Text(
                                  song.title.isNotEmpty
                                      ? song.title[0].toUpperCase()
                                      : '?',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.black87,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      song.title,
                                      style: TextStyle(
                                        fontWeight: isSelected
                                            ? FontWeight.bold
                                            : FontWeight.w500,
                                        fontSize: 13.0,
                                        color: isSelected
                                            ? Theme.of(context)
                                                .colorScheme
                                                .primary
                                            : null,
                                        height: 1.25,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (song.artist.isNotEmpty) ...[
                                      const SizedBox(height: 3),
                                      Text(
                                        song.artist,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant,
                                          height: 1.15,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(
                                        minWidth: 26, minHeight: 28),
                                    tooltip: song.isFavorite
                                        ? 'Remover dos favoritos'
                                        : 'Favoritar',
                                    icon: Icon(
                                      song.isFavorite
                                          ? Icons.star
                                          : Icons.star_border,
                                      size: 19,
                                      color: song.isFavorite
                                          ? Colors.amber[700]
                                          : Colors.grey[400],
                                    ),
                                    onPressed: () => widget.repository
                                        .toggleFavorite(song.id),
                                  ),
                                  PopupMenuButton<String>(
                                    key: ValueKey('btn_song_menu_${song.id}'),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(
                                        minWidth: 24, minHeight: 28),
                                    icon: const Icon(Icons.more_vert, size: 18),
                                    onSelected: (val) async {
                                      if (val == 'share_community') {
                                        _shareToCommunity([song]);
                                      } else if (val == 'manage_themes') {
                                        _showSongThemesDialog(song);
                                      } else if (val == 'remove_from_theme') {
                                        if (_selectedTheme != null) {
                                          await widget.repository
                                              .removeTagFromSong(
                                                  song.id, _selectedTheme!);
                                          _ensureFirstSongSelected();
                                        }
                                      } else if (val == 'add_to_list') {
                                        _showAddToSetlistDialog(song);
                                      } else if (val == 'edit') {
                                        final savedSong = await Navigator.push<Song>(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => SongEditScreen(
                                              repository: widget.repository,
                                              musicThemes: widget.musicThemes,
                                              song: song,
                                            ),
                                          ),
                                        );
                                        final targetId = savedSong?.id ?? song.id;
                                        final fresh = widget.repository.allSongs
                                            .where((s) => s.id == targetId);
                                        if (fresh.isNotEmpty && mounted) {
                                          final updated = fresh.first;
                                          setState(() {
                                            _currentSong = updated;
                                            _initKaraokeController(updated);
                                          });
                                          if (savedSong != null) {
                                            unawaited(widget.sync.sync());
                                          }
                                        }
                                      } else if (val == 'delete') {
                                        final confirm = await _confirmDeletion(
                                          title: 'Excluir Cifra',
                                          message:
                                              'Tem certeza que deseja excluir "${song.title}" do repertório?',
                                        );
                                        if (confirm == true) {
                                          await widget.repository
                                              .remove(song.id);
                                          await widget.setlists
                                              .removeItemsForSong(song.id);
                                          _ensureFirstSongSelected();
                                          try {
                                            await widget.sync.sync();
                                          } catch (_) {}
                                          if (mounted) {
                                            ScaffoldMessenger.of(this.context)
                                                .showSnackBar(
                                              SnackBar(
                                                  content: Text(
                                                      'Cifra "${song.title}" excluída.')),
                                            );
                                          }
                                        }
                                      }
                                    },
                                    itemBuilder: (_) => [
                                      if (_tabIndex == 3 &&
                                          _selectedTheme != null)
                                        PopupMenuItem(
                                          value: 'remove_from_theme',
                                          child: Row(
                                            children: [
                                              Icon(Icons.folder_off_outlined,
                                                  size: 18,
                                                  color: Colors.orange[800]),
                                              const SizedBox(width: 8),
                                              const Text('Remover música deste tema'),
                                            ],
                                          ),
                                        ),
                                      const PopupMenuItem(
                                        value: 'share_community',
                                        child: Row(
                                          children: [
                                            Icon(Icons.share_rounded,
                                                size: 18, color: AppCores.roxo),
                                            SizedBox(width: 8),
                                            Text('Compartilhar com a Comunidade'),
                                          ],
                                        ),
                                      ),
                                      const PopupMenuItem(
                                        value: 'manage_themes',
                                        child: Row(
                                          children: [
                                            Icon(Icons.folder_outlined,
                                                size: 18, color: Colors.indigo),
                                            SizedBox(width: 8),
                                            Text('Gerenciar temas e estilos'),
                                          ],
                                        ),
                                      ),
                                      const PopupMenuItem(
                                        value: 'add_to_list',
                                        child: Row(
                                          children: [
                                            Icon(Icons.playlist_add,
                                                size: 18, color: Colors.indigo),
                                            SizedBox(width: 8),
                                            Text('Incluir em uma lista de repertório'),
                                          ],
                                        ),
                                      ),
                                      const PopupMenuItem(
                                        value: 'edit',
                                        child: Row(
                                          children: [
                                            Icon(Icons.edit_outlined, size: 18),
                                            SizedBox(width: 8),
                                            Text('Editar cifra e acordes'),
                                          ],
                                        ),
                                      ),
                                      const PopupMenuItem(
                                        value: 'delete',
                                        child: Row(
                                          children: [
                                            Icon(Icons.delete_outline,
                                                size: 18, color: Colors.red),
                                            SizedBox(width: 8),
                                            Text('Excluir cifra da biblioteca',
                                                style: TextStyle(
                                                    color: Colors.red)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            if (showAlphabet) _buildAlphabetColumn(initials, songs),
          ],
        ),
        if (_activeInitialBubble != null)
          Center(
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Text(
                _activeInitialBubble!,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        widget.repository,
        widget.setlists,
        widget.account,
        widget.musicThemes
      ]),
      builder: (context, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 720;

            return Focus(
              focusNode: _mainFocusNode,
              autofocus: true,
              onKeyEvent: _handleKeyEvent,
              child: Scaffold(
                key: const ValueKey('app_main_scaffold'),
                appBar: isMobile
                    ? AppBar(
                        titleSpacing: 4,
                        title: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _currentSong?.title ?? 'MinhasCifras',
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                            if (_currentSong != null &&
                                _currentSong!.artist.isNotEmpty)
                              Text(
                                _currentSong!.artist,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                          ],
                        ),
                        leadingWidth: Navigator.canPop(context) ? 92 : 48,
                        leading: Builder(
                          builder: (ctx) => Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (Navigator.canPop(context))
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                      minWidth: 38, minHeight: 38),
                                  tooltip: 'Voltar ao Início',
                                  icon: const Icon(Icons.arrow_back_rounded,
                                      size: 22),
                                  onPressed: _voltarParaInicio,
                                ),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                    minWidth: 38, minHeight: 38),
                                tooltip: 'Menu de cifras',
                                icon: const Icon(Icons.menu_rounded, size: 22),
                                onPressed: () => Scaffold.of(ctx).openDrawer(),
                              ),
                            ],
                          ),
                        ),
                        actions: [
                          if (_currentSong != null) ...[
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                  minWidth: 36, minHeight: 36),
                              tooltip: _currentSong!.isFavorite
                                  ? 'Remover dos favoritos'
                                  : 'Adicionar aos favoritos',
                              icon: Icon(
                                _currentSong!.isFavorite
                                    ? Icons.star
                                    : Icons.star_border,
                                color: _currentSong!.isFavorite
                                    ? Colors.amber[700]
                                    : null,
                                size: 22,
                              ),
                              onPressed: () async {
                                await widget.repository
                                    .toggleFavorite(_currentSong!.id);
                                final updated = widget.repository.songs
                                    .where((s) => s.id == _currentSong!.id)
                                    .firstOrNull;
                                if (updated != null && mounted) {
                                  setState(() => _currentSong = updated);
                                }
                              },
                            ),
                            if (_currentSong!.hasAudio)
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                    minWidth: 36, minHeight: 36),
                                tooltip: _showKaraokePlayer
                                    ? 'Ocultar Karaokê'
                                    : 'Exibir Karaokê',
                                icon: Icon(
                                  _showKaraokePlayer
                                      ? Icons.mic_rounded
                                      : Icons.mic_none_rounded,
                                  color: _showKaraokePlayer
                                      ? AppCores.roxo
                                      : null,
                                  size: 20,
                                ),
                                onPressed: () => setState(
                                    () => _showKaraokePlayer = !_showKaraokePlayer),
                              ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                  minWidth: 36, minHeight: 36),
                              tooltip: 'Editar cifra',
                              icon: const Icon(Icons.edit_outlined, size: 20),
                              onPressed: _editCurrentSong,
                            ),
                          ],
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                                minWidth: 36, minHeight: 36),
                            tooltip: 'Verificar Atualizações do App',
                            icon: const Icon(Icons.system_update_rounded,
                                size: 20, color: Colors.purpleAccent),
                            onPressed: () async {
                              await ServicoAtualizacaoPwa.verificarAtualizacao(context);
                            },
                          ),
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                                minWidth: 36, minHeight: 36),
                            onSelected: (val) async {
                              if (val == 'home') {
                                _voltarParaInicio();
                              } else if (val == 'share_community') {
                                if (_currentSong != null) {
                                  await _shareToCommunity([_currentSong!]);
                                } else {
                                  await _shareToCommunity();
                                }
                              } else if (val == 'manage_themes') {
                                if (_currentSong != null) {
                                  _showSongThemesDialog(_currentSong!);
                                }
                              } else if (val == 'toggle_theme') {
                                widget.theme?.toggle(context);
                              } else if (val == 'sync') {
                                await widget.sync.sync();
                              } else if (val == 'check_update') {
                                if (context.mounted) {
                                  await ServicoAtualizacaoPwa.verificarAtualizacao(context);
                                }
                              } else if (val == 'account') {
                                DesktopLoginDialog.show(
                                  context,
                                  widget.account,
                                  songs: widget.repository,
                                  setlists: widget.setlists,
                                  musicThemes: widget.musicThemes,
                                  chords: widget.chords,
                                  sync: widget.sync,
                                );
                              }
                            },
                            itemBuilder: (ctx) => [
                              if (Navigator.canPop(context))
                                const PopupMenuItem(
                                  value: 'home',
                                  child: Row(
                                    children: [
                                      Icon(Icons.home_rounded,
                                          size: 18, color: AppCores.roxo),
                                      SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          'Voltar à Página Inicial',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              const PopupMenuItem(
                                value: 'share_community',
                                child: Row(
                                  children: [
                                    Icon(Icons.public_rounded,
                                        size: 18, color: AppCores.roxo),
                                    SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        'Compartilhar com a Comunidade',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (_currentSong != null)
                                const PopupMenuItem(
                                  value: 'manage_themes',
                                  child: Row(
                                    children: [
                                      Icon(Icons.folder_outlined,
                                          size: 18, color: Colors.indigo),
                                      SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          'Gerenciar temas e estilos',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              if (widget.theme != null)
                                PopupMenuItem(
                                  value: 'toggle_theme',
                                  child: Row(
                                    children: [
                                      Icon(
                                        widget.theme!.isDark(context)
                                            ? Icons.light_mode
                                            : Icons.dark_mode_outlined,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          widget.theme!.isDark(context)
                                              ? 'Alternar para Modo Claro'
                                              : 'Alternar para Modo Escuro',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              const PopupMenuItem(
                                value: 'sync',
                                child: Row(
                                  children: [
                                    Icon(Icons.sync, size: 18),
                                    SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        'Sincronizar com a Nuvem',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 'account',
                                child: Row(
                                  children: [
                                    const Icon(Icons.cloud_sync_outlined,
                                        size: 18),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        widget.account.syncCode != null
                                            ? 'Sincronização Nuvem (${widget.account.syncCode})'
                                            : 'Sincronização em Nuvem',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'check_update',
                                child: Row(
                                  children: [
                                    Icon(Icons.system_update_rounded,
                                        size: 18, color: Colors.purpleAccent),
                                    SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        'Verificar Atualizações do App',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      )
                    : null,
                drawer: isMobile
                    ? Drawer(
                        child: SafeArea(child: _buildSidebarContent()),
                      )
                    : null,
                body: SafeArea(
                  top: !isMobile,
                  child: Row(
                    children: [
                      // Barra Lateral (Sidebar) no Desktop / Tablets
                      if (!isMobile && _showSidebar)
                        SizedBox(
                          width: 375,
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border(
                                  right: BorderSide(
                                      color:
                                          Colors.grey.withValues(alpha: 0.2))),
                            ),
                            child: _buildSidebarContent(),
                          ),
                        ),
                      // Painel de Leitura Limpo para o Músico
                      Expanded(
                        child: _buildMusicianReader(isMobile),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
