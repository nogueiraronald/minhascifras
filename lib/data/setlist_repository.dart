import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/setlist.dart';
import '../models/setlist_item.dart';

/// Setlists e seus itens, salvos localmente (offline).
class SetlistRepository extends ChangeNotifier {
  SetlistRepository._(this._prefs, this._lists, this._items);

  static const _kLists = 'setlists_v1';
  static const _kItems = 'setlist_items_v1';

  final SharedPreferences _prefs;
  final List<Setlist> _lists;
  final List<SetlistItem> _items;

  /// Chamado após alterações do usuário (não pela sincronização).
  VoidCallback? onLocalChange;

  static Future<SetlistRepository> open() async {
    final prefs = await SharedPreferences.getInstance();
    List<T> load<T>(String key, T Function(Map<String, dynamic>) fromJson) {
      final raw = prefs.getString(key);
      if (raw == null) return <T>[];
      return (jsonDecode(raw) as List)
          .map((e) => fromJson(e as Map<String, dynamic>))
          .toList();
    }

    return SetlistRepository._(
        prefs, load(_kLists, Setlist.fromJson), load(_kItems, SetlistItem.fromJson));
  }

  List<Setlist> get setlists {
    final l = _lists.where((s) => !s.deleted).toList();
    l.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return l;
  }

  List<Setlist> get allSetlists => List.unmodifiable(_lists);
  List<SetlistItem> get allItems => List.unmodifiable(_items);

  List<SetlistItem> itemsFor(String setlistId) {
    final l = _items.where((i) => i.setlistId == setlistId && !i.deleted).toList();
    l.sort((a, b) => a.position.compareTo(b.position));
    return l;
  }

  Future<void> saveSetlist(Setlist s) async {
    final i = _lists.indexWhere((e) => e.id == s.id);
    if (i >= 0) {
      _lists[i] = s;
    } else {
      _lists.add(s);
    }
    await _persist();
  }

  Future<void> removeSetlist(String id) async {
    final i = _lists.indexWhere((e) => e.id == id);
    if (i < 0) return;
    _lists[i] = _lists[i].copyWith(deleted: true);
    for (final it in itemsFor(id)) {
      _replaceItem(it.copyWith(deleted: true));
    }
    await _persist();
  }

  Future<void> addSongs(String setlistId, List<String> songIds) async {
    var pos = itemsFor(setlistId).length;
    for (final sid in songIds) {
      _items.add(SetlistItem(
          id: const Uuid().v4(), setlistId: setlistId, songId: sid, position: pos++));
    }
    await _persist();
  }

  Future<void> removeItem(String itemId) async {
    final i = _items.indexWhere((e) => e.id == itemId);
    if (i < 0) return;
    final listId = _items[i].setlistId;
    _items[i] = _items[i].copyWith(deleted: true);
    _renumber(listId, itemsFor(listId).map((e) => e.id).toList());
    await _persist();
  }

  Future<void> setTranspose(String itemId, int steps) async {
    final i = _items.indexWhere((e) => e.id == itemId);
    if (i < 0) return;
    _items[i] = _items[i].copyWith(transpose: steps);
    await _persist();
  }

  /// [orderedIds] = ids dos itens na nova ordem.
  Future<void> reorder(String setlistId, List<String> orderedIds) async {
    _renumber(setlistId, orderedIds);
    await _persist();
  }

  /// Grava dados vindos da nuvem sem disparar nova sincronização.
  Future<void> upsertAll({
    List<Setlist> setlists = const [],
    List<SetlistItem> items = const [],
  }) async {
    for (final s in setlists) {
      final i = _lists.indexWhere((e) => e.id == s.id);
      if (i >= 0) {
        _lists[i] = s;
      } else {
        _lists.add(s);
      }
    }
    for (final it in items) {
      final i = _items.indexWhere((e) => e.id == it.id);
      if (i >= 0) {
        _items[i] = it;
      } else {
        _items.add(it);
      }
    }
    await _persist(local: false);
  }

  void _renumber(String setlistId, List<String> orderedIds) {
    final rest = itemsFor(setlistId).map((e) => e.id).where((id) => !orderedIds.contains(id));
    final ids = [...orderedIds, ...rest];
    for (var p = 0; p < ids.length; p++) {
      final i = _items.indexWhere((e) => e.id == ids[p]);
      if (i >= 0 && _items[i].position != p) _items[i] = _items[i].copyWith(position: p);
    }
  }

  void _replaceItem(SetlistItem it) {
    final i = _items.indexWhere((e) => e.id == it.id);
    if (i >= 0) _items[i] = it;
  }

  Future<void> _persist({bool local = true}) async {
    await _prefs.setString(_kLists, jsonEncode(_lists.map((e) => e.toJson()).toList()));
    await _prefs.setString(_kItems, jsonEncode(_items.map((e) => e.toJson()).toList()));
    notifyListeners();
    if (local) onLocalChange?.call();
  }
}
