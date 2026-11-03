import 'package:flutter/material.dart';

import '../servicos/transpositor_acordes.dart';
import 'estilo_app.dart';

/// Mostra a cifra com suporte a transposição, acordes tocáveis e
/// destaque visual animado do trecho cantado estilo Karaokê, mantendo
/// sempre a linha ativa exatamente no centro da tela (meio da tela).
class ChordSheetView extends StatefulWidget {
  const ChordSheetView({
    super.key,
    required this.content,
    required this.transpose,
    required this.fontSize,
    required this.onChordTap,
    this.controller,
    this.activeLineIndex,
    this.playbackProgress,
    this.autoScroll = true,
    this.onLineTap,
    this.onSeekProgress,
  });

  final String content;
  final int transpose;
  final double fontSize;
  final void Function(String chord) onChordTap;
  final ScrollController? controller;

  /// Índice explícito da linha cantada no Karaokê
  final int? activeLineIndex;

  /// Progresso da música (0.0 a 1.0) para cálculo proporcional automático
  final double? playbackProgress;

  /// Se deve rolar suavemente para manter a linha cantada no centro vertical da tela
  final bool autoScroll;

  /// Callback chamado ao tocar em qualquer linha
  final void Function(int lineIndex)? onLineTap;

  /// Callback chamado com a fração temporal ao tocar em uma linha
  final void Function(double progress)? onSeekProgress;

  @override
  State<ChordSheetView> createState() => _ChordSheetViewState();
}

class _ChordSheetViewState extends State<ChordSheetView> {
  @override
  void didUpdateWidget(covariant ChordSheetView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _checkJumpIfFar(oldWidget);
  }

