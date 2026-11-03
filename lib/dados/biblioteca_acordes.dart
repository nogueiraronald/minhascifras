import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../modelos/formato_acorde.dart';
import '../servicos/transpositor_acordes.dart';

/// Biblioteca de acordes: padrões embutidos + acordes do usuário (têm prioridade).
class ChordLibrary {
  ChordLibrary._(this._prefs, this._custom);

  static const _key = 'chords_v1';
  final SharedPreferences _prefs;
  final Map<String, String> _custom;

  static const _builtIn = <String, String>{
    'C': 'x,3,2,0,1,0;0,3,2,0,1,0',
    'D': 'x,x,0,2,3,2;0,0,0,1,3,2',
    'E': '0,2,2,1,0,0;0,2,3,1,0,0',
    'F': '1,3,3,2,1,1;1,3,4,2,1,1',
    'G': '3,2,0,0,0,3;2,1,0,0,0,3',
    'A': 'x,0,2,2,2,0;0,0,1,2,3,0',
    'B': 'x,2,4,4,4,2;0,1,2,3,4,1',
    'Cm': 'x,3,5,5,4,3;0,1,3,4,2,1',
    'Dm': 'x,x,0,2,3,1;0,0,0,2,3,1',
    'Em': '0,2,2,0,0,0;0,2,3,0,0,0',
    'Fm': '1,3,3,1,1,1;1,3,4,1,1,1',
    'Gm': '3,5,5,3,3,3;1,3,4,1,1,1',
    'Am': 'x,0,2,2,1,0;0,0,2,3,1,0',
    'Bm': 'x,2,4,4,3,2;0,1,3,4,2,1',
    'C7': 'x,3,2,3,1,0;0,3,2,4,1,0',
    'D7': 'x,x,0,2,1,2;0,0,0,2,1,3',
    'E7': '0,2,0,1,0,0;0,2,0,1,0,0',
    'G7': '3,2,0,0,0,1;3,2,0,0,0,1',
    'A7': 'x,0,2,0,2,0;0,0,1,0,2,0',
    'B7': 'x,2,1,2,0,2;0,2,1,3,0,4',
    'Am7': 'x,0,2,0,1,0;0,0,2,0,1,0',
    'Dm7': 'x,x,0,2,1,1;0,0,0,2,1,1',
    'Em7': '0,2,0,0,0,0;0,1,0,0,0,0',
    'Cmaj7': 'x,3,2,0,0,0;0,3,2,0,0,0',
    'Fmaj7': 'x,x,3,2,1,0;0,0,3,2,1,0',
    'F#m': '2,4,4,2,2,2;1,3,4,1,1,1;2',
    'C#m': 'x,4,6,6,5,4;0,1,3,4,2,1;4',
    'C#m7': 'x,4,6,4,5,4;0,1,3,1,2,1;4',
    'Dbm7': 'x,4,6,4,5,4;0,1,3,1,2,1;4',
    'G#m': '4,6,6,4,4,4;1,3,4,1,1,1;4',
    'Abm': '4,6,6,4,4,4;1,3,4,1,1,1;4',
    'G#': '4,6,6,5,4,4;1,3,4,2,1,1;4',
    'Ab': '4,6,6,5,4,4;1,3,4,2,1,1;4',
    'C#': 'x,4,6,6,6,4;0,1,2,3,4,1;4',
    'Db': 'x,4,6,6,6,4;0,1,2,3,4,1;4',
    'D#m': 'x,6,8,8,7,6;0,1,3,4,2,1;6',
    'Ebm': 'x,6,8,8,7,6;0,1,3,4,2,1;6',
    'D#': 'x,6,8,8,8,6;0,1,2,3,4,1;6',
    'Eb': 'x,6,8,8,8,6;0,1,2,3,4,1;6',
    'A#m': 'x,1,3,3,2,1;0,1,3,4,2,1;1',
    'Bbm': 'x,1,3,3,2,1;0,1,3,4,2,1;1',
    'F#': '2,4,4,3,2,2;1,3,4,2,1,1;2',
    'Bb': 'x,1,3,3,3,1;0,1,2,3,4,1;1',
    'Bm7': 'x,2,4,2,3,2;0,1,3,1,2,1;2',
    'F#7': '2,4,2,3,2,2;1,3,1,2,1,1;2',
    'G#7': '4,6,4,5,4,4;1,3,1,2,1,1;4',
  };

  static Future<ChordLibrary> open() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    final map = raw == null
        ? <String, String>{}
        : Map<String, String>.from(jsonDecode(raw) as Map);
    return ChordLibrary._(prefs, map);
  }

  ChordShape? find(String chord) {
    for (final name in {chord, ChordTransposer.enharmonic(chord)}) {
      final text = _custom[name] ?? _builtIn[name];
      if (text != null) return ChordShape.parse(text);
    }
    final slash = chord.indexOf('/');
    return slash > 0 ? find(chord.substring(0, slash)) : null;
  }

  Future<void> save(String chord, ChordShape shape) async {
    _custom[chord] = shape.toText();
    await _prefs.setString(_key, jsonEncode(_custom));
  }
}
