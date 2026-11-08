import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cifras_app/modelos/musica.dart';
import 'package:cifras_app/dados/repositorio_musicas.dart';
import 'package:cifras_app/dados/repositorio_temas.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('ThemeRepository initializes with 0 themes for new user and allows CRUD', () async {
    final repo = await ThemeRepository.open();
    expect(repo.themes.isEmpty, isTrue);

    await repo.addTheme('Adoração');
    await repo.addTheme('Baião');
    expect(repo.themes.contains('Adoração'), isTrue);
    expect(repo.themes.contains('Baião'), isTrue);

    await repo.addTheme('Gospel Contemporâneo');
    expect(repo.themes.contains('Gospel Contemporâneo'), isTrue);

    final songRepo = await SongRepository.open();
    await songRepo.save(Song(
      id: 's1',
      title: 'Música 1',
      artist: 'Artista 1',
      content: 'C G',
      tags: const ['Adoração', 'Gospel Contemporâneo'],
    ));

    expect(repo.countFor('Adoração', songRepo.songs), equals(1));
    expect(repo.countFor('Baião', songRepo.songs), equals(0));

    await repo.renameTheme('Gospel Contemporâneo', 'Gospel Moderno', songRepo);
    expect(repo.themes.contains('Gospel Moderno'), isTrue);
    expect(songRepo.songs.first.tags.contains('Gospel Moderno'), isTrue);

    await repo.removeTheme('Gospel Moderno', songRepo);
    expect(repo.themes.contains('Gospel Moderno'), isFalse);
    expect(songRepo.songs.first.tags.contains('Gospel Moderno'), isFalse);
  });

  test('SongRepository tag helpers manage tags on songs', () async {
    final songRepo = await SongRepository.open();
    await songRepo.save(Song(
      id: 's2',
      title: 'Aleluia',
      artist: 'Coral',
      content: 'D A',
    ));

    await songRepo.addTagToSong('s2', 'Louvor');
    expect(songRepo.songs.firstWhere((s) => s.id == 's2').tags, contains('Louvor'));

    await songRepo.setSongTags('s2', ['Louvor', 'Aclamação', 'Final']);
    expect(songRepo.songs.firstWhere((s) => s.id == 's2').tags.length, equals(3));

    await songRepo.removeTagFromSong('s2', 'Aclamação');
    expect(songRepo.songs.firstWhere((s) => s.id == 's2').tags, isNot(contains('Aclamação')));
  });
}
