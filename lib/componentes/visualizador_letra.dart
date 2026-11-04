import 'package:flutter/material.dart';

import '../servicos/transpositor_acordes.dart';
import 'estilo_app.dart';

/// Exibe apenas a letra pura da música (omitindo acordes), ideal para cantores e vocalistas,
/// com suporte a destaque da linha cantada estilo Karaokê.
/// Exibe apenas a letra pura da música (omitindo acordes), ideal para cantores e vocalistas,
/// com suporte a destaque da linha cantada estilo Karaokê, mantendo sempre a linha
/// ativa exatamente no centro da tela (meio da tela).
class LyricsView extends StatefulWidget {
  const LyricsView({
    super.key,
    required this.content,
    required this.fontSize,
    this.controller,
    this.activeLineIndex,
    this.playbackProgress,
    this.autoScroll = true,
    this.onLineTap,
    this.onSeekProgress,
  });

  final String content;
  final double fontSize;
  final ScrollController? controller;

  /// Índice explícito da linha cantada no Karaokê
  final int? activeLineIndex;

  /// Progresso da música (0.0 a 1.0) para cálculo proporcional automático
  final double? playbackProgress;

  /// Se deve rolar suavemente para manter a linha cantada no centro vertical da tela
  final bool autoScroll;

  /// Callback chamado ao tocar em qualquer linha para saltar o áudio para aquele trecho
  final void Function(int lineIndex)? onLineTap;

  /// Callback chamado com a fração temporal ao tocar em uma linha
  final void Function(double progress)? onSeekProgress;

  @override
  State<LyricsView> createState() => _LyricsViewState();
}

class _LyricsViewState extends State<LyricsView> {
  @override
  void didUpdateWidget(covariant LyricsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _checkJumpIfFar(oldWidget);
  }

