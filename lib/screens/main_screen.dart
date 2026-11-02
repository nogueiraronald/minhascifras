import 'dart:async';

import 'package:flutter/material.dart';

import '../data/account_controller.dart';
import '../data/chord_library.dart';
import '../data/setlist_repository.dart';
import '../data/song_repository.dart';
import '../models/setlist.dart';
import '../models/setlist_item.dart';
import '../models/song.dart';
import '../services/cifra_import_service.dart';
import '../services/export_service.dart';
import '../services/sync_service.dart';
import '../widgets/account_button.dart';
import '../widgets/chord_dialog.dart';
import '../widgets/chord_sheet_view.dart';
import '../widgets/import_link_dialog.dart';
import '../widgets/name_dialog.dart';
import '../widgets/song_picker.dart';
import '../widgets/sync_button.dart';
import 'song_edit_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({
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

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  // 0 = Todas as Músicas, 1 = Setlists
  int _tabIndex = 0;
  Setlist? _selectedSetlist;

  // Busca
  final _searchController = TextEditingController();
  String _searchQuery = '';

  // Seleção e visualização da cifra
  Song? _currentSong;
  SetlistItem? _currentSetlistItem;
  int _transpose = 0;

  // Leitor
  final _scrollController = ScrollController();
  Timer? _scrollTimer;
  double _fontSize = 17;
  double _speed = 30; // pixels por segundo
  bool _isPlaying = false;

  // Modo Limpo / Barra Lateral
  bool _showSidebar = true;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureFirstSongSelected();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  /// Garante que o app abra na primeira música disponível
  void _ensureFirstSongSelected() {
    final songs = _getVisibleSongs();
    if (songs.isNotEmpty) {
      if (_currentSong == null || !songs.any((s) => s.id == _currentSong!.id)) {
        _selectSong(songs.first);
      }
    } else {
      setState(() {
        _currentSong = null;
        _currentSetlistItem = null;
        _transpose = 0;
      });
    }
  }

  List<Song> _getVisibleSongs() {
    final all = widget.repository.songs;

    List<Song> baseList;
    if (_tabIndex == 1 && _selectedSetlist != null) {
      final items = widget.setlists.itemsFor(_selectedSetlist!.id);
      final songMap = {for (final s in all) s.id: s};
      baseList = [
        for (final item in items)
          if (songMap[item.songId] != null) songMap[item.songId]!,
      ];
    } else {
      baseList = all; // Já vem em ordem alfabética do repository
    }

    if (_searchQuery.isEmpty) {
      return baseList;
    }

    // Busca por Nome da música, Artista e Letra/Cifra
    return baseList.where((s) {
      final titleMatch = s.title.toLowerCase().contains(_searchQuery);
      final artistMatch = s.artist.toLowerCase().contains(_searchQuery);
      final contentMatch = s.content.toLowerCase().contains(_searchQuery);
      return titleMatch || artistMatch || contentMatch;
    }).toList();
  }

  void _selectSong(Song song) {
    _stopScroll();
    SetlistItem? item;
    int songTranspose = 0;

    if (_tabIndex == 1 && _selectedSetlist != null) {
      final items = widget.setlists.itemsFor(_selectedSetlist!.id);
      final found = items.where((it) => it.songId == song.id);
      if (found.isNotEmpty) {
        item = found.first;
        songTranspose = item.transpose;
      }
    }

    setState(() {
      _currentSong = song;
      _currentSetlistItem = item;
      _transpose = songTranspose;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
    });
  }

  /// Altera o tom da música.
  /// Se estiver em uma Setlist: altera APENAS na setlist específica, mantendo o original intacto!
  void _changeTranspose(int delta) {
    final newTranspose = _transpose + delta;
    setState(() {
      _transpose = newTranspose;
    });

    if (_currentSetlistItem != null) {
      widget.setlists.setTranspose(_currentSetlistItem!.id, newTranspose);
    }
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
      if (!_scrollController.hasClients) return;
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

  void _navigateSong(int delta) {
    final songs = _getVisibleSongs();
    if (songs.isEmpty || _currentSong == null) return;
    final currentIndex = songs.indexWhere((s) => s.id == _currentSong!.id);
    if (currentIndex < 0) return;
    final nextIndex = currentIndex + delta;
    if (nextIndex >= 0 && nextIndex < songs.length) {
      _selectSong(songs[nextIndex]);
    }
  }

  // --- Ações de Importação e Setlists ---
  Future<void> _importLink() async {
    final song = await ImportLinkDialog.show(context);
    if (song != null) {
      await widget.repository.save(song);
      _selectSong(song);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cifra "${song.title}" importada e aberta!')),
        );
      }
    }
  }

  Future<void> _importFiles() async {
    final songs = await CifraImportService.pickAndImportFiles();
    if (songs.isNotEmpty) {
      await widget.repository.saveAll(songs);
      _selectSong(songs.first);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${songs.length} cifra(s) importada(s) com sucesso!')),
        );
      }
    }
  }

  Future<void> _createManualSong() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SongEditScreen(repository: widget.repository)),
    );
    _ensureFirstSongSelected();
  }

  Future<void> _createNewSetlist() async {
    final name = await askName(context, title: 'Nova Setlist');
    if (name == null || name.trim().isEmpty) return;

    final newList = Setlist(id: UniqueKey().toString(), name: name.trim());
    await widget.setlists.saveSetlist(newList);
    setState(() {
      _tabIndex = 1;
      _selectedSetlist = newList;
    });
    _ensureFirstSongSelected();
  }

  void _showAddToSetlistDialog(Song song) {
    final allLists = widget.setlists.setlists;

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.playlist_add, color: Colors.indigo),
            const SizedBox(width: 8),
            Expanded(child: Text('Adicionar "${song.title}" à Setlist')),
          ],
        ),
        content: SizedBox(
          width: 380,
          child: allLists.isEmpty
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Nenhuma setlist criada ainda.'),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _createNewSetlist();
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Criar primeira setlist'),
                    ),
                  ],
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: allLists.length,
                  itemBuilder: (_, i) {
                    final list = allLists[i];
                    final alreadyIn = widget.setlists
                        .itemsFor(list.id)
                        .any((it) => it.songId == song.id);

                    return ListTile(
                      leading: Icon(
                        alreadyIn ? Icons.check_circle : Icons.queue_music,
                        color: alreadyIn ? Colors.green : Colors.grey,
                      ),
                      title: Text(list.name),
                      trailing: alreadyIn
                          ? const Text('Já adicionada', style: TextStyle(color: Colors.green, fontSize: 12))
                          : const Icon(Icons.add_circle_outline, color: Colors.indigo),
                      onTap: () async {
                        Navigator.pop(ctx);
                        if (!alreadyIn) {
                          await widget.setlists.addSongs(list.id, [song.id]);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Música incluída na setlist "${list.name}".')),
                            );
                          }
                        }
                      },
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fechar'),
          ),
          if (allLists.isNotEmpty)
            TextButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                _createNewSetlist();
              },
              icon: const Icon(Icons.add),
              label: const Text('Nova Setlist'),
            ),
        ],
      ),
    );
  }

  // --- Interface do Músico (Reader) ---
  Widget _buildMusicianReader(bool isMobile) {
    if (_currentSong == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.music_note_outlined, size: 72, color: Colors.grey),
              const SizedBox(height: 16),
              const Text(
                'Nenhuma música selecionada.',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Importe músicas por link, arquivos .txt ou crie sua primeira cifra.',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  FilledButton.icon(
                    onPressed: _importLink,
                    icon: const Icon(Icons.link),
                    label: const Text('Importar por link'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _importFiles,
                    icon: const Icon(Icons.folder_open),
                    label: const Text('Importar arquivos (.txt / .zip)'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    final visibleSongs = _getVisibleSongs();
    final currentIndex = visibleSongs.indexWhere((s) => s.id == _currentSong!.id);
    final inSetlist = _tabIndex == 1 && _selectedSetlist != null;

    return Column(
      children: [
        // Topo Limpo do Músico
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            border: Border(bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.2))),
          ),
          child: Row(
            children: [
              // Botão para alternar a visualização da barra lateral (Modo Limpo)
              IconButton(
                tooltip: _showSidebar ? 'Modo Limpo (Recolher barra lateral)' : 'Expandir barra lateral',
                icon: Icon(_showSidebar ? Icons.view_sidebar_outlined : Icons.menu),
                onPressed: () {
                  if (isMobile) {
                    Scaffold.of(context).openDrawer();
                  } else {
                    setState(() => _showSidebar = !_showSidebar);
                  }
                },
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _currentSong!.title,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (_currentSong!.artist.isNotEmpty)
                      Text(
                        _currentSong!.artist,
                        style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              if (inSetlist)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: Colors.indigo.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Setlist: ${_selectedSetlist!.name}',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.indigo),
                  ),
                ),
              // Controle de Tom
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Diminuir tom (-1 semitom)',
                      icon: const Icon(Icons.remove, size: 18),
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(),
                      onPressed: () => _changeTranspose(-1),
                    ),
                    InkWell(
                      onTap: _transpose != 0 ? _resetTranspose : null,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          _transpose == 0
                              ? 'Tom 0'
                              : (_transpose > 0 ? '+$_transpose' : '$_transpose'),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: _transpose != 0 ? Colors.indigo : null,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Aumentar tom (+1 semitom)',
                      icon: const Icon(Icons.add, size: 18),
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(),
                      onPressed: () => _changeTranspose(1),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Editar música
              IconButton(
                tooltip: 'Editar cifra',
                icon: const Icon(Icons.edit_outlined, size: 20),
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SongEditScreen(repository: widget.repository, song: _currentSong),
                    ),
                  );
                  final fresh = widget.repository.allSongs.where((s) => s.id == _currentSong!.id);
                  if (fresh.isNotEmpty) {
                    setState(() => _currentSong = fresh.first);
                  }
                },
              ),
            ],
          ),
        ),

        // Cifra (Área de Leitura Central)
        Expanded(
          child: ChordSheetView(
            content: _currentSong!.content,
            transpose: _transpose,
            fontSize: _fontSize,
            controller: _scrollController,
            onChordTap: (chord) => showChordDialog(context, widget.chords, chord),
          ),
        ),

        // Barra inferior focada no músico (Rolagem, Fonte, Próxima/Anterior)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(top: BorderSide(color: Colors.grey.withValues(alpha: 0.2))),
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                // Navegação de músicas
                IconButton(
                  tooltip: 'Música anterior',
                  icon: const Icon(Icons.skip_previous),
                  onPressed: currentIndex > 0 ? () => _navigateSong(-1) : null,
                ),
                Text(
                  '${currentIndex >= 0 ? currentIndex + 1 : 1}/${visibleSongs.length}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  tooltip: 'Próxima música',
                  icon: const Icon(Icons.skip_next),
                  onPressed: currentIndex < visibleSongs.length - 1 ? () => _navigateSong(1) : null,
                ),
                const SizedBox(width: 12),
                // Play / Pause de Auto-scroll
                IconButton.filled(
                  tooltip: _isPlaying ? 'Pausar rolagem' : 'Iniciar rolagem automática',
                  icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                  onPressed: _isPlaying ? _stopScroll : _startScroll,
                ),
                const SizedBox(width: 8),
                const Icon(Icons.speed, size: 16, color: Colors.grey),
                SizedBox(
                  width: 90,
                  child: Slider(
                    value: _speed,
                    min: 5,
                    max: 120,
                    onChanged: (v) => setState(() => _speed = v),
                  ),
                ),
                const Spacer(),
                // Fonte
                IconButton(
                  tooltip: 'Diminuir fonte',
                  icon: const Icon(Icons.text_decrease, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => setState(() => _fontSize = (_fontSize - 1).clamp(10, 36)),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text('${_fontSize.toInt()}', style: const TextStyle(fontSize: 11)),
                ),
                IconButton(
                  tooltip: 'Aumentar fonte',
                  icon: const Icon(Icons.text_increase, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => setState(() => _fontSize = (_fontSize + 1).clamp(10, 36)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // --- Barra Lateral (Músicas e Setlists) ---
  Widget _buildSidebarContent() {
    final visibleSongs = _getVisibleSongs();
    final allSetlists = widget.setlists.setlists;

    return Column(
      children: [
        // Cabeçalho da Barra Lateral
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.25),
            border: Border(bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.2))),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.queue_music, color: Colors.indigo, size: 24),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Cifras & Listas',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                  ),
                  SyncButton(sync: widget.sync, account: widget.account),
                  AccountButton(account: widget.account),
                ],
              ),
              const SizedBox(height: 10),
              // Botões de Ação Rápida (Importar Link / Arquivos)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      ),
                      onPressed: _importLink,
                      icon: const Icon(Icons.link, size: 16),
                      label: const Text('Link', style: TextStyle(fontSize: 12)),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      ),
                      onPressed: _importFiles,
                      icon: const Icon(Icons.folder_open, size: 16),
                      label: const Text('Arquivos', style: TextStyle(fontSize: 12)),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton.filledTonal(
                    tooltip: 'Nova cifra manual',
                    icon: const Icon(Icons.add, size: 18),
                    onPressed: _createManualSong,
                  ),
                ],
              ),
            ],
          ),
        ),

        // Abas: "Todas as Músicas" vs "Setlists"
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
          child: SegmentedButton<int>(
            segments: [
              ButtonSegment<int>(
                value: 0,
                label: Text('Todas (${widget.repository.songs.length})', style: const TextStyle(fontSize: 12)),
                icon: const Icon(Icons.library_music, size: 16),
              ),
              ButtonSegment<int>(
                value: 1,
                label: Text('Setlists (${allSetlists.length})', style: const TextStyle(fontSize: 12)),
                icon: const Icon(Icons.playlist_play, size: 16),
              ),
            ],
            selected: {_tabIndex},
            onSelectionChanged: (val) {
              setState(() {
                _tabIndex = val.first;
                if (_tabIndex == 1 && _selectedSetlist == null && allSetlists.isNotEmpty) {
                  _selectedSetlist = allSetlists.first;
                }
              });
              _ensureFirstSongSelected();
            },
          ),
        ),

        // Se estiver em Setlists: Seletor da Setlist Atual
        if (_tabIndex == 1) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: allSetlists.isEmpty
                      ? const Text('Nenhuma setlist criada', style: TextStyle(color: Colors.grey, fontSize: 13))
                      : DropdownButtonHideUnderline(
                          child: DropdownButton<Setlist>(
                            isExpanded: true,
                            value: allSetlists.any((s) => s.id == _selectedSetlist?.id)
                                ? _selectedSetlist
                                : allSetlists.first,
                            items: allSetlists.map((s) {
                              final count = widget.setlists.itemsFor(s.id).length;
                              return DropdownMenuItem(
                                value: s,
                                child: Text(
                                  '${s.name} ($count)',
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            onChanged: (s) {
                              setState(() => _selectedSetlist = s);
                              _ensureFirstSongSelected();
                            },
                          ),
                        ),
                ),
                IconButton(
                  tooltip: 'Nova Setlist',
                  icon: const Icon(Icons.add_circle, color: Colors.indigo, size: 22),
                  onPressed: _createNewSetlist,
                ),
                if (_selectedSetlist != null)
                  PopupMenuButton<String>(
                    tooltip: 'Opções da Setlist',
                    icon: const Icon(Icons.more_vert, size: 20),
                    onSelected: (action) async {
                      if (action == 'rename') {
                        final newName = await askName(context,
                            title: 'Renomear Setlist', initial: _selectedSetlist!.name);
                        if (newName != null && newName.trim().isNotEmpty) {
                          final updated = _selectedSetlist!.copyWith(name: newName.trim());
                          await widget.setlists.saveSetlist(updated);
                          setState(() => _selectedSetlist = updated);
                        }
                      } else if (action == 'add_songs') {
                        final ids = await pickSongs(context, widget.repository.songs);
                        if (ids != null && ids.isNotEmpty) {
                          await widget.setlists.addSongs(_selectedSetlist!.id, ids);
                          _ensureFirstSongSelected();
                        }
                      } else if (action == 'delete') {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Excluir Setlist'),
                            content: Text('Deseja excluir a setlist "${_selectedSetlist!.name}"?'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
                              FilledButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                                child: const Text('Excluir'),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          await widget.setlists.removeSetlist(_selectedSetlist!.id);
                          final remaining = widget.setlists.setlists;
                          setState(() {
                            _selectedSetlist = remaining.isNotEmpty ? remaining.first : null;
                          });
                          _ensureFirstSongSelected();
                        }
                      } else if (action == 'export') {
                        final items = widget.setlists.itemsFor(_selectedSetlist!.id);
                        final allSongs = {for (final s in widget.repository.songs) s.id: s};
                        final listSongs = [
                          for (final it in items)
                            if (allSongs[it.songId] != null) (allSongs[it.songId]!, it.transpose)
                        ];
                        final ok = await ExportService.exportSetlist(_selectedSetlist!.name, listSongs);
                        if (ok && mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('ZIP da setlist salvo com sucesso.')),
                          );
                        }
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'add_songs',
                        child: Row(
                          children: [
                            Icon(Icons.playlist_add, size: 18),
                            SizedBox(width: 8),
                            Text('Adicionar músicas'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'rename',
                        child: Row(
                          children: [
                            Icon(Icons.edit, size: 18),
                            SizedBox(width: 8),
                            Text('Renomear'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'export',
                        child: Row(
                          children: [
                            Icon(Icons.archive_outlined, size: 18),
                            SizedBox(width: 8),
                            Text('Exportar (.zip)'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, color: Colors.red, size: 18),
                            SizedBox(width: 8),
                            Text('Excluir lista', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
        ],

        // Campo de Pesquisa Inteligente (Nome, Artista, Letra)
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
          child: TextField(
            controller: _searchController,
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
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ),

        // Lista de Músicas
        Expanded(
          child: visibleSongs.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      _searchQuery.isNotEmpty
                          ? 'Nenhuma música encontrada para "$_searchQuery".'
                          : (_tabIndex == 1
                              ? 'Nenhuma música nesta setlist.\nToque no menu para adicionar.'
                              : 'Nenhuma música na biblioteca.\nUse os botões acima para importar.'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ),
                )
              : (_tabIndex == 1 && _selectedSetlist != null && _searchQuery.isEmpty)
                  // MODO SETLIST: Suporta Reordenar com Drag & Drop (ReorderableListView)
                  ? ReorderableListView.builder(
                      itemCount: visibleSongs.length,
                      onReorder: (oldIndex, newIndex) async {
                        if (newIndex > oldIndex) newIndex -= 1;
                        final items = widget.setlists.itemsFor(_selectedSetlist!.id);
                        if (oldIndex < items.length && newIndex < items.length) {
                          final moved = items.removeAt(oldIndex);
                          items.insert(newIndex, moved);
                          await widget.setlists.reorder(
                            _selectedSetlist!.id,
                            items.map((e) => e.id).toList(),
                          );
                        }
                      },
                      itemBuilder: (context, index) {
                        final song = visibleSongs[index];
                        final isSelected = _currentSong?.id == song.id;
                        final items = widget.setlists.itemsFor(_selectedSetlist!.id);
                        final item = items.where((it) => it.songId == song.id).firstOrNull;
                        final transposeVal = item?.transpose ?? 0;

                        return Container(
                          key: ValueKey(item?.id ?? song.id),
                          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.6)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ListTile(
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                            leading: ReorderableDragStartListener(
                              index: index,
                              child: const Icon(Icons.drag_indicator, color: Colors.grey, size: 20),
                            ),
                            title: Text(
                              '${index + 1}. ${song.title}',
                              style: TextStyle(
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                fontSize: 14,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              '${song.artist.isEmpty ? 'Sem artista' : song.artist} • ${transposeVal == 0 ? 'Tom original' : (transposeVal > 0 ? '+$transposeVal' : '$transposeVal')}',
                              style: const TextStyle(fontSize: 11),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 18),
                              tooltip: 'Remover da setlist',
                              onPressed: () async {
                                if (item != null) {
                                  await widget.setlists.removeItem(item.id);
                                  _ensureFirstSongSelected();
                                }
                              },
                            ),
                            onTap: () => _selectSong(song),
                          ),
                        );
                      },
                    )
                  // MODO TODAS AS MÚSICAS: Ordem alfabética
                  : ListView.builder(
                      itemCount: visibleSongs.length,
                      itemBuilder: (context, index) {
                        final song = visibleSongs[index];
                        final isSelected = _currentSong?.id == song.id;

                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.6)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ListTile(
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                            leading: CircleAvatar(
                              radius: 14,
                              backgroundColor: isSelected
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.surfaceContainerHighest,
                              child: Text(
                                song.title.isNotEmpty ? song.title[0].toUpperCase() : '?',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected ? Colors.white : Colors.black87,
                                ),
                              ),
                            ),
                            title: Text(
                              song.title,
                              style: TextStyle(
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                fontSize: 14,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: song.artist.isNotEmpty
                                ? Text(
                                    song.artist,
                                    style: const TextStyle(fontSize: 11),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  )
                                : null,
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Botão rápido para incluir em uma setlist
                                IconButton(
                                  tooltip: 'Adicionar à Setlist',
                                  icon: const Icon(Icons.playlist_add, size: 20, color: Colors.indigo),
                                  onPressed: () => _showAddToSetlistDialog(song),
                                ),
                                PopupMenuButton<String>(
                                  icon: const Icon(Icons.more_vert, size: 18),
                                  onSelected: (val) async {
                                    if (val == 'edit') {
                                      await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              SongEditScreen(repository: widget.repository, song: song),
                                        ),
                                      );
                                    } else if (val == 'delete') {
                                      await widget.repository.remove(song.id);
                                      _ensureFirstSongSelected();
                                    }
                                  },
                                  itemBuilder: (_) => const [
                                    PopupMenuItem(value: 'edit', child: Text('Editar')),
                                    PopupMenuItem(
                                      value: 'delete',
                                      child: Text('Excluir', style: TextStyle(color: Colors.red)),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            onTap: () => _selectSong(song),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([widget.repository, widget.setlists, widget.account]),
      builder: (context, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 720;

            if (isMobile) {
              // Celular: Cifra na tela principal e Sidebar no Drawer
              return Scaffold(
                appBar: AppBar(
                  title: Text(_currentSong?.title ?? 'Cifras'),
                  leading: Builder(
                    builder: (btnContext) => IconButton(
                      icon: const Icon(Icons.menu),
                      onPressed: () => Scaffold.of(btnContext).openDrawer(),
                    ),
                  ),
                  actions: [
                    SyncButton(sync: widget.sync, account: widget.account),
                    AccountButton(account: widget.account),
                  ],
                ),
                drawer: Drawer(
                  child: SafeArea(child: _buildSidebarContent()),
                ),
                body: _buildMusicianReader(true),
              );
            }

            // Desktop / Tablets: Split-View Responsivo com Sidebar recolhível
            return Scaffold(
              body: SafeArea(
                child: Row(
                  children: [
                    // Barra Lateral (Sidebar)
                    if (_showSidebar)
                      SizedBox(
                        width: 330,
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border(right: BorderSide(color: Colors.grey.withValues(alpha: 0.2))),
                          ),
                          child: _buildSidebarContent(),
                        ),
                      ),
                    // Painel de Leitura Limpo para o Músico
                    Expanded(
                      child: _buildMusicianReader(false),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
