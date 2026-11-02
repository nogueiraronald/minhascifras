import 'package:cifras_app/services/chord_transposer.dart';
import 'package:cifras_app/services/cifra_import_service.dart';
import 'package:cifras_app/services/google_auth_service.dart';
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
  test('GoogleAuthService is safe on current platform without crash', () {
    expect(() => GoogleAuthService(), returnsNormally);
  });

  test('CifraImportService importa da URL do Supabase', () async {
    final song = await CifraImportService.importFromUrl(
      'https://www.cifraclub.com.br/florianopolis-house-of-prayer/sublime/',
    );
    expect(song.title, 'Sublime');
    expect(song.artist, 'Florianópolis House of Prayer');
    expect(song.content, contains('Maravilhoso, admirável'));
  });
}
