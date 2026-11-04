import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cifras_app/servicos/servico_atualizacao_pwa.dart';

void main() {
  testWidgets('ServicoAtualizacaoPwa.verificarAtualizacao executa sem erros e exibe SnackBar',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => ServicoAtualizacaoPwa.verificarAtualizacao(context),
              child: const Text('Checar Atualizações'),
            ),
          ),
        ),
      ),
    );

    // Clica no botão para disparar a verificação de atualizações
    await tester.tap(find.text('Checar Atualizações'));
    await tester.pump();

    // Deve exibir feedback visual ao usuário
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.textContaining('Minhas Cifras'), findsOneWidget);
  });
}
