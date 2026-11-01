import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../data/chord_library.dart';
import '../data/setlist_repository.dart';
import '../data/song_repository.dart';
import '../models/setlist.dart';
import '../widgets/name_dialog.dart';
import 'setlist_detail_screen.dart';

class SetlistsScreen extends StatelessWidget {
  const SetlistsScreen({
    super.key,
    required this.setlists,
    required this.songs,
    required this.chords,
  });

  final SetlistRepository setlists;
  final SongRepository songs;
  final ChordLibrary chords;

  Future<void> _create(BuildContext context) async {
    final name = await askName(context, title: 'Nova lista');
    if (name == null || name.isEmpty) return;
    await setlists.saveSetlist(Setlist(id: const Uuid().v4(), name: name));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Setlists')),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Nova lista'),
        onPressed: () => _create(context),
      ),
      body: ListenableBuilder(
        listenable: setlists,
        builder: (context, _) {
          final lists = setlists.setlists;
          if (lists.isEmpty) {
            return const Center(
              child: Text('Nenhuma lista ainda.\nToque em "Nova lista".',
                  textAlign: TextAlign.center),
            );
          }
          return ListView.builder(
            itemCount: lists.length,
            itemBuilder: (context, i) {
              final s = lists[i];
              return Dismissible(
                key: ValueKey(s.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  color: Colors.red,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 16),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                onDismissed: (_) => setlists.removeSetlist(s.id),
                child: ListTile(
                  leading: const Icon(Icons.queue_music),
                  title: Text(s.name),
                  subtitle: Text('${setlists.itemsFor(s.id).length} músicas'),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SetlistDetailScreen(
                          setlist: s, setlists: setlists, songs: songs, chords: chords),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
