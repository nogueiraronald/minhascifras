import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../modelos/musica.dart';
import 'repositorio_musicas.dart';

/// Gerenciador de Temas / Estilos musicais (Adoração, Comunhão, Baião, Casamento, etc.)
class ThemeRepository extends ChangeNotifier {
  ThemeRepository._(
    this._prefs,
    List<String> themes, {
    required bool isExplicitlyCleared,
  })  : _themes = themes,
        _isExplicitlyCleared = isExplicitlyCleared;

  static const _key = 'music_themes_v1';
  static const _clearedKey = 'music_themes_explicitly_cleared_v1';
  final SharedPreferences _prefs;
  final List<String> _themes;
  bool _isExplicitlyCleared;

  /// Retorna se o usuário limpou intencionalmente todos os temas.
  bool get isExplicitlyCleared => _isExplicitlyCleared;

  /// Chamado após alterações do usuário (não pela sincronização).
  VoidCallback? onLocalChange;

  /// Indica se há alterações de temas locais pendentes para envio ao banco em nuvem
  bool hasPendingChanges = false;

  void markSynced() {
    hasPendingChanges = false;
  }

  static const List<String> defaultThemes = [
    'Aclamação',
    'Adoração',
    'Amor de Deus',
    'Animação',
    'Ato Penitencial',
    'Baião',
    'Bênção',
    'Blues',
    'Bossa Nova',
    'Casamento',
    'Católicas',
    'Comunhão',
    'Cura',
    'Entrada',
    'Envio',
    'Espírito Santo',
    'Final',
    'Glória',
    'Louvor',
    'Maria',
    'Meditação',
    'Natal',
    'Ofertório',
    'Paz',
    'Páscoa',
    'Perdão',
    'Pós-Comunhão',
    'Quaresma',
    'Reconciliação',
    'Reflexão',
    'Santo',
    'Vocacional',
  ];

  static Future<ThemeRepository> open() async {
    final prefs = await SharedPreferences.getInstance();
    // Remove chave legada de temas deletados para liberar espaço
    await prefs.remove('music_deleted_themes_v1');
    final raw = prefs.getString(_key);
    final isExplicitlyCleared = prefs.getBool(_clearedKey) ?? false;

    List<String> list;
    if (raw == null) {
      list = [];
      await prefs.setString(_key, jsonEncode(list));
    } else {
      list = (jsonDecode(raw) as List)
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }

    list.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return ThemeRepository._(
      prefs,
      list,
      isExplicitlyCleared: isExplicitlyCleared,
    );
  }

  List<String> get themes {
    final copy = List<String>.from(_themes);
    copy.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return copy;
  }

  List<String> get deletedThemes => const [];

  int countFor(String theme, List<Song> songs) {
    final tLower = theme.toLowerCase().trim();
    return songs.where((s) => !s.deleted && s.tags.any((t) => t.toLowerCase().trim() == tLower)).length;
  }

  List<Song> songsFor(String theme, List<Song> songs) {
    final tLower = theme.toLowerCase().trim();
    final list = songs.where((s) => !s.deleted && s.tags.any((t) => t.toLowerCase().trim() == tLower)).toList();
    list.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    return list;
  }

  Future<void> addTheme(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    final tLower = trimmed.toLowerCase();
    if (!_themes.any((t) => t.toLowerCase() == tLower)) {
      _themes.add(trimmed);
      _themes.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      _isExplicitlyCleared = false;
      await _prefs.setBool(_clearedKey, false);
      await _persist();
    }
  }

  Future<void> addThemeFromSync(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    final tLower = trimmed.toLowerCase();
    if (!_themes.any((t) => t.toLowerCase() == tLower)) {
      _themes.add(trimmed);
      _themes.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      await _persist(fromSync: true);
    }
  }

  Future<void> removeThemeFromSync(String name) async {
    final trimmed = name.trim();
    final tLower = trimmed.toLowerCase();
    final initial = _themes.length;
    _themes.removeWhere((t) => t.toLowerCase() == tLower);
    if (_themes.length != initial) {
      await _persist(fromSync: true);
    }
  }

  Future<void> renameTheme(String oldName, String newName, SongRepository songRepo) async {
    final oldTrimmed = oldName.trim();
    final newTrimmed = newName.trim();
    if (oldTrimmed.isEmpty || newTrimmed.isEmpty || oldTrimmed.toLowerCase() == newTrimmed.toLowerCase()) return;

    final index = _themes.indexWhere((t) => t.toLowerCase() == oldTrimmed.toLowerCase());
    if (index >= 0) {
      _themes[index] = newTrimmed;
      _themes.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      await _persist();
      await songRepo.renameTagInAll(oldTrimmed, newTrimmed);
    }
  }

  Future<void> removeTheme(String name, SongRepository songRepo) async {
    final trimmed = name.trim();
    final tLower = trimmed.toLowerCase();
    final initialCount = _themes.length;
    _themes.removeWhere((t) => t.toLowerCase() == tLower);
    if (_themes.length != initialCount) {
      if (_themes.isEmpty) {
        _isExplicitlyCleared = true;
        await _prefs.setBool(_clearedKey, true);
      }
      await _persist();
      await songRepo.removeTagFromAll(trimmed);
    }
  }

  /// Reseta todos os temas para zero (usuário novo ou deslogado inicia com 0 temas).
  Future<void> resetToDefault() async {
    await clearAll();
  }

  /// Limpa e define a lista de temas do usuário autenticado.
  Future<void> setThemes(
    List<String> newThemes, {
    List<String> deletedThemes = const [],
    bool fromSync = false,
  }) async {
    final set = <String>{};
    for (final t in newThemes) {
      final trimmed = t.trim();
      if (trimmed.isNotEmpty) {
        set.add(trimmed);
      }
    }
    _themes
      ..clear()
      ..addAll(set)
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    if (newThemes.isNotEmpty) {
      _isExplicitlyCleared = false;
      await _prefs.setBool(_clearedKey, false);
    }
    await _persist(fromSync: fromSync);
  }

  /// Exclui todos os temas locais e desvincula as músicas associadas,
  /// marcando explicitamente para sincronizar a lista vazia no banco em nuvem.
  Future<void> clearAll([SongRepository? songRepo]) async {
    _themes.clear();
    _isExplicitlyCleared = true;
    await _prefs.setBool(_clearedKey, true);
    if (songRepo != null) {
      await songRepo.removeAllTags();
    }
    await _persist(fromSync: false);
  }

  Future<void> _persist({bool fromSync = false}) async {
    await _prefs.setString(_key, jsonEncode(_themes));
    notifyListeners();
    if (!fromSync) {
      hasPendingChanges = true;
      onLocalChange?.call();
    }
  }
}
