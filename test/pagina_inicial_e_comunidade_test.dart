import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cifras_app/componentes/logo_aplicativo.dart';
import 'package:cifras_app/dados/biblioteca_acordes.dart';
import 'package:cifras_app/dados/controlador_conta.dart';
import 'package:cifras_app/dados/repositorio_listas.dart';
import 'package:cifras_app/dados/repositorio_musicas.dart';
import 'package:cifras_app/dados/repositorio_temas.dart';
import 'package:cifras_app/modelos/musica.dart';
import 'package:cifras_app/modelos/musica_comunidade.dart';
import 'package:cifras_app/servicos/dados_nuvem.dart';
import 'package:cifras_app/servicos/servico_comunidade.dart';
import 'package:cifras_app/servicos/servico_sincronizacao.dart';
import 'package:cifras_app/servicos/servico_supabase_sync.dart';
import 'package:cifras_app/telas/tela_comunidade.dart';
import 'package:cifras_app/telas/tela_inicial.dart';
import 'package:cifras_app/telas/tela_principal.dart';

class _FakeSupabaseSync extends SupabaseSyncService {
  CloudData remoteData = const CloudData();

  @override
  Future<CloudData> readAll(String syncCode) async => remoteData;

  @override
  Future<void> writeAll(String syncCode, CloudData data) async {
    remoteData = data;
  }
}

class _FakeCommunityService extends CommunityService {
  _FakeCommunityService({List<CommunitySong>? initial})
      : onlineFeed = initial ?? [];

  List<CommunitySong> onlineFeed;

  @override
  Future<List<CommunitySong>> fetchCommunitySongs() async {
    final sorted = List<CommunitySong>.of(onlineFeed)
      ..sort((a, b) => b.sharedAt.compareTo(a.sharedAt));
    return sorted;
  }

  @override
  Future<List<CommunitySong>> publishSongs({
    required List<Song> songs,
    required String nickname,
    required String email,
    String? imageUrl,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanNick = nickname.trim().replaceFirst(RegExp(r'^@+'), '');
    if (cleanEmail.isEmpty || cleanNick.isEmpty) {
      throw const FormatException('Credenciais incompletas');
    }
    final newSongs = songs
        .where(
          (s) => !isSongSharedByUser(
            song: s,
            userEmail: cleanEmail,
            communitySongs: onlineFeed,
          ),
        )
        .toList();
    if (newSongs.isEmpty) {
      throw const FormatException(
        'Esta(s) música(s) já foi(ram) compartilhada(s) por você na comunidade.',
      );
    }
    final now = DateTime(2026, 11, 8, 12, 0);
    for (var i = 0; i < newSongs.length; i++) {
      final s = newSongs[i];
      onlineFeed.insert(
        0,
        CommunitySong(
          id: 'comm_${onlineFeed.length + i + 1}',
          song: s,
          sharedByNickname: cleanNick,
          sharedByEmail: cleanEmail,
          sharedAt: now.add(Duration(minutes: i)),
          imageUrl: imageUrl,
        ),
      );
    }
    onlineFeed.sort((a, b) => b.sharedAt.compareTo(a.sharedAt));
    return List<CommunitySong>.of(onlineFeed);
  }

  @override
  Future<List<CommunitySong>> unpublishSong({
    required CommunitySong target,
    required String userEmail,
  }) async {
    final cleanEmail = userEmail.trim().toLowerCase();
    final targetKey = CommunityService.normAuthorSongKey(
      target.sharedByEmail,
      target.song.title,
      target.song.artist,
    );
    onlineFeed = onlineFeed.where((item) {
      final isOwner = item.sharedByEmail.trim().toLowerCase() == cleanEmail;
      if (!isOwner) return true;
      final itemKey = CommunityService.normAuthorSongKey(
        item.sharedByEmail,
        item.song.title,
        item.song.artist,
      );
      return !(item.id == target.id ||
          item.song.id == target.song.id ||
          itemKey == targetKey);
    }).toList()
      ..sort((a, b) => b.sharedAt.compareTo(a.sharedAt));
    return List<CommunitySong>.of(onlineFeed);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Página Inicial e Comunidade - Bateria Completa de Testes', () {
    late SongRepository repo;
    late ChordLibrary chords;
    late AccountController account;
    late SetlistRepository setlists;
    late ThemeRepository musicThemes;
    late SyncService sync;
    late _FakeSupabaseSync fakeSupabase;
    late _FakeCommunityService fakeCommunity;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      fakeSupabase = _FakeSupabaseSync();
      repo = await SongRepository.open();
      chords = await ChordLibrary.open();
      account = await AccountController.open(supabaseSync: fakeSupabase);
      setlists = await SetlistRepository.open();
      musicThemes = await ThemeRepository.open();
      sync = SyncService(repo, setlists, account, supabaseSync: fakeSupabase);

      await repo.save(
        Song(
          id: 'user_song_1',
          title: 'Minha Canção Pessoal',
          artist: 'Banda Local',
          content: 'C G Am F\nLetra da canção pessoal',
        ),
      );

      fakeCommunity = _FakeCommunityService(
        initial: [
          CommunitySong(
            id: 'c1',
            song: Song(
              id: 'cs1',
              title: 'Sublime Graça',
              artist: 'Domínio Público',
              content: 'G C G\nSublime graça do Senhor',
            ),
            sharedByNickname: 'joao_violao',
            sharedByEmail: 'joao@musica.com',
            sharedAt: DateTime(2026, 11, 7, 15, 30),
          ),
        ],
      );
    });

