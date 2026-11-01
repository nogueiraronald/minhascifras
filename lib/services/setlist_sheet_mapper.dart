import '../models/setlist.dart';
import '../models/setlist_item.dart';

/// Abas "Setlists" (id, nome, observacoes, atualizadoEm, excluido) e
/// "ItensSetlist" (id, setlistId, musicaId, posicao, tomNaLista, atualizadoEm, excluido).
/// tomNaLista = deslocamento em semitons (ex.: 2 ou -3).
class SetlistSheetMapper {
  SetlistSheetMapper._();

  static List<String> setlistToRow(Setlist s) =>
      [s.id, s.name, s.notes, s.updatedAt.toIso8601String(), s.deleted ? 'true' : 'false'];

  static Setlist? setlistFromRow(List<String> row) {
    String at(int i) => i < row.length ? row[i] : '';
    if (at(0).isEmpty) return null;
    return Setlist(
      id: at(0),
      name: at(1),
      notes: at(2),
      updatedAt: DateTime.tryParse(at(3)) ?? DateTime.fromMillisecondsSinceEpoch(0),
      deleted: at(4).toLowerCase() == 'true',
    );
  }

  static List<String> itemToRow(SetlistItem i) => [
        i.id,
        i.setlistId,
        i.songId,
        '${i.position}',
        '${i.transpose}',
        i.updatedAt.toIso8601String(),
        i.deleted ? 'true' : 'false',
      ];

  static SetlistItem? itemFromRow(List<String> row) {
    String at(int i) => i < row.length ? row[i] : '';
    if (at(0).isEmpty || at(1).isEmpty || at(2).isEmpty) return null;
    return SetlistItem(
      id: at(0),
      setlistId: at(1),
      songId: at(2),
      position: int.tryParse(at(3)) ?? 0,
      transpose: int.tryParse(at(4)) ?? 0,
      updatedAt: DateTime.tryParse(at(5)) ?? DateTime.fromMillisecondsSinceEpoch(0),
      deleted: at(6).toLowerCase() == 'true',
    );
  }
}
