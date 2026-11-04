import '../modelos/lista_repertorio.dart';
import '../modelos/item_lista_repertorio.dart';
import '../modelos/musica.dart';

/// Conteúdo das abas da planilha.
class CloudData {
  const CloudData({
    this.songs = const [],
    this.setlists = const [],
    this.items = const [],
    this.deletedSongIds = const [],
    this.deletedSetlistIds = const [],
    this.deletedItemIds = const [],
    this.passwordHash,
  });

  final List<Song> songs;
  final List<Setlist> setlists;
  final List<SetlistItem> items;
  final List<String> deletedSongIds;
  final List<String> deletedSetlistIds;
  final List<String> deletedItemIds;
  final String? passwordHash;
}
