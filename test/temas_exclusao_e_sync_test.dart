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

  test('ThemeRepository open inicia com 0 temas para novo usuário', () async {
    final themeRepo = await ThemeRepository.open();
    expect(themeRepo.themes.isEmpty, isTrue);
    expect(themeRepo.themes.length, 0);
  });

  test('ThemeRepository removeTheme remove o tema permanentemente e não acumula registros inúteis', () async {
    final songRepo = await SongRepository.open();
    final themeRepo = await ThemeRepository.open();

    await themeRepo.addTheme('Baião');
    expect(themeRepo.themes.contains('Baião'), isTrue);

    // Remove o tema 'Baião'
    await themeRepo.removeTheme('Baião', songRepo);
    expect(themeRepo.themes.contains('Baião'), isFalse);

    // Simula reabrir o app do SharedPreferences
    final themeRepoReopened = await ThemeRepository.open();
    expect(themeRepoReopened.themes.contains('Baião'), isFalse);
  });

  test('ThemeRepository setThemes atualiza os temas ativos do usuário', () async {
    final songRepo = await SongRepository.open();
    final themeRepo = await ThemeRepository.open();

    await themeRepo.addTheme('Casamento');
    expect(themeRepo.themes.contains('Casamento'), isTrue);

    await themeRepo.removeTheme('Casamento', songRepo);
    expect(themeRepo.themes.contains('Casamento'), isFalse);

    // Nova lista vinda de sincronização ou seleção
    await themeRepo.setThemes(['Adoração', 'Louvor'], fromSync: true);

    expect(themeRepo.themes.contains('Casamento'), isFalse);
    expect(themeRepo.themes.contains('Adoração'), isTrue);
    expect(themeRepo.themes.contains('Louvor'), isTrue);
  });

  test('ThemeRepository addTheme permite recriar tema normalmente', () async {
    final songRepo = await SongRepository.open();
    final themeRepo = await ThemeRepository.open();

    await themeRepo.addTheme('Blues');
    await themeRepo.removeTheme('Blues', songRepo);
    expect(themeRepo.themes.contains('Blues'), isFalse);

    // Usuário decide recriar o tema
    await themeRepo.addTheme('Blues');
    expect(themeRepo.themes.contains('Blues'), isTrue);

    // Ao reabrir, ele permanece presente
    final themeRepoReopened = await ThemeRepository.open();
    expect(themeRepoReopened.themes.contains('Blues'), isTrue);
  });

  test('ThemeRepository removeTheme desvincula tags das músicas existentes', () async {
    final songRepo = await SongRepository.open();
    final themeRepo = await ThemeRepository.open();

    await themeRepo.addTheme('Amor de Deus');
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

