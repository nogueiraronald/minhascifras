import 'package:flutter/material.dart';

import '../services/chord_transposer.dart';

/// Mostra a cifra; cada acorde é tocável.
class ChordSheetView extends StatelessWidget {
  const ChordSheetView({
    super.key,
    required this.content,
    required this.transpose,
    required this.fontSize,
    required this.onChordTap,
    this.controller,
  });

  final String content;
  final int transpose;
  final double fontSize;
  final void Function(String chord) onChordTap;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final lines = content.replaceAll('\r\n', '\n').split('\n');
    final base = TextStyle(
        fontFamily: 'monospace', fontSize: fontSize, height: 1.3, color: scheme.onSurface);
    final chordStyle =
        base.copyWith(fontWeight: FontWeight.bold, color: scheme.primary);

    return ListView.builder(
      controller: controller,
      padding: const EdgeInsets.all(16),
      itemCount: lines.length,
      itemBuilder: (_, i) {
        final line = lines[i];
        if (!ChordTransposer.isChordLine(line)) {
          return Text(line.isEmpty ? ' ' : line, style: base);
        }
        final spans = <InlineSpan>[];
        for (final m in RegExp(r'(\s+)|(\S+)').allMatches(line)) {
          final ws = m.group(1);
          if (ws != null) {
            spans.add(TextSpan(text: ws));
            continue;
          }
          final raw = m.group(2)!;
          final shown =
              transpose == 0 ? raw : ChordTransposer.transposeChord(raw, transpose);
          spans.add(WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: GestureDetector(
              onTap: () => onChordTap(shown),
              child: Text(shown, style: chordStyle),
            ),
          ));
        }
        return Text.rich(TextSpan(style: base, children: spans));
      },
    );
  }
}
