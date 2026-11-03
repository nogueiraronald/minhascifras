import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:cifras_app/modelos/musica.dart';
import 'package:cifras_app/servicos/controlador_audio_karaoke.dart';

void main() {
  test('Sincronização de A Barca marca corretamente o refrão aos 32s', () async {
    final captions = <ClosedCaption>[
      ClosedCaption('Tu', const Duration(seconds: 8), const Duration(milliseconds: 6439), const []),
      ClosedCaption('te abiraste da praia,', const Duration(seconds: 10), const Duration(milliseconds: 7559), const []),
      ClosedCaption('não buscaste', const Duration(seconds: 14), const Duration(milliseconds: 7201), const []),
      ClosedCaption('nem sábios, nem ricos.', const Duration(seconds: 18), const Duration(milliseconds: 7641), const []),
      ClosedCaption('Somente queres', const Duration(seconds: 21), const Duration(milliseconds: 7760), const []),
      ClosedCaption('que eu te siga,', const Duration(seconds: 25), const Duration(milliseconds: 7040), const []),
      ClosedCaption('Senhor.', const Duration(seconds: 29), const Duration(milliseconds: 3000), const []),
      ClosedCaption('Tu me olhaste nos olhos', const Duration(seconds: 32), const Duration(milliseconds: 7320), const []),
      ClosedCaption('a sorrir,', const Duration(seconds: 37), const Duration(milliseconds: 7320), const []),
      ClosedCaption('pronunciaste meu nome.', const Duration(seconds: 40), const Duration(milliseconds: 7200), const []),
      ClosedCaption('Lá na praia', const Duration(seconds: 44), const Duration(milliseconds: 7041), const []),
      ClosedCaption('eu deixei o meu barco.', const Duration(seconds: 47), const Duration(milliseconds: 7160), const []),
      ClosedCaption('Junto a ti', const Duration(seconds: 51), const Duration(milliseconds: 7480), const []),
      ClosedCaption('buscarei outro mar.', const Duration(seconds: 54), const Duration(milliseconds: 4440), const []),
      ClosedCaption('Tu', const Duration(seconds: 59), const Duration(milliseconds: 6401), const []),
      ClosedCaption('sabes bem que meu barco', const Duration(seconds: 61), const Duration(milliseconds: 7679), const []),
    ];

    const songContent = '''A Barca
Padre Zezinho
D A/C#               Bm
TU, TE ABEIRASTE DA PRAIA
        G (Em)              A
NÃO BUSCASTE NEM SÁBIOS NEM RICOS,
         D   A           D     (Am D7)
SOMENTE QUERES QUE EU TE SIGA!

    G  A                   D A/C# Bm
SENHOR,  TU ME OLHASTE NOS OLHOS
     Em  A                  D  (Am D)
A SORRIR, PRONUNCIASTES MEU NOME,
      G   A                    D  A/C# Bm
LÁ NA PRAIA,  EU LARGUEI O MEU BARCO,
       Em A                D  (A)
JUNTO A TI BUSCAREI OUTRO MAR.''';

    final song = Song(
      id: 'test',
      title: 'A Barca',
      artist: 'Padre Zezinho',
      content: songContent,
      audioUrl: 'https://www.youtube.com/watch?v=yLHhAGl3Bqw',
    );

    final scrollController = ScrollController();
    final ctrl = KaraokeAudioController(
      song: song,
      scrollController: scrollController,
      enableNativeAudio: false,
    );
    ctrl.setCaptionsForTesting(captions);

    // 1. Aos 10s: Primeira estrofe
    await ctrl.seek(const Duration(seconds: 10));
    expect(ctrl.activeChordLineIndex, equals(2)); // D A/C# Bm
    expect(ctrl.activeLyricsLineIndex, equals(3)); // TU, TE ABEIRASTE DA PRAIA

    // 2. Aos 14s: Segunda linha
    await ctrl.seek(const Duration(seconds: 14));
    expect(ctrl.activeChordLineIndex, equals(4)); // G (Em) A
    expect(ctrl.activeLyricsLineIndex, equals(5)); // NÃO BUSCASTE...

    // 3. Aos 20s: Terceira linha
    await ctrl.seek(const Duration(seconds: 20));
    expect(ctrl.activeChordLineIndex, equals(6)); // D A D (Am D7)
    expect(ctrl.activeLyricsLineIndex, equals(7)); // SOMENTE QUERES...

    // 4. Aos 32s (momento do print do usuário): DEVE MARCAR "SENHOR, TU ME OLHASTE NOS OLHOS"
    await ctrl.seek(const Duration(seconds: 32));
    expect(ctrl.activeChordLineIndex, equals(9)); // G A D A/C# Bm
    expect(ctrl.activeLyricsLineIndex, equals(10)); // SENHOR, TU ME OLHASTE NOS OLHOS

    // 5. Aos 38s: Próxima linha do refrão
    await ctrl.seek(const Duration(seconds: 38));
    expect(ctrl.activeChordLineIndex, equals(11)); // Em A D (Am D)
    expect(ctrl.activeLyricsLineIndex, equals(12)); // A SORRIR...

    ctrl.dispose();
    scrollController.dispose();
  });
}
