import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cifras_app/modelos/musica.dart';
import 'package:cifras_app/modelos/lista_repertorio.dart';
import 'package:cifras_app/dados/repositorio_listas.dart';
import 'package:cifras_app/dados/repositorio_musicas.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('SetlistRepository can create, count and filter setlists', () async {
    SharedPreferences.setMockInitialValues({});
    final songsRepo = await SongRepository.open();
    final setlistRepo = await SetlistRepository.open();

    await songsRepo.save(Song(id: 's1', title: 'Música 1', content: 'C G'));
    await songsRepo.save(Song(id: 's2', title: 'Música 2', content: 'D A'));

    final l1 = Setlist(id: 'l1', name: 'Culto de Domingo');
    final l2 = Setlist(id: 'l2', name: 'Jovens');
    await setlistRepo.saveSetlist(l1);
    await setlistRepo.saveSetlist(l2);

    await setlistRepo.addSongs('l1', ['s1', 's2']);
    await setlistRepo.addSongs('l2', ['s1']);

    expect(setlistRepo.countFor('l1', songsRepo.songs.map((e) => e.id)), 2);
    expect(setlistRepo.countFor('l2', songsRepo.songs.map((e) => e.id)), 1);

    final filtered = setlistRepo.setlists
        .where((s) => s.name.toLowerCase().contains('domingo'))
        .toList();
    expect(filtered.length, 1);
    expect(filtered.first.name, 'Culto de Domingo');
  });
}
