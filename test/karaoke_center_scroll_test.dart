import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cifras_app/componentes/visualizador_cifra.dart';
import 'package:cifras_app/componentes/visualizador_letra.dart';

void main() {
  const songContent = '''[Intro] C G Am F

C            G
Primeira estrofe da canção
Am           F
Segunda linha da estrofe

C            G
Refrão cantado com alegria
Am           F
Última linha da música inteira''';

  testWidgets('ChordSheetView centraliza linha ativa com padding inferior para última linha', (tester) async {
    final scrollController = ScrollController();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 600,
            width: 400,
            child: ChordSheetView(
              content: songContent,
              transpose: 0,
              fontSize: 16,
              controller: scrollController,
              activeLineIndex: 6, // 'Am           F' antes da última linha
              onChordTap: (_) {},
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verifica se a ListView foi renderizada com sucesso
    final listView = tester.widget<ListView>(find.byType(ListView));
    expect(listView.padding, isNotNull);
    final edgeInsets = listView.padding as EdgeInsets;
    // O padding inferior deve ser generoso (>= 420) para permitir que a última linha suba até o meio da tela
    expect(edgeInsets.bottom, greaterThanOrEqualTo(420.0));
  });

  testWidgets('LyricsView centraliza linha ativa com padding inferior para última linha', (tester) async {
    final scrollController = ScrollController();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 600,
            width: 400,
            child: LyricsView(
              content: songContent,
              fontSize: 16,
              controller: scrollController,
              activeLineIndex: 7, // 'Última linha da música inteira'
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final listView = tester.widget<ListView>(find.byType(ListView));
    expect(listView.padding, isNotNull);
    final edgeInsets = listView.padding as EdgeInsets;
    expect(edgeInsets.bottom, greaterThanOrEqualTo(420.0));
    expect(find.text('Última linha da música inteira'), findsOneWidget);
  });
}
