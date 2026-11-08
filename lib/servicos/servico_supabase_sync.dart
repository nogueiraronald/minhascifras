import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../configuracao/configuracao_app.dart';
import '../modelos/item_lista_repertorio.dart';
import '../modelos/lista_repertorio.dart';
import '../modelos/musica.dart';
import 'dados_nuvem.dart';

/// Serviço de sincronização e backup em nuvem no Supabase por código de compartilhamento.
class SupabaseSyncService {
  SupabaseSyncService();

  Map<String, String> get _readHeaders => {
        'apikey': AppConfig.supabaseAnonKey,
        'Authorization': 'Bearer ${AppConfig.supabaseAnonKey}',
        'Accept': 'application/json',
      };

  Map<String, String> get _writeHeaders => {
        'apikey': AppConfig.supabaseAnonKey,
        'Authorization': 'Bearer ${AppConfig.supabaseAnonKey}',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  Future<http.Response> _getWithRetry(Uri uri, Map<String, String> headers) async {
    Object? lastError;
    for (int attempt = 1; attempt <= 3; attempt++) {
      try {
        final response =
            await http.get(uri, headers: headers).timeout(const Duration(seconds: 20));
        return response;
      } catch (e) {
        lastError = e;
        if (attempt < 3) {
          await Future.delayed(Duration(milliseconds: 300 * attempt));
        }
      }
    }
    throw lastError!;
  }

  Future<http.Response> _postWithRetry(
      Uri uri, Map<String, String> headers, String body) async {
    Object? lastError;
    for (int attempt = 1; attempt <= 2; attempt++) {
      try {
        final response = await http
            .post(uri, headers: headers, body: body)
            .timeout(const Duration(seconds: 25));
        return response;
      } catch (e) {
        lastError = e;
        if (attempt < 2) {
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }
    }
    throw lastError!;
  }

  /// Lê todas as músicas e setlists salvas para o código de sincronização fornecido.
  Future<CloudData> readAll(String syncCode) async {
    final cleanCode = syncCode.trim().toUpperCase();
    if (cleanCode.isEmpty) {
      return const CloudData();
    }

    final uri = Uri.parse(
        '${AppConfig.supabaseUrl}/rest/v1/repertorios_sync?codigo=eq.$cleanCode&select=dados,atualizado_em');

    final response = await _getWithRetry(uri, _readHeaders);

    if (response.statusCode != 200) {
      throw Exception(
          'Erro ao ler do Supabase (${response.statusCode}): ${response.body}');
    }

    final rawText = kIsWeb ? response.body : utf8.decode(response.bodyBytes);
    final list = jsonDecode(rawText) as List;
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
    final deletedSongKeys = ((dados['deletedSongKeys'] as List?) ?? [])
        .map((e) => e.toString())
        .toList();
    final deletedSetlistIds = ((dados['deletedSetlistIds'] as List?) ?? [])
        .map((e) => e.toString())
        .toList();
    final deletedItemIds = ((dados['deletedItemIds'] as List?) ?? [])
        .map((e) => e.toString())
        .toList();

    final passwordHash = dados['senha_hash'] as String?;
    final nickname = dados['nickname'] as String?;

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
      deletedSongKeys: deletedSongKeys,
      deletedSetlistIds: deletedSetlistIds,
      deletedItemIds: deletedItemIds,
      passwordHash: passwordHash,
      nickname: nickname,
    );
  }

  /// Verifica se um código possui senha de proteção configurada na nuvem.
  Future<String?> checkPasswordHash(String syncCode) async {
    final cleanCode = syncCode.trim().toUpperCase();
    if (cleanCode.isEmpty) return null;

    final uri = Uri.parse(
        '${AppConfig.supabaseUrl}/rest/v1/repertorios_sync?codigo=eq.$cleanCode&select=dados');

    try {
      final response = await _getWithRetry(uri, _readHeaders);
      if (response.statusCode != 200) return null;

      final rawText = kIsWeb ? response.body : utf8.decode(response.bodyBytes);
      final list = jsonDecode(rawText) as List;
      if (list.isEmpty) return null;

      final first = list.first as Map<String, dynamic>;
      final dados = first['dados'] as Map<String, dynamic>? ?? {};
      return dados['senha_hash'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// Verifica se um nickname já está em uso por outra conta/e-mail no Supabase.
  Future<bool> isNicknameTakenByAnotherUser({
    required String nickname,
    required String ownSyncCode,
    required String ownEmail,
  }) async {
    final cleanNick =
        nickname.trim().replaceFirst(RegExp(r'^@+'), '').toLowerCase();
    final cleanCode = ownSyncCode.trim().toUpperCase();
    final cleanEmail = ownEmail.trim().toLowerCase();
    if (cleanNick.isEmpty) return false;

    final uri = Uri.parse(
      '${AppConfig.supabaseUrl}/rest/v1/repertorios_sync?select=codigo,dados',
    );

    try {
      final response = await _getWithRetry(uri, _readHeaders);
      if (response.statusCode != 200) return false;

      final rawText = kIsWeb ? response.body : utf8.decode(response.bodyBytes);
      final list = jsonDecode(rawText) as List;

      for (final item in list) {
        if (item is! Map<String, dynamic>) continue;
        final codigo = (item['codigo'] as String? ?? '').trim().toUpperCase();
        final dados = item['dados'] as Map<String, dynamic>? ?? {};

        if (codigo == 'COMUNIDADE_GLOBAL_V1') {
          final registry =
              dados['nicknames_registry'] as Map<String, dynamic>? ?? {};
          final ownerEmail =
              (registry[cleanNick] as String? ?? '').trim().toLowerCase();
          if (ownerEmail.isNotEmpty && ownerEmail != cleanEmail) {
            return true;
          }
          final rawSongs = (dados['community_songs'] as List?) ?? [];
          for (final s in rawSongs.whereType<Map<String, dynamic>>()) {
            final sharedNick = (s['sharedByNickname'] as String? ?? '')
                .trim()
                .replaceFirst(RegExp(r'^@+'), '')
                .toLowerCase();
            final sharedEmail =
                (s['sharedByEmail'] as String? ?? '').trim().toLowerCase();
            if (sharedNick == cleanNick &&
                sharedEmail.isNotEmpty &&
                sharedEmail != cleanEmail) {
              return true;
            }
          }
          continue;
        }

        if (codigo != cleanCode) {
          final remoteNick = (dados['nickname'] as String? ?? '')
              .trim()
              .replaceFirst(RegExp(r'^@+'), '')
              .toLowerCase();
          if (remoteNick == cleanNick) {
            return true;
          }
        }
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Grava o repertório completo para o código de sincronização usando Upsert.
  Future<void> writeAll(String syncCode, CloudData data) async {
    final cleanCode = syncCode.trim().toUpperCase();
    if (cleanCode.isEmpty) return;

    final uri = Uri.parse('${AppConfig.supabaseUrl}/rest/v1/repertorios_sync');

    final dadosMap = <String, dynamic>{
      'songs': data.songs.map((s) => s.toJson()).toList(),
      'setlists': data.setlists.map((s) => s.toJson()).toList(),
      'items': data.items.map((i) => i.toJson()).toList(),
      'deletedSongIds': data.deletedSongIds,
      'deletedSongKeys': data.deletedSongKeys,
      'deletedSetlistIds': data.deletedSetlistIds,
      'deletedItemIds': data.deletedItemIds,
    };
    if (data.passwordHash != null && data.passwordHash!.isNotEmpty) {
      dadosMap['senha_hash'] = data.passwordHash;
    } else {
      dadosMap['senha_hash'] = null;
    }
    if (data.nickname != null && data.nickname!.trim().isNotEmpty) {
      dadosMap['nickname'] = data.nickname!.trim();
    }

    final payload = {
      'codigo': cleanCode,
      'dados': dadosMap,
      'atualizado_em': DateTime.now().toUtc().toIso8601String(),
    };

    final headers = {
      ..._writeHeaders,
      'Prefer': 'resolution=merge-duplicates,return=minimal',
    };

    final response = await _postWithRetry(
      uri,
      headers,
      jsonEncode(payload),
    );

    if (response.statusCode >= 300) {
      throw Exception(
          'Falha ao salvar no Supabase (${response.statusCode}): ${response.body}');
    }
  }
}
