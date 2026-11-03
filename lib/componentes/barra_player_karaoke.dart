import 'dart:ui';
import 'package:flutter/material.dart';
import '../modelos/musica.dart';
import '../servicos/controlador_audio_karaoke.dart';
import 'estilo_app.dart';

/// Barra de controle de áudio e karaokê compacta, moderna e elegante (estilo dock).
/// Projetada para ocupar o mínimo de espaço vertical (menos de 60px) mantendo
/// todos os controles essenciais (Seek, Play/Pause, ±10s, Volume, Karaokê).
class BarraPlayerKaraoke extends StatelessWidget {
  const BarraPlayerKaraoke({
    super.key,
    required this.controller,
    this.onClose,
  });

  final KaraokeAudioController controller;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final song = controller.song;
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final currentMs = controller.currentPosition.inMilliseconds;
        final totalMs = controller.totalDuration.inMilliseconds;
        final sliderValue = totalMs > 0 ? (currentMs / totalMs).clamp(0.0, 1.0) : 0.0;

        Color serviceColor = const Color(0xFF6366F1);
        IconData serviceIcon = Icons.audio_file_rounded;
        if (song.audioType == 'youtube') {
          serviceColor = const Color(0xFFEF4444);
          serviceIcon = Icons.play_circle_fill_rounded;
        }

