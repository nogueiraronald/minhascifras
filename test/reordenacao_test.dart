import 'package:cifras_app/dados/repositorio_listas.dart';
import 'package:cifras_app/modelos/lista_repertorio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('SetlistRepository reorders items correctly', () async {
    SharedPreferences.setMockInitialValues({});
    final repo = await SetlistRepository.open();

    final setlist = Setlist(id: 'sl1', name: 'Culto Domingo');
    await repo.saveSetlist(setlist);

    await repo.addSongs('sl1', ['songA', 'songB', 'songC']);

    var items = repo.itemsFor('sl1');
    expect(items.map((e) => e.songId).toList(), ['songA', 'songB', 'songC']);

    // Move songC (index 2) to index 0
    final moved = items.removeAt(2);
    items.insert(0, moved);

    await repo.reorder('sl1', items.map((e) => e.id).toList());

    final updated = repo.itemsFor('sl1');
    expect(updated.map((e) => e.songId).toList(), ['songC', 'songA', 'songB']);
  });

  test('SetlistRepository updates count and removes items when a song is deleted', () async {
    SharedPreferences.setMockInitialValues({});
    final repo = await SetlistRepository.open();

    final setlist = Setlist(id: 'sl2', name: 'Repertório');
    await repo.saveSetlist(setlist);
    await repo.addSongs('sl2', ['s1', 's2', 's3']);

    // Com s1, s2, s3 ativas:
    expect(repo.countFor('sl2', ['s1', 's2', 's3']), 3);

    // Se s2 for excluída:
    expect(repo.countFor('sl2', ['s1', 's3']), 2);

    // Chamando removeItemsForSong para s2:
    await repo.removeItemsForSong('s2');
    expect(repo.itemsFor('sl2').length, 2);
    expect(repo.countFor('sl2'), 2);

    // Limpeza de itens órfãos (se só restasse s1):
    await repo.cleanupOrphanedItems(['s1']);
    expect(repo.itemsFor('sl2').length, 1);
    expect(repo.countFor('sl2'), 1);
  });
}
