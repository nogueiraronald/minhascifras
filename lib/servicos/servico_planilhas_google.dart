import 'dart:convert';

import 'package:http/http.dart' as http;

import '../modelos/lista_repertorio.dart';
import '../modelos/item_lista_repertorio.dart';
import '../modelos/musica.dart';
import 'dados_nuvem.dart';
import 'servico_autenticacao_google.dart';

class SheetsException implements Exception {
  SheetsException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Sincronização em Nuvem via Google Drive REST API.
///
/// Salva o banco de dados e backup das cifras em `MinhasCifras_Backup.json` no Google Drive
/// pessoal do usuário. Utiliza o escopo seguro e nativo `drive.file`, funcionando 100%
/// autônomo e sem depender de APIs extras desativadas no Google Cloud Console.
class SheetsService {
  SheetsService(this._auth);

  final GoogleAuthService _auth;

  static const String backupFileName = 'MinhasCifras_Backup.json';

  Future<Map<String, String>> _headers() async => {
        ...await _auth.authHeaders(),
        'Content-Type': 'application/json',
      };

  void _check(http.Response r) {
    if (r.statusCode >= 300) {
      final bodyLower = r.body.toLowerCase();
      if (r.statusCode == 429 || bodyLower.contains('quota') || bodyLower.contains('rate_limit')) {
        throw SheetsException('Limite de requisições do Google atingido temporariamente. Aguarde alguns instantes.');
      }
      try {
        final j = jsonDecode(r.body);
        if (j is Map && j['error'] is Map && j['error']['message'] != null) {
          throw SheetsException('${j['error']['message']}');
        }
      } catch (_) {}
      throw SheetsException('Google respondeu com erro ${r.statusCode}');
    }
  }

  /// Repete com espera crescente se o Google limitar cota (429 ou 403 rate_limit) ou falhar (5xx).
  Future<http.Response> _send(Future<http.Response> Function() call) async {
    for (var attempt = 0;; attempt++) {
      final r = await call();
      final bodyLower = r.body.toLowerCase();
      final isRateLimit = r.statusCode == 429 ||
          (r.statusCode == 403 &&
              (bodyLower.contains('rate_limit') ||
                  bodyLower.contains('quota') ||
                  bodyLower.contains('ratelimitexceeded') ||
                  bodyLower.contains('userratelimitexceeded')));
      final isServerError = r.statusCode >= 500;

      if ((isRateLimit || isServerError) && attempt < 4) {
        final waitSeconds = 2 * (1 << attempt); // 2s, 4s, 8s, 16s
        await Future<void>.delayed(Duration(seconds: waitSeconds));
        continue;
      }
      _check(r);
      return r;
    }
  }

  /// Garante a existência do arquivo de backup `MinhasCifras_Backup.json` no Google Drive do usuário.
  Future<String> ensureSpreadsheet() async {
    // 1. Procura se o arquivo já existe no Drive
    final q = Uri.encodeQueryComponent("name = '$backupFileName' and trashed = false");
    final searchUri = Uri.parse(
      'https://www.googleapis.com/drive/v3/files?spaces=drive&q=$q&fields=files(id,name)',
    );
    final searchRes = await _send(() async => http.get(searchUri, headers: await _headers()));
    final files = (jsonDecode(searchRes.body)['files'] as List?) ?? [];
    if (files.isNotEmpty) {
      return files.first['id'] as String;
    }

    // 2. Se não existir, cria o arquivo diretamente no Google Drive
    final createUri = Uri.parse('https://www.googleapis.com/drive/v3/files');
    final createRes = await _send(() async => http.post(
          createUri,
          headers: await _headers(),
          body: jsonEncode({
            'name': backupFileName,
            'mimeType': 'application/json',
            'description': 'MinhasCifras - Banco de Dados e Backup em Nuvem',
          }),
        ));
    final fileId = jsonDecode(createRes.body)['id'] as String;

    // 3. Inicializa o arquivo com estrutura JSON
    final uploadUri = Uri.parse(
      'https://www.googleapis.com/upload/drive/v3/files/$fileId?uploadType=media',
    );
    await _send(() async => http.patch(
          uploadUri,
          headers: {
            ...await _headers(),
            'Content-Type': 'application/json; charset=utf-8',
          },
          body: jsonEncode({
            'appName': 'MinhasCifras',
            'version': 1,
            'updatedAt': DateTime.now().toIso8601String(),
            'songs': [],
            'deletedSongIds': [],
            'setlists': [],
            'deletedSetlistIds': [],
            'items': [],
            'deletedItemIds': [],
          }),
        ));

    return fileId;
  }

