import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/account_controller.dart';
import '../data/setlist_repository.dart';
import '../data/song_repository.dart';
import '../models/setlist.dart';
import '../models/setlist_item.dart';
import '../models/song.dart';
import 'cloud_data.dart';

class _Merge<T> {
  const _Merge(this.pull, this.push);
  final List<T> pull;
  final bool push;
}

/// Sincronização econômica: no máximo 1 leitura + 1 escrita por rodada,
/// só dispara em login, após alterações locais (com espera de 5 s) ou manualmente.
class SyncService extends ChangeNotifier {
  SyncService(this._songs, this._setlists, this._account) {
    _songs.onLocalChange = _schedule;
    _setlists.onLocalChange = _schedule;
    _account.addListener(_onAccount);
    // Tenta de novo depois de falhas (ex.: ficou offline).
    _retry = Timer.periodic(const Duration(minutes: 5), (_) {
      if (error != null) sync();
    });
  }

  final SongRepository _songs;
  final SetlistRepository _setlists;
  final AccountController _account;
  Timer? _debounce;
  Timer? _retry;
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
    _debounce = Timer(const Duration(seconds: 5), sync);
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

    final s = _merge<Song>(remote.songs, _songs.allSongs, (e) => e.id, (e) => e.updatedAt);
    final l = _merge<Setlist>(
        remote.setlists, _setlists.allSetlists, (e) => e.id, (e) => e.updatedAt);
    final i = _merge<SetlistItem>(
        remote.items, _setlists.allItems, (e) => e.id, (e) => e.updatedAt);

    if (s.pull.isNotEmpty) await _songs.upsertAll(s.pull);
    if (l.pull.isNotEmpty || i.pull.isNotEmpty) {
      await _setlists.upsertAll(setlists: l.pull, items: i.pull);
    }
    if (s.push || l.push || i.push) {
      await _account.sheets.writeAll(
        id,
        CloudData(
          songs: _songs.allSongs,
          setlists: _setlists.allSetlists,
          items: _setlists.allItems,
        ),
      );
    }
  }

  /// Vence a versão com updatedAt mais recente (por registro).
  static _Merge<T> _merge<T>(
    List<T> remote,
    List<T> local,
    String Function(T) idOf,
    DateTime Function(T) atOf,
  ) {
    final localById = {for (final e in local) idOf(e): e};
    final remoteIds = {for (final e in remote) idOf(e)};
    final pull = <T>[];
    var push = local.any((e) => !remoteIds.contains(idOf(e)));
    for (final r in remote) {
      final l = localById[idOf(r)];
      if (l == null || atOf(r).isAfter(atOf(l))) {
        pull.add(r);
      } else if (atOf(l).isAfter(atOf(r))) {
        push = true;
      }
    }
    return _Merge(pull, push);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _retry?.cancel();
    _account.removeListener(_onAccount);
    super.dispose();
  }
}
