import 'package:flutter/material.dart';

import '../models/chord_shape.dart';

class ChordDiagram extends StatelessWidget {
  const ChordDiagram({super.key, required this.shape});

  final ChordShape shape;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(140, 170),
      painter: _ChordPainter(shape, Theme.of(context).colorScheme.onSurface),
    );
  }
}

class _ChordPainter extends CustomPainter {
  _ChordPainter(this.shape, this.color);

  final ChordShape shape;
  final Color color;

  void _text(Canvas c, String t, Offset center, {double size = 13}) {
    final tp = TextPainter(
      text: TextSpan(text: t, style: TextStyle(color: color, fontSize: size)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  void paint(Canvas canvas, Size size) {
    const left = 26.0, top = 30.0, rows = 5;
    final w = size.width - left - 12;
    final h = size.height - top - 8;
    final sg = w / 5, fg = h / rows;
    final line = Paint()
      ..color = color
      ..strokeWidth = 1.2;
    final ring = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final fill = Paint()..color = color;
    final base = shape.baseFret;

    for (var i = 0; i < 6; i++) {
      final x = left + i * sg;
      canvas.drawLine(Offset(x, top), Offset(x, top + h), line);
    }
    for (var f = 0; f <= rows; f++) {
      final p = (f == 0 && base == 1)
          ? (Paint()
            ..color = color
            ..strokeWidth = 4)
          : line;
      canvas.drawLine(Offset(left, top + f * fg), Offset(left + w, top + f * fg), p);
    }
    for (var i = 0; i < 6; i++) {
      final fr = shape.frets[i];
      final x = left + i * sg;
      if (fr < 0) {
        _text(canvas, 'x', Offset(x, top - 12));
      } else if (fr == 0) {
        canvas.drawCircle(Offset(x, top - 12), 5, ring);
      } else {
        final row = fr - base + 1;
        if (row >= 1 && row <= rows) {
          canvas.drawCircle(Offset(x, top + (row - 0.5) * fg), 7, fill);
        }
      }
    }
    if (base > 1) _text(canvas, '$baseª', Offset(10, top + fg / 2), size: 11);
  }

  @override
  bool shouldRepaint(covariant _ChordPainter old) => true;
}
