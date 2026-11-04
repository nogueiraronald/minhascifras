import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cifras_app/modelos/musica.dart';
import 'package:cifras_app/servicos/controlador_audio_karaoke.dart';

void main() {
  group('KaraokeAudioController - Sincronização Bidirecional com YouTube', () {
    late Song song;
    late ScrollController scrollController;

    setUp(() {
      scrollController = ScrollController();
      song = Song(
        id: 'yt_sync_1',
        title: 'Música Sincronizada',
        artist: 'Artista Teste',
        content: '''
[Intro] C G Am F

C            G
Primeira estrofe cantada
Am           F
Segunda estrofe cantada
''',
        audioUrl: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
        audioDurationSeconds: 180,
      );
    });

    tearDown(() {
      scrollController.dispose();
    });

    test('Play aciona onPlayYoutube e inicia Karaokê', () async {
      final controller = KaraokeAudioController(
        song: song,
        scrollController: scrollController,
        enableNativeAudio: false,
      );

      bool playCalled = false;
      controller.onPlayYoutube = () {
        playCalled = true;
      };

      await controller.play();

      expect(playCalled, isTrue);
      expect(controller.isPlaying, isTrue);

      controller.dispose();
    });

    test('Pause aciona onPauseYoutube e pausa Karaokê', () async {
      final controller = KaraokeAudioController(
        song: song,
        scrollController: scrollController,
        enableNativeAudio: false,
      );

      await controller.play();

      bool pauseCalled = false;
      controller.onPauseYoutube = () {
        pauseCalled = true;
      };

      await controller.pause();

      expect(pauseCalled, isTrue);
      expect(controller.isPlaying, isFalse);

      controller.dispose();
    });

    test('Seek aciona onSeekYoutube com a posição correta', () async {
      final controller = KaraokeAudioController(
        song: song,
        scrollController: scrollController,
        enableNativeAudio: false,
      );

      Duration? seekTarget;
      controller.onSeekYoutube = (pos) {
        seekTarget = pos;
      };

      await controller.seek(const Duration(seconds: 42));

      expect(seekTarget, equals(const Duration(seconds: 42)));
      expect(controller.currentPosition, equals(const Duration(seconds: 42)));

      controller.dispose();
    });

    test('updateYoutubePlayback vindo do player do YouTube atualiza a posição e sincronia', () {
      final controller = KaraokeAudioController(
        song: song,
        scrollController: scrollController,
        enableNativeAudio: false,
      );

      // Simula o YouTube player enviando a posição real do vídeo
      controller.updateYoutubePlayback(
        position: const Duration(seconds: 90),
        duration: const Duration(seconds: 180),
      );

      expect(controller.currentPosition, equals(const Duration(seconds: 90)));
      expect(controller.progress, closeTo(0.5, 0.01));
      expect(controller.activeChordLineIndex, isNotNull);

      controller.dispose();
    });

    test('onYoutubeStateChanged sincroniza o estado quando usuário toca no vídeo do YouTube', () {
      final controller = KaraokeAudioController(
        song: song,
        scrollController: scrollController,
        enableNativeAudio: false,
      );

      expect(controller.isPlaying, isFalse);

      // Usuário toca no player de vídeo do YouTube
      controller.onYoutubeStateChanged(isPlaying: true);
      expect(controller.isPlaying, isTrue);

      // Usuário pausa no player de vídeo do YouTube
      controller.onYoutubeStateChanged(isPlaying: false);
      expect(controller.isPlaying, isFalse);

      controller.dispose();
    });
  });
}
