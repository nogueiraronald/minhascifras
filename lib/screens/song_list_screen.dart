import 'package:flutter/material.dart';

import '../data/account_controller.dart';
import '../data/chord_library.dart';
import '../data/setlist_repository.dart';
import '../data/song_repository.dart';
import '../services/export_service.dart';
import '../services/sync_service.dart';
import '../widgets/account_button.dart';
import '../widgets/sync_button.dart';
import 'setlists_screen.dart';
import 'song_edit_screen.dart';
import 'song_reader_screen.dart';

class SongListScreen extends StatelessWidget {
  const SongListScreen({
    super.key,
    required this.repository,
    required this.chords,
    required this.account,
    required this.sync,
    required this.setlists,
  });

  final SongRepository repository;
  final ChordLibrary chords;
  final AccountController account;
  final SyncService sync;
  final SetlistRepository setlists;

  Future<void> _exportAll(BuildContext context) async {
    final ok = await ExportService.exportSongs(repository.songs);
    if (ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ZIP salvo.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Minhas cifras'),
        actions: [
          SyncButton(sync: sync, account: account),
          AccountButton(account: account),
          IconButton(
            tooltip: 'Setlists',
            icon: const Icon(Icons.queue_music),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    SetlistsScreen(setlists: setlists, songs: repository, chords: chords),
              ),
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (_) => _exportAll(context),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'export', child: Text('Exportar tudo (.zip)')),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Nova cifra'),
        onPressed: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => SongEditScreen(repository: repository))),
      ),
      body: ListenableBuilder(
        listenable: repository,
        builder: (context, _) {
          final songs = repository.songs;
          if (songs.isEmpty) {
            return const Center(
              child: Text('Nenhuma cifra ainda.\nToque em "Nova cifra" para começar.',
                  textAlign: TextAlign.center),
            );
          }
          return ListView.builder(
            itemCount: songs.length,
            itemBuilder: (context, i) {
              final s = songs[i];
              return Dismissible(
                key: ValueKey(s.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  color: Colors.red,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 16),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                onDismissed: (_) => repository.remove(s.id),
                child: ListTile(
                  title: Text(s.title),
                  subtitle: s.artist.isEmpty ? null : Text(s.artist),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SongReaderScreen(
                          songs: songs, initialIndex: i, chords: chords, repository: repository),
                    ),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => SongEditScreen(repository: repository, song: s)),
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