  /// Caso haja um salto muito grande (ex: seek manual para o fim de uma música de 400 linhas),
  /// faz um salto prévio aproximado para garantir que a linha entre na área de layout do ListView
  void _checkJumpIfFar(ChordSheetView oldWidget) {
    if (!widget.autoScroll) return;
    final active = widget.activeLineIndex;
    final oldActive = oldWidget.activeLineIndex;
    if (active != null && active != oldActive && widget.controller != null && widget.controller!.hasClients) {
      final clean = ChordTransposer.cleanText(widget.content);
      final lines = clean.replaceAll('\r\n', '\n').split('\n');
      if (lines.isNotEmpty) {
        final maxScroll = widget.controller!.position.maxScrollExtent;
        if (maxScroll > 0) {
          final approx = (maxScroll * (active / lines.length)).clamp(0.0, maxScroll);
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
    final lines = clean.replaceAll('\r\n', '\n').split('\n');

    // Mapeia índices exclusivos das linhas de acordes
    final chordIndices = <int>[];
    for (int i = 0; i < lines.length; i++) {
      if (ChordTransposer.isChordLine(lines[i])) {
        chordIndices.add(i);
      }
    }

    // Determina a linha de acorde ativa (via detecção do controlador ou fallback proporcional)
    int? resolvedActiveChordIndex = widget.activeLineIndex;
    if (resolvedActiveChordIndex == null && widget.playbackProgress != null && chordIndices.isNotEmpty) {
      final idx = (chordIndices.length * widget.playbackProgress!.clamp(0.0, 1.0)).floor().clamp(0, chordIndices.length - 1);
      resolvedActiveChordIndex = chordIndices[idx];
    }

    final hasTapCallback = widget.onLineTap != null || widget.onSeekProgress != null;
    void handleTap(int index) {
      widget.onLineTap?.call(index);
      if (widget.onSeekProgress != null && lines.isNotEmpty) {
        widget.onSeekProgress!(index / lines.length);
      }
    }

    final base = TextStyle(
      fontFamily: 'monospace',
      fontSize: widget.fontSize,
      height: 1.35,
      color: scheme.onSurface,
    );
    final chordStyle = base.copyWith(
      fontWeight: FontWeight.bold,
      color: scheme.primary,
    );

    // Padding inferior generoso garantindo que mesmo a ÚLTIMA linha da música possa
    // ser posicionada com folga exatamente no centro vertical da tela (alignment: 0.5)
    final screenHeight = MediaQuery.of(context).size.height;
    final bottomPadding = (screenHeight * 0.55).clamp(420.0, 900.0);

    return ListView.builder(
      controller: widget.controller,
      cacheExtent: 5000,
      padding: EdgeInsets.fromLTRB(16, 20, 16, bottomPadding),
      itemCount: lines.length,
      itemBuilder: (_, i) {
        final line = lines[i];
        final isBlank = line.trim().isEmpty;
        final isChord = ChordTransposer.isChordLine(line);
        // No modo cifra, APENAS linhas de acordes podem ser ressaltadas!
        final isActive = isChord && resolvedActiveChordIndex != null && i == resolvedActiveChordIndex;

        Widget lineWidget;

        if (isBlank) {
          lineWidget = Text(' ', style: base);
        } else if (!isChord) {
          final isMarker = ChordTransposer.isMarker(line) || RegExp(r'^\[.*\]$').hasMatch(line.trim());
          final style = isMarker
              ? base.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.3,
                )
              : base;
          lineWidget = Text(line, style: style);
        } else {
          // Linha de acordes
          final spans = <InlineSpan>[];
          for (final m in RegExp(r'(\s+)|(\S+)').allMatches(line)) {
            final ws = m.group(1);
            if (ws != null) {
              spans.add(TextSpan(text: ws));
              continue;
            }
            final raw = m.group(2)!;
            final parsed = ChordTransposer.parseTokenChord(raw);
            if (parsed != null) {
              if (parsed.prefix.isNotEmpty) {
                spans.add(TextSpan(text: parsed.prefix, style: base));
              }
              final shownChord = widget.transpose == 0
                  ? parsed.chord
                  : ChordTransposer.transposeChord(parsed.chord, widget.transpose);

              final chordColor = isActive ? AppCores.rosa : scheme.primary;

              spans.add(WidgetSpan(
                alignment: PlaceholderAlignment.baseline,
                baseline: TextBaseline.alphabetic,
                child: GestureDetector(
                  onTap: () => widget.onChordTap(ChordTransposer.cleanChordForLookup(shownChord)),
                  child: Text(
                    shownChord,
                    style: chordStyle.copyWith(
                      color: chordColor,
                      fontWeight: isActive ? FontWeight.w900 : FontWeight.bold,
                      shadows: isActive
                          ? [
                              Shadow(
                                color: AppCores.rosa.withValues(alpha: 0.45),
                                blurRadius: 8,
                              ),
                            ]
                          : null,
                    ),
                  ),
                ),
              ));
              if (parsed.suffix.isNotEmpty) {
                spans.add(TextSpan(text: parsed.suffix, style: base));
              }
            } else {
              spans.add(TextSpan(
                text: raw,
                style: ChordTransposer.isMarker(raw)
                    ? base.copyWith(
                        color: isActive
                            ? AppCores.rosa
                            : scheme.primary.withValues(alpha: 0.8),
                        fontWeight: FontWeight.w700,
                      )
                    : (isActive ? base.copyWith(fontWeight: FontWeight.w800) : base),
              ));
            }
          }
          lineWidget = Text.rich(TextSpan(style: base, children: spans));
        }

        Widget childWidget;
        // Se esta linha for o trecho atualmente cantado no Karaokê
        if (isActive && !isBlank) {
          childWidget = InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: hasTapCallback ? () => handleTap(i) : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(vertical: 2),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
        } else if (hasTapCallback && !isBlank) {
          childWidget = InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: () => handleTap(i),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              child: lineWidget,
            ),
          );
        } else {
          childWidget = Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            child: lineWidget,
          );
        }

        return _ActiveKaraokeLine(
          key: ValueKey(i),
          isActive: isActive && widget.autoScroll,
          child: childWidget,
        );
      },
    );
  }
}

/// Envolve uma linha da cifra ou letra e, quando ativada pelo Karaokê,
/// Envolve uma linha da cifra e, quando ativada pelo Karaokê,
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
