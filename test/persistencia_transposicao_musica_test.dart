import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cifras_app/modelos/musica.dart';
import 'package:cifras_app/dados/repositorio_musicas.dart';
import 'package:cifras_app/servicos/transpositor_acordes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('ChordTransposer transposes Tom: line as well as chords', () {
    const raw = '''
Tom: G

[Intro] G  D  Em  C

G
Eu sei que tudo é Teu
''';

    final transposed = ChordTransposer.transposeContent(raw, 2);
    expect(transposed.contains('Tom: A'), isTrue);
    expect(transposed.contains('A  E  F#m  D'), isTrue);
    expect(ChordTransposer.detectKey(transposed), equals('A'));
  });

  test('SongRepository persists transposed content and triggers onLocalChange', () async {
    SharedPreferences.setMockInitialValues({});
    final repo = await SongRepository.open();

    bool cloudSyncTriggered = false;
    repo.onLocalChange = () {
      cloudSyncTriggered = true;
    };

    final song = Song(
      id: 's1',
      title: 'Minha Canção',
      artist: 'Cantor',
      originalKey: 'G',
      content: 'Tom: G\n\nG  C  D\nLinha de letra\n',
    );
    await repo.save(song);
    cloudSyncTriggered = false;

    // Simula a mudança de tom permanente (+2 semitons, G -> A)
    final newContent = ChordTransposer.transposeContent(song.content, 2);
    final newKey = ChordTransposer.detectKey(newContent) ?? 'A';
    final updated = song.copyWith(
      content: newContent,
      originalKey: newKey,
    );
    await repo.save(updated);

    expect(cloudSyncTriggered, isTrue);
    final saved = repo.songs.firstWhere((s) => s.id == 's1');
    expect(saved.content.contains('Tom: A'), isTrue);
    expect(saved.content.contains('A  D  E'), isTrue);
    expect(saved.originalKey, equals('A'));
  });
}
