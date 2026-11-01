import 'package:cifras_app/services/chord_transposer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('transpõe acordes', () {
    expect(ChordTransposer.transposeChord('C', 2), 'D');
    expect(ChordTransposer.transposeChord('Am7/G', 2), 'Bm7/A');
    expect(ChordTransposer.transposeChord('Bb', 2), 'C');
  });

  test('detecta linhas de acordes', () {
    expect(ChordTransposer.isChordLine('C   G   Am  F'), isTrue);
    expect(ChordTransposer.isChordLine('Eu vou cantar'), isFalse);
  });
}
