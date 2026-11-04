import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

Widget buildYoutubePlayerView({
  required BuildContext context,
  required String videoId,
  VoidCallback? onClose,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;

  return Container(
    width: 280,
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: isDark ? const Color(0xFF0F172A) : Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? 0.40 : 0.15),
          blurRadius: 12,
          offset: const Offset(0, 3),
        ),
      ],
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.smart_display_rounded, size: 16, color: Color(0xFFEF4444)),
                SizedBox(width: 6),
                Text(
                  'Clipe do YouTube',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            if (onClose != null)
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 16),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                onPressed: onClose,
              ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(
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
            ),
          ),
        ),
      ],
    ),
  );
}
