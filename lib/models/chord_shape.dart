import 'dart:math';

/// Desenho de um acorde: 6 valores (corda 6 -> 1). -1 = muda, 0 = solta.
class ChordShape {
  const ChordShape(this.frets);

  final List<int> frets;

  /// Aceita "x,3,2,0,1,0" ou "x32010". Retorna null se inválido.
  static ChordShape? parse(String text) {
    final t = text.trim().toLowerCase();
    if (t.isEmpty) return null;
    final parts = t.contains(',')
        ? t.split(',').map((e) => e.trim()).toList()
        : t.split('');
    if (parts.length != 6) return null;
    final frets = <int>[];
    for (final p in parts) {
      final v = p == 'x' ? -1 : int.tryParse(p);
      if (v == null || v > 24) return null;
      frets.add(v);
    }
    return ChordShape(frets);
  }

  String toText() => frets.map((f) => f < 0 ? 'x' : '$f').join(',');

  int get baseFret {
    final pressed = frets.where((f) => f > 0);
    if (pressed.isEmpty) return 1;
    if (pressed.reduce(max) <= 5) return 1;
    return pressed.reduce(min);
  }
}
