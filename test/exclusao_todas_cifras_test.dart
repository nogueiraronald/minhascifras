import 'package:cifras_app/dados/biblioteca_acordes.dart';
import 'package:cifras_app/dados/controlador_conta.dart';
import 'package:cifras_app/dados/repositorio_listas.dart';
import 'package:cifras_app/dados/repositorio_musicas.dart';
import 'package:cifras_app/dados/repositorio_temas.dart';
import 'package:cifras_app/modelos/musica.dart';
import 'package:cifras_app/servicos/recarregador_pagina.dart';
import 'package:cifras_app/servicos/servico_sincronizacao.dart';
import 'package:cifras_app/telas/tela_principal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('reloadWebPage executa sem erros na plataforma de testes', () {
    expect(() => reloadWebPage(), returnsNormally);
  });

  testWidgets('Ao apagar todas as cifras, o leitor limpa imediatamente o conteúdo antigo', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final repo = await SongRepository.open();
    final chords = await ChordLibrary.open();
    final account = await AccountController.open();
    final setlists = await SetlistRepository.open();
    final themes = await ThemeRepository.open();
    final sync = SyncService(repo, setlists, account);

    final song = Song(
      id: 'song-test-1',
      title: 'Minha Linda Canção',
      artist: 'Artista Teste',
      content: 'C          G\nLetra que não deve ser lida após apagar',
    );
    await repo.save(song);

    await tester.pumpWidget(
      MaterialApp(
        home: MainScreen(
          repository: repo,
          chords: chords,
          account: account,
          sync: sync,
          setlists: setlists,
          musicThemes: themes,
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verifica que a música estava aberta no leitor inicialmente
    expect(find.text('Minha Linda Canção'), findsAtLeastNWidgets(1));
    expect(find.textContaining('Letra que não deve ser lida'), findsOneWidget);

    // Agora apagamos todas as cifras do repositório
    await repo.removeAll();
    await setlists.removeAllItems();

    // Drena o debounce timer de sincronização e reconstrói a tela
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    // Verifica que a letra antiga NÃO é mais renderizada
    expect(find.textContaining('Letra que não deve ser lida'), findsNothing);

    // Verifica que o leitor foi resetado e exibe o estado vazio
    expect(find.text('Nenhuma música selecionada.'), findsOneWidget);
    expect(find.text('Nova Cifra'), findsAtLeastNWidgets(1));
  });
}
