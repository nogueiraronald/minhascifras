import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../modelos/musica.dart';
import 'repositorio_musicas.dart';

/// Gerenciador de Temas / Estilos musicais (Adoração, Comunhão, Baião, Casamento, etc.)
class ThemeRepository extends ChangeNotifier {
  ThemeRepository._(this._prefs, List<String> themes) : _themes = themes;

  static const _key = 'music_themes_v1';
  final SharedPreferences _prefs;
  final List<String> _themes;

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
    final raw = prefs.getString(_key);
    List<String> list;
    if (raw == null) {
      list = List.from(defaultThemes);
      await prefs.setString(_key, jsonEncode(list));
    } else {
      final decoded = (jsonDecode(raw) as List).map((e) => e.toString().trim()).toList();
      final set = <String>{...defaultThemes, ...decoded};
      list = set.toList();
    }
    list.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return ThemeRepository._(prefs, list);
  }

  List<String> get themes {
    final copy = List<String>.from(_themes);
    copy.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return copy;
  }

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
    if (!_themes.any((t) => t.toLowerCase() == trimmed.toLowerCase())) {
      _themes.add(trimmed);
      _themes.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      await _persist();
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
    final initialCount = _themes.length;
    _themes.removeWhere((t) => t.toLowerCase() == trimmed.toLowerCase());
    if (_themes.length != initialCount) {
      await _persist();
      await songRepo.removeTagFromAll(trimmed);
    }
  }

  Future<void> _persist() async {
    await _prefs.setString(_key, jsonEncode(_themes));
    notifyListeners();
  }
}