  /// Caso haja um salto muito grande, faz um salto prévio aproximado
  void _checkJumpIfFar(LyricsView oldWidget) {
    if (!widget.autoScroll) return;
    final active = widget.activeLineIndex;
    final oldActive = oldWidget.activeLineIndex;
    if (active != null && active != oldActive && widget.controller != null && widget.controller!.hasClients) {
      final clean = ChordTransposer.cleanText(widget.content);
      final rawLines = clean.replaceAll('\r\n', '\n').split('\n');
      if (rawLines.isNotEmpty) {
        final maxScroll = widget.controller!.position.maxScrollExtent;
        if (maxScroll > 0) {
          final approx = (maxScroll * (active / rawLines.length)).clamp(0.0, maxScroll);
          if ((widget.controller!.offset - approx).abs() > 3000) {
            widget.controller!.jumpTo(approx);
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final clean = ChordTransposer.cleanText(widget.content);
    final rawLines = clean.replaceAll('\r\n', '\n').split('\n');

    // Filtra as linhas para exibir apenas letras e marcadores estruturais ([Intro], [Refrão], etc.)
    final List<_LyricsLine> displayLines = [];

    for (int i = 0; i < rawLines.length; i++) {
      final line = rawLines[i].trimRight();
      final trimmed = line.trim();

      // Linha vazia
      if (trimmed.isEmpty) {
        if (displayLines.isNotEmpty && !displayLines.last.isEmpty) {
          displayLines.add(const _LyricsLine.empty());
        }
        continue;
      }

      // Marcadores como [Refrão], [Intro], [Ponte], [Solo], [Final]
      if (ChordTransposer.isMarker(trimmed) || RegExp(r'^\[.*\]$').hasMatch(trimmed)) {
        displayLines.add(_LyricsLine.marker(trimmed, originalIndex: i));
        continue;
      }

      // Se a linha for classificada como linha de acordes:
      if (ChordTransposer.isChordLine(line)) {
        final markerMatch = RegExp(r'\[(.*?)\]').firstMatch(line);
        if (markerMatch != null) {
          final markerText = '[${markerMatch.group(1)}]';
          displayLines.add(_LyricsLine.marker(markerText, originalIndex: i));
        }
        continue;
      }

      // Linha de letra: remove possíveis acordes embutidos entre colchetes se houver
      final cleanLyrics = line.replaceAll(RegExp(r'\[[A-G][b#]?[^\]]*\]'), '').trimRight();
      if (cleanLyrics.isNotEmpty) {
        displayLines.add(_LyricsLine.text(cleanLyrics, originalIndex: i));
      }
    }

    // Mapeia índices exclusivos das linhas reais de letra e marcadores estruturais
    final lyricIndices = <int>[];
    for (int i = 0; i < displayLines.length; i++) {
      if (!displayLines[i].isEmpty) {
        lyricIndices.add(i);
      }
    }

    // Determina a linha de letra ativa (via detecção do controlador com mapeamento de índice original ou fallback)
    int? resolvedActiveLyricIndex;
    final targetIdx = widget.activeLineIndex;
    if (targetIdx != null) {
      final found = displayLines.indexWhere((l) => l.originalIndex == targetIdx);
      if (found != -1) {
        resolvedActiveLyricIndex = found;
      } else if (targetIdx < displayLines.length) {
        resolvedActiveLyricIndex = targetIdx;
      }
    }

    if (resolvedActiveLyricIndex == null && widget.playbackProgress != null && lyricIndices.isNotEmpty) {
      final idx = (lyricIndices.length * widget.playbackProgress!.clamp(0.0, 1.0)).floor().clamp(0, lyricIndices.length - 1);
      resolvedActiveLyricIndex = lyricIndices[idx];
    }

    final hasTapCallback = widget.onLineTap != null || widget.onSeekProgress != null;
    void handleTap(int index) {
      widget.onLineTap?.call(index);
      if (widget.onSeekProgress != null && displayLines.isNotEmpty) {
        widget.onSeekProgress!(index / displayLines.length);
      }
    }

    // Padding inferior generoso garantindo que mesmo a ÚLTIMA linha da letra possa
    // ser posicionada com folga exatamente no centro vertical da tela (alignment: 0.5)
    final screenHeight = MediaQuery.of(context).size.height;
    final bottomPadding = (screenHeight * 0.55).clamp(420.0, 900.0);

    return ListView.builder(
      controller: widget.controller,
      cacheExtent: 5000,
      padding: EdgeInsets.fromLTRB(24, 20, 24, bottomPadding),
      itemCount: displayLines.length,
      itemBuilder: (context, index) {
        final item = displayLines[index];
        final isLyric = !item.isEmpty;
        // No modo letra, linhas de letra E marcadores estruturais podem ser ressaltados!
        final isActive = isLyric && resolvedActiveLyricIndex != null && index == resolvedActiveLyricIndex;

        if (item.isEmpty) {
          return const SizedBox(height: 16);
        }

        if (item.isMarker) {
          final markerWidget = Padding(
            padding: const EdgeInsets.only(top: 18, bottom: 8),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isActive
                        ? (isDark
                            ? AppCores.roxo.withValues(alpha: 0.28)
                            : AppCores.rosa.withValues(alpha: 0.12))
                        : scheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isActive ? AppCores.rosa : scheme.primary.withValues(alpha: 0.4),
                      width: isActive ? 1.5 : 1.0,
                    ),
                  ),
                  child: Text(
                    item.content,
                    style: TextStyle(
                      fontSize: (widget.fontSize * 0.85).clamp(11.0, 18.0),
                      fontWeight: FontWeight.bold,
                      color: isActive ? AppCores.rosa : scheme.primary,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          );

          return _ActiveKaraokeLine(
            key: ValueKey(index),
            isActive: isActive && widget.autoScroll,
            child: markerWidget,
          );
        }

        final lineWidget = Text(
          item.content,
          style: TextStyle(
            fontSize: widget.fontSize,
            height: 1.5,
            fontWeight: isActive ? FontWeight.w800 : FontWeight.w400,
            color: isActive
                ? (isDark ? Colors.white : const Color(0xFF0F172A))
                : scheme.onSurface,
            letterSpacing: 0.2,
          ),
        );

        Widget childWidget;
        if (isActive) {
          childWidget = InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: hasTapCallback ? () => handleTap(index) : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(vertical: 2),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: isDark
                    ? AppCores.roxo.withValues(alpha: 0.22)
                    : AppCores.rosa.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppCores.rosa,
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppCores.rosa.withValues(alpha: isDark ? 0.20 : 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: lineWidget,
            ),
          );
        } else if (hasTapCallback) {
          childWidget = InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: () => handleTap(index),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: lineWidget,
            ),
          );
        } else {
          childWidget = Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: lineWidget,
          );
        }

        return _ActiveKaraokeLine(
          key: ValueKey(index),
          isActive: isActive && widget.autoScroll,
          child: childWidget,
        );
      },
    );
  }
}

/// Envolve uma linha da letra e, quando ativada pelo Karaokê,
/// rola suavemente para posicioná-la com precisão matemática no centro exato da tela (meio da tela).
class _ActiveKaraokeLine extends StatefulWidget {
  const _ActiveKaraokeLine({
    super.key,
    required this.child,
    required this.isActive,
  });

  final Widget child;
  final bool isActive;

  @override
  State<_ActiveKaraokeLine> createState() => _ActiveKaraokeLineState();
}

class _ActiveKaraokeLineState extends State<_ActiveKaraokeLine> {
  @override
  void initState() {
    super.initState();
    if (widget.isActive) {
      _scrollToCenter();
    }
  }

  @override
  void didUpdateWidget(covariant _ActiveKaraokeLine oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _scrollToCenter();
    }
  }

  void _scrollToCenter() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        Scrollable.ensureVisible(
          context,
          alignment: 0.5, // 0.5 = Centro vertical exato da tela (meio da tela)
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
        );
      } catch (_) {}
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _LyricsLine {
  final String content;
  final bool isMarker;
  final bool isEmpty;
  final int? originalIndex;

  const _LyricsLine.text(this.content, {this.originalIndex})
      : isMarker = false,
        isEmpty = false;

  const _LyricsLine.marker(this.content, {this.originalIndex})
      : isMarker = true,
        isEmpty = false;

  const _LyricsLine.empty()
      : content = '',
        isMarker = false,
        isEmpty = true,
        originalIndex = null;
}