        return Container(
          margin: const EdgeInsets.fromLTRB(10, 0, 10, 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
              BoxShadow(
                color: serviceColor.withValues(alpha: 0.15),
                blurRadius: 6,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF0F172A).withValues(alpha: 0.92)
                      : Colors.white.withValues(alpha: 0.96),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: serviceColor.withValues(alpha: 0.22),
                    width: 1.0,
                  ),
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 620;

                    if (isNarrow) {
                      return _buildTwoRowLayout(
                        context,
                        song,
                        sliderValue,
                        totalMs,
                        serviceColor,
                        serviceIcon,
                        isDark,
                        constraints.maxWidth,
                      );
                    }

                    return _buildSingleRowLayout(
                      context,
                      song,
                      sliderValue,
                      totalMs,
                      serviceColor,
                      serviceIcon,
                      isDark,
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Layout em Linha Única para telas maiores / desktop (altura ~44px)
  Widget _buildSingleRowLayout(
    BuildContext context,
    Song song,
    double sliderValue,
    int totalMs,
    Color serviceColor,
    IconData serviceIcon,
    bool isDark,
  ) {
    return SizedBox(
      height: 42,
      child: Row(
        children: [
          // Badge e Título
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: serviceColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(serviceIcon, size: 13, color: serviceColor),
                const SizedBox(width: 4),
                Text(
                  song.audioServiceName,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: serviceColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 140),
            child: Text(
              song.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (controller.isLoadingAudio) ...[
            const SizedBox(width: 6),
            const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(strokeWidth: 1.8),
            ),
          ],
          const SizedBox(width: 8),

          // Tempo Atual
          Text(
            Song.formatDuration(controller.currentPosition.inSeconds),
            style: TextStyle(
              fontSize: 10.5,
              fontFamily: 'monospace',
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.grey[300] : Colors.grey[800],
            ),
          ),
          const SizedBox(width: 4),

          // Slider Interativo Central
          Expanded(
            child: _buildSlider(context, sliderValue, totalMs, serviceColor, isDark),
          ),
          const SizedBox(width: 4),

          // Tempo Total
          Text(
            Song.formatDuration(controller.totalDuration.inSeconds),
            style: TextStyle(
              fontSize: 10.5,
              fontFamily: 'monospace',
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
          const SizedBox(width: 8),

          // Botões de Controle Compactos
          _buildActionButtons(context, isDark, serviceColor, compact: false),
        ],
      ),
    );
  }

  /// Layout em Duas Linhas Ultra-Compactas para telas estreitas / mobile (altura ~58px)
  Widget _buildTwoRowLayout(
    BuildContext context,
    Song song,
    double sliderValue,
    int totalMs,
    Color serviceColor,
    IconData serviceIcon,
    bool isDark,
    double maxWidth,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Linha 1: Slider contínuo com minutagem compacta (altura: ~18px)
        SizedBox(
          height: 18,
          child: Row(
            children: [
              Text(
                Song.formatDuration(controller.currentPosition.inSeconds),
                style: TextStyle(
                  fontSize: 10,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.grey[300] : Colors.grey[800],
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: _buildSlider(context, sliderValue, totalMs, serviceColor, isDark),
              ),
              const SizedBox(width: 4),
              Text(
                Song.formatDuration(controller.totalDuration.inSeconds),
                style: TextStyle(
                  fontSize: 10,
                  fontFamily: 'monospace',
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
            ],
          ),
        ),

        // Linha 2: Informações da música + Controles (altura: ~34px)
        SizedBox(
          height: 34,
          child: Row(
            children: [
              // Ícone do serviço e Nome da Música
              Icon(serviceIcon, size: 14, color: serviceColor),
              const SizedBox(width: 5),
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        song.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (controller.isLoadingAudio) ...[
                      const SizedBox(width: 6),
                      const SizedBox(
                        width: 10,
                        height: 10,
                        child: CircularProgressIndicator(strokeWidth: 1.5),
                      ),
                    ],
                  ],
                ),
              ),

              // Controles Centrais e de Ação
              _buildActionButtons(context, isDark, serviceColor, compact: true, maxWidth: maxWidth),
            ],
          ),
        ),
      ],
    );
  }

  /// Slider de reprodução ultra-fino
  Widget _buildSlider(
    BuildContext context,
    double sliderValue,
    int totalMs,
    Color serviceColor,
    bool isDark,
  ) {
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: 2.5,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 4.5),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
        activeTrackColor: serviceColor,
        inactiveTrackColor: isDark
            ? Colors.white.withValues(alpha: 0.15)
            : Colors.black.withValues(alpha: 0.10),
        thumbColor: AppCores.rosa,
      ),
      child: Slider(
        value: sliderValue,
        onChanged: (val) {
          final targetSeconds = (val * totalMs / 1000).round();
          controller.seek(Duration(seconds: targetSeconds));
        },
      ),
    );
  }

  /// Conjunto de botões de controle (Play, Pause, ±10s, Volume, Fechar)
  Widget _buildActionButtons(
    BuildContext context,
    bool isDark,
    Color serviceColor, {
    required bool compact,
    double? maxWidth,
  }) {
    final showFullButtons = !compact || (maxWidth != null && maxWidth >= 380);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Reiniciar (apenas se houver espaço)
        if (showFullButtons)
          IconButton(
            icon: const Icon(Icons.skip_previous_rounded, size: 18),
            tooltip: 'Reiniciar música',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
            onPressed: controller.restart,
          ),

        // Voltar 10s
        IconButton(
          icon: const Icon(Icons.replay_10_rounded, size: 19),
          tooltip: 'Voltar 10s',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          onPressed: () => controller.seekRelative(-10),
        ),
        const SizedBox(width: 2),

        // Botão Central de Play / Pause
        InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: controller.togglePlayPause,
          child: Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppCores.gradienteLogo,
              boxShadow: [
                BoxShadow(
                  color: AppCores.roxo.withValues(alpha: 0.30),
                  blurRadius: 6,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: controller.isLoadingAudio
                ? const Center(
                    child: SizedBox(
                      width: 13,
                      height: 13,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 1.8,
                      ),
                    ),
                  )
                : Icon(
                    controller.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
          ),
        ),
        const SizedBox(width: 2),

        // Avançar 10s
        IconButton(
          icon: const Icon(Icons.forward_10_rounded, size: 19),
          tooltip: 'Avançar 10s',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          onPressed: () => controller.seekRelative(10),
        ),

        // Volume / Muto
        IconButton(
          icon: Icon(
            controller.isMuted
                ? Icons.volume_off_rounded
                : (controller.volume < 0.5 ? Icons.volume_down_rounded : Icons.volume_up_rounded),
            size: 17,
            color: controller.isMuted
                ? Colors.redAccent
                : (isDark ? Colors.grey[300] : Colors.grey[700]),
          ),
          tooltip: controller.isMuted ? 'Desmutar' : 'Mutar',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
          onPressed: controller.toggleMute,
        ),

        // Abrir app externo (YouTube) se houver espaço
        if (showFullButtons)
          IconButton(
            icon: Icon(Icons.open_in_new_rounded, size: 14, color: serviceColor),
            tooltip: 'Abrir no ${controller.song.audioServiceName}',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
            onPressed: controller.openExternalApp,
          ),

        // Botão Fechar / Ocultar Player
        if (onClose != null) ...[
          const SizedBox(width: 2),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 16),
            tooltip: 'Ocultar player',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
            onPressed: onClose,
          ),
        ],
      ],
    );
  }
}
