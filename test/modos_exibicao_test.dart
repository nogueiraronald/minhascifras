import 'package:cifras_app/componentes/visualizador_letra.dart';
import 'package:cifras_app/componentes/visualizador_partitura.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const testSongContent = '''
[Intro] C  G  Am  F

C            G
A alegria está no coração
Am           F
De quem já conhece a Jesus
''';

  group('LyricsView', () {
    testWidgets('renders lyrics and section markers without displaying chords', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LyricsView(
              content: testSongContent,
              fontSize: 16,
            ),
          ),
        ),
      );

      // Marcador de seção é mantido
      expect(find.text('[Intro]'), findsOneWidget);

      // Letras são exibidas
      expect(find.text('A alegria está no coração'), findsOneWidget);
      expect(find.text('De quem já conhece a Jesus'), findsOneWidget);

      // Acordes puros não devem aparecer como linhas de texto
      expect(find.text('C  G  Am  F'), findsNothing);
      expect(find.text('C            G'), findsNothing);
    });
  });

  group('ScoreSheetView', () {
    testWidgets('renders musical staff with clef, chords and measures', (tester) async {
      String? tappedChord;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ScoreSheetView(
              content: testSongContent,
              transpose: 0,
              fontSize: 16,
              onChordTap: (chord) => tappedChord = chord,
            ),
          ),
        ),
      );

      // Os acordes aparecem na partitura
      expect(find.text('C'), findsWidgets);
      expect(find.text('G'), findsWidgets);
      expect(find.text('Am'), findsWidgets);
      expect(find.text('F'), findsWidgets);

      // Clicar no acorde aciona o callback
      await tester.tap(find.text('Am').first);
      expect(tappedChord, 'Am');
    });

    testWidgets('transposition updates chord notes in score sheet', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ScoreSheetView(
              content: testSongContent,
              transpose: 2, // C -> D, G -> A, Am -> Bm, F -> G
              fontSize: 16,
              onChordTap: (_) {},
            ),
          ),
        ),
      );

      // C transposto +2 semitons vira D
      expect(find.text('D'), findsWidgets);
      expect(find.text('A'), findsWidgets);
      expect(find.text('Bm'), findsWidgets);
    });
  });

  group('Offline Preferences Persistence', () {
    test('persists and restores reader font size, speed and display mode offline', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      // Salva preferências offline
      await prefs.setDouble('user_reader_font_size_v1', 22.0);
      await prefs.setDouble('user_reader_scroll_speed_v1', 45.0);
      await prefs.setString('user_reader_display_mode_v1', 'score');

      // Recupera preferências
      final restoredFontSize = prefs.getDouble('user_reader_font_size_v1');
      final restoredSpeed = prefs.getDouble('user_reader_scroll_speed_v1');
      final restoredMode = prefs.getString('user_reader_display_mode_v1');

      expect(restoredFontSize, 22.0);
      expect(restoredSpeed, 45.0);
      expect(restoredMode, 'score');
    });
  });
}
