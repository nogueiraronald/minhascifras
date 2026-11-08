import 'dart:async';

import 'package:flutter/foundation.dart';

import '../dados/controlador_conta.dart';
import '../dados/repositorio_listas.dart';
import '../dados/repositorio_musicas.dart';
import '../dados/repositorio_temas.dart';
import '../modelos/lista_repertorio.dart';
import '../modelos/item_lista_repertorio.dart';
import '../modelos/musica.dart';
import 'dados_nuvem.dart';
import 'servico_supabase_sync.dart';

/// Sincronização inteligente sem duplicidade no Supabase:
/// Reconcilia músicas por (Título + Artista) e Setlists por Nome.
/// Vence a versão com updatedAt mais recente ou mescla sem gerar duplicatas.
class SyncService extends ChangeNotifier {
  SyncService(
    this._songs,
    this._setlists,
    this._account, {
    ThemeRepository? musicThemes,
    SupabaseSyncService? supabaseSync,
  })  : _musicThemes = musicThemes,
        _supabaseSync = supabaseSync ?? SupabaseSyncService() {
    _songs.onLocalChange = _schedule;
    _setlists.onLocalChange = _schedule;
    _musicThemes?.onLocalChange = _schedule;
    _account.addListener(_onAccount);
  }

  final SongRepository _songs;
  final SetlistRepository _setlists;
  final AccountController _account;
  final ThemeRepository? _musicThemes;
  final SupabaseSyncService _supabaseSync;

  Timer? _debounce;
  bool _running = false;
  bool _again = false;
  String? _lastCode;

  bool syncing = false;
  String? error;
  DateTime? lastSync;

  void _onAccount() {
    if (_account.status == AccountStatus.ready && _lastCode != _account.syncCode) {
      _lastCode = _account.syncCode;
      sync();
    }
  }