  /// Lê todas as músicas e setlists salvas no arquivo do Google Drive.
  Future<CloudData> readAll(String id) async {
    final uri = Uri.parse('https://www.googleapis.com/drive/v3/files/$id?alt=media');
    http.Response r;
    try {
      r = await _send(() async => http.get(uri, headers: await _headers()));
    } on SheetsException catch (e) {
      // Se o ID antigo não existir mais no Drive, busca ou recria o backup
      if (e.message.contains('404') || e.message.contains('400')) {
        final newId = await ensureSpreadsheet();
        if (newId != id) {
          return readAll(newId);
        }
      }
      rethrow;
    }

    if (r.body.trim().isEmpty) {
      return const CloudData();
    }

    try {
      final json = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
      final songs = ((json['songs'] as List?) ?? const [])
          .map((e) => Song.fromJson(e as Map<String, dynamic>))
          .where((s) => !s.deleted)
          .toList();
      final setlists = ((json['setlists'] as List?) ?? const [])
          .map((e) => Setlist.fromJson(e as Map<String, dynamic>))
          .where((s) => !s.deleted)
          .toList();
      final items = ((json['items'] as List?) ?? const [])
          .map((e) => SetlistItem.fromJson(e as Map<String, dynamic>))
          .where((s) => !s.deleted)
          .toList();
      final deletedSongIds = ((json['deletedSongIds'] as List?) ?? const [])
          .map((e) => '$e')
          .toList();
      final deletedSetlistIds = ((json['deletedSetlistIds'] as List?) ?? const [])
          .map((e) => '$e')
          .toList();
      final deletedItemIds = ((json['deletedItemIds'] as List?) ?? const [])
          .map((e) => '$e')
          .toList();

      return CloudData(
        songs: songs,
        setlists: setlists,
        items: items,
        deletedSongIds: deletedSongIds,
        deletedSetlistIds: deletedSetlistIds,
        deletedItemIds: deletedItemIds,
      );
    } catch (_) {
      return const CloudData();
    }
  }

  /// Grava no arquivo do Google Drive apenas as cifras e listas ativas.
  /// Músicas excluídas localmente são completamente removidas das linhas da nuvem.
  Future<void> writeAll(String id, CloudData d) async {
    final body = jsonEncode({
      'appName': 'MinhasCifras',
      'version': 1,
      'updatedAt': DateTime.now().toIso8601String(),
      'songs': d.songs.where((s) => !s.deleted).map((s) => s.toJson()).toList(),
      'deletedSongIds': d.deletedSongIds,
      'setlists': d.setlists.where((s) => !s.deleted).map((s) => s.toJson()).toList(),
      'deletedSetlistIds': d.deletedSetlistIds,
      'items': d.items.where((i) => !i.deleted).map((i) => i.toJson()).toList(),
      'deletedItemIds': d.deletedItemIds,
    });

    final uri = Uri.parse(
      'https://www.googleapis.com/upload/drive/v3/files/$id?uploadType=media',
    );
    await _send(() async => http.patch(
          uri,
          headers: {
            ...await _headers(),
            'Content-Type': 'application/json; charset=utf-8',
          },
          body: body,
        ));
  }
}
