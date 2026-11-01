import 'dart:async';

import 'package:flutter/material.dart';

import '../data/chord_library.dart';
import '../data/song_repository.dart';
import '../models/song.dart';
import '../widgets/chord_dialog.dart';
import '../widgets/chord_sheet_view.dart';
import 'song_edit_screen.dart';

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

  Song get _song => _songs[_index];

  @override
  void dispose() {
    _timer?.cancel();
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
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(0);
    });
  }

  void _shiftKey(int delta) {
    setState(() => _transposes[_index] += delta);
    widget.onTransposeChanged?.call(_index, _transposes[_index]);
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
    if (fresh.isNotEmpty) setState(() => _songs[_index] = fresh.first);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_song.title),
        actions: [
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
      body: ChordSheetView(
        content: _song.content,
        transpose: _transpose,
        fontSize: _fontSize,
        controller: _scroll,
        onChordTap: (c) => showChordDialog(context, widget.chords, c),
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