  void _schedule() {
    _debounce?.cancel();
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
      final msg = e.toString().toLowerCase();
      if (msg.contains('clientexception') ||
          msg.contains('load failed') ||
          msg.contains('socketexception') ||
          msg.contains('timeout') ||
          msg.contains('failed host lookup') ||
          msg.contains('network is unreachable')) {
        error = 'Não foi possível conectar à Nuvem. Verifique sua conexão com a internet e tente novamente.';
      } else {
        error = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
      }
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
    final code = _account.syncCode;
    if (code == null || code.isEmpty) return;

    final remote = await _supabaseSync.readAll(code);

    // SEGURANÇA CRÍTICA: Se o repertório na nuvem tem senha configurada,
    // o cliente local DEVE possuir o mesmo hash de senha para ter acesso aos dados.
    if (remote.passwordHash != null && remote.passwordHash!.isNotEmpty) {
      if (_account.passwordHash != remote.passwordHash) {
        _account.lockWithRemoteHash(remote.passwordHash!);
        error =
            'Este repertório está protegido por senha. Informe a senha para sincronizar.';
        notifyListeners();
        return;
      }
    }

    // Se a nuvem informou IDs ou Chaves excluídas, exclui localmente apenas se a música
    // não estiver ativa com alteração recente (ex: acabou de ser importada ou recriada pelo usuário).
    final now = DateTime.now();
    for (final deletedId in remote.deletedSongIds) {
      final existing =
          _songs.allSongs.where((s) => s.id == deletedId && !s.deleted).firstOrNull;
      if (existing != null) {
        if (now.difference(existing.updatedAt).inMinutes < 15) {
          continue;
        }
        await _songs.remove(deletedId);
      }
    }
    for (final deletedKey in remote.deletedSongKeys) {
      final existing = _songs.allSongs
          .where((s) =>
              !s.deleted &&
              '${s.title.trim().toLowerCase()}|${s.artist.trim().toLowerCase()}' ==
                  deletedKey)
          .firstOrNull;
      if (existing != null) {
        if (now.difference(existing.updatedAt).inMinutes < 15) {
          continue;
        }
        await _songs.remove(existing.id);
      }
    }
    for (final deletedId in remote.deletedSetlistIds) {
      final existing = _setlists.allSetlists
          .where((s) => s.id == deletedId && !s.deleted)
          .firstOrNull;
      if (existing != null) {
        await _setlists.removeSetlist(deletedId);
      }
    }

    // 1. Reconciliação e desduplicação de músicas por (Título + Artista)
    final (songPull, songPush, localToRemoteSongIdMap) =
        _deduplicateAndMergeSongs(
      remote.songs,
      _songs.allSongs,
      remote.deletedSongIds,
      remote.deletedSongKeys,
    );

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

    var themePush = false;
    final allDeletedThemes = <String>{};
    if (_musicThemes != null) {
      allDeletedThemes.addAll(remote.deletedThemes);
      allDeletedThemes.addAll(_musicThemes.deletedThemes);

      // Aplica exclusões remotas aos temas locais
      for (final del in remote.deletedThemes) {
        final dLower = del.trim().toLowerCase();
        if (_musicThemes.themes.any((t) => t.toLowerCase() == dLower)) {
          await _musicThemes.removeThemeFromSync(del);
        }
      }

      // Adiciona novos temas da nuvem que NÃO foram excluídos pelo usuário
      for (final rTheme in remote.themes) {
        final rLower = rTheme.trim().toLowerCase();
        if (!allDeletedThemes.contains(rLower) &&
            !_musicThemes.themes.any((t) => t.toLowerCase() == rLower)) {
          await _musicThemes.addThemeFromSync(rTheme);
        }
      }

      // Se um tema local foi adicionado pelo usuário após ter sido excluído na nuvem,
      // ele é retirado de allDeletedThemes
      for (final t in _musicThemes.themes) {
        allDeletedThemes.remove(t.toLowerCase().trim());
      }

      // Verifica se a lista de temas locais ou exclusões difere da nuvem
      final localThemeSet =
          _musicThemes.themes.map((t) => t.toLowerCase()).toSet();
      final remoteThemeSet =
          remote.themes.map((t) => t.toLowerCase()).toSet();
      if (localThemeSet.length != remoteThemeSet.length ||
          !localThemeSet.containsAll(remoteThemeSet) ||
          allDeletedThemes.length != remote.deletedThemes.length) {
        themePush = true;
      }
    }

    final activeLocalKeys = _songs.songs
        .map((s) => '${s.title.trim().toLowerCase()}|${s.artist.trim().toLowerCase()}')
        .toSet();
    final activeLocalIds = _songs.songs.map((s) => s.id).toSet();

    final allDeletedSongIds = {
      ...remote.deletedSongIds,
      ..._songs.allSongs.where((s) => s.deleted).map((s) => s.id),
    }.where((id) => !activeLocalIds.contains(id)).toList();

    final allDeletedSongKeys = {
      ...remote.deletedSongKeys,
      ..._songs.allSongs
          .where((s) => s.deleted)
          .map((s) =>
              '${s.title.trim().toLowerCase()}|${s.artist.trim().toLowerCase()}'),
    }.where((key) => !activeLocalKeys.contains(key)).toList();

    final allDeletedSetlistIds = {
      ...remote.deletedSetlistIds,
      ..._setlists.allSetlists.where((s) => s.deleted).map((s) => s.id),
    }.toList();

    final allDeletedItemIds = {
      ...remote.deletedItemIds,
      ..._setlists.allItems.where((i) => i.deleted).map((i) => i.id),
    }.toList();

    // Sempre envia o backup na primeira sincronização ou quando houver novidades locais ou senha alterada
    final isFirstUpload = remote.songs.isEmpty && _songs.songs.isNotEmpty;
    final passwordChanged = _account.passwordHash != remote.passwordHash;
    final nicknameChanged = _account.userNickname != null &&
        _account.userNickname!.isNotEmpty &&
        _account.userNickname != remote.nickname;
    final deletionsRevoked = allDeletedSongKeys.length < remote.deletedSongKeys.length ||
        allDeletedSongIds.length < remote.deletedSongIds.length;
    if ((_account.userNickname == null || _account.userNickname!.isEmpty) &&
        remote.nickname != null &&
        remote.nickname!.isNotEmpty) {
      await _account.setNickname(remote.nickname!);
    }
    if (songPush || setlistPush || itemPush || themePush || isFirstUpload || passwordChanged || nicknameChanged || deletionsRevoked) {
      await _supabaseSync.writeAll(
        code,
        CloudData(
          songs: _songs.songs,
          setlists: _setlists.setlists,
          items: _setlists.items,
          themes: _musicThemes?.themes ?? const [],
          deletedSongIds: allDeletedSongIds,
          deletedSongKeys: allDeletedSongKeys,
          deletedSetlistIds: allDeletedSetlistIds,
          deletedItemIds: allDeletedItemIds,
          deletedThemes: allDeletedThemes.toList(),
          passwordHash: _account.passwordHash,
          nickname: _account.userNickname ?? remote.nickname,
        ),
      );
    }
  }

