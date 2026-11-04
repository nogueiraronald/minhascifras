import 'package:flutter/material.dart';
import '../servicos/controlador_audio_karaoke.dart';
import 'player_youtube_embutido_stub.dart'
    if (dart.library.html) 'player_youtube_embutido_web.dart' as impl;

/// Componente que exibe o player oficial do YouTube de forma integrada e elegante,
/// com sincronização bidirecional em tempo real com o Karaokê.
class PlayerYoutubeEmbutido extends StatelessWidget {
  const PlayerYoutubeEmbutido({
    super.key,
    required this.videoId,
    this.controller,
    this.onClose,
  });

  final String videoId;
  final KaraokeAudioController? controller;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return impl.buildYoutubePlayerView(
      context: context,
      videoId: videoId,
      controller: controller,
      onClose: onClose,
    );
  }
}
