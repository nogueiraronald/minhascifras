import 'package:cifras_app/configuracao/configuracao_app.dart';
import 'package:cifras_app/modelos/formato_acorde.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ChordShape parses frets and fingers correctly', () {
    final shape = ChordShape.parse('x,3,2,0,1,0;0,3,2,0,1,0');
    expect(shape, isNotNull);
    expect(shape!.frets, equals([-1, 3, 2, 0, 1, 0]));
    expect(shape.fingers, equals([0, 3, 2, 0, 1, 0]));
    expect(shape.fingerFor(1), equals(3)); // Corda 5 = dedo 3
    expect(shape.fingerFor(4), equals(1)); // Corda 2 = dedo 1
    expect(shape.toText(), equals('x,3,2,0,1,0;0,3,2,0,1,0'));
  });

  test('ChordShape backwards compatibility without fingers', () {
    final shape = ChordShape.parse('x,3,2,0,1,0');
    expect(shape, isNotNull);
    expect(shape!.frets, equals([-1, 3, 2, 0, 1, 0]));
    expect(shape.fingerFor(0), equals(0));
    expect(shape.toText(), equals('x,3,2,0,1,0'));
  });

  test('ChordShape calculates baseFret for G#m correctly at fret 4', () {
    final gSharpMinor = ChordShape.parse('4,6,6,4,4,4;1,3,4,1,1,1');
    expect(gSharpMinor, isNotNull);
    expect(gSharpMinor!.baseFret, equals(4));

    final parsedWithOverride = ChordShape.parse('4,6,6,4,4,4;1,3,4,1,1,1;4');
    expect(parsedWithOverride, isNotNull);
    expect(parsedWithOverride!.baseFret, equals(4));
    expect(parsedWithOverride.baseFretOverride, equals(4));
    expect(parsedWithOverride.toText(), equals('4,6,6,4,4,4;1,3,4,1,1,1;4'));
  });

  test('AppConfig contains required Supabase credentials', () {
    expect(AppConfig.supabaseUrl, contains('supabase.co'));
    expect(AppConfig.supabaseAnonKey.isNotEmpty, isTrue);
  });
}
