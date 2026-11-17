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

  testWidgets('Ao clicar na letra D na coluna alfabética, a 1ª música da letra D fica visível e em destaque no topo da barra lateral', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final repo = await SongRepository.open();
    final chords = await ChordLibrary.open();
    final account = await AccountController.open();
    final setlists = await SetlistRepository.open();
    final themes = await ThemeRepository.open();
    final sync = SyncService(repo, setlists, account);

    final songsToSave = <Song>[];
    // Cria 15 músicas com A, B e C (para empurrar D e T para fora da janela inicial da barra lateral)
    for (int i = 1; i <= 6; i++) {
      songsToSave.add(Song(id: 'a-$i', title: 'Amor $i', artist: 'Artista A', content: 'C G'));
    }
    for (int i = 1; i <= 6; i++) {
      songsToSave.add(Song(id: 'b-$i', title: 'Bendito $i', artist: 'Artista B', content: 'D A'));
    }
    for (int i = 1; i <= 6; i++) {
      songsToSave.add(Song(id: 'c-$i', title: 'Canto $i', artist: 'Artista C', content: 'E B'));
    }
    songsToSave.add(Song(id: 'd-1', title: 'Deus Está Aqui', artist: 'Artista D', content: 'F C'));
    songsToSave.add(Song(id: 'd-2', title: 'Doce Presença', artist: 'Artista D', content: 'G D'));
    songsToSave.add(Song(id: 't-1', title: 'Tua Graça Me Basta', artist: 'Artista T', content: 'A E'));
    songsToSave.add(Song(id: 't-2', title: 'Tudo Entregarei', artist: 'Artista T', content: 'C G'));
    await repo.saveAll(songsToSave);

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

    // Clica na letra 'D' na coluna alfabética lateral
    final letterD = find.text('D').last;
    await tester.tap(letterD);
    await tester.pumpAndSettle(const Duration(milliseconds: 800));

    // A primeira música da letra D ('Deus Está Aqui') deve estar visível e destacada na barra lateral
    final dItemFinder = find.byKey(const ValueKey('sidebar_song_d-1'));
    expect(dItemFinder, findsOneWidget);

    // Agora pula para a letra 'T'
    final letterT = find.text('T').last;
    await tester.tap(letterT);
    await tester.pumpAndSettle(const Duration(milliseconds: 800));

    expect(find.byKey(const ValueKey('sidebar_song_t-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('sidebar_song_t-2')), findsOneWidget);

    // Exclui a primeira música da letra T ('Tua Graça Me Basta') pelo menu da barra lateral
    await tester.tap(find.byKey(const ValueKey('btn_song_menu_t-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Excluir cifra da biblioteca'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Excluir'));
    await tester.pumpAndSettle(const Duration(milliseconds: 600));

    // A lista NÃO deve voltar para a letra A! Deve continuar na letra T exibindo 'Tudo Entregarei'
    expect(find.byKey(const ValueKey('sidebar_song_t-2')), findsOneWidget);
    expect(find.text('Tudo Entregarei'), findsAtLeastNWidgets(2)); // Na barra lateral e no leitor
    expect(find.byKey(const ValueKey('sidebar_song_a-1')), findsNothing);
  });
}