  @visibleForTesting
  static (List<Song> pull, bool push, Map<String, String> songIdMap)
      deduplicateAndMergeSongsForTesting(
    List<Song> remote,
    List<Song> local,
    List<String> remoteDeletedIds, [
    List<String> remoteDeletedKeys = const [],
  ]) =>
      _deduplicateAndMergeSongs(remote, local, remoteDeletedIds, remoteDeletedKeys);

  /// Mescla músicas locais e da nuvem sem gerar duplicidade.
  /// Identifica músicas equivalentes pelo mesmo Título e Artista (case-insensitive).
  static (List<Song> pull, bool push, Map<String, String> songIdMap)
      _deduplicateAndMergeSongs(
    List<Song> remote,
    List<Song> local,
    List<String> remoteDeletedIds, [
    List<String> remoteDeletedKeys = const [],
  ]) {
    final pull = <Song>[];
    var push = false;
    final songIdMap = <String, String>{};

    String normKey(String title, String artist) =>
        '${title.trim().toLowerCase()}|${artist.trim().toLowerCase()}';

    final deletedKeySet = remoteDeletedKeys.toSet();
    final deletedIdSet = remoteDeletedIds.toSet();

    final remoteByKey = <String, Song>{};
    for (final r in remote) {
      final key = normKey(r.title, r.artist);
      if (!r.deleted && !deletedIdSet.contains(r.id) && !deletedKeySet.contains(key)) {
        remoteByKey[key] = r;
      }
    }

    final localByKey = <String, Song>{};
    for (final l in local) {
      localByKey[normKey(l.title, l.artist)] = l;
    }

    // Compara músicas locais com as da nuvem
    final now = DateTime.now();
    for (final l in local) {
      final key = normKey(l.title, l.artist);
      final r = remoteByKey[key];

      // Se a música foi excluída na nuvem (por chave ou ID):
      // Se o usuário local a reativou ou importou recentemente (!l.deleted e alterada nos últimos 15 min),
      // trata como restauração explícita (ressurreição) e envia para a nuvem.
      if (deletedKeySet.contains(key) || deletedIdSet.contains(l.id)) {
        if (!l.deleted && now.difference(l.updatedAt).inMinutes < 15) {
          push = true;
        } else {
          continue;
        }
      }

      if (r == null) {
        // Se a música local não está marcada como deletada, envia para a nuvem
        if (!l.deleted) {
          push = true;
        }
      } else {
        // Mesma música encontrada na nuvem: mapeia os IDs para vincular setlists
        songIdMap[l.id] = r.id;

        if (l.deleted) {
          // Excluída localmente: dispara push para remover da nuvem
          push = true;
        } else {
          // Ambas existem: vence a que foi editada mais recentemente
          if (r.updatedAt.isAfter(l.updatedAt)) {
            pull.add(Song(
              id: l.id,
              title: r.title,
              artist: r.artist,
              content: r.content,
              originalKey: r.originalKey,
              isFavorite: r.isFavorite,
              tags: r.tags,
              audioUrl: r.audioUrl,
              audioDurationSeconds: r.audioDurationSeconds,
              updatedAt: r.updatedAt,
              deleted: r.deleted,
            ));
          } else if (l.updatedAt.isAfter(r.updatedAt)) {
            push = true;
          }
        }
      }
    }

    // Músicas que estão na nuvem mas NÃO estão no dispositivo local
    for (final r in remote) {
      if (r.deleted || remoteDeletedIds.contains(r.id)) continue;
      final key = normKey(r.title, r.artist);
      if (!localByKey.containsKey(key)) {
        pull.add(r);
      }
    }

    return (pull, push, songIdMap);
  }

