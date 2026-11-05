import 'dart:async';

import 'package:flutter/material.dart';

import '../componentes/barra_player_karaoke.dart';
import '../componentes/dialogo_acordes.dart';
import '../componentes/player_youtube_embutido.dart';
import '../componentes/visualizador_cifra.dart';
import '../dados/biblioteca_acordes.dart';
import '../dados/repositorio_musicas.dart';
import '../modelos/musica.dart';
import '../servicos/controlador_audio_karaoke.dart';
import '../servicos/servico_wakelock.dart';
import '../servicos/transpositor_acordes.dart';
import 'tela_edicao_cifra.dart';

class SongReaderScreen extends StatefulWidget {
  const SongReaderScreen({
    super.key,
    required this.songs,
    required this.initialIndex,
    required this.chords,
    required this.repository,
    this.initialTransposes,
    this.onTransposeChanged,
  });

  final List<Song> songs;
  final int initialIndex;
  final ChordLibrary chords;
  final SongRepository repository;
  final List<int>? initialTransposes;
  final void Function(int index, int steps)? onTransposeChanged;

  @override
  State<SongReaderScreen> createState() => _SongReaderScreenState();
}

class _SongReaderScreenState extends State<SongReaderScreen> {
  late final List<Song> _songs = List<Song>.of(widget.songs);
  late int _index = widget.initialIndex;
  final _scroll = ScrollController();
  Timer? _timer;
  late final List<int> _transposes = List<int>.of(
      widget.initialTransposes ?? List<int>.filled(widget.songs.length, 0));
  int get _transpose => _transposes[_index];
  double _fontSize = 18;
  double _speed = 30; // pixels por segundo
  bool _playing = false;

  KaraokeAudioController? _karaokeController;
  bool _showKaraokePlayer = true;
  bool _showYoutubeVideo = true;

  Song get _song => _songs[_index];

  @override
  void initState() {
    super.initState();
    ServicoWakeLock.manterTelaAtiva(true);
    _initKaraoke(_song);
  }

