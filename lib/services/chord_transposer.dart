/// Detecção e transposição de acordes em texto.
class ChordTransposer {
  ChordTransposer._();

  static const _sharps = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];
  static const _flats = ['C', 'Db', 'D', 'Eb', 'E', 'F', 'Gb', 'G', 'Ab', 'A', 'Bb', 'B'];

  static final _chord = RegExp(r'^([A-G][#b]?)([^/\s]*)(?:/([A-G][#b]?))?$');
  static final _quality =
      RegExp(r'^(maj|min|dim|aug|sus|add|m|M|\+|-|°|º|\d|\(|\)|#|b)*$');
  static final _hasFlat = RegExp(r'^[A-G]b|/[A-G]b');

  static bool isChord(String token) {
    final m = _chord.firstMatch(token);
    return m != null && _quality.hasMatch(m.group(2)!);
  }

  /// Linha composta somente por acordes.
  static bool isChordLine(String line) {
    final t = line.trim();
    if (t.isEmpty) return false;
    return t.split(RegExp(r'\s+')).every(isChord);
  }

  static String transposeChord(String chord, int steps, {bool? useFlats}) {
    final m = _chord.firstMatch(chord);
    if (m == null) return chord;
    final flats = useFlats ?? _hasFlat.hasMatch(chord);
    final bass = m.group(3);
    final root = _shift(m.group(1)!, steps, flats);
    return '$root${m.group(2)}${bass == null ? '' : '/${_shift(bass, steps, flats)}'}';
  }

  /// Transpõe todas as linhas de acordes de um texto.
  static String transposeContent(String content, int steps) {
    if (steps == 0) return content;
    return content
        .split('\n')
        .map((line) => isChordLine(line)
            ? line.replaceAllMapped(
                RegExp(r'\S+'), (m) => transposeChord(m.group(0)!, steps))
            : line)
        .join('\n');
  }

  /// Mesmo acorde com o outro nome (C# <-> Db).
  static String enharmonic(String chord) =>
      transposeChord(chord, 0, useFlats: !_hasFlat.hasMatch(chord));

  static String _shift(String note, int steps, bool flats) {
    var i = _sharps.indexOf(note);
    if (i < 0) i = _flats.indexOf(note);
    if (i < 0) return note;
    return (flats ? _flats : _sharps)[((i + steps) % 12 + 12) % 12];
  }
}
