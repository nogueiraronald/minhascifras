import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cifras_app/dados/biblioteca_acordes.dart';
import 'package:cifras_app/dados/repositorio_musicas.dart';
import 'package:cifras_app/dados/repositorio_temas.dart';
import 'package:cifras_app/dados/repositorio_listas.dart';
import 'package:cifras_app/dados/controlador_conta.dart';
import 'package:cifras_app/servicos/servico_sincronizacao.dart';
import 'package:cifras_app/servicos/servico_supabase_sync.dart';
import 'package:cifras_app/servicos/servico_pedal_bridge.dart';
import 'package:cifras_app/telas/tela_principal.dart';
import 'package:cifras_app/modelos/musica.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Exclusão Total de Temas e Persistência', () {
    test('ThemeRepository.clearAll limpa temas, remove tags de músicas e seta isExplicitlyCleared', () async {
      final songRepo = await SongRepository.open();
      final themeRepo = await ThemeRepository.open();

      await songRepo.save(Song(
        id: 'song1',
        title: 'Música 1',
        artist: 'Artista 1',
        content: 'Letra com cifra',
        tags: ['Adoração', 'Louvor'],
        updatedAt: DateTime.now(),
      ));

      await themeRepo.addTheme('Adoração');
      await themeRepo.addTheme('Louvor');
      expect(themeRepo.themes.length, 2);
      expect(themeRepo.isExplicitlyCleared, false);
      expect(songRepo.songs.first.tags, contains('Adoração'));

      // Executa exclusão total de temas
      await themeRepo.clearAll(songRepo);

      expect(themeRepo.themes, isEmpty);
      expect(themeRepo.isExplicitlyCleared, true);
      expect(songRepo.songs.first.tags, isEmpty);
      expect(themeRepo.hasPendingChanges, true);

      // Reabrindo o repositório deve manter isExplicitlyCleared = true
      final reloadedRepo = await ThemeRepository.open();
      expect(reloadedRepo.themes, isEmpty);
      expect(reloadedRepo.isExplicitlyCleared, true);
    });
  });

  group('Ponte de Pedal Bluetooth e Pilha de Listeners', () {
    test('Registrar e desregistrar listeners respeita a ordem de pilha', () {
      final events = <String>[];
      void listenerPrincipal(String action) => events.add('principal:$action');
      void listenerComunidade(String action) => events.add('comunidade:$action');

      ServicoPedalBridge.registrar(listenerPrincipal);
      ServicoPedalBridge.registrar(listenerComunidade);

      // Ao fechar a comunidade, desregistra apenas o da comunidade
      ServicoPedalBridge.desregistrar(listenerComunidade);

      // O listener principal permanece registrado
      ServicoPedalBridge.desregistrar(listenerPrincipal);
    });
  });

  group('UI: Botão de Atualização e Exclusão Total de Temas', () {
    testWidgets('Barra de ações da cifra NÃO possui botão de atualização duplicado', (tester) async {
      final songRepo = await SongRepository.open();
      final themeRepo = await ThemeRepository.open();
      final setlistsRepo = await SetlistRepository.open();
      final chordsRepo = await ChordLibrary.open();
      final account = await AccountController.open();
      final sync = SyncService(songRepo, setlistsRepo, account,
          musicThemes: themeRepo, supabaseSync: SupabaseSyncService());

      await songRepo.save(Song(
        id: 's1',
        title: 'A Barca',
        artist: 'Padre Zezinho',
        content: 'Tu te abeiraste da praia...',
        updatedAt: DateTime.now(),
      ));

      await tester.binding.setSurfaceSize(const Size(1366, 768));

      await tester.pumpWidget(
        MaterialApp(
          home: MainScreen(
            repository: songRepo,
            musicThemes: themeRepo,
            setlists: setlistsRepo,
            chords: chordsRepo,
            account: account,
            sync: sync,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // O leitor de música está aberto com "A Barca"
      expect(find.text('A Barca'), findsWidgets);

      // Procurar botões com tooltip "Verificar Atualizações do App"
      // Deve haver exatamente 1 botão no aplicativo inteiro (no cabeçalho da sidebar), e NENHUM na barra de ações da cifra
      final updateButtons = find.byTooltip('Verificar Atualizações do App');
      expect(updateButtons, findsOneWidget);
    });

    testWidgets('Aba de temas exibe botões de Excluir Todos os Temas', (tester) async {
      final songRepo = await SongRepository.open();
      final themeRepo = await ThemeRepository.open();
      final setlistsRepo = await SetlistRepository.open();
      final chordsRepo = await ChordLibrary.open();
      final account = await AccountController.open();
      final sync = SyncService(songRepo, setlistsRepo, account,
          musicThemes: themeRepo, supabaseSync: SupabaseSyncService());

      await themeRepo.addTheme('Adoração');
      await themeRepo.addTheme('Louvor');

      await tester.binding.setSurfaceSize(const Size(1366, 768));

      await tester.pumpWidget(
        MaterialApp(
          home: MainScreen(
            repository: songRepo,
            musicThemes: themeRepo,
            setlists: setlistsRepo,
            chords: chordsRepo,
            account: account,
            sync: sync,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Alterna para a aba Temas (aba 3 / 'Temas (2)')
      final tabTemas = find.textContaining('Temas (2)');
      expect(tabTemas, findsOneWidget);
      await tester.tap(tabTemas);
      await tester.pumpAndSettle();

      // Botão no cabeçalho e botão no rodapé
      final btnExcluirTodos = find.byTooltip('Excluir Todos os Temas');
      expect(btnExcluirTodos, findsNWidgets(2));

      // Clica no botão de excluir todos os temas
      await tester.tap(btnExcluirTodos.first);
      await tester.pumpAndSettle();

      // Diálogo de confirmação deve aparecer
      expect(find.text('Excluir Todos os Temas'), findsWidgets);
      expect(find.textContaining('Tem certeza que deseja excluir permanentemente todos os temas'), findsOneWidget);

      // Confirma a exclusão no diálogo
      final confirmButton = find.text('Excluir Todos');
      expect(confirmButton, findsOneWidget);
      await tester.tap(confirmButton);
      await tester.pumpAndSettle();

      // Temas devem estar vazios
      expect(themeRepo.themes, isEmpty);
      expect(themeRepo.isExplicitlyCleared, true);
    });
  });
}
