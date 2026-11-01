import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/setlist.dart';
import '../models/setlist_item.dart';
import '../models/song.dart';
import 'cloud_data.dart';
import 'google_auth_service.dart';
import 'setlist_sheet_mapper.dart';
import 'sheet_schema.dart';
import 'song_sheet_mapper.dart';

class SheetsException implements Exception {
  SheetsException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Encontra ou cria a planilha do usuário (Drive + Sheets REST).
class SheetsService {
  SheetsService(this._auth);

  final GoogleAuthService _auth;

  Future<Map<String, String>> _headers() async =>
      {...await _auth.authHeaders(), 'Content-Type': 'application/json'};

  void _check(http.Response r) {
    if (r.statusCode >= 300) {
      throw SheetsException('Google respondeu ${r.statusCode}: ${r.body}');
    }
  }

  /// Procura uma planilha já criada por este app nesta conta (outros aparelhos).
  Future<String?> _findExisting() async {
    final q = "name='${SheetSchema.title}' and "
        "mimeType='application/vnd.google-apps.spreadsheet' and trashed=false";
    final uri = Uri.https('www.googleapis.com', '/drive/v3/files',
        {'q': q, 'fields': 'files(id)', 'orderBy': 'createdTime'});
    final r = await http.get(uri, headers: await _headers());
    _check(r);
    final files = (jsonDecode(r.body)['files'] as List);
    return files.isEmpty ? null : (files.first as Map)['id'] as String;
  }

  Future<String> _create() async {
    final sheets = SheetSchema.tabs.entries.map((e) => {
          'properties': {'title': e.key},
          'data': [
            {
              'startRow': 0,
              'startColumn': 0,
              'rowData': e.value
                  .map((row) => {
                        'values': row
                            .map((c) => {
                                  'userEnteredValue': {'stringValue': c}
                                })
                            .toList(),
                      })
                  .toList(),
            }
          ],
        });
    final r = await http.post(
      Uri.parse('https://sheets.googleapis.com/v4/spreadsheets'),
      headers: await _headers(),
      body: jsonEncode({
        'properties': {'title': SheetSchema.title},
        'sheets': sheets.toList(),
      }),
    );
    _check(r);
    return jsonDecode(r.body)['spreadsheetId'] as String;
  }

  Future<String> ensureSpreadsheet() async =>
      await _findExisting() ?? await _create();

  /// Repete com espera crescente se o Google limitar (429) ou falhar (5xx).
  Future<http.Response> _send(Future<http.Response> Function() call) async {
    for (var attempt = 0;; attempt++) {
      final r = await call();
      if ((r.statusCode == 429 || r.statusCode >= 500) && attempt < 3) {
        await Future<void>.delayed(Duration(seconds: 2 << attempt));
        continue;
      }
      _check(r);
      return r;
    }
  }

  /// 1 requisição lê as três abas.
  Future<CloudData> readAll(String id) async {
    final uri = Uri.parse('https://sheets.googleapis.com/v4/spreadsheets/$id/values:batchGet'
        '?ranges=Musicas!A2:H&ranges=Setlists!A2:E&ranges=ItensSetlist!A2:G');
    final r = await _send(() async => http.get(uri, headers: await _headers()));
    final ranges = jsonDecode(r.body)['valueRanges'] as List;
    List<List<String>> rows(int i) => ((ranges[i]['values'] as List?) ?? const [])
        .map((row) => (row as List).map((e) => '$e').toList())
        .toList();
    return CloudData(
      songs: rows(0).map(SongSheetMapper.fromRow).whereType<Song>().toList(),
      setlists: rows(1).map(SetlistSheetMapper.setlistFromRow).whereType<Setlist>().toList(),
      items: rows(2).map(SetlistSheetMapper.itemFromRow).whereType<SetlistItem>().toList(),
    );
  }

  /// 1 requisição grava as três abas (linhas nunca são removidas: exclusão é lógica).
  Future<void> writeAll(String id, CloudData d) async {
    final data = <Map<String, dynamic>>[];
    void add(String tab, String lastCol, List<List<String>> rows) {
      if (rows.isEmpty) return;
      data.add({
        'range': '$tab!A2:$lastCol${rows.length + 1}',
        'majorDimension': 'ROWS',
        'values': rows,
      });
    }

    add('Musicas', 'H', d.songs.map(SongSheetMapper.toRow).toList());
    add('Setlists', 'E', d.setlists.map(SetlistSheetMapper.setlistToRow).toList());
    add('ItensSetlist', 'G', d.items.map(SetlistSheetMapper.itemToRow).toList());
    if (data.isEmpty) return;
    final uri =
        Uri.parse('https://sheets.googleapis.com/v4/spreadsheets/$id/values:batchUpdate');
    final body = jsonEncode({'valueInputOption': 'RAW', 'data': data});
    await _send(() async => http.post(uri, headers: await _headers(), body: body));
  }
}
