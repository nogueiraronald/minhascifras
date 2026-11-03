import 'package:cifras_app/modelos/musica.dart';
import 'package:cifras_app/servicos/servico_sincronizacao.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
}
