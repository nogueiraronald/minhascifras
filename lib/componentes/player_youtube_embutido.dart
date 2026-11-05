import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../servicos/controlador_audio_karaoke.dart';
import 'player_youtube_embutido_stub.dart'
    if (dart.library.html) 'player_youtube_embutido_web.dart' as impl;

/// Componente que exibe o mini player oficial do YouTube de forma integrada,
/// permitindo ser livremente arrastado (alterado de local) e redimensionado
/// pelo usuário, com sincronização bidirecional em tempo real com o Karaokê.
class PlayerYoutubeEmbutido extends StatefulWidget {
  const PlayerYoutubeEmbutido({
    super.key,
    required this.videoId,
    this.controller,
    this.onClose,
    this.visible = true,
    this.initialRight = 12.0,
    this.initialBottom = 8.0,
  });

  final String videoId;
  final KaraokeAudioController? controller;
  final VoidCallback? onClose;
  final bool visible;
  final double initialRight;
  final double initialBottom;

  @override
  State<PlayerYoutubeEmbutido> createState() => _PlayerYoutubeEmbutidoState();
}

class _PlayerYoutubeEmbutidoState extends State<PlayerYoutubeEmbutido> {
  static const String _prefKeyWidth = 'user_mini_player_width_v1';
  static const String _prefKeyRight = 'user_mini_player_right_v1';
  static const String _prefKeyBottom = 'user_mini_player_bottom_v1';

  late double _right = widget.initialRight;
  late double _bottom = widget.initialBottom;
  double _width = 290.0;
  bool _isInteracting = false;

  @override
  void initState() {
    super.initState();
    _loadSavedGeometry();
  }

