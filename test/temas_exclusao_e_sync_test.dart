import 'package:cifras_app/dados/repositorio_musicas.dart';
import 'package:cifras_app/dados/repositorio_temas.dart';
import 'package:cifras_app/modelos/musica.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('ThemeRepository removeTheme remove o tema permanentemente e não o ressuscita ao reabrir', () async {
    final songRepo = await SongRepository.open();
    final themeRepo = await ThemeRepository.open();

    expect(themeRepo.themes.contains('Baião'), isTrue);

    // Remove o tema 'Baião'
    await themeRepo.removeTheme('Baião', songRepo);
    expect(themeRepo.themes.contains('Baião'), isFalse);
    expect(themeRepo.deletedThemes.contains('baião'), isTrue);

    // Simula reabrir o app do SharedPreferences
    final themeRepoReopened = await ThemeRepository.open();
    expect(themeRepoReopened.themes.contains('Baião'), isFalse);
    expect(themeRepoReopened.deletedThemes.contains('baião'), isTrue);
  });

  test('ThemeRepository setThemes ignora temas que estão na lista de excluídos', () async {
    final songRepo = await SongRepository.open();
    final themeRepo = await ThemeRepository.open();

    // Usuário excluiu 'Casamento'
    await themeRepo.removeTheme('Casamento', songRepo);
    expect(themeRepo.themes.contains('Casamento'), isFalse);

    // Sync tenta reinserir uma lista que contém 'Casamento'
    await themeRepo.setThemes(['Adoração', 'Casamento', 'Louvor'], fromSync: true);

    expect(themeRepo.themes.contains('Casamento'), isFalse);
    expect(themeRepo.themes.contains('Adoração'), isTrue);
    expect(themeRepo.themes.contains('Louvor'), isTrue);
  });

  test('ThemeRepository addTheme permite recriar tema previamente excluído', () async {
    final songRepo = await SongRepository.open();
    final themeRepo = await ThemeRepository.open();

    await themeRepo.removeTheme('Blues', songRepo);
    expect(themeRepo.themes.contains('Blues'), isFalse);
    expect(themeRepo.deletedThemes.contains('blues'), isTrue);

    // Usuário decide recriar o tema
    await themeRepo.addTheme('Blues');
    expect(themeRepo.themes.contains('Blues'), isTrue);
    expect(themeRepo.deletedThemes.contains('blues'), isFalse);

    // Ao reabrir, ele permanece presente
    final themeRepoReopened = await ThemeRepository.open();
    expect(themeRepoReopened.themes.contains('Blues'), isTrue);
  });

  test('ThemeRepository removeTheme desvincula tags das músicas existentes', () async {
    final songRepo = await SongRepository.open();
    final themeRepo = await ThemeRepository.open();

    final song = Song(
      id: 's1',
      title: 'Canção de Amor',
      artist: 'Cantor A',
      content: 'C G',
      tags: ['Amor de Deus', 'Louvor'],
    );
    await songRepo.save(song);

    expect(songRepo.songs.first.tags, contains('Amor de Deus'));

    // Remove o tema 'Amor de Deus'
    await themeRepo.removeTheme('Amor de Deus', songRepo);

    expect(themeRepo.themes.contains('Amor de Deus'), isFalse);
    final updatedSong = songRepo.songs.first;
    expect(updatedSong.tags.contains('Amor de Deus'), isFalse);
    expect(updatedSong.tags.contains('Louvor'), isTrue);
  });
}

