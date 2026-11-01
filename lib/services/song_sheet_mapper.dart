import '../models/song.dart';

/// Converte Song <-> linha da aba "Musicas"
/// (id, titulo, artista, tomOriginal, conteudo, criadoEm, atualizadoEm, excluido).
class SongSheetMapper {
  SongSheetMapper._();

  static List<String> toRow(Song s) => [
        s.id,
        s.title,
        s.artist,
        s.originalKey,
        s.content,
        '', // criadoEm (reservado)
        s.updatedAt.toIso8601String(),
        s.deleted ? 'true' : 'false',
      ];

  static Song? fromRow(List<String> row) {
    String at(int i) => i < row.length ? row[i] : '';
    if (at(0).isEmpty) return null;
    return Song(
      id: at(0),
      title: at(1),
      artist: at(2),
      originalKey: at(3),
      content: at(4),
      updatedAt: DateTime.tryParse(at(6)) ?? DateTime.fromMillisecondsSinceEpoch(0),
      deleted: at(7).toLowerCase() == 'true',
    );
  }
}
