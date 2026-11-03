import 'dart:async';

import 'package:flutter/foundation.dart';

import '../dados/controlador_conta.dart';
import '../dados/repositorio_listas.dart';
import '../dados/repositorio_musicas.dart';
import '../modelos/lista_repertorio.dart';
import '../modelos/item_lista_repertorio.dart';
import '../modelos/musica.dart';
import 'dados_nuvem.dart';

/// Sincronização inteligente sem duplicidade:
/// Reconcilia músicas por (Título + Artista) e Setlists por Nome.
/// Vence a versão com updatedAt mais recente ou mescla sem gerar duplicatas.
class SyncService extends ChangeNotifier {
  SyncService(this._songs, this._setlists, this._account) {
    // Sincroniza apenas nos 3 momentos especificados:
    // 1. Ao abrir o app / conectar conta
    // 2. Ao adicionar ou editar uma música
    // 3. Manualmente pelo botão
    _songs.onLocalChange = _schedule;
    _account.addListener(_onAccount);
  }

  final SongRepository _songs;
  final SetlistRepository _setlists;
  final AccountController _account;
  Timer? _debounce;
  bool _running = false;
  bool _again = false;
  AccountStatus? _lastStatus;

  bool syncing = false;
  String? error;
  DateTime? lastSync;

  void _onAccount() {
    if (_account.status == AccountStatus.ready && _lastStatus != AccountStatus.ready) {
      sync();
    }
    _lastStatus = _account.status;
  }

  void _schedule() {
    _debounce?.cancel();
    // Resposta rápida (400ms) ao salvar/adicionar música, sem lentidão desnecessária
    _debounce = Timer(const Duration(milliseconds: 400), sync);
  }

  Future<void> sync() async {
    if (_account.status != AccountStatus.ready) return;
    if (_running) {
      _again = true;
      return;
    }
    _running = true;
    syncing = true;
    error = null;
    notifyListeners();
    try {
      await _run();
      lastSync = DateTime.now();
    } catch (e) {
      error = '$e';
    }
    _running = false;
    syncing = false;
    notifyListeners();
    if (_again) {
      _again = false;
      _schedule();
    }
  }

  Future<void> _run() async {
    final id = _account.spreadsheetId!;
    final remote = await _account.sheets.readAll(id);

    // Se a nuvem informou IDs excluídos, exclui localmente também
    for (final deletedId in remote.deletedSongIds) {
      final existing = _songs.allSongs.where((s) => s.id == deletedId && !s.deleted).firstOrNull;
      if (existing != null) {
        await _songs.remove(deletedId);
      }
    }
    for (final deletedId in remote.deletedSetlistIds) {
      final existing = _setlists.allSetlists.where((s) => s.id == deletedId && !s.deleted).firstOrNull;
      if (existing != null) {
        await _setlists.removeSetlist(deletedId);
      }
    }

    // 1. Reconciliação e desduplicação de músicas por (Título + Artista)
    final (songPull, songPush, localToRemoteSongIdMap) =
        _deduplicateAndMergeSongs(remote.songs, _songs.allSongs, remote.deletedSongIds);

    // 2. Reconciliação e desduplicação de setlists por Nome
    final (setlistPull, setlistPush, localToRemoteSetlistIdMap) =
        _deduplicateAndMergeSetlists(remote.setlists, _setlists.allSetlists, remote.deletedSetlistIds);

    // 3. Reconciliação e desduplicação de itens de setlist
    final (itemPull, itemPush) = _deduplicateAndMergeItems(
      remote.items,
      _setlists.allItems,
      localToRemoteSongIdMap,
      localToRemoteSetlistIdMap,
      remote.deletedItemIds,
    );

    if (songPull.isNotEmpty) await _songs.upsertAll(songPull);
    if (setlistPull.isNotEmpty || itemPull.isNotEmpty) {
      await _setlists.upsertAll(setlists: setlistPull, items: itemPull);
    }

    final allDeletedSongIds = {
      ...remote.deletedSongIds,
      ..._songs.allSongs.where((s) => s.deleted).map((s) => s.id),
    }.toList();

    final allDeletedSetlistIds = {
      ...remote.deletedSetlistIds,
      ..._setlists.allSetlists.where((s) => s.deleted).map((s) => s.id),
    }.toList();

    final allDeletedItemIds = {
      ...remote.deletedItemIds,
      ..._setlists.allItems.where((i) => i.deleted).map((i) => i.id),
    }.toList();

    if (songPush || setlistPush || itemPush) {
      await _account.sheets.writeAll(
        id,
        CloudData(
          // Envia APENAS itens ativos: as linhas deletadas são completamente removidas
          songs: _songs.songs,
          setlists: _setlists.setlists,
          items: _setlists.items,
          deletedSongIds: allDeletedSongIds,
          deletedSetlistIds: allDeletedSetlistIds,
          deletedItemIds: allDeletedItemIds,
        ),
      );
    }
  }

  @visibleForTesting
  static (List<Song> pull, bool push, Map<String, String> songIdMap)
      deduplicateAndMergeSongsForTesting(
    List<Song> remote,
    List<Song> local,
    List<String> remoteDeletedIds,
  ) =>
      _deduplicateAndMergeSongs(remote, local, remoteDeletedIds);

