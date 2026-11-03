import 'package:flutter/material.dart';

import '../modelos/musica.dart';

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
  String _filter = '';

  void _previewSong(BuildContext context, Song song) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.music_note, color: Colors.indigo),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    song.title,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (song.artist.isNotEmpty)
                    Text(
                      song.artist,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
        content: SizedBox(
          width: 500,
          height: 420,
          child: SingleChildScrollView(
            child: SelectableText(
              song.content.isEmpty ? '(Cifra sem conteúdo)' : song.content,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13, height: 1.3),
            ),
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.songs.where((s) {
      if (_filter.isEmpty) return true;
      final q = _filter.toLowerCase();
      return s.title.toLowerCase().contains(q) || s.artist.toLowerCase().contains(q);
    }).toList();

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.playlist_add, color: Colors.indigo),
          SizedBox(width: 8),
          Expanded(child: Text('Adicionar músicas à Lista')),
        ],
      ),
      content: SizedBox(
        width: 480,
        height: 450,
        child: Column(
          children: [
            TextField(
              decoration: InputDecoration(
                hintText: 'Filtrar por título ou artista...',
                prefixIcon: const Icon(Icons.search, size: 18),
                suffixIcon: _filter.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 16),
                        onPressed: () => setState(() => _filter = ''),
                      )
                    : null,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onChanged: (val) => setState(() => _filter = val.trim()),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        widget.songs.isEmpty
                            ? 'Nenhuma cifra cadastrada na biblioteca.'
                            : 'Nenhuma música encontrada.',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (ctx, i) {
                        final s = filtered[i];
                        final isChecked = _selected.contains(s.id);

                        return CheckboxListTile(
                          value: isChecked,
                          title: Text(
                            s.title,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: s.artist.isNotEmpty
                              ? Text(
                                  s.artist,
                                  style: const TextStyle(fontSize: 11),
                                  overflow: TextOverflow.ellipsis,
                                )
                              : null,
                          secondary: IconButton(
                            tooltip: 'Visualizar cifra',
                            icon: const Icon(Icons.visibility_outlined, color: Colors.indigo, size: 20),
                            onPressed: () => _previewSong(context, s),
                          ),
                          onChanged: (v) => setState(() {
                            if (v == true) {
                              _selected.add(s.id);
                            } else {
                              _selected.remove(s.id);
                            }
                          }),
                        );
                      },
                    ),
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
