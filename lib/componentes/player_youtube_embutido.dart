import 'package:flutter/material.dart';
import 'player_youtube_embutido_stub.dart'
    if (dart.library.html) 'player_youtube_embutido_web.dart' as impl;

/// Componente que exibe o player oficial do YouTube de forma integrada e elegante,
/// permitindo que o usuário assista e ouça o clipe dentro do aplicativo sem perder
/// a visão da cifra nem a sincronia do Karaokê.
class PlayerYoutubeEmbutido extends StatelessWidget {
  const PlayerYoutubeEmbutido({
    super.key,
    required this.videoId,
    this.onClose,
  });

  final String videoId;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return impl.buildYoutubePlayerView(
      context: context,
      videoId: videoId,
      onClose: onClose,
    );
  }
}
