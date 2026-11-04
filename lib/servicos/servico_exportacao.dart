import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:archive/archive.dart';

import '../modelos/musica.dart';
import 'salvador_arquivo.dart';
import 'transpositor_acordes.dart';

/// Exporta cifras em .zip, com um .txt por música.
class ExportService {
  ExportService._();

  /// Todas as músicas, no tom original.
  static Future<bool> exportSongs(List<Song> songs) =>
      _saveZip('cifras.zip', _files([for (final s in songs) (s, 0)], numbered: false));

  /// Uma setlist, na ordem e nos tons definidos nela.
  static Future<bool> exportSetlist(String name, List<(Song, int)> items) =>
      _saveZip('${_safe(name)}.zip', _files(items, numbered: true));

  static Map<String, String> _files(List<(Song, int)> items, {required bool numbered}) {
    final files = <String, String>{};
    for (var i = 0; i < items.length; i++) {
      final (song, steps) = items[i];
      var base = _safe(song.artist.isEmpty ? song.title : '${song.artist} - ${song.title}');
      if (numbered) base = '${(i + 1).toString().padLeft(2, '0')} - $base';
      var name = '$base.txt';
      for (var n = 2; files.containsKey(name); n++) {
        name = '$base ($n).txt';
      }
      files[name] = ChordTransposer.transposeContent(song.content, steps);
    }
    return files;
  }

  static String _safe(String s) {
    final t = s.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
    return t.isEmpty ? 'sem titulo' : t;
  }

  static Future<bool> _saveZip(String fileName, Map<String, String> files) async {
    final archive = Archive();
    for (final e in files.entries) {
      final bytes = utf8.encode(e.value);
      archive.addFile(ArchiveFile(e.key, bytes.length, bytes));
    }
    final bytes = Uint8List.fromList(ZipEncoder().encode(archive)!);
    return saveFileToDevice(fileName, bytes);
  }
}
