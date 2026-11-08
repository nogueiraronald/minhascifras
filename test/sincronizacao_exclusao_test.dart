import 'package:cifras_app/dados/repositorio_musicas.dart';
import 'package:cifras_app/modelos/musica.dart';
import 'package:cifras_app/servicos/servico_sincronizacao.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('SyncService identifies locally deleted songs and triggers push to remove from cloud', () {
    final remoteSongs = [
      Song(id: 's1', title: 'Alívio', artist: 'Jesse Aguiar', content: 'C G'),
      Song(id: 's2', title: 'Me Ama', artist: 'Diante do Trono', content: 'Am F'),
    ];

    // Localmente, o usuário excluiu 's1' (deleted: true)
    final localSongs = [
      Song(id: 's1', title: 'Alívio', artist: 'Jesse Aguiar', content: 'C G', deleted: true),
      Song(id: 's2', title: 'Me Ama', artist: 'Diante do Trono', content: 'Am F'),
    ];

    final (pull, push, idMap) = SyncService.deduplicateAndMergeSongsForTesting(
      remoteSongs,
      localSongs,
      const [],
    );

    // s1 não deve ser baixada (pull)
    expect(pull.any((s) => s.id == 's1'), isFalse);
    // push deve ser true para que a nuvem seja regravada sem a linha da música excluída
    expect(push, isTrue);
  });

  test('SyncService não re-envia para a nuvem música que foi excluída por outro aparelho via deletedSongKeys', () {
    final timestamp = DateTime(2026, 1, 1);
    // Na nuvem a música 'Alívio' foi excluída pelo aparelho A e agora só existe 'Me Ama'
    final remoteSongs = [
      Song(id: 's2_remota', title: 'Me Ama', artist: 'Diante do Trono', content: 'Am F', updatedAt: timestamp),
    ];
    final remoteDeletedKeys = ['alívio|jesse aguiar'];

    // No aparelho B, a música 'Alívio' tinha um ID local diferente ('s1_aparelho_b')
    final localSongs = [
      Song(id: 's1_aparelho_b', title: 'Alívio', artist: 'Jesse Aguiar', content: 'C G', updatedAt: timestamp),
      Song(id: 's2_local', title: 'Me Ama', artist: 'Diante do Trono', content: 'Am F', updatedAt: timestamp),
    ];

    final (pull, push, idMap) = SyncService.deduplicateAndMergeSongsForTesting(
      remoteSongs,
      localSongs,
      const [],
      remoteDeletedKeys,
    );

    // O aparelho B não deve forçar push para re-enviar a música excluída
    expect(push, isFalse);
    expect(pull.any((s) => s.title == 'Alívio'), isFalse);
  });

  test('SongRepository saveAll não duplica músicas com mesmo título e artista', () async {
    SharedPreferences.setMockInitialValues({});
    final repo = await SongRepository.open();

    final m1 = Song(id: 'id-1', title: 'Raridade', artist: 'Anderson Freire', content: 'C G');
    await repo.save(m1);
    expect(repo.songs.length, 1);

    // Importando a mesma música novamente com ID diferente (ex: vindo de arquivo repetido)
    final m2 = Song(id: 'id-2', title: 'Raridade', artist: 'Anderson Freire', content: 'C G Am');
    await repo.saveAll([m2]);

    // Não deve duplicar na lista de músicas ativas
    expect(repo.songs.length, 1);
    expect(repo.songs.first.content, 'C G Am');
  });

  test('SongRepository.save reativa música previamente excluída', () async {
    SharedPreferences.setMockInitialValues({});
    final repo = await SongRepository.open();

    final m1 = Song(id: 'id-del', title: 'Ó Luz do Senhor', artist: 'Padre Zezinho', content: 'D A');
    await repo.save(m1);
    expect(repo.songs.length, 1);

    await repo.remove('id-del');
    expect(repo.songs.length, 0);

    // O usuário importa da comunidade a mesma música com novo ID
    final mImportada = Song(
      id: 'id-novo-uuid',
      title: 'Ó Luz do Senhor',
      artist: 'Padre Zezinho',
      content: 'D A Bm G',
      updatedAt: DateTime.now(),
    );
    await repo.save(mImportada);

    // A música deve voltar ativa
    expect(repo.songs.length, 1);
    expect(repo.songs.first.title, 'Ó Luz do Senhor');
    expect(repo.songs.first.deleted, isFalse);
    expect(repo.songs.first.content, 'D A Bm G');
  });

  test('SyncService ressuscita música recentemente importada mesmo que remoteDeletedKeys a contenha', () {
    final remoteSongs = <Song>[];
    final remoteDeletedKeys = ['ó luz do senhor|padre zezinho'];

    final localRecentSong = Song(
      id: 's_recente',
      title: 'Ó Luz do Senhor',
      artist: 'Padre Zezinho',
      content: 'D A Bm G',
      updatedAt: DateTime.now(),
    );

    final (pull, push, idMap) = SyncService.deduplicateAndMergeSongsForTesting(
      remoteSongs,
      [localRecentSong],
      const [],
      remoteDeletedKeys,
    );

    // Como foi importada/criada nos últimos 15 min, deve disparar push para revogar na nuvem
    expect(push, isTrue);
  });
}