  /// Mescla setlists sem duplicar nomes idênticos
  static (List<Setlist> pull, bool push, Map<String, String> setlistIdMap)
      _deduplicateAndMergeSetlists(
    List<Setlist> remote,
    List<Setlist> local,
    List<String> remoteDeletedIds,
  ) {
    final pull = <Setlist>[];
    var push = false;
    final setlistIdMap = <String, String>{};

    String normKey(String name) => name.trim().toLowerCase();

    final remoteByKey = <String, Setlist>{};
    for (final r in remote) {
      if (!r.deleted && !remoteDeletedIds.contains(r.id)) {
        remoteByKey[normKey(r.name)] = r;
      }
    }

    final localByKey = <String, Setlist>{};
    for (final l in local) {
      localByKey[normKey(l.name)] = l;
    }

    for (final l in local) {
      final key = normKey(l.name);
      final r = remoteByKey[key];

      if (r == null) {
        if (!l.deleted) push = true;
      } else {
        setlistIdMap[l.id] = r.id;
        if (l.deleted) {
          push = true;
        } else {
          if (r.updatedAt.isAfter(l.updatedAt)) {
            pull.add(Setlist(
              id: l.id,
              name: r.name,
              notes: r.notes,
              updatedAt: r.updatedAt,
              deleted: r.deleted,
            ));
          } else if (l.updatedAt.isAfter(r.updatedAt)) {
            push = true;
          }
        }
      }
    }

    for (final r in remote) {
      if (r.deleted || remoteDeletedIds.contains(r.id)) continue;
      final key = normKey(r.name);
      if (!localByKey.containsKey(key)) {
        pull.add(r);
      }
    }

    return (pull, push, setlistIdMap);
  }

  /// Mescla itens de setlist
  static (List<SetlistItem> pull, bool push) _deduplicateAndMergeItems(
    List<SetlistItem> remote,
    List<SetlistItem> local,
    Map<String, String> localToRemoteSongIdMap,
    Map<String, String> localToRemoteSetlistIdMap,
    List<String> remoteDeletedIds,
  ) {
    final pull = <SetlistItem>[];
    var push = false;

    String itemKey(String setlistId, String songId, int pos) =>
        '$setlistId|$songId|$pos';

    final remoteItems = <String, SetlistItem>{};
    for (final r in remote) {
      if (!r.deleted && !remoteDeletedIds.contains(r.id)) {
        remoteItems[itemKey(r.setlistId, r.songId, r.position)] = r;
      }
    }

    final localItems = <String, SetlistItem>{};
    for (final l in local) {
      final remSetlistId = localToRemoteSetlistIdMap[l.setlistId] ?? l.setlistId;
      final remSongId = localToRemoteSongIdMap[l.songId] ?? l.songId;
      localItems[itemKey(remSetlistId, remSongId, l.position)] = l;
    }

    for (final l in local) {
      final remSetlistId = localToRemoteSetlistIdMap[l.setlistId] ?? l.setlistId;
      final remSongId = localToRemoteSongIdMap[l.songId] ?? l.songId;
      final key = itemKey(remSetlistId, remSongId, l.position);

      final r = remoteItems[key];
      if (r == null) {
        if (!l.deleted) push = true;
      } else {
        if (l.deleted) {
          push = true;
        } else if (r.updatedAt.isAfter(l.updatedAt)) {
          pull.add(r.copyWith(position: l.position));
        } else if (l.updatedAt.isAfter(r.updatedAt)) {
          push = true;
        }
      }
    }

    for (final r in remote) {
      if (r.deleted || remoteDeletedIds.contains(r.id)) continue;
      final key = itemKey(r.setlistId, r.songId, r.position);
      if (!localItems.containsKey(key)) {
        pull.add(r);
      }
    }

    return (pull, push);
  }
}
