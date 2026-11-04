import 'dart:convert';
import 'package:http/http.dart' as http;

import '../configuracao/configuracao_app.dart';
import '../modelos/item_lista_repertorio.dart';
import '../modelos/lista_repertorio.dart';
import '../modelos/musica.dart';
import 'dados_nuvem.dart';

/// Serviço de sincronização e backup em nuvem no Supabase por código de compartilhamento.
class SupabaseSyncService {
  SupabaseSyncService();

  Map<String, String> get _headers => {
        'apikey': AppConfig.supabaseAnonKey,
        'Authorization': 'Bearer ${AppConfig.supabaseAnonKey}',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  /// Lê todas as músicas e setlists salvas para o código de sincronização fornecido.
  Future<CloudData> readAll(String syncCode) async {
    final cleanCode = syncCode.trim().toUpperCase();
    if (cleanCode.isEmpty) {
      return const CloudData();
    }

    final uri = Uri.parse(
        '${AppConfig.supabaseUrl}/rest/v1/repertorios_sync?codigo=eq.$cleanCode&select=dados,atualizado_em');

    final response = await http.get(uri, headers: _headers);

    if (response.statusCode != 200) {
      throw Exception(
          'Erro ao ler do Supabase (${response.statusCode}): ${response.body}');
    }

    final list = jsonDecode(utf8.decode(response.bodyBytes)) as List;
    if (list.isEmpty) {
      return const CloudData();
    }

    final first = list.first as Map<String, dynamic>;
    final dados = first['dados'] as Map<String, dynamic>? ?? {};

    final songsRaw = (dados['songs'] as List?) ?? [];
    final setlistsRaw = (dados['setlists'] as List?) ?? [];
    final itemsRaw = (dados['items'] as List?) ?? [];
    final deletedSongIds = ((dados['deletedSongIds'] as List?) ?? [])
        .map((e) => e.toString())
        .toList();
    final deletedSetlistIds = ((dados['deletedSetlistIds'] as List?) ?? [])
        .map((e) => e.toString())
        .toList();
    final deletedItemIds = ((dados['deletedItemIds'] as List?) ?? [])
        .map((e) => e.toString())
        .toList();

    return CloudData(
      songs: songsRaw
          .whereType<Map<String, dynamic>>()
          .map((j) => Song.fromJson(j))
          .toList(),
      setlists: setlistsRaw
          .whereType<Map<String, dynamic>>()
          .map((j) => Setlist.fromJson(j))
          .toList(),
      items: itemsRaw
          .whereType<Map<String, dynamic>>()
          .map((j) => SetlistItem.fromJson(j))
          .toList(),
      deletedSongIds: deletedSongIds,
      deletedSetlistIds: deletedSetlistIds,
      deletedItemIds: deletedItemIds,
    );
  }

  /// Grava o repertório completo para o código de sincronização usando Upsert.
  Future<void> writeAll(String syncCode, CloudData data) async {
    final cleanCode = syncCode.trim().toUpperCase();
    if (cleanCode.isEmpty) return;

    final uri = Uri.parse('${AppConfig.supabaseUrl}/rest/v1/repertorios_sync');

    final payload = {
      'codigo': cleanCode,
      'dados': {
        'songs': data.songs.map((s) => s.toJson()).toList(),
        'setlists': data.setlists.map((s) => s.toJson()).toList(),
        'items': data.items.map((i) => i.toJson()).toList(),
        'deletedSongIds': data.deletedSongIds,
        'deletedSetlistIds': data.deletedSetlistIds,
        'deletedItemIds': data.deletedItemIds,
      },
      'atualizado_em': DateTime.now().toUtc().toIso8601String(),
    };

    final headers = {
      ..._headers,
      'Prefer': 'resolution=merge-duplicates,return=minimal',
    };

    final response = await http.post(
      uri,
      headers: headers,
      body: jsonEncode(payload),
    );

    if (response.statusCode >= 300) {
      throw Exception(
          'Falha ao salvar no Supabase (${response.statusCode}): ${response.body}');
    }
  }
}
