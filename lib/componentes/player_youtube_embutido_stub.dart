import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../servicos/controlador_audio_karaoke.dart';

Widget buildYoutubePlayerView({
  required BuildContext context,
  required String videoId,
  KaraokeAudioController? controller,
  VoidCallback? onClose,
  bool isInteracting = false,
}) {
  return Stack(
    fit: StackFit.expand,
    children: [
      Image.network(
        'https://img.youtube.com/vi/$videoId/hqdefault.jpg',
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          color: Colors.black87,
          child: const Icon(Icons.music_note_rounded, color: Colors.white54, size: 36),
        ),
      ),
      Center(
        child: IconButton.filled(
          style: IconButton.styleFrom(
            backgroundColor: const Color(0xFFEF4444),
            foregroundColor: Colors.white,
          ),
          icon: const Icon(Icons.open_in_new_rounded, size: 20),
          tooltip: 'Abrir clipe oficial em janela paralela',
          onPressed: () {
            final url = Uri.parse('https://www.youtube.com/watch?v=$videoId');
            launchUrl(url, mode: LaunchMode.externalApplication);
          },
        ),
      ),
    ],
  );
}