  /// Mescla músicas locais e da nuvem sem gerar duplicidade.
  /// Identifica músicas equivalentes pelo mesmo Título e Artista (case-insensitive).
  static (List<Song> pull, bool push, Map<String, String> songIdMap)
      _deduplicateAndMergeSongs(
    List<Song> remote,
    List<Song> local,
    List<String> remoteDeletedIds,
  ) {
    String songKey(Song s) =>
        '${s.title.trim().toLowerCase()}:::${s.artist.trim().toLowerCase()}';

    final remoteById = {for (final r in remote) r.id: r};
    final remoteByKey = {for (final r in remote) songKey(r): r};
    final remoteDeletedSet = remoteDeletedIds.toSet();

    final localById = {for (final l in local) l.id: l};
    final localByKey = {for (final l in local) songKey(l): l};

    final pull = <Song>[];
    var push = false;
    final idMap = <String, String>{}; // localId -> canonicalId

    // Compara o que existe localmente com a nuvem
    for (final l in local) {
      final key = songKey(l);
      final r = remoteById[l.id] ?? remoteByKey[key];

      if (r != null) {
        idMap[l.id] = r.id;
        if (l.deleted) {
          // Excluída localmente: remove da nuvem se r ainda não constava como deletada
          if (!r.deleted) push = true;
        } else if (r.updatedAt.isAfter(l.updatedAt)) {
          pull.add(r);
        } else if (l.updatedAt.isAfter(r.updatedAt) || l.content != r.content) {
          push = true;
        }
      } else {
        // Música nova local que ainda não existe na nuvem
        if (l.deleted) {
          if (!remoteDeletedSet.contains(l.id)) push = true;
        } else {
          push = true;
        }
      }
    }

    // Identifica músicas na nuvem que não existem localmente
    for (final r in remote) {
      final key = songKey(r);
      final l = localById[r.id] ?? localByKey[key];
      if (l == null) {
        pull.add(r);
      } else if (l.deleted) {
        // Localmente foi deletada, garante que seja removida da nuvem
        push = true;
      }
    }

    return (pull, push, idMap);
  }

  /// Mescla setlists locais e da nuvem sem gerar duplicidade de nomes.
  static (List<Setlist> pull, bool push, Map<String, String> setlistIdMap)
      _deduplicateAndMergeSetlists(
    List<Setlist> remote,
    List<Setlist> local,
    List<String> remoteDeletedIds,
  ) {
    String setlistKey(Setlist s) => s.name.trim().toLowerCase();

    final remoteById = {for (final r in remote) r.id: r};
    final remoteByKey = {for (final r in remote) setlistKey(r): r};
    final remoteDeletedSet = remoteDeletedIds.toSet();

    final localById = {for (final l in local) l.id: l};
    final localByKey = {for (final l in local) setlistKey(l): l};

    final pull = <Setlist>[];
    var push = false;
    final idMap = <String, String>{};

    for (final l in local) {
      final key = setlistKey(l);
      final r = remoteById[l.id] ?? remoteByKey[key];

      if (r != null) {
        idMap[l.id] = r.id;
        if (l.deleted) {
          push = true;
        } else if (r.updatedAt.isAfter(l.updatedAt)) {
          pull.add(r);
        } else if (l.updatedAt.isAfter(r.updatedAt) || l.id != r.id) {
          push = true;
        }
      } else {
        if (l.deleted) {
          if (!remoteDeletedSet.contains(l.id)) push = true;
        } else {
          if (!remoteDeletedSet.contains(l.id)) push = true;
        }
      }
    }

    for (final r in remote) {
      final key = setlistKey(r);
      final l = localById[r.id] ?? localByKey[key];
      if (l == null) {
        pull.add(r);
      } else if (l.deleted) {
        push = true;
      }
    }

    return (pull, push, idMap);
  }

  /// Mescla itens de setlist garantindo que a mesma música não apareça duplicada na mesma setlist
  static (List<SetlistItem> pull, bool push) _deduplicateAndMergeItems(
    List<SetlistItem> remote,
    List<SetlistItem> local,
    Map<String, String> songIdMap,
    Map<String, String> setlistIdMap,
    List<String> remoteDeletedIds,
  ) {
    String itemKey(String setlistId, String songId) => '$setlistId:::$songId';

    final remoteById = {for (final r in remote) r.id: r};
    final remoteByKey = {for (final r in remote) itemKey(r.setlistId, r.songId): r};
    final remoteDeletedSet = remoteDeletedIds.toSet();

    final pull = <SetlistItem>[];
    var push = false;

    for (final l in local) {
      final targetSetlistId = setlistIdMap[l.setlistId] ?? l.setlistId;
      final targetSongId = songIdMap[l.songId] ?? l.songId;
      final key = itemKey(targetSetlistId, targetSongId);

      final r = remoteById[l.id] ?? remoteByKey[key];
      if (r != null) {
        if (l.deleted) {
          push = true;
        } else if (r.updatedAt.isAfter(l.updatedAt)) {
          pull.add(r);
        } else if (l.updatedAt.isAfter(r.updatedAt)) {
          push = true;
        }
      } else {
        if (l.deleted) {
          if (!remoteDeletedSet.contains(l.id)) push = true;
        } else {
          if (!remoteDeletedSet.contains(l.id)) push = true;
        }
      }
    }

    for (final r in remote) {
      final l = local.where((it) {
        final targetSetlistId = setlistIdMap[it.setlistId] ?? it.setlistId;
        final targetSongId = songIdMap[it.songId] ?? it.songId;
        return r.id == it.id || (r.setlistId == targetSetlistId && r.songId == targetSongId);
      }).firstOrNull;

      if (l == null) {
        pull.add(r);
      } else if (l.deleted) {
        push = true;
      }
    }

    return (pull, push);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _account.removeListener(_onAccount);
    super.dispose();
  }
}