  Future<void> _loadSavedGeometry() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedWidth = prefs.getDouble(_prefKeyWidth);
      final savedRight = prefs.getDouble(_prefKeyRight);
      final savedBottom = prefs.getDouble(_prefKeyBottom);
      if (!mounted) return;
      setState(() {
        if (savedWidth != null && savedWidth >= 160 && savedWidth <= 600) {
          _width = savedWidth;
        }
        if (savedRight != null && savedRight >= 0) {
          _right = savedRight;
        }
        if (savedBottom != null && savedBottom >= 0) {
          _bottom = savedBottom;
        }
      });
    } catch (_) {}
  }

  Future<void> _saveGeometry() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_prefKeyWidth, _width);
      await prefs.setDouble(_prefKeyRight, _right);
      await prefs.setDouble(_prefKeyBottom, _bottom);
    } catch (_) {}
  }

  void _changeWidthBy(double delta, double minWidth, double maxAllowedWidth) {
    setState(() {
      _width = (_width + delta).clamp(minWidth, maxAllowedWidth);
    });
    _saveGeometry();
  }

  /// Alterna rapidamente o mini player entre os 4 cantos da tela
  void _cycleCorner(double maxRight, double maxBottom, double effectiveRight, double effectiveBottom) {
    final isRight = effectiveRight < maxRight / 2;
    final isBottom = effectiveBottom < maxBottom / 2;

    setState(() {
      if (isRight && isBottom) {
        // Inferior Direito -> Superior Direito
        _right = 12.0;
        _bottom = math.max(8.0, maxBottom - 8.0);
      } else if (isRight && !isBottom) {
        // Superior Direito -> Superior Esquerdo
        _right = math.max(12.0, maxRight - 8.0);
        _bottom = math.max(8.0, maxBottom - 8.0);
      } else if (!isRight && !isBottom) {
        // Superior Esquerdo -> Inferior Esquerdo
        _right = math.max(12.0, maxRight - 8.0);
        _bottom = 8.0;
      } else {
        // Inferior Esquerdo -> Inferior Direito
        _right = 12.0;
        _bottom = 8.0;
      }
    });
    _saveGeometry();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth.isFinite && constraints.maxWidth > 0
            ? constraints.maxWidth
            : MediaQuery.of(context).size.width;
        final maxHeight = constraints.maxHeight.isFinite && constraints.maxHeight > 0
            ? constraints.maxHeight
            : MediaQuery.of(context).size.height;

        const minWidth = 160.0;
        final maxAllowedWidth = (maxWidth - 16.0).clamp(minWidth, 560.0);
        final effectiveWidth = _width.clamp(minWidth, maxAllowedWidth);
        final videoHeight = (effectiveWidth * 9.0 / 16.0).roundToDouble();
        const headerHeight = 32.0;
        final totalHeight = videoHeight + headerHeight;

        final maxRight = math.max(4.0, maxWidth - effectiveWidth - 4.0);
        final maxBottom = math.max(4.0, maxHeight - totalHeight - 4.0);
        final effectiveRight = _right.clamp(4.0, maxRight);
        final effectiveBottom = _bottom.clamp(4.0, maxBottom);

        return SizedBox(
          width: maxWidth,
          height: maxHeight,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                key: const ValueKey('mini_player_positioned'),
                right: effectiveRight,
                bottom: effectiveBottom,
                width: effectiveWidth,
                child: Visibility(
                  visible: widget.visible,
                  maintainState: true,
                  maintainAnimation: true,
                  maintainSize: false,
                  child: _buildPlayerCard(
                    context: context,
                    isDark: isDark,
                    effectiveWidth: effectiveWidth,
                    videoHeight: videoHeight,
                    minWidth: minWidth,
                    maxAllowedWidth: maxAllowedWidth,
                    maxRight: maxRight,
                    maxBottom: maxBottom,
                    effectiveRight: effectiveRight,
                    effectiveBottom: effectiveBottom,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPlayerCard({
    required BuildContext context,
    required bool isDark,
    required double effectiveWidth,
    required double videoHeight,
    required double minWidth,
    required double maxAllowedWidth,
    required double maxRight,
    required double maxBottom,
    required double effectiveRight,
    required double effectiveBottom,
  }) {
    return Container(
      key: const ValueKey('mini_player_card'),
      width: effectiveWidth,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFEF4444).withValues(alpha: _isInteracting ? 0.75 : 0.35),
          width: _isInteracting ? 1.6 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.18),
            blurRadius: _isInteracting ? 18 : 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Barra Superior Arrastável (Move o Mini Player e oferece controles rápidos de tamanho/local)
          MouseRegion(
            cursor: SystemMouseCursors.move,
            child: GestureDetector(
              key: const ValueKey('mini_player_drag_header'),
              behavior: HitTestBehavior.opaque,
              onPanStart: (_) {
                setState(() {
                  _right = effectiveRight;
                  _bottom = effectiveBottom;
                  _isInteracting = true;
                });
              },
              onPanUpdate: (details) {
                setState(() {
                  _right = (_right - details.delta.dx).clamp(4.0, maxRight);
                  _bottom = (_bottom - details.delta.dy).clamp(4.0, maxBottom);
                });
              },
              onPanEnd: (_) {
                setState(() => _isInteracting = false);
                _saveGeometry();
              },
              onPanCancel: () {
                setState(() => _isInteracting = false);
                _saveGeometry();
              },
              child: Container(
                height: 32,
                padding: const EdgeInsets.fromLTRB(6, 2, 4, 2),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1E293B).withValues(alpha: 0.7)
                      : const Color(0xFFF8FAFC),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.drag_indicator_rounded,
                      size: 14,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                    const SizedBox(width: 2),
                    const Icon(
                      Icons.smart_display_rounded,
                      size: 15,
                      color: Color(0xFFEF4444),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        effectiveWidth < 235 ? 'YouTube' : 'YouTube Integrado',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    // Botão Diminuir (-)
                    IconButton(
                      key: const ValueKey('mini_player_shrink_btn'),
                      icon: const Icon(Icons.remove_rounded, size: 14),
                      tooltip: 'Diminuir tamanho do player',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                      onPressed: effectiveWidth > minWidth
                          ? () => _changeWidthBy(-40, minWidth, maxAllowedWidth)
                          : null,
                    ),
                    // Botão Aumentar (+)
                    IconButton(
                      key: const ValueKey('mini_player_expand_btn'),
                      icon: const Icon(Icons.add_rounded, size: 14),
                      tooltip: 'Aumentar tamanho do player',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                      onPressed: effectiveWidth < maxAllowedWidth
                          ? () => _changeWidthBy(40, minWidth, maxAllowedWidth)
                          : null,
                    ),
                    // Botão Alternar Canto / Local
                    IconButton(
                      key: const ValueKey('mini_player_move_corner_btn'),
                      icon: const Icon(Icons.open_with_rounded, size: 13),
                      tooltip: 'Mudar local do player (ou arraste esta barra)',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                      onPressed: () => _cycleCorner(
                        maxRight,
                        maxBottom,
                        effectiveRight,
                        effectiveBottom,
                      ),
                    ),
                    if (widget.onClose != null)
                      IconButton(
                        key: const ValueKey('mini_player_close_btn'),
                        icon: const Icon(Icons.close_rounded, size: 15),
                        tooltip: 'Ocultar vídeo (áudio continua tocando)',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                        onPressed: widget.onClose,
                      ),
                  ],
                ),
              ),
            ),
          ),

          // Área do Vídeo com alças de redimensionamento nos cantos inferiores
          ClipRRect(
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(13)),
            child: SizedBox(
              width: effectiveWidth,
              height: videoHeight,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  impl.buildYoutubePlayerView(
                    context: context,
                    videoId: widget.videoId,
                    controller: widget.controller,
                    onClose: widget.onClose,
                    isInteracting: _isInteracting,
                  ),

                  // Enquanto estiver arrastando/redimensionando, bloqueia captura de eventos pelo iframe
                  if (_isInteracting)
                    const Positioned.fill(
                      child: ColoredBox(color: Colors.transparent),
                    ),

                  // Alça de redimensionamento no canto inferior esquerdo (puxar para esquerda aumenta largura)
                  Positioned(
                    left: 0,
                    bottom: 0,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.resizeUpRightDownLeft,
                      child: GestureDetector(
                        key: const ValueKey('mini_player_resize_handle_left'),
                        behavior: HitTestBehavior.opaque,
                        onPanStart: (_) {
                          setState(() {
                            _width = effectiveWidth;
                            _right = effectiveRight;
                            _bottom = effectiveBottom;
                            _isInteracting = true;
                          });
                        },
                        onPanUpdate: (details) {
                          setState(() {
                            // Puxar para a esquerda (delta.dx < 0) aumenta a largura mantendo a borda direita
                            final newWidth = (_width - details.delta.dx).clamp(minWidth, maxAllowedWidth);
                            _width = newWidth;
                            // Puxar para baixo (delta.dy > 0) move a base ou ajusta
                            _bottom = (_bottom - details.delta.dy).clamp(4.0, maxBottom);
                          });
                        },
                        onPanEnd: (_) {
                          setState(() => _isInteracting = false);
                          _saveGeometry();
                        },
                        onPanCancel: () {
                          setState(() => _isInteracting = false);
                          _saveGeometry();
                        },
                        child: Container(
                          width: 24,
                          height: 24,
                          alignment: Alignment.bottomLeft,
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.45),
                            borderRadius: const BorderRadius.only(
                              topRight: Radius.circular(8),
                            ),
                          ),
                          child: const Icon(
                            Icons.open_in_full_rounded,
                            size: 13,
                            color: Colors.white70,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Alça de redimensionamento no canto inferior direito
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.resizeUpLeftDownRight,
                      child: GestureDetector(
                        key: const ValueKey('mini_player_resize_handle'),
                        behavior: HitTestBehavior.opaque,
                        onPanStart: (_) {
                          setState(() {
                            _width = effectiveWidth;
                            _right = effectiveRight;
                            _bottom = effectiveBottom;
                            _isInteracting = true;
                          });
                        },
                        onPanUpdate: (details) {
                          setState(() {
                            // Puxar para a direita (delta.dx > 0) aumenta a largura mantendo a borda esquerda
                            final oldWidth = _width;
                            final newWidth = (_width + details.delta.dx).clamp(minWidth, maxAllowedWidth);
                            final widthDiff = newWidth - oldWidth;
                            _width = newWidth;
                            _right = (_right - widthDiff).clamp(4.0, maxRight);
                            _bottom = (_bottom - details.delta.dy).clamp(4.0, maxBottom);
                          });
                        },
                        onPanEnd: (_) {
                          setState(() => _isInteracting = false);
                          _saveGeometry();
                        },
                        onPanCancel: () {
                          setState(() => _isInteracting = false);
                          _saveGeometry();
                        },
                        child: Container(
                          width: 24,
                          height: 24,
                          alignment: Alignment.bottomRight,
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.45),
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(8),
                            ),
                          ),
                          child: const Icon(
                            Icons.south_east_rounded,
                            size: 13,
                            color: Colors.white70,
                          ),
                        ),
                      ),
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
}
