import 'package:cifras_app/modelos/musica.dart';
import 'package:cifras_app/servicos/controlador_audio_karaoke.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

void main() {
  group('Modelo Song - Suporte a Áudio e Karaokê', () {
    test('Detecta corretamente serviços de áudio por URL', () {
      final yt1 = Song(
        id: '1',
        title: 'Música 1',
        content: 'C G',
        audioUrl: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
      );
      expect(yt1.hasAudio, isTrue);
      expect(yt1.audioType, equals('youtube'));
      expect(yt1.audioServiceName, equals('YouTube'));

      final yt2 = yt1.copyWith(audioUrl: 'https://youtu.be/dQw4w9WgXcQ');
      expect(yt2.audioType, equals('youtube'));

      // Link de redirecionamento do Google com destino para o YouTube
      final googleYt = yt1.copyWith(
        audioUrl: 'https://www.google.com/url?sa=t&url=https%3A%2F%2Fwww.youtube.com%2Fwatch%3Fv%3DAoGbvO0eV74&rct=j',
      );
      expect(googleYt.audioType, equals('youtube'));
      expect(Song.extractYoutubeVideoId(googleYt.audioUrl!), equals('AoGbvO0eV74'));
      expect(Song.cleanAudioUrl(googleYt.audioUrl!), equals('https://www.youtube.com/watch?v=AoGbvO0eV74'));

      final mp3Local = yt1.copyWith(audioUrl: '/Users/musicas/louvor.mp3');
      expect(mp3Local.audioType, equals('mp3'));
      expect(mp3Local.audioServiceName, equals('Arquivo MP3'));

      final mp3Web = yt1.copyWith(audioUrl: 'https://exemplo.com/audio.mp3');
      expect(mp3Web.audioType, equals('mp3'));
      expect(mp3Web.audioServiceName, equals('Arquivo MP3'));

      final noAudio = yt1.copyWith(audioUrl: '');
      expect(noAudio.hasAudio, isFalse);
      expect(noAudio.audioType, equals('none'));
      expect(noAudio.audioServiceName, equals('Nenhum'));
    });

    test('Serialização e Deserialização JSON preserva dados de áudio', () {
      final song = Song(
        id: 'abc-123',
        title: 'Hino da Vitória',
        artist: 'Cassiane',
        originalKey: 'G',
        content: 'G D Em C',
        audioUrl: 'https://www.youtube.com/watch?v=cassiane',
        audioDurationSeconds: 215, // 03:35
      );

      final json = song.toJson();
      expect(json['audioUrl'], equals('https://www.youtube.com/watch?v=cassiane'));
      expect(json['audioDurationSeconds'], equals(215));

      final restored = Song.fromJson(json);
      expect(restored.id, equals(song.id));
      expect(restored.audioUrl, equals(song.audioUrl));
      expect(restored.audioDurationSeconds, equals(song.audioDurationSeconds));
      expect(restored.hasAudio, isTrue);
    });

    test('Formatadores de duração e conversores', () {
      expect(Song.formatDuration(null), equals('--:--'));
      expect(Song.formatDuration(0), equals('--:--'));
      expect(Song.formatDuration(65), equals('01:05'));
      expect(Song.formatDuration(215), equals('03:35'));

      expect(Song.parseDuration('3:35'), equals(215));
      expect(Song.parseDuration('03:35'), equals(215));
      expect(Song.parseDuration('120'), equals(120));
      expect(Song.parseDuration('invalid'), isNull);
    });
  });

  group('KaraokeAudioController - Controle e Sincronização de Rolagem', () {
    testWidgets('Inicializa com duração da música e permite alternar auto-scroll', (tester) async {
      final song = Song(
        id: 's1',
        title: 'Teste',
        content: 'C G Am F',
        audioUrl: 'https://youtube.com/watch?v=teste',
        audioDurationSeconds: 180,
      );

      final scrollController = ScrollController();
      final controller = KaraokeAudioController(
        song: song,
        scrollController: scrollController,
        enableNativeAudio: false,
      );

      expect(controller.totalDuration.inSeconds, equals(180));
      expect(controller.isPlaying, isFalse);
      expect(controller.isAutoScrollEnabled, isTrue);

      controller.toggleAutoScroll();
      expect(controller.isAutoScrollEnabled, isFalse);

      controller.toggleAutoScroll();
      expect(controller.isAutoScrollEnabled, isTrue);

      // Seek dentro do intervalo
      await controller.seek(const Duration(seconds: 90));
      expect(controller.currentPosition.inSeconds, equals(90));
      expect(controller.progress, closeTo(0.5, 0.01));

      // Avançar 10 segundos
      await controller.seekRelative(10);
      expect(controller.currentPosition.inSeconds, equals(100));

      // Voltar 10 segundos
      await controller.seekRelative(-10);
      expect(controller.currentPosition.inSeconds, equals(90));

      // Reiniciar música
      await controller.restart();
      expect(controller.currentPosition, equals(Duration.zero));
      expect(controller.progress, equals(0.0));

      // Seek além do limite máximo fixa no totalDuration
      await controller.seek(const Duration(seconds: 300));
      expect(controller.currentPosition.inSeconds, equals(180));

      // Seek negativo fixa em zero
      await controller.seek(const Duration(seconds: -10));
      expect(controller.currentPosition, equals(Duration.zero));

      // Teste de cálculo de linha ativa Karaokê
      final sampleLines = ['[Intro]', 'C G Am F', '', 'Vem que a tempestade', 'C G Am F'];
      await controller.seek(const Duration(seconds: 0));
      expect(controller.calculateActiveLine(sampleLines.length, sampleLines), equals(0));

      await controller.seek(const Duration(seconds: 90)); // 50%
      final midLine = controller.calculateActiveLine(sampleLines.length, sampleLines);
      expect(midLine, inInclusiveRange(0, sampleLines.length - 1));

      // Garante que activeChordLineIndex retorna apenas linhas de acordes
      expect(controller.activeChordLineIndex, isNotNull);
      expect(controller.activeChordLineIndex, equals(0));

      controller.dispose();
      scrollController.dispose();
    });

    test('Identifica e separa linhas de acordes e letra na música', () {
      final song = Song(
        id: 'cifra-teste',
        title: 'Confia em Mim',
        content: 'C9  E7  Am\nNão tenhas medo, pois Eu estou aqui\nF7+  Dm7  Gsus  G\nÉ o teu Senhor que diz\n',
        audioUrl: 'https://youtube.com/watch?v=AoGbvO0eV74',
        audioDurationSeconds: 200,
      );

      final scrollController = ScrollController();
      final controller = KaraokeAudioController(
        song: song,
        scrollController: scrollController,
        enableNativeAudio: false,
      );

      // No início (0s)
      expect(controller.activeChordLineIndex, equals(0)); // C9 E7 Am
      expect(controller.activeLyricsLineIndex, equals(1)); // Não tenhas medo

      // No meio (100s / 50%)
      controller.seek(const Duration(seconds: 100));
      expect(controller.activeChordLineIndex, equals(2)); // F7+ Dm7 Gsus G
      expect(controller.activeLyricsLineIndex, equals(3)); // É o teu Senhor que diz

      controller.dispose();
      scrollController.dispose();
    });

    test('Exclui cabeçalhos de título e artista das linhas cantadas de letra', () {
      final songWithHeaders = Song(
        id: 'cifra-headers',
        title: 'Confia em mim',
        artist: 'Vida Reluz',
        content: '''Confia em mim
Vida Reluz
(intro) C9  F F/G Em Am Dm/Bb F/G

C9               F           F/G        C9
Vem, que a tempestade já não pode te abalar,
      F            G       G#º    Am             F           Dm7
a segurança em meu barco encontrarás, confia em mim, o meu amor te
       Gsus  G
abrigará.''',
        audioUrl: 'https://youtube.com/watch?v=AoGbvO0eV74',
        audioDurationSeconds: 210,
      );

      final scrollController = ScrollController();
      final controller = KaraokeAudioController(
        song: songWithHeaders,
        scrollController: scrollController,
        enableNativeAudio: false,
      );

      // Linha 0 (título) e Linha 1 (artista) não devem estar entre as letras cantadas!
      // A primeira linha de acordes é a Linha 2 (intro).
      expect(controller.activeChordLineIndex, equals(2));
      // A primeira linha de letra cantada deve ser a Linha 5 ("Vem, que a tempestade..."), NÃO a linha 0 ou 1!
      expect(controller.activeLyricsLineIndex, equals(5));

      controller.dispose();
      scrollController.dispose();
    });

    test('Interpreta áudio dinamicamente, mantendo intro no início e voltando ao refrão em repetições', () async {
      final song = Song(
        id: 'cifra-dinamica',
        title: 'Confia em mim',
        artist: 'Vida Reluz',
        content: '''Confia em mim
Vida Reluz
(intro) C9  F F/G Em Am Dm/Bb F/G

C9               F           F/G        C9
Vem, que a tempestade já não pode te abalar,
      F            G       G#º    Am             F           Dm7
a segurança em meu barco encontrarás, confia em mim, o meu amor te
       Gsus  G
abrigará.

          C9                    E7                       Am
Não tenhas medo, pois eu estou aqui! É o teu Senhor quem diz
 F7+    Dm7     Gsus        C9               E7
Quero guiar os passos teus. Vem entrega-te então,
                    Am
Farei morada em teu coração.''',
        audioUrl: 'https://youtube.com/watch?v=AoGbvO0eV74',
        audioDurationSeconds: 360,
      );

      final scrollController = ScrollController();
      final controller = KaraokeAudioController(
        song: song,
        scrollController: scrollController,
        enableNativeAudio: false,
      );

      // Simula legendas reais do áudio (fala na intro, primeira estrofe, refrão 1, e refrão 2 repetido)
      final mockCaptions = [
        // 0s a 60s: Fala na introdução
        ClosedCaption(
          'e quando nós vamos ao encontro do senhor como nós cantamos o senhor também vem ao nosso encontro',
          const Duration(seconds: 5),
          const Duration(seconds: 7),
          const [],
        ),
        ClosedCaption(
          'os discípulos enfrentaram uma tempestade muito forte todos com medo e o senhor foi até eles caminhar sobre as águas',
          const Duration(seconds: 24),
          const Duration(seconds: 8),
          const [],
        ),
        // 84s (01:24): O canto realmente começa!
        ClosedCaption(
          'vem que a tempestade já não pode te abalar',
          const Duration(seconds: 84),
          const Duration(seconds: 6),
          const [],
        ),
        // 104s (01:44): Segunda linha da estrofe
        ClosedCaption(
          'a segurança em meu barco encontrarás confie em mim o meu amor te',
          const Duration(seconds: 104),
          const Duration(seconds: 7),
          const [],
        ),
        // 135s (02:15): Refrão 1
        ClosedCaption(
          'não tenhas medo pois eu estou aqui é o teu Senhor quem diz',
          const Duration(seconds: 135),
          const Duration(seconds: 7),
          const [],
        ),
        // 145s (02:25): Segunda parte do refrão
        ClosedCaption(
          'quero guiar os passos teus vem entrega-te então farei morada em teu coração',
          const Duration(seconds: 145),
          const Duration(seconds: 8),
          const [],
        ),
        // 242s (04:02): REFRÃO 2 REPETIDO NO ÁUDIO! (A cifra tem o refrão uma vez só)
        ClosedCaption(
          'não tenhas medo eu estou aqui é o teu Senhor quem diz',
          const Duration(seconds: 242),
          const Duration(seconds: 7),
          const [],
        ),
      ];

      controller.setCaptionsForTesting(mockCaptions);

      // 1. Durante a introdução falada (0s, 30s): DEVE FICAR NA INTRODUÇÃO (Linha 2 de acordes)
      await controller.seek(const Duration(seconds: 30));
      expect(controller.activeChordLineIndex, equals(2)); // (intro)
      expect(controller.activeLyricsLineIndex, isNull); // Letra ainda não começou

      // 2. Quando o canto começa (85s / 01:25): DEVE MARCAR A PRIMEIRA ESTROFE
      await controller.seek(const Duration(seconds: 85));
      expect(controller.activeChordLineIndex, equals(4)); // C9 F F/G C9
      expect(controller.activeLyricsLineIndex, equals(5)); // Vem, que a tempestade...

      // 3. No momento do print do usuário (104s / 01:44): DEVE MARCAR A LINHA 6/7
      await controller.seek(const Duration(seconds: 104));
      expect(controller.activeChordLineIndex, equals(6)); // F G G#º Am F Dm7
      expect(controller.activeLyricsLineIndex, equals(7)); // a segurança em meu barco...

      // 4. No Refrão 1 (135s / 02:15): DEVE MARCAR O REFRÃO
      await controller.seek(const Duration(seconds: 136));
      expect(controller.activeChordLineIndex, equals(11)); // C9 E7 Am
      expect(controller.activeLyricsLineIndex, equals(12)); // Não tenhas medo...

      // 5. No Refrão 2 REPETIDO (242s / 04:02): A CIFRA DEVE VOLTAR AO REFRÃO (LINHA 11/12)!
      await controller.seek(const Duration(seconds: 243));
      expect(controller.activeChordLineIndex, equals(11)); // VOLTA PARA O REFRÃO: C9 E7 Am!
      expect(controller.activeLyricsLineIndex, equals(12)); // VOLTA PARA: Não tenhas medo...

      controller.dispose();
      scrollController.dispose();
    });
  });
}
