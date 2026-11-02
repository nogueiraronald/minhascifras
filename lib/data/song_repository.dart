import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/song.dart';

/// Armazenamento local (offline). Trocar por Drift/SQLite no futuro
/// exige mudar apenas este arquivo.
class SongRepository extends ChangeNotifier {
  SongRepository._(this._prefs, this._songs);

  static const _key = 'songs_v1';
  final SharedPreferences _prefs;
  final List<Song> _songs;

  /// Chamado após alterações feitas pelo usuário (não pela sincronização).
  VoidCallback? onLocalChange;

  static Future<SongRepository> open() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    final list = raw == null
        ? <Song>[]
        : (jsonDecode(raw) as List)
            .map((e) => Song.fromJson(e as Map<String, dynamic>))
            .toList();
    return SongRepository._(prefs, list);
  }

  List<Song> get songs {
    final list = _songs.where((s) => !s.deleted).toList();
    list.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    return list;
  }

  Future<void> save(Song song) async {
    final i = _songs.indexWhere((s) => s.id == song.id);
    if (i >= 0) {
      _songs[i] = song;
    } else {
      _songs.add(song);
    }
    await _persist();
    onLocalChange?.call();
  }

  Future<void> saveAll(List<Song> songs) async {
    for (final song in songs) {
      final i = _songs.indexWhere((s) => s.id == song.id);
      if (i >= 0) {
        _songs[i] = song;
      } else {
        _songs.add(song);
      }
    }
    await _persist();
    onLocalChange?.call();
  }

  Future<void> remove(String id) async {
    final i = _songs.indexWhere((s) => s.id == id);
    if (i < 0) return;
    _songs[i] = _songs[i].copyWith(deleted: true);
    await _persist();
    onLocalChange?.call();
  }

  /// Todas as músicas, inclusive as marcadas como excluídas (para sincronizar).
  List<Song> get allSongs => List.unmodifiable(_songs);

  /// Grava músicas vindas da nuvem sem disparar nova sincronização.
  Future<void> upsertAll(List<Song> incoming) async {
    for (final song in incoming) {
      final i = _songs.indexWhere((s) => s.id == song.id);
      if (i >= 0) {
        _songs[i] = song;
      } else {
        _songs.add(song);
      }
    }
    await _persist();
  }

  Future<void> _persist() async {
    await _prefs.setString(
        _key, jsonEncode(_songs.map((s) => s.toJson()).toList()));
    notifyListeners();
  }
}
