import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../models/song.dart';

/// Serviço para obter e importar cifras tanto por link (Cifra Club via Supabase)
/// quanto em lote por arquivos locais (.txt ou .zip).
class CifraImportService {
  CifraImportService._();

  static const String endpointUrl =
      'https://ydwyokhftlauuzfrbjut.supabase.co/functions/v1/obter_cifras';

  /// Obtém uma cifra a partir de uma URL (ex: Cifra Club) usando a função Supabase.
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
            imported.add(_songFromFileNameAndContent(name, content));
          }
        }
      } else if (extension == 'txt') {
        final content = utf8.decode(bytes, allowMalformed: true);
        imported.add(_songFromFileNameAndContent(file.name, content));
      }
    }

    return imported;
  }

  static Song _songFromFileNameAndContent(String rawFileName, String content) {
    // Normaliza nome do arquivo
    var fileName = rawFileName.split('/').last.split(r'\').last;
    var baseName = fileName.replaceAll(RegExp(r'\.txt$', caseSensitive: false), '').trim();

    // Remove numeração de setlist se houver (ex: "01 - Artista - Titulo" ou "01 - Titulo")
    baseName = baseName.replaceAll(RegExp(r'^\d+\s*-\s*'), '');

    String artist = '';
    String title = baseName;

    // Se tiver formato "Artista - Titulo"
    if (baseName.contains(' - ')) {
      final parts = baseName.split(' - ');
      if (parts.length >= 2) {
        artist = parts[0].trim();
        title = parts.sublist(1).join(' - ').trim();
      }
    }

    return Song(
      id: const Uuid().v4(),
      title: title.isEmpty ? 'Sem título' : title,
      artist: artist,
      content: content,
    );
  }
}
