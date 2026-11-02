import 'package:flutter/material.dart';

import '../data/account_controller.dart';
import '../data/chord_library.dart';
import '../data/setlist_repository.dart';
import '../data/song_repository.dart';
import '../services/cifra_import_service.dart';
import '../services/export_service.dart';
import '../services/sync_service.dart';
import '../widgets/account_button.dart';
import '../widgets/import_link_dialog.dart';
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

  Future<void> _importFromLink(BuildContext context) async {
    final song = await ImportLinkDialog.show(context);
    if (song != null) {
      await repository.save(song);
      if (!context.mounted) return;
      final currentSongs = repository.songs;
      final idx = currentSongs.indexWhere((s) => s.id == song.id);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cifra "${song.title}" importada com sucesso!'),
          action: idx >= 0
              ? SnackBarAction(
                  label: 'Abrir',
                  onPressed: () {
                    if (!context.mounted) return;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SongReaderScreen(
                          songs: currentSongs,
                          initialIndex: idx,
                          chords: chords,
                          repository: repository,
                        ),
                      ),
                    );
                  },
                )
              : null,
        ),
      );
    }
  }

  Future<void> _importFiles(BuildContext context) async {
    final songs = await CifraImportService.pickAndImportFiles();
    if (songs.isEmpty) return;

    await repository.saveAll(songs);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${songs.length} cifra(s) importada(s) com sucesso!')),
      );
    }
  }

  void _showAddOptions(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.link, color: Colors.blue),
              title: const Text('Importar por link'),
              subtitle: const Text('Obter cifra do Cifra Club via link'),
              onTap: () {
                Navigator.pop(sheetContext);
                _importFromLink(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.folder_open, color: Colors.amber),
              title: const Text('Importar arquivos (.txt ou .zip em lote)'),
              subtitle: const Text('Selecione múltiplos .txt ou um arquivo .zip'),
              onTap: () {
                Navigator.pop(sheetContext);
                _importFiles(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_note, color: Colors.green),
              title: const Text('Digitar / Criar manualmente'),
              subtitle: const Text('Escreva uma nova cifra do zero'),
              onTap: () {
                Navigator.pop(sheetContext);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => SongEditScreen(repository: repository)),
                );
              },
            ),
          ],
        ),
      ),
    );
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
            tooltip: 'Importar por link',
            icon: const Icon(Icons.link),
            onPressed: () => _importFromLink(context),
          ),
          IconButton(
            tooltip: 'Importar arquivos (.txt / .zip)',
            icon: const Icon(Icons.file_open_outlined),
            onPressed: () => _importFiles(context),
          ),
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
            tooltip: 'Mais opções',
            onSelected: (val) {
              if (val == 'export') _exportAll(context);
              if (val == 'import_link') _importFromLink(context);
              if (val == 'import_files') _importFiles(context);
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'import_link',
                child: Row(
                  children: [
                    Icon(Icons.link, size: 20),
                    SizedBox(width: 8),
                    Text('Importar por link'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'import_files',
                child: Row(
                  children: [
                    Icon(Icons.folder_open, size: 20),
                    SizedBox(width: 8),
                    Text('Importar arquivos em lote'),
                  ],
                ),
              ),
              PopupMenuDivider(),
              PopupMenuItem(
                value: 'export',
                child: Row(
                  children: [
                    Icon(Icons.archive_outlined, size: 20),
                    SizedBox(width: 8),
                    Text('Exportar tudo (.zip)'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Nova cifra'),
        onPressed: () => _showAddOptions(context),
      ),
      body: ListenableBuilder(
        listenable: repository,
        builder: (context, _) {
          final songs = repository.songs;
          if (songs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.music_note, size: 64, color: Colors.grey),
                    const SizedBox(height: 16),
                    const Text(
                      'Nenhuma cifra cadastrada ainda.',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Você pode importar cifras pelo link, selecionar múltiplos arquivos ou criar uma nova manualmente.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 24),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      alignment: WrapAlignment.center,
                      children: [
                        FilledButton.icon(
                          onPressed: () => _importFromLink(context),
                          icon: const Icon(Icons.link),
                          label: const Text('Importar por link'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _importFiles(context),
                          icon: const Icon(Icons.folder_open),
                          label: const Text('Importar arquivos (.txt/.zip)'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => SongEditScreen(repository: repository)),
                          ),
                          icon: const Icon(Icons.add),
                          label: const Text('Criar manual'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
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
                  leading: const CircleAvatar(
                    child: Icon(Icons.music_note, size: 20),
                  ),
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
                    tooltip: 'Editar cifra',
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
