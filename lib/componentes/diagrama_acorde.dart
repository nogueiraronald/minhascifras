import 'dart:math';

import 'package:flutter/material.dart';

import '../modelos/formato_acorde.dart';

class ChordDiagram extends StatelessWidget {
  const ChordDiagram({super.key, required this.shape, this.size = const Size(170, 215)});

  final ChordShape shape;
  final Size size;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CustomPaint(
          size: size,
          painter: _ChordPainter(shape, Theme.of(context).colorScheme.onSurface),
        ),
        if (shape.fingers != null && shape.fingers!.any((f) => f > 0)) ...[
          const SizedBox(height: 6),
          const Text(
            'Dedos: 1 = Indicador • 2 = Médio • 3 = Anelar • 4 = Mínimo',
            style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w500),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}

class _ChordPainter extends CustomPainter {
  _ChordPainter(this.shape, this.color);

  final ChordShape shape;
  final Color color;

  void _text(
    Canvas c,
    String t,
    Offset center, {
    double size = 12,
    FontWeight weight = FontWeight.normal,
    Color? customColor,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: t,
        style: TextStyle(
          color: customColor ?? color,
          fontSize: size,
          fontWeight: weight,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  void paint(Canvas canvas, Size size) {
    const left = 38.0;
    const top = 32.0;

    final base = shape.baseFret;
    final pressed = shape.frets.where((f) => f > 0).toList();
    final maxFret = pressed.isNotEmpty ? pressed.reduce(max) : base;
    final neededRows = maxFret - base + 1;
    final rows = max(5, neededRows);

    final w = size.width - left - 16;
    final h = size.height - top - 24;
    final sg = w / 5;
    final fg = h / rows;

    final line = Paint()
      ..color = color.withValues(alpha: 0.6)
      ..strokeWidth = 1.2;
    final ring = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final fill = Paint()..color = color;

    // Linhas verticais (cordas 6 a 1)
    for (var i = 0; i < 6; i++) {
      final x = left + i * sg;
      canvas.drawLine(Offset(x, top), Offset(x, top + h), line);

      // Rótulo da corda na parte inferior (6ª, 5ª, 4ª, 3ª, 2ª, 1ª)
      _text(
        canvas,
        ChordShape.stringShort[i].split(' ').first,
        Offset(x, top + h + 12),
        size: 9,
        weight: FontWeight.w600,
        customColor: color.withValues(alpha: 0.6),
      );
    }

    // Trastes horizontais
    for (var f = 0; f <= rows; f++) {
      final p = (f == 0 && base == 1)
          ? (Paint()
            ..color = color
            ..strokeWidth = 4.5)
          : line;
      canvas.drawLine(Offset(left, top + f * fg), Offset(left + w, top + f * fg), p);
    }

    // Rótulos de todas as casas do diagrama na lateral esquerda
    for (var f = 0; f < rows; f++) {
      final fretNumber = base + f;
      final y = top + (f + 0.5) * fg;

      if (f == 0 && base > 1) {
        // Destaque da primeira casa quando for além da 1ª (ex: 4ª)
        final badgePaint = Paint()
          ..color = Colors.indigo.withValues(alpha: 0.15)
          ..style = PaintingStyle.fill;
        final rect = RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(18, y), width: 30, height: 18),
          const Radius.circular(5),
        );
        canvas.drawRRect(rect, badgePaint);

        _text(
          canvas,
          '$fretNumberª',
          Offset(18, y),
          size: 11,
          weight: FontWeight.bold,
          customColor: Colors.indigo,
        );
      } else {
        _text(
          canvas,
          '$fretNumberª',
          Offset(18, y),
          size: 10,
          weight: f == 0 ? FontWeight.bold : FontWeight.w500,
          customColor: color.withValues(alpha: 0.55),
        );
      }
    }

    // Detecta se há pestana (2 ou mais cordas na mesma casa)
    final fretCounts = <int, List<int>>{};
    for (var i = 0; i < 6; i++) {
      final fr = shape.frets[i];
      if (fr > 0) {
        fretCounts.putIfAbsent(fr, () => []).add(i);
      }
    }

    int? barreFret;
    List<int>? barreStrings;
    for (final entry in fretCounts.entries) {
      if (entry.value.length >= 2) {
        final strings = entry.value;
        final minStr = strings.first;
        final maxStr = strings.last;
        if (maxStr - minStr >= 1 && (shape.fingerFor(minStr) == 1 || entry.key == base)) {
          barreFret = entry.key;
          barreStrings = strings;
          break;
        }
      }
    }

    if (barreFret != null && barreStrings != null) {
      final row = barreFret - base + 1;
      if (row >= 1 && row <= rows) {
        final x1 = left + barreStrings.first * sg;
        final x2 = left + barreStrings.last * sg;
        final y = top + (row - 0.5) * fg;
        final barreRect = RRect.fromRectAndRadius(
          Rect.fromLTRB(x1 - 8.5, y - 8.5, x2 + 8.5, y + 8.5),
          const Radius.circular(8.5),
        );
        canvas.drawRRect(barreRect, fill);

        final barreFinger = shape.fingerFor(barreStrings.first);
        if (barreFinger > 0) {
          _text(
            canvas,
            barreFinger == 5 ? 'T' : '$barreFinger',
            Offset(x1, y),
            size: 10,
            weight: FontWeight.bold,
            customColor: Colors.white,
          );
        }
      }
    }

    // Marcações nas cordas (X, O, ou Dedo na Casa)
    for (var i = 0; i < 6; i++) {
      final fr = shape.frets[i];
      final x = left + i * sg;

      if (fr < 0) {
        // Abafada (x)
        _text(canvas, '✕', Offset(x, top - 12), size: 12, weight: FontWeight.bold, customColor: Colors.red[700]);
      } else if (fr == 0) {
        // Corda solta (O)
        canvas.drawCircle(Offset(x, top - 12), 5, ring);
      } else {
        final isPartOfBarre = barreFret == fr && barreStrings != null && barreStrings.contains(i);
        final row = fr - base + 1;

        if (row >= 1 && row <= rows) {
          final dotCenter = Offset(x, top + (row - 0.5) * fg);
          if (!isPartOfBarre || i != barreStrings.first) {
            canvas.drawCircle(dotCenter, 8.5, fill);
          }

          // Desenha o número do dedo dentro do ponto se informado
          final finger = shape.fingerFor(i);
          if (finger > 0 && (!isPartOfBarre || i != barreStrings.first)) {
            final fStr = finger == 5 ? 'T' : '$finger';
            _text(
              canvas,
              fStr,
              dotCenter,
              size: 10,
              weight: FontWeight.bold,
              customColor: Colors.white,
            );
          }
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ChordPainter old) => true;
}
