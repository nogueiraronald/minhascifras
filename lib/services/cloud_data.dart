import '../models/setlist.dart';
import '../models/setlist_item.dart';
import '../models/song.dart';

/// Conteúdo das abas da planilha.
class CloudData {
  const CloudData({
    this.songs = const [],
    this.setlists = const [],
    this.items = const [],
  });

  final List<Song> songs;
  final List<Setlist> setlists;
  final List<SetlistItem> items;
}
