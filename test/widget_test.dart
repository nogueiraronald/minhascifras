import 'package:cifras_app/servicos/transpositor_acordes.dart';
import 'package:cifras_app/servicos/servico_importacao_cifra.dart';
import 'package:cifras_app/servicos/servico_autenticacao_google.dart';
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
    expect(ChordTransposer.isChordLine('[Intro] E  F#  G#m7'), isTrue);
    expect(ChordTransposer.isChordLine('\u200b E          F#        G#m7'), isTrue);
    expect(ChordTransposer.isChordLine('\u200bHoje eu voltei no passado'), isFalse);
    expect(ChordTransposer.isChordLine('G, G7, C, G'), isTrue);
    expect(ChordTransposer.isChordLine('G - G7 - C - G'), isTrue);
    expect(ChordTransposer.isChordLine('Intro: G, G7, C, G'), isTrue);
    expect(ChordTransposer.isChordLine('Posso.....'), isFalse);
  });

  test('transpõe linhas de acordes com marcadores e caracteres invisíveis', () {
    final transposed = ChordTransposer.transposeContent('[Intro] E  F#  G#m7', 1);
    expect(transposed, contains('[Intro] F  G  Am7'));

    final transposedCommas = ChordTransposer.transposeContent('G, G7, C, G', 2);
    expect(transposedCommas, equals('A, A7, D, A'));
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
