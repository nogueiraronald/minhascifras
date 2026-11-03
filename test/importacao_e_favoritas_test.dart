import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cifras_app/modelos/musica.dart';
import 'package:cifras_app/dados/repositorio_musicas.dart';
import 'package:cifras_app/dados/repositorio_listas.dart';
import 'package:cifras_app/modelos/lista_repertorio.dart';
import 'package:cifras_app/servicos/servico_importacao_cifra.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Song serialization includes isFavorite', () {
    final s1 = Song(
      id: '1',
      title: 'Raridade',
      artist: 'Anderson Freire',
      content: 'C G Am F',
      isFavorite: true,
    );
    final json = s1.toJson();
    expect(json['isFavorite'], isTrue);

    final s2 = Song.fromJson(json);
    expect(s2.isFavorite, isTrue);

    final s3 = s2.copyWith(isFavorite: false);
    expect(s3.isFavorite, isFalse);
  });

  test('SongRepository toggleFavorite and removeAll', () async {
    SharedPreferences.setMockInitialValues({});
    final repo = await SongRepository.open();
    final setlists = await SetlistRepository.open();

    await repo.save(Song(id: 's1', title: 'Aclame ao Senhor', content: 'G D Em C'));
    await repo.save(Song(id: 's2', title: 'Bondade de Deus', content: 'C F G'));

    expect(repo.songs.length, 2);
    expect(repo.songs.first.isFavorite, isFalse);

    await repo.toggleFavorite('s1');
    expect(repo.songs.firstWhere((s) => s.id == 's1').isFavorite, isTrue);

    await repo.toggleFavorite('s1');
    expect(repo.songs.firstWhere((s) => s.id == 's1').isFavorite, isFalse);

    // Setlist items
    final list = Setlist(id: 'l1', name: 'Domingo');
    await setlists.saveSetlist(list);
    await setlists.addSongs('l1', ['s1', 's2']);
    expect(setlists.itemsFor('l1').length, 2);

    // Remove all
    await repo.removeAll();
    await setlists.removeAllItems();

    expect(repo.songs, isEmpty);
    expect(setlists.itemsFor('l1'), isEmpty);
  });

  test('CifraImportService.extractMetadata extracts title and artist from content and removes sequencer', () {
    const content = '''
A Alegria
Antiga Evangélica
G    G7    C    G
A alegria está no coração de quem já conhece a Jesus.
''';

    final meta = CifraImportService.extractMetadata(
      content: content,
      rawFileName: '001_A Alegria_Antiga Evangélica.txt',
    );

    expect(meta.title, 'A Alegria');
    expect(meta.artist, 'Antiga Evangélica');
    expect(meta.originalKey, 'G');
  });

  test('SongRepository.sanitizeSongMetadata fixes existing songs with sequentials in title', () async {
    SharedPreferences.setMockInitialValues({});
    final repo = await SongRepository.open();

    const content = '''
A Alegria
Antiga Evangélica
G    G7    C    G
A alegria está no coração.
''';

    await repo.save(Song(
      id: 'song1',
      title: '001_A Alegria_Antiga Evangélica',
      artist: '',
      content: content,
    ));

    expect(repo.songs.first.title, '001_A Alegria_Antiga Evangélica');

    final updated = await repo.sanitizeSongMetadata();
    expect(updated, 1);

    final cleaned = repo.songs.firstWhere((s) => s.id == 'song1');
    expect(cleaned.title, 'A Alegria');
    expect(cleaned.artist, 'Antiga Evangélica');
  });
}
