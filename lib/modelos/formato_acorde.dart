import 'dart:math';

/// Desenho de um acorde: 6 cordas (corda 6 -> 1).
/// frets: -1 = abafada/muda (x), 0 = solta, >0 = casa.
/// fingers: 0 = sem dedo, 1 = Indicador, 2 = Médio, 3 = Anelar, 4 = Mínimo, 5 = Polegar (T).
class ChordShape {
  const ChordShape(this.frets, [this.fingers, this.baseFretOverride]);

  final List<int> frets;
  final List<int>? fingers;
  final int? baseFretOverride;

  static const List<String> stringNames = [
    '6ª (Mi / E)',
    '5ª (Lá / A)',
    '4ª (Ré / D)',
    '3ª (Sol / G)',
    '2ª (Si / B)',
    '1ª (Mi / e)',
  ];

  static const List<String> stringShort = [
    '6ª E',
    '5ª A',
    '4ª D',
    '3ª G',
    '2ª B',
    '1ª e',
  ];

  static const List<String> fingerNames = [
    '- Nenhum',
    '1 - Indicador',
    '2 - Médio',
    '3 - Anelar',
    '4 - Mínimo',
    'T - Polegar',
  ];

  /// Aceita "x,3,2,0,1,0", com dedos "x,3,2,0,1,0;0,3,2,0,1,0",
  /// ou com casa inicial "4,6,6,4,4,4;1,3,4,1,1,1;4".
  static ChordShape? parse(String text) {
    final t = text.trim().toLowerCase();
    if (t.isEmpty) return null;

    String fretsPart = t;
    String? fingersPart;
    int? baseOverride;

    if (t.contains(';')) {
      final s = t.split(';');
      fretsPart = s[0];
      fingersPart = s.length > 1 ? s[1] : null;
      if (s.length > 2) {
        baseOverride = int.tryParse(s[2].trim());
      }
    } else if (t.contains('|')) {
      final s = t.split('|');
      fretsPart = s[0];
      fingersPart = s.length > 1 ? s[1] : null;
      if (s.length > 2) {
        baseOverride = int.tryParse(s[2].trim());
      }
    }

    final parts = fretsPart.contains(',')
        ? fretsPart.split(',').map((e) => e.trim()).toList()
        : fretsPart.split('');
    if (parts.length != 6) return null;

    final frets = <int>[];
    for (final p in parts) {
      final v = p == 'x' ? -1 : int.tryParse(p);
      if (v == null || v > 24) return null;
      frets.add(v);
    }

    List<int>? fingers;
    if (fingersPart != null && fingersPart.trim().isNotEmpty) {
      final fParts = fingersPart.contains(',')
          ? fingersPart.split(',').map((e) => e.trim()).toList()
          : fingersPart.split('');
      if (fParts.length == 6) {
        fingers = [];
        for (final p in fParts) {
          if (p == 't' || p == 'p') {
            fingers.add(5);
          } else {
            final v = int.tryParse(p) ?? 0;
            fingers.add(v.clamp(0, 5));
          }
        }
      }
    }

    return ChordShape(frets, fingers, baseOverride);
  }

  String toText() {
    final fretsStr = frets.map((f) => f < 0 ? 'x' : '$f').join(',');
    final hasFingers = fingers != null && fingers!.any((f) => f > 0);
    final fingersStr = hasFingers
        ? fingers!.map((f) => f == 5 ? 'T' : '$f').join(',')
        : '0,0,0,0,0,0';

    if (baseFretOverride != null && baseFretOverride! > 0) {
      return '$fretsStr;$fingersStr;$baseFretOverride';
    }
    if (hasFingers) {
      return '$fretsStr;$fingersStr';
    }
    return fretsStr;
  }

  /// Casa inicial onde o diagrama começa a ser desenhado.
  int get baseFret {
    if (baseFretOverride != null && baseFretOverride! >= 1) {
      return baseFretOverride!;
    }
    final pressed = frets.where((f) => f > 0).toList();
    if (pressed.isEmpty) return 1;

    // Se o acorde tiver cordas soltas (0), é obrigado a começar na pestana fixa (casa 1)
    if (frets.contains(0)) return 1;

    final minFret = pressed.reduce(min);
    if (minFret <= 1) return 1;

    // Acordes com pestana ou fechados começam no menor traste pressionado
    return minFret;
  }

  int fingerFor(int stringIndex) {
    if (fingers != null && stringIndex >= 0 && stringIndex < fingers!.length) {
      return fingers![stringIndex];
    }
    return 0;
  }

  ChordShape copyWith({
    List<int>? frets,
    List<int>? fingers,
    int? baseFretOverride,
  }) {
    return ChordShape(
      frets ?? List<int>.from(this.frets),
      fingers ?? (this.fingers != null ? List<int>.from(this.fingers!) : null),
      baseFretOverride ?? this.baseFretOverride,
    );
  }
}