    Widget buildHomeApp() {
      return MaterialApp(
        home: TelaInicial(
          repository: repo,
          chords: chords,
          account: account,
          sync: sync,
          setlists: setlists,
          musicThemes: musicThemes,
          communityService: fakeCommunity,
        ),
      );
    }

    const viewports = <String, Size>{
      'Desktop 1920x1080': Size(1920, 1080),
      'Desktop 1366x768': Size(1366, 768),
      'macOS 1440x900': Size(1440, 900),
      'macOS 1280x800': Size(1280, 800),
      'iPhone 430x932': Size(430, 932),
      'iPhone 390x844': Size(390, 844),
      'iPhone 375x667': Size(375, 667),
      'Android 412x915': Size(412, 915),
      'Android 360x800': Size(360, 800),
    };

    for (final entry in viewports.entries) {
      testWidgets(
        'TelaInicial e TelaComunidade renderizam sem overflow em ${entry.key}',
        (tester) async {
          tester.view.physicalSize = entry.value;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() => tester.view.resetPhysicalSize());

          await tester.pumpWidget(buildHomeApp());
          await tester.pumpAndSettle();

          expect(find.byType(TelaInicial), findsOneWidget);
          expect(find.text('Minhas Cifras'), findsOneWidget);
          expect(find.text('Comunidade'), findsOneWidget);
          // Garante que os textos técnicos antigos foram removidos e substituídos pela divulgação elegante
          expect(find.text('Acesso Online'), findsNothing);
          expect(find.text('Carrossel de Recentes'), findsNothing);
          expect(find.text('Importação sob Demanda'), findsNothing);
          expect(tester.takeException(), isNull);

          // Navega para Comunidade
          await tester.ensureVisible(find.byKey(const ValueKey('card_comunidade')));
          await tester.tap(find.byKey(const ValueKey('card_comunidade')));
          await tester.pumpAndSettle();

          expect(find.byType(TelaComunidade), findsOneWidget);
          expect(find.text('Últimas Cifras Compartilhadas'), findsOneWidget);
          expect(find.text('Sublime Graça'), findsWidgets);
          expect(find.text('@joao_violao'), findsWidgets);
          expect(find.text('Acesso Online'), findsNothing);
          expect(find.text('Carrossel de Recentes'), findsNothing);
          expect(find.text('Importação sob Demanda'), findsNothing);
          // Verifica que BotaoVoltarInicio possui exatamente o mesmo tamanho (34x34) do ícone do AppLogo
          final backBtnSize = tester.getSize(find.byType(BotaoVoltarInicio));
          expect(backBtnSize, const Size(34, 34));
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets(
      'Card Minhas Cifras direciona para a lista de cifras do usuário (MainScreen) e permite compartilhar cifras com a Comunidade',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(buildHomeApp());
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('card_minhas_cifras')));
        await tester.pumpAndSettle();

        expect(find.byType(MainScreen), findsOneWidget);
        expect(find.text('Minha Canção Pessoal'), findsWidgets);

        // Verifica que o botão de voltar à página inicial tem o mesmo tamanho do badge do logo (34x34)
        final backBtnSize = tester.getSize(find.byType(BotaoVoltarInicio));
        expect(backBtnSize, const Size(34, 34));

        // Verifica o compartilhamento através do menu de opções (⋮) da cifra
        final moreBtn = find.byKey(ValueKey('btn_song_menu_${repo.songs.first.id}'));
        expect(moreBtn, findsOneWidget);
        await tester.tap(moreBtn);
        await tester.pumpAndSettle();

        final shareMenuItem = find.text('Compartilhar com a Comunidade');
        expect(shareMenuItem, findsOneWidget);
        await tester.tap(shareMenuItem);
        await tester.pumpAndSettle();

        // Abre a identificação na comunidade para quem ainda não está logado
        expect(find.text('Identificação na Comunidade'), findsOneWidget);
      },
    );

    testWidgets(
      'Cifras da comunidade são apenas online e só entram na lista do usuário ao importar',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(buildHomeApp());
        await tester.pumpAndSettle();

        // Antes de importar, a música da comunidade não está na lista local do usuário
        expect(repo.songs.any((s) => s.title == 'Sublime Graça'), isFalse);

        await tester.tap(find.byKey(const ValueKey('card_comunidade')));
        await tester.pumpAndSettle();

        // Mesmo abrindo a comunidade online, não baixa automaticamente para repo.songs
        expect(repo.songs.any((s) => s.title == 'Sublime Graça'), isFalse);

        // Clica em Importar no carrossel
        await tester.tap(find.text('Importar').first);
        await tester.pumpAndSettle();

        expect(repo.songs.any((s) => s.title == 'Sublime Graça'), isTrue);
      },
    );

    testWidgets(
      'Postar na comunidade exige email, senha e nickname e permite escolher músicas da lista',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(buildHomeApp());
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('card_minhas_cifras')));
        await tester.pumpAndSettle();

        // Abre o menu da cifra para compartilhar com a comunidade
        final moreBtn =
            find.byKey(ValueKey('btn_song_menu_${repo.songs.first.id}'));
        await tester.tap(moreBtn);
        await tester.pumpAndSettle();

        await tester.tap(find.text('Compartilhar com a Comunidade'));
        await tester.pumpAndSettle();

        expect(find.text('Identificação na Comunidade'), findsOneWidget);

        await tester.enterText(
          find.byKey(const ValueKey('community_auth_email')),
          'ronald@cifras.com',
        );
        await tester.enterText(
          find.byKey(const ValueKey('community_auth_password')),
          'senha123',
        );
        await tester.enterText(
          find.byKey(const ValueKey('community_auth_nickname')),
          'ronald_music',
        );

        await tester.tap(find.text('Continuar'));
        await tester.pumpAndSettle();

        expect(account.canPostToCommunity, isTrue);
        expect(account.userNickname, 'ronald_music');

        // Agora exibe o seletor de músicas do usuário para compartilhar
        expect(find.text('Compartilhar na Comunidade'), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(CheckboxListTile),
            matching: find.text('Minha Canção Pessoal'),
          ),
          findsOneWidget,
        );

        // Publica a música selecionada
        await tester.tap(find.text('Publicar (1)'));
        await tester.pumpAndSettle();

        // Tenta abrir o modal de compartilhamento novamente -> a música já compartilhada não pode ser marcada de novo
        await tester.tap(moreBtn);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Compartilhar com a Comunidade'));
        await tester.pumpAndSettle();

        expect(
          find.textContaining('Já compartilhada na comunidade'),
          findsOneWidget,
        );
        expect(find.byType(CheckboxListTile), findsNothing);

        // Remove do compartilhamento pelo próprio modal
        await tester.tap(
          find.byKey(const ValueKey('btn_dialog_unshare_user_song_1')),
        );
        await tester.pumpAndSettle();

        expect(find.textContaining('Já compartilhada na comunidade'), findsNothing);
        expect(find.byType(CheckboxListTile), findsOneWidget);
      },
    );

    testWidgets(
      'Carrossel limita a 10 itens, exibe 2 por vez em telas pequenas e 4 por vez em telas grandes, e remover da comunidade mantém a cifra importada',
      (tester) async {
        // Alimenta a comunidade com 14 músicas compartilhadas
        fakeCommunity.onlineFeed = List.generate(
          14,
          (i) => CommunitySong(
            id: 'item_$i',
            song: Song(
              id: 's_$i',
              title: 'Cifra Comunitária $i',
              artist: 'Artista $i',
              content: 'C G Am F',
            ),
            sharedByNickname: 'autor_$i',
            sharedByEmail: 'autor$i@musica.com',
            sharedAt: DateTime(2026, 11, 8, 10, i),
          ),
        );

        // 1) Tela grande (1280x800): 4 por vez -> 10 itens geram 3 páginas (1/3)
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(buildHomeApp());
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('card_comunidade')));
        await tester.pumpAndSettle();

        expect(find.text('1/3'), findsOneWidget);

        // Importa uma música da comunidade para a lista pessoal do usuário
        final targetComm = fakeCommunity.onlineFeed.first;
        await fakeCommunity.importSongToUserList(
          communitySong: targetComm,
          repository: repo,
        );
        expect(
          repo.songs.any((s) => s.title == targetComm.song.title),
          isTrue,
        );

        // O autor remove a música do compartilhamento na comunidade
        await fakeCommunity.unpublishSong(
          target: targetComm,
          userEmail: targetComm.sharedByEmail,
        );

        // Sai da exibição da comunidade, mas se mantém intacta na lista pessoal de quem já importou
        expect(
          fakeCommunity.onlineFeed.any((c) => c.id == targetComm.id),
          isFalse,
        );
        expect(
          repo.songs.any((s) => s.title == targetComm.song.title),
          isTrue,
        );

        // 2) Tela pequena (390x844): 2 por vez -> 10 itens geram 5 páginas (1/5)
        tester.view.physicalSize = const Size(390, 844);
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.refresh_rounded));
        await tester.pumpAndSettle();

        expect(find.text('1/5'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    test('AccountController valida canPostToCommunity com email, senha e nickname', () async {
      final passHash = sha256.convert(utf8.encode('123456')).toString();
      fakeSupabase.remoteData = CloudData(passwordHash: passHash);

      expect(account.canPostToCommunity, isFalse);

      await account.loginWithEmailAndPassword(
        emailInput: 'autor@comunidade.com',
        passwordInput: '123456',
        nicknameInput: '@autor_top',
      );

      expect(account.isLoggedIn, isTrue);
      expect(account.isPasswordProtected, isTrue);
      expect(account.userNickname, 'autor_top');
      expect(account.canPostToCommunity, isTrue);
    });

    testWidgets(
      'Comunidade agrupa músicas por artista em ordem alfabética e lista músicas em ordem alfabética',
      (tester) async {
        final mockSongs = [
          CommunitySong(
            id: 'c1',
            song: Song(id: 's1', title: 'Zeloso Amor', artist: 'Banda B', content: 'C G\nLetra'),
            sharedByNickname: 'user1',
            sharedByEmail: 'u1@test.com',
            sharedAt: DateTime(2026, 11, 1),
          ),
          CommunitySong(
            id: 'c2',
            song: Song(id: 's2', title: 'Águas Claras', artist: 'Banda B', content: 'C G\nLetra'),
            sharedByNickname: 'user1',
            sharedByEmail: 'u1@test.com',
            sharedAt: DateTime(2026, 11, 2),
          ),
          CommunitySong(
            id: 'c3',
            song: Song(id: 's3', title: 'Bendito Seja', artist: 'Artista A', content: 'C G\nLetra'),
            sharedByNickname: 'user2',
            sharedByEmail: 'u2@test.com',
            sharedAt: DateTime(2026, 11, 3),
          ),
        ];

        final community = _FakeCommunityService(initial: mockSongs);

        await tester.pumpWidget(
          MaterialApp(
            home: TelaComunidade(
              repository: repo,
              chords: chords,
              account: account,
              sync: sync,
              setlists: setlists,
              communityService: community,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Verifica que os artistas aparecem como cabeçalhos de grupos
        expect(find.text('Artista A'), findsWidgets);
        expect(find.text('Banda B'), findsWidgets);

        // Verifica a contagem de cifras por artista
        expect(find.text('1 cifra'), findsOneWidget); // Artista A
        expect(find.text('2 cifras'), findsOneWidget); // Banda B

        // Músicas estão visíveis (tanto no carrossel quanto nos grupos de artista)
        expect(find.text('Bendito Seja'), findsWidgets);
        expect(find.text('Águas Claras'), findsWidgets);
        expect(find.text('Zeloso Amor'), findsWidgets);
      },
    );

    testWidgets(
      'Autocomplete no TextField exibe sugestões de artistas e músicas e permite filtrar ao clicar',
      (tester) async {
        final mockSongs = [
          CommunitySong(
            id: 'c1',
            song: Song(id: 's1', title: 'A Barca', artist: 'Padre Zezinho', content: 'C G\nLetra'),
            sharedByNickname: 'user1',
            sharedByEmail: 'u1@test.com',
            sharedAt: DateTime(2026, 11, 1),
          ),
          CommunitySong(
            id: 'c2',
            song: Song(id: 's2', title: 'Oração Pela Família', artist: 'Padre Zezinho', content: 'C G\nLetra'),
            sharedByNickname: 'user1',
            sharedByEmail: 'u1@test.com',
            sharedAt: DateTime(2026, 11, 2),
          ),
        ];

        final community = _FakeCommunityService(initial: mockSongs);

        await tester.pumpWidget(
          MaterialApp(
            home: TelaComunidade(
              repository: repo,
              chords: chords,
              account: account,
              sync: sync,
              setlists: setlists,
              communityService: community,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Digita "padre" no campo de busca
        final searchField = find.byType(TextField);
        await tester.enterText(searchField, 'padre');
        await tester.pumpAndSettle();

        // Painel de sugestões deve aparecer sugerindo o Artista
        expect(find.text('Sugestões de busca:'), findsOneWidget);
        expect(find.byKey(const ValueKey('suggestion_artist_Padre Zezinho')), findsOneWidget);

        // Ao tocar na sugestão, preenche a busca e filtra
        await tester.tap(find.byKey(const ValueKey('suggestion_artist_Padre Zezinho')));
        await tester.pumpAndSettle();

        expect(find.text('Padre Zezinho'), findsWidgets);
      },
    );

    testWidgets(
      'Paginação na comunidade divide grupos de artistas e permite navegar entre páginas',
      (tester) async {
        // Criar 7 artistas diferentes (cada página exibe até 5 artistas)
        final mockSongs = List.generate(
          7,
          (i) => CommunitySong(
            id: 'comm_$i',
            song: Song(
              id: 'song_$i',
              title: 'Música $i',
              artist: 'Artista ${String.fromCharCode(65 + i)}',
              content: 'C G\nLetra $i',
            ),
            sharedByNickname: 'user',
            sharedByEmail: 'user@test.com',
            sharedAt: DateTime(2026, 11, i + 1),
          ),
        );

        final community = _FakeCommunityService(initial: mockSongs);

        await tester.pumpWidget(
          MaterialApp(
            home: TelaComunidade(
              repository: repo,
              chords: chords,
              account: account,
              sync: sync,
              setlists: setlists,
              communityService: community,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 7 artistas / 5 por página -> 2 páginas (1 / 2)
        expect(find.text('1 / 2'), findsWidgets);

        // Clica para ir para a próxima página
        final nextBtn = find.byKey(const ValueKey('btn_community_next_page')).first;
        await tester.tap(nextBtn);
        await tester.pumpAndSettle();

        // Agora está na página 2 / 2
        expect(find.text('2 / 2'), findsWidgets);

        // Clica para voltar para a página anterior
        final prevBtn = find.byKey(const ValueKey('btn_community_prev_page')).first;
        await tester.tap(prevBtn);
        await tester.pumpAndSettle();

        expect(find.text('1 / 2'), findsWidgets);
      },
    );

    testWidgets(
      'Navegação mobile: voltar de Minhas Cifras retorna à Tela Inicial',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          MaterialApp(
            home: TelaInicial(
              repository: repo,
              chords: chords,
              account: account,
              sync: sync,
              setlists: setlists,
              musicThemes: musicThemes,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Clica no card "Minhas Cifras"
        await tester.tap(find.text('Minhas Cifras'));
        await tester.pumpAndSettle();

        // Está dentro de Minhas Cifras (MainScreen)
        expect(find.byKey(const ValueKey('app_main_scaffold')), findsOneWidget);

        // No celular, clica no botão voltar ao início na AppBar
        final backBtn = find.byTooltip('Voltar ao Início');
        expect(backBtn, findsOneWidget);
        await tester.tap(backBtn);
        await tester.pumpAndSettle();

        // Retornou para a TelaInicial com sucesso
        expect(find.byKey(const ValueKey('home_screen_scaffold')), findsOneWidget);
        expect(find.text('Comunidade'), findsOneWidget);
      },
    );
  });
}