  void _initKaraoke(Song song) {
    _karaokeController?.dispose();
    if (song.hasAudio) {
      _showYoutubeVideo = true;
      _showKaraokePlayer = true;
      _karaokeController = KaraokeAudioController(
        song: song,
        scrollController: _scroll,
      );
    } else {
      _showYoutubeVideo = false;
      _showKaraokePlayer = false;
      _karaokeController = null;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _karaokeController?.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _start() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (!_scroll.hasClients) return;
      final max = _scroll.position.maxScrollExtent;
      final next = _scroll.offset + _speed * 0.05;
      if (next >= max) {
        _scroll.jumpTo(max);
        _stop();
      } else {
        _scroll.jumpTo(next);
      }
    });
    setState(() => _playing = true);
  }

  void _stop() {
    _timer?.cancel();
    if (mounted) setState(() => _playing = false);
  }

  void _go(int delta) {
    final next = _index + delta;
    if (next < 0 || next >= _songs.length) return;
    _stop();
    setState(() {
      _index = next;
      _initKaraoke(_songs[next]);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(0);
    });
  }

  Future<void> _shiftKey(int delta) async {
    if (widget.onTransposeChanged != null) {
      setState(() => _transposes[_index] += delta);
      widget.onTransposeChanged?.call(_index, _transposes[_index]);
    } else {
      final current = _song;
      final newContent = ChordTransposer.transposeContent(current.content, delta);
      final newKey = ChordTransposer.detectKey(newContent) ??
          (current.originalKey.isNotEmpty
              ? ChordTransposer.transposeChord(current.originalKey, delta)
              : '');
      final updated = current.copyWith(
        content: newContent,
        originalKey: newKey.isNotEmpty ? newKey : null,
      );
      setState(() {
        _songs[_index] = updated;
      });
      await widget.repository.save(updated);
    }
  }

  Future<void> _edit() async {
    _stop();
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SongEditScreen(repository: widget.repository, song: _song),
      ),
    );
    if (!mounted) return;
    final fresh = widget.repository.allSongs.where((s) => s.id == _song.id);
    if (fresh.isNotEmpty) {
      setState(() {
        _songs[_index] = fresh.first;
        _initKaraoke(fresh.first);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_song.title),
        actions: [
          if (_song.hasAudio)
            IconButton(
              tooltip: _showKaraokePlayer ? 'Ocultar Player Karaokê' : 'Exibir Player Karaokê',
              icon: Icon(
                _showKaraokePlayer ? Icons.mic_rounded : Icons.mic_none_rounded,
                color: _showKaraokePlayer ? const Color(0xFF6366F1) : null,
              ),
              onPressed: () => setState(() => _showKaraokePlayer = !_showKaraokePlayer),
            )
          else
            TextButton.icon(
              onPressed: _edit,
              icon: const Icon(Icons.add_link_rounded, size: 15),
              label: const Text('Áudio', style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF6366F1),
                visualDensity: VisualDensity.compact,
              ),
            ),
          IconButton(
            tooltip: 'Editar cifra',
            icon: const Icon(Icons.edit_outlined),
            onPressed: _edit,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(child: Text('${_index + 1}/${_songs.length}')),
          ),
        ],
      ),
      body: Stack(
        children: [
          if (_karaokeController != null)
            ListenableBuilder(
              listenable: _karaokeController!,
              builder: (context, _) {
                final isPlayingOrStarted = _karaokeController!.isPlaying ||
                    _karaokeController!.currentPosition > Duration.zero;
                final progress =
                    isPlayingOrStarted ? _karaokeController!.progress : null;
                final activeChord =
                    isPlayingOrStarted ? _karaokeController!.activeChordLineIndex : null;

                return ChordSheetView(
                  content: _song.content,
                  transpose: _transpose,
                  fontSize: _fontSize,
                  controller: _scroll,
                  playbackProgress: progress,
                  activeLineIndex: activeChord,
                  autoScroll: _karaokeController?.isAutoScrollEnabled ?? true,
                  onSeekProgress: (p) => _karaokeController?.seekProgress(p),
                  onChordTap: (c) => showChordDialog(context, widget.chords, c),
                );
              },
            )
          else
            ChordSheetView(
              content: _song.content,
              transpose: _transpose,
              fontSize: _fontSize,
              controller: _scroll,
              onChordTap: (c) => showChordDialog(context, widget.chords, c),
            ),
          if (_karaokeController != null && _showKaraokePlayer)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: BarraPlayerKaraoke(
                controller: _karaokeController!,
                onClose: () => setState(() => _showKaraokePlayer = false),
                onToggleVideo: () => setState(() => _showYoutubeVideo = !_showYoutubeVideo),
                isVideoVisible: _showYoutubeVideo,
              ),
            ),
          if (_song.hasAudio &&
              _song.audioType == 'youtube' &&
              Song.extractYoutubeVideoId(_song.audioUrl!) != null)
            PlayerYoutubeEmbutido(
              videoId: Song.extractYoutubeVideoId(_song.audioUrl!)!,
              controller: _karaokeController,
              visible: _showYoutubeVideo,
              initialRight: 12,
              initialBottom: 56,
              onClose: () => setState(() => _showYoutubeVideo = false),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(children: [
                const Icon(Icons.speed),
                Expanded(
                  child: Slider(
                    value: _speed,
                    min: 5,
                    max: 120,
                    onChanged: (v) => setState(() => _speed = v),
                  ),
                ),
              ]),
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  IconButton(
                    tooltip: 'Música anterior',
                    icon: const Icon(Icons.skip_previous),
                    onPressed: _index > 0 ? () => _go(-1) : null,
                  ),
                  IconButton.filled(
                    tooltip: 'Rolagem automática',
                    icon: Icon(_playing ? Icons.pause : Icons.play_arrow),
                    onPressed: _playing ? _stop : _start,
                  ),
                  IconButton(
                    tooltip: 'Próxima música',
                    icon: const Icon(Icons.skip_next),
                    onPressed: _index < _songs.length - 1 ? () => _go(1) : null,
                  ),
                  const SizedBox(width: 16),
                  IconButton(
                    tooltip: 'Diminuir fonte',
                    icon: const Icon(Icons.text_decrease),
                    onPressed: () => setState(() => _fontSize = (_fontSize - 2).clamp(10, 40)),
                  ),
                  IconButton(
                    tooltip: 'Aumentar fonte',
                    icon: const Icon(Icons.text_increase),
                    onPressed: () => setState(() => _fontSize = (_fontSize + 2).clamp(10, 40)),
                  ),
                  const SizedBox(width: 16),
                  IconButton(
                    tooltip: 'Tom -1',
                    icon: const Icon(Icons.remove),
                    onPressed: () => _shiftKey(-1),
                  ),
                  Text(_transpose > 0 ? '+$_transpose' : '$_transpose'),
                  IconButton(
                    tooltip: 'Tom +1',
                    icon: const Icon(Icons.add),
                    onPressed: () => _shiftKey(1),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
