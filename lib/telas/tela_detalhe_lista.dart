import 'package:flutter/material.dart';

import '../dados/biblioteca_acordes.dart';
import '../dados/repositorio_listas.dart';
import '../dados/repositorio_musicas.dart';
import '../modelos/lista_repertorio.dart';
import '../modelos/item_lista_repertorio.dart';
import '../modelos/musica.dart';
import '../servicos/servico_exportacao.dart';
import '../componentes/dialogo_nome.dart';
import '../componentes/seletor_musicas.dart';
import 'tela_leitor_cifra.dart';

typedef _Entry = ({SetlistItem item, Song song});

class SetlistDetailScreen extends StatelessWidget {
  const SetlistDetailScreen({
    super.key,
    required this.setlist,
    required this.setlists,
    required this.songs,
    required this.chords,
  });

  final Setlist setlist;
  final SetlistRepository setlists;
  final SongRepository songs;
  final ChordLibrary chords;

  List<_Entry> _entries() {
    final byId = {for (final s in songs.songs) s.id: s};
    return [
      for (final it in setlists.itemsFor(setlist.id))
        if (byId[it.songId] != null) (item: it, song: byId[it.songId]!),
    ];
  }

  Setlist _current() =>
      setlists.allSetlists.firstWhere((s) => s.id == setlist.id, orElse: () => setlist);

  String _keyLabel(int t) => t == 0 ? 'Tom original' : 'Tom ${t > 0 ? '+$t' : '$t'}';

  Future<void> _add(BuildContext context) async {
    final ids = await pickSongs(context, songs.songs);
    if (ids == null || ids.isEmpty) return;
    await setlists.addSongs(setlist.id, ids);
  }

  Future<void> _rename(BuildContext context) async {
    final name = await askName(context, title: 'Renomear lista', initial: _current().name);
    if (name == null || name.isEmpty) return;
    await setlists.saveSetlist(_current().copyWith(name: name));
  }

  Future<void> _export(BuildContext context, List<_Entry> entries) async {
    final ok = await ExportService.exportSetlist(
        _current().name, [for (final e in entries) (e.song, e.item.transpose)]);
    if (ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ZIP salvo.')));
    }
  }

  void _open(BuildContext context, List<_Entry> entries, int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SongReaderScreen(
          songs: [for (final e in entries) e.song],
          initialIndex: index,
          chords: chords,
          repository: songs,
          initialTransposes: [for (final e in entries) e.item.transpose],
          onTransposeChanged: (i, steps) => setlists.setTranspose(entries[i].item.id, steps),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([setlists, songs]),
      builder: (context, _) {
        final entries = _entries();
        return Scaffold(
          appBar: AppBar(
            title: Text(_current().name),
            actions: [
              IconButton(
                tooltip: 'Adicionar músicas',
                icon: const Icon(Icons.playlist_add),
                onPressed: () => _add(context),
              ),
              PopupMenuButton<String>(
                tooltip: 'Mais opções da lista',
                onSelected: (v) => v == 'rename' ? _rename(context) : _export(context, entries),
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'rename',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined, size: 18),
                        SizedBox(width: 10),
                        Text('Renomear lista'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'export',
                    child: Row(
                      children: [
                        Icon(Icons.archive_outlined, size: 18),
                        SizedBox(width: 10),
                        Text('Exportar lista em ZIP'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          body: entries.isEmpty
              ? const Center(
                  child: Text('Lista vazia.\nToque em + para adicionar músicas.',
                      textAlign: TextAlign.center),
                )
              : ReorderableListView.builder(
                  itemCount: entries.length,
                  onReorder: (oldIndex, newIndex) {
                    if (newIndex > oldIndex) newIndex -= 1;
                    final ids = entries.map((e) => e.item.id).toList();
                    ids.insert(newIndex, ids.removeAt(oldIndex));
                    setlists.reorder(setlist.id, ids);
                  },
                  itemBuilder: (context, i) {
                    final e = entries[i];
                    return ListTile(
                      key: ValueKey(e.item.id),
                      title: Text('${i + 1}. ${e.song.title}'),
                      subtitle: Text(_keyLabel(e.item.transpose)),
                      onTap: () => _open(context, entries, i),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            tooltip: 'Tom -1',
                            icon: const Icon(Icons.remove),
                            onPressed: () =>
                                setlists.setTranspose(e.item.id, e.item.transpose - 1),
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            tooltip: 'Tom +1',
                            icon: const Icon(Icons.add),
                            onPressed: () =>
                                setlists.setTranspose(e.item.id, e.item.transpose + 1),
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            tooltip: 'Remover da lista',
                            icon: const Icon(Icons.close),
                            onPressed: () => setlists.removeItem(e.item.id),
                          ),
                          const SizedBox(width: 24),
                        ],
                      ),
                    );
                  },
                ),
        );
      },
    );
  }
}
