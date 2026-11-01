import 'package:flutter/material.dart';

import '../models/song.dart';

/// Escolha várias músicas. Retorna os ids na ordem em que foram marcadas.
Future<List<String>?> pickSongs(BuildContext context, List<Song> songs) {
  return showDialog<List<String>>(
    context: context,
    builder: (_) => _SongPicker(songs: songs),
  );
}

class _SongPicker extends StatefulWidget {
  const _SongPicker({required this.songs});

  final List<Song> songs;

  @override
  State<_SongPicker> createState() => _SongPickerState();
}

class _SongPickerState extends State<_SongPicker> {
  final _selected = <String>{};

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Adicionar músicas'),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: widget.songs.isEmpty
            ? const Center(child: Text('Nenhuma cifra cadastrada.'))
            : ListView(
                children: [
                  for (final s in widget.songs)
                    CheckboxListTile(
                      value: _selected.contains(s.id),
                      title: Text(s.title),
                      subtitle: s.artist.isEmpty ? null : Text(s.artist),
                      onChanged: (v) => setState(() {
                        if (v == true) {
                          _selected.add(s.id);
                        } else {
                          _selected.remove(s.id);
                        }
                      }),
                    ),
                ],
              ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          onPressed: _selected.isEmpty ? null : () => Navigator.pop(context, _selected.toList()),
          child: Text('Adicionar (${_selected.length})'),
        ),
      ],
    );
  }
}
