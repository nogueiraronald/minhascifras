import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../configuracao/configuracao_app.dart';
import '../modelos/musica.dart';
import 'transpositor_acordes.dart';

/// Serviço para obter e importar cifras tanto por link da internet (via Supabase)
/// quanto em lote por arquivos locais (.txt ou .zip).
class CifraImportService {
  CifraImportService._();

  static const String endpointUrl = AppConfig.obterCifrasUrl;

  /// Obtém uma cifra a partir de uma URL usando a função Supabase.
  static Future<Song> importFromUrl(String rawUrl) async {
    var url = rawUrl.trim();
    if (url.isEmpty) {
      throw ArgumentError('Por favor, informe uma URL válida.');
    }

    // Remove caracteres especiais de placeholder como $0 no final se o usuário tiver colado
    if (url.endsWith('/\$0')) {
      url = url.substring(0, url.length - 2);
    } else if (url.endsWith('\$0')) {
      url = url.substring(0, url.length - 2);
    }

    final response = await http.post(
      Uri.parse(endpointUrl),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'url': url}),
    );

    if (response.statusCode != 200) {
      String msg = 'Erro ${response.statusCode} ao obter cifra.';
      try {
        final errJson = jsonDecode(response.body);
        if (errJson is Map && errJson['erro'] != null) {
          msg = errJson['erro'].toString();
        }
      } catch (_) {}
      throw Exception(msg);
    }

    final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    if (data['sucesso'] == false && data['erro'] != null) {
      throw Exception(data['erro'].toString());
    }

    final title = (data['nome_da_musica'] as String?)?.trim() ?? '';
    final artist = (data['artista'] as String?)?.trim() ?? '';
    final content = (data['cifra'] as String?) ?? '';
    final key = (data['tom'] as String?)?.trim() ?? '';

    if (title.isEmpty && content.isEmpty) {
      throw Exception('Nenhuma cifra encontrada para o link fornecido.');
    }

    return Song(
      id: const Uuid().v4(),
      title: title.isEmpty ? 'Sem título' : title,
      artist: artist,
      content: content,
      originalKey: key,
    );
  }

  /// Permite selecionar múltiplos arquivos (.txt e/ou .zip) e extrai todas as cifras encontradas.
  static Future<List<Song>> pickAndImportFiles() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['txt', 'zip'],
      allowMultiple: true,
      withData: true,
    );

    if (result == null || result.files.isEmpty) {
      return [];
    }

    final imported = <Song>[];

    for (final file in result.files) {
      Uint8List? bytes = file.bytes;
      if (bytes == null && file.path != null && !kIsWeb) {
        bytes = await File(file.path!).readAsBytes();
      }
      if (bytes == null) continue;

      final extension = file.extension?.toLowerCase() ?? '';

      if (extension == 'zip') {
        final archive = ZipDecoder().decodeBytes(bytes);
        for (final archiveFile in archive) {
          if (!archiveFile.isFile) continue;
          final name = archiveFile.name;
          if (name.toLowerCase().endsWith('.txt') && !name.startsWith('__MACOSX/')) {
            final content = utf8.decode(archiveFile.content as List<int>, allowMalformed: true);
            imported.add(songFromContentAndFileName(content: content, rawFileName: name));
          }
        }
      } else if (extension == 'txt') {
        final content = utf8.decode(bytes, allowMalformed: true);
        imported.add(songFromContentAndFileName(content: content, rawFileName: file.name));
      }
    }

    return imported;
  }

  /// Constrói um objeto [Song] extraindo título, artista e tom prioritariamente do conteúdo do arquivo.
  static Song songFromContentAndFileName({
    required String content,
    String rawFileName = '',
    String? id,
    bool isFavorite = false,
  }) {
    final meta = extractMetadata(content: content, rawFileName: rawFileName);
    return Song(
      id: id ?? const Uuid().v4(),
      title: meta.title,
      artist: meta.artist,
      content: content,
      originalKey: meta.originalKey,
      isFavorite: isFavorite,
    );
  }

  /// Extrai metadados (Título, Artista, Tom) priorizando o conteúdo interno do arquivo
  /// e utilizando o nome do arquivo apenas para fallback ou complemento.
  static ({String title, String artist, String originalKey}) extractMetadata({
    required String content,
    String rawFileName = '',
  }) {
    final lines = content.split('\n').map((l) => l.trim()).toList();

    String title = '';
    String artist = '';
    String originalKey = '';

    // 1. Tags explícitas nas primeiras 15 linhas (ex: "Artista: ...", "Tom: ...", "{title: ...}")
    for (int i = 0; i < lines.length && i < 15; i++) {
      final line = lines[i];
      if (line.isEmpty) continue;

      final artistMatch = RegExp(r'^(?:artista|artist|autor)\s*:\s*(.+)$', caseSensitive: false).firstMatch(line) ??
          RegExp(r'^\{(?:artist|artista|subtitle)\s*:\s*(.+)\}$', caseSensitive: false).firstMatch(line);
      if (artistMatch != null && artist.isEmpty) {
        artist = artistMatch.group(1)?.trim() ?? '';
      }

      final titleMatch = RegExp(r'^(?:m[úu]sica|t[íi]tulo|title)\s*:\s*(.+)$', caseSensitive: false).firstMatch(line) ??
          RegExp(r'^\{(?:title|t[íi]tulo)\s*:\s*(.+)\}$', caseSensitive: false).firstMatch(line);
      if (titleMatch != null && title.isEmpty) {
        title = titleMatch.group(1)?.trim() ?? '';
      }

      final keyMatch = RegExp(r'^(?:tom|key|tom original)\s*:\s*([A-Ga-g][#bB]?[m-]?)$', caseSensitive: false).firstMatch(line);
      if (keyMatch != null && originalKey.isEmpty) {
        originalKey = keyMatch.group(1)?.trim() ?? '';
      }
    }

    // 2. Extração das primeiras linhas de texto dentro do arquivo (formato padrão de cifra em txt)
    final textLines = <String>[];
    for (final l in lines) {
      if (l.isEmpty) continue;
      // Ignora metadados explícitos já capturados
      if (RegExp(r'^(?:tom|key|tom original|artista|artist|autor|m[úu]sica|t[íi]tulo|title)\s*:', caseSensitive: false).hasMatch(l)) {
        continue;
      }
      if (l.startsWith('{') && l.endsWith('}')) continue;
      textLines.add(l);
      if (textLines.length >= 6) break;
    }

    if (textLines.isNotEmpty) {
      final line0 = textLines[0];
      final isChord0 = ChordTransposer.isChordLine(line0);
      final isSection0 = line0.startsWith('[') || line0.startsWith('(') || line0.toLowerCase().startsWith('intro:');
      final isTab0 = RegExp(r'^[eBGDAE]\|').hasMatch(line0);

      // Se a primeira linha não for acorde, seção nem tablatura, e for relativamente curta: é o Título!
      if (!isChord0 && !isSection0 && !isTab0 && line0.length <= 80) {
        if (title.isEmpty) {
          if (line0.contains(' - ')) {
            final p = line0.split(' - ');
            title = p[0].trim();
            if (artist.isEmpty && p.length > 1) {
              artist = p.sublist(1).join(' - ').trim();
            }
          } else {
            title = line0;
          }
        }

        // Se houver segunda linha e não temos artista
        if (artist.isEmpty && textLines.length >= 2) {
          final line1 = textLines[1];
          final isChord1 = ChordTransposer.isChordLine(line1);
          final isSection1 = line1.startsWith('[') || line1.startsWith('(') || line1.toLowerCase().startsWith('intro:');
          final isTab1 = RegExp(r'^[eBGDAE]\|').hasMatch(line1);

          if (!isChord1 && !isSection1 && !isTab1 && line1.length <= 60) {
            artist = line1;
          }
        }
      }
    }

    // 3. Informações extraídas do nome do arquivo (fallback ou complemento de artista)
    var fileName = rawFileName.split('/').last.split(r'\').last;
    var baseName = fileName.replaceAll(RegExp(r'\.(txt|crd|chopro)$', caseSensitive: false), '').trim();
    // Remove numeração sequencial inicial (ex: "001_", "001 - ", "01. ", "001-", "01 ")
    baseName = baseName.replaceAll(RegExp(r'^\d+[\s_.-]+'), '').trim();

    String fileTitle = '';
    String fileArtist = '';

    if (baseName.isNotEmpty) {
      if (baseName.contains(' - ')) {
        final p = baseName.split(' - ');
        fileTitle = p[0].trim();
        fileArtist = p.sublist(1).join(' - ').trim();
      } else if (baseName.contains('_')) {
        final p = baseName.split('_');
        if (p.length == 2) {
          fileTitle = p[0].trim();
          fileArtist = p[1].trim();
        } else if (p.length > 2 && !baseName.contains(' ')) {
          fileTitle = baseName.replaceAll('_', ' ');
        } else {
          fileTitle = p[0].trim();
          fileArtist = p.sublist(1).join(' ').trim();
        }
      } else {
        fileTitle = baseName;
      }
    }

    if (title.isEmpty) {
      title = fileTitle.isNotEmpty ? fileTitle : 'Sem título';
    }

    if (artist.isEmpty && fileArtist.isNotEmpty) {
      artist = fileArtist;
    }

    // 4. Limpeza rigorosa final: nunca permitir sequencial inicial no título
    title = title.replaceAll(RegExp(r'^\d+[\s_.-]+'), '').trim();
    if (title.contains('_') && !title.contains(' ')) {
      title = title.replaceAll('_', ' ');
    }
    if (artist.contains('_') && !artist.contains(' ')) {
      artist = artist.replaceAll('_', ' ');
    }

    if (originalKey.isEmpty) {
      originalKey = ChordTransposer.detectKey(content) ?? '';
    }

    return (
      title: title.isEmpty ? 'Sem título' : title,
      artist: artist,
      originalKey: originalKey,
    );
  }
}
