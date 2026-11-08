import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../modelos/musica.dart';
import '../servicos/transpositor_acordes.dart';
import '../servicos/servico_importacao_cifra.dart';

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
            .map((e) {
              final s = Song.fromJson(e as Map<String, dynamic>);
              return s.copyWith(
                content: ChordTransposer.cleanText(s.content),
                audioUrl: Song.cleanAudioUrl(s.audioUrl),
                updatedAt: s.updatedAt,
              );
            })
            .toList();
    final repo = SongRepository._(prefs, list);
    await repo.sanitizeSongMetadata();
    return repo;
  }

  List<Song> get songs {
    final list = _songs.where((s) => !s.deleted).toList();
    list.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    return list;
  }

  /// Normaliza chave de identificação única por título e artista
  static String normKey(String title, String artist) {
    return '${title.trim().toLowerCase()}_${artist.trim().toLowerCase()}';
  }

  Future<void> save(Song song) async {
    final cleanSong = song.copyWith(content: ChordTransposer.cleanText(song.content));
    final key = normKey(cleanSong.title, cleanSong.artist);
    final i = _songs.indexWhere((s) =>
        s.id == cleanSong.id || normKey(s.title, s.artist) == key);
    if (i >= 0) {
      final prevUpdatedAt = _songs[i].updatedAt;
      final nextUpdatedAt = cleanSong.updatedAt.isAfter(prevUpdatedAt)
          ? cleanSong.updatedAt
          : prevUpdatedAt.add(const Duration(seconds: 1));
      _songs[i] = cleanSong.copyWith(
        id: _songs[i].id,
        deleted: false,
        updatedAt: nextUpdatedAt,
      );
    } else {
      _songs.add(cleanSong);
    }
    await _persist();
    onLocalChange?.call();
    notifyListeners();
  }

  Future<void> saveAll(List<Song> songs) async {
    for (final song in songs) {
      final cleanSong = song.copyWith(content: ChordTransposer.cleanText(song.content));
      final key = normKey(cleanSong.title, cleanSong.artist);
      final i = _songs.indexWhere((s) =>
          s.id == cleanSong.id || normKey(s.title, s.artist) == key);
      if (i >= 0) {
        final prevUpdatedAt = _songs[i].updatedAt;
        final nextUpdatedAt = cleanSong.updatedAt.isAfter(prevUpdatedAt)
            ? cleanSong.updatedAt
            : prevUpdatedAt.add(const Duration(seconds: 1));
        _songs[i] = cleanSong.copyWith(
          id: _songs[i].id,
          deleted: false,
          updatedAt: nextUpdatedAt,
        );
      } else {
        _songs.add(cleanSong);
      }
    }
    await _persist();
    onLocalChange?.call();
    notifyListeners();
  }

  Future<void> toggleFavorite(String id) async {
    final i = _songs.indexWhere((s) => s.id == id);
    if (i < 0) return;
    _songs[i] = _songs[i].copyWith(isFavorite: !_songs[i].isFavorite);
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

  /// Limpa todas as músicas locais para deslogar e começar um novo repertório do zero.
  Future<void> clearAll() async {
    _songs.clear();
    await _persist();
    notifyListeners();
  }

  Future<void> setSongTags(String id, List<String> tags) async {
    final i = _songs.indexWhere((s) => s.id == id);
    if (i < 0) return;
    final cleanTags = tags.map((t) => t.trim()).where((t) => t.isNotEmpty).toSet().toList();
    _songs[i] = _songs[i].copyWith(tags: cleanTags);
    await _persist();
    onLocalChange?.call();
  }

  Future<void> addTagToSong(String id, String tag) async {
    final i = _songs.indexWhere((s) => s.id == id);
    if (i < 0) return;
    final current = List<String>.from(_songs[i].tags);
    final trimmed = tag.trim();
    if (!current.any((t) => t.toLowerCase() == trimmed.toLowerCase())) {
      current.add(trimmed);
      _songs[i] = _songs[i].copyWith(tags: current);
      await _persist();
      onLocalChange?.call();
    }
  }

  Future<void> removeTagFromSong(String id, String tag) async {
    final i = _songs.indexWhere((s) => s.id == id);
    if (i < 0) return;
    final current = List<String>.from(_songs[i].tags);
    final initialCount = current.length;
    current.removeWhere((t) => t.toLowerCase() == tag.toLowerCase().trim());
    if (current.length != initialCount) {
      _songs[i] = _songs[i].copyWith(tags: current);
      await _persist();
      onLocalChange?.call();
    }
  }

  Future<void> addSongsToTheme(List<String> songIds, String theme) async {
    final trimmed = theme.trim();
    if (trimmed.isEmpty) return;
    bool changed = false;
    for (final id in songIds) {
      final i = _songs.indexWhere((s) => s.id == id);
      if (i >= 0) {
        final current = List<String>.from(_songs[i].tags);
        if (!current.any((t) => t.toLowerCase() == trimmed.toLowerCase())) {
          current.add(trimmed);
          _songs[i] = _songs[i].copyWith(tags: current);
          changed = true;
        }
      }
    }
    if (changed) {
      await _persist();
      onLocalChange?.call();
    }
  }

  Future<void> removeTagFromAll(String tag) async {
    final trimmed = tag.toLowerCase().trim();
    bool changed = false;
    for (int i = 0; i < _songs.length; i++) {
      if (_songs[i].tags.any((t) => t.toLowerCase().trim() == trimmed)) {
        final current = List<String>.from(_songs[i].tags);
        current.removeWhere((t) => t.toLowerCase().trim() == trimmed);
        _songs[i] = _songs[i].copyWith(tags: current);
        changed = true;
      }
    }
    if (changed) {
      await _persist();
      onLocalChange?.call();
    }
  }

  Future<void> renameTagInAll(String oldTag, String newTag) async {
    final oldTrimmed = oldTag.toLowerCase().trim();
    final newTrimmed = newTag.trim();
    bool changed = false;
    for (int i = 0; i < _songs.length; i++) {
      if (_songs[i].tags.any((t) => t.toLowerCase().trim() == oldTrimmed)) {
        final current = _songs[i].tags.map((t) => t.toLowerCase().trim() == oldTrimmed ? newTrimmed : t).toList();
        _songs[i] = _songs[i].copyWith(tags: current);
        changed = true;
      }
    }
    if (changed) {
      await _persist();
      onLocalChange?.call();
    }
  }

  Future<void> removeAll() async {
    bool changed = false;
    for (int i = 0; i < _songs.length; i++) {
      if (!_songs[i].deleted) {
        _songs[i] = _songs[i].copyWith(deleted: true);
        changed = true;
      }
    }
    if (changed) {
      await _persist();
      onLocalChange?.call();
    }
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

  /// Sanitiza títulos e artistas de músicas que possuam numeração sequencial (ex: 001_Nome_Artista)
  /// ou campos de artista vazios que possam ser extraídos do conteúdo ou nome do arquivo.
  Future<int> sanitizeSongMetadata() async {
    int updatedCount = 0;
    for (int i = 0; i < _songs.length; i++) {
      final s = _songs[i];
      if (s.deleted) continue;

      final hasSeq = RegExp(r'^\d+[\s_.-]+').hasMatch(s.title);
      final hasUnderscore = s.title.contains('_');
      final needsFix = hasSeq || hasUnderscore || s.artist.isEmpty;

      if (needsFix) {
        final meta = CifraImportService.extractMetadata(
          content: s.content,
          rawFileName: s.title,
        );

        final newTitle = meta.title.isNotEmpty ? meta.title : s.title;
        final newArtist = (s.artist.isEmpty && meta.artist.isNotEmpty) ? meta.artist : s.artist;
        final newKey = (s.originalKey.isEmpty && meta.originalKey.isNotEmpty) ? meta.originalKey : s.originalKey;

        if (newTitle != s.title || newArtist != s.artist || newKey != s.originalKey) {
          _songs[i] = s.copyWith(
            title: newTitle,
            artist: newArtist,
            originalKey: newKey,
            updatedAt: s.updatedAt,
          );
          updatedCount++;
        }
      }
    }

    if (updatedCount > 0) {
      await _persist();
      onLocalChange?.call();
    }
    return updatedCount;
  }

  Future<void> _persist() async {
    await _prefs.setString(
        _key, jsonEncode(_songs.map((s) => s.toJson()).toList()));
    notifyListeners();
  }
}
