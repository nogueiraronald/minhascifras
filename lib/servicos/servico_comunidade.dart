import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../configuracao/configuracao_app.dart';
import '../dados/repositorio_musicas.dart';
import '../modelos/musica.dart';
import '../modelos/musica_comunidade.dart';

/// Serviço exclusivamente ONLINE para a Comunidade de Cifras.
///
/// IMPORTANTE: As cifras da comunidade NÃO são baixadas automaticamente
/// na sincronização local do usuário para evitar grande volume de arquivos.
/// Elas são consultadas apenas online sob demanda e só entram na lista do
/// usuário quando ele clicar explicitamente em "Importar".
class CommunityService {
  CommunityService();

  static const String communityFeedCode = 'COMUNIDADE_GLOBAL_V1';
  static const int maxCarouselItems = 10;
  static const Uuid _uuid = Uuid();

  static String normAuthorSongKey(
          String authorEmail, String title, String artist) =>
      '${authorEmail.trim().toLowerCase()}|${title.trim().toLowerCase()}|${artist.trim().toLowerCase()}';

  /// Retorna o registro compartilhado caso o usuário (`userEmail`) já tenha compartilhado `song` na comunidade.
  CommunitySong? findSharedSongByUser({
    required Song song,
    required String userEmail,
    required List<CommunitySong> communitySongs,
  }) {
    final cleanEmail = userEmail.trim().toLowerCase();
    if (cleanEmail.isEmpty) return null;
    final targetKey = normAuthorSongKey(cleanEmail, song.title, song.artist);
    for (final item in communitySongs) {
      if (item.sharedByEmail.trim().toLowerCase() == cleanEmail) {
        if (item.song.id == song.id ||
            normAuthorSongKey(
                    item.sharedByEmail, item.song.title, item.song.artist) ==
                targetKey) {
          return item;
        }
      }
    }
    return null;
  }

  /// Verifica se o usuário já compartilhou determinada música na comunidade.
  bool isSongSharedByUser({
    required Song song,
    required String userEmail,
    required List<CommunitySong> communitySongs,
  }) {
    return findSharedSongByUser(
          song: song,
          userEmail: userEmail,
          communitySongs: communitySongs,
        ) !=
        null;
  }

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
        'Prefer': 'resolution=merge-duplicates,return=minimal',
      };

  /// Busca online as cifras compartilhadas pela comunidade, ordenadas das mais recentes para as mais antigas.
  Future<List<CommunitySong>> fetchCommunitySongs() async {
    final uri = Uri.parse(
      '${AppConfig.supabaseUrl}/rest/v1/repertorios_sync?codigo=eq.$communityFeedCode&select=dados,atualizado_em',
    );

    final response = await http
        .get(uri, headers: _readHeaders)
        .timeout(const Duration(seconds: 20));

    if (response.statusCode != 200) {
      throw Exception(
        'Não foi possível carregar as cifras da comunidade (${response.statusCode}).',
      );
    }

    final rawText = kIsWeb ? response.body : utf8.decode(response.bodyBytes);
    final list = jsonDecode(rawText) as List;
    if (list.isEmpty) {
      return [];
    }

    final first = list.first as Map<String, dynamic>;
    final dados = first['dados'] as Map<String, dynamic>? ?? {};
    final rawSongs = (dados['community_songs'] as List?) ?? [];

    final communitySongs = rawSongs
        .whereType<Map<String, dynamic>>()
        .map(CommunitySong.fromJson)
        .where((c) => c.song.title.trim().isNotEmpty && !c.song.deleted)
        .toList();

    communitySongs.sort((a, b) => b.sharedAt.compareTo(a.sharedAt));
    return communitySongs;
  }

  /// Publica uma ou mais músicas do usuário logado na Comunidade.
  /// Exige e-mail cadastrado e nickname informado.
  Future<List<CommunitySong>> publishSongs({
    required List<Song> songs,
    required String nickname,
    required String email,
    String? imageUrl,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanNickname = nickname.trim().replaceFirst(RegExp(r'^@+'), '');
    final cleanImage =
        (imageUrl != null && imageUrl.trim().isNotEmpty) ? imageUrl.trim() : null;

    if (cleanEmail.isEmpty || !cleanEmail.contains('@')) {
      throw const FormatException(
        'É necessário estar logado com e-mail e senha para compartilhar cifras na comunidade.',
      );
    }
    if (cleanNickname.isEmpty) {
      throw const FormatException(
        'Por favor, informe um nickname para identificar seu compartilhamento na comunidade.',
      );
    }
    if (songs.isEmpty) {
      throw const FormatException(
        'Selecione pelo menos uma música para compartilhar.',
      );
    }

    final current = await fetchCommunitySongs();
    final now = DateTime.now();

    final nickLower = cleanNickname.toLowerCase();
    final takenByOther = current.any(
      (c) =>
          c.sharedByNickname.trim().replaceFirst(RegExp(r'^@+'), '').toLowerCase() ==
              nickLower &&
          c.sharedByEmail.trim().toLowerCase() != cleanEmail,
    );
    if (takenByOther) {
      throw FormatException(
        'O nickname "@$cleanNickname" já está em uso por outro e-mail. Por favor, escolha outro nickname.',
      );
    }

    final newSongs = songs
        .where(
          (s) => !isSongSharedByUser(
            song: s,
            userEmail: cleanEmail,
            communitySongs: current,
          ),
        )
        .toList();

    if (newSongs.isEmpty) {
      throw const FormatException(
        'Esta(s) música(s) já foi(ram) compartilhada(s) por você na comunidade.',
      );
    }

    final byKey = <String, CommunitySong>{
      for (final item in current)
        normAuthorSongKey(
          item.sharedByEmail,
          item.song.title,
          item.song.artist,
        ): item,
    };

    for (var i = 0; i < newSongs.length; i++) {
      final s = newSongs[i];
      final key = normAuthorSongKey(cleanEmail, s.title, s.artist);
      final sharedAt = now.add(Duration(milliseconds: i));

      byKey[key] = CommunitySong(
        id: _uuid.v4(),
        song: s.copyWith(
          isFavorite: false,
          deleted: false,
          updatedAt: sharedAt,
        ),
        sharedByNickname: cleanNickname,
        sharedByEmail: cleanEmail,
        sharedAt: sharedAt,
        imageUrl: cleanImage ?? s.imageUrl,
        importCount: 0,
      );
    }

    final updatedList = byKey.values.toList()
      ..sort((a, b) => b.sharedAt.compareTo(a.sharedAt));

    await _saveCommunityFeed(updatedList);
    return updatedList;
  }

  /// Remove uma cifra do compartilhamento na comunidade (apenas da exibição na comunidade;
  /// usuários que já importaram mantêm suas cópias intactas em suas listas pessoais).
  Future<List<CommunitySong>> unpublishSong({
    required CommunitySong target,
    required String userEmail,
  }) async {
    final cleanEmail = userEmail.trim().toLowerCase();
    if (cleanEmail.isEmpty) {
      throw const FormatException(
        'Faça login na sua conta para remover cifras compartilhadas.',
      );
    }

    final current = await fetchCommunitySongs();
    final targetKey = normAuthorSongKey(
      target.sharedByEmail,
      target.song.title,
      target.song.artist,
    );

    final updatedList = current.where((item) {
      final isOwner = item.sharedByEmail.trim().toLowerCase() == cleanEmail;
      if (!isOwner) return true;
      final itemKey = normAuthorSongKey(
        item.sharedByEmail,
        item.song.title,
        item.song.artist,
      );
      final matchesTarget = item.id == target.id ||
          item.song.id == target.song.id ||
          itemKey == targetKey;
      return !matchesTarget;
    }).toList()
      ..sort((a, b) => b.sharedAt.compareTo(a.sharedAt));

    await _saveCommunityFeed(updatedList);
    return updatedList;
  }

  Future<void> _saveCommunityFeed(List<CommunitySong> updatedList) async {
    final nicknamesRegistry = <String, String>{};
    for (final item in updatedList) {
      final nick = item.sharedByNickname
          .trim()
          .replaceFirst(RegExp(r'^@+'), '')
          .toLowerCase();
      final email = item.sharedByEmail.trim().toLowerCase();
      if (nick.isNotEmpty && email.isNotEmpty) {
        nicknamesRegistry[nick] = email;
      }
    }

    final uri = Uri.parse('${AppConfig.supabaseUrl}/rest/v1/repertorios_sync');
    final payload = {
      'codigo': communityFeedCode,
      'dados': {
        'community_songs': updatedList.map((e) => e.toJson()).toList(),
        'nicknames_registry': nicknamesRegistry,
      },
      'atualizado_em': DateTime.now().toUtc().toIso8601String(),
    };

    final response = await http
        .post(uri, headers: _writeHeaders, body: jsonEncode(payload))
        .timeout(const Duration(seconds: 25));

    if (response.statusCode >= 300) {
      throw Exception(
        'Falha ao atualizar cifras na comunidade (${response.statusCode}): ${response.body}',
      );
    }
  }

  /// Importa uma cifra da comunidade para a lista pessoal do usuário (repositório local + sync pessoal)
  /// e contabiliza +1 import para a cifra compartilhada na comunidade.
  Future<Song> importSongToUserList({
    required CommunitySong communitySong,
    required SongRepository repository,
  }) async {
    final source = communitySong.song;
    final imported = Song(
      id: _uuid.v4(),
      title: source.title,
      artist: source.artist,
      content: source.content,
      originalKey: source.originalKey,
      isFavorite: false,
      tags: List<String>.from(source.tags),
      audioUrl: source.audioUrl,
      audioDurationSeconds: source.audioDurationSeconds,
      imageUrl: communitySong.imageUrl ?? source.imageUrl,
      updatedAt: DateTime.now(),
      deleted: false,
    );
    await repository.save(imported);

    try {
      await recordCommunitySongImport(communitySong);
    } catch (_) {}

    return imported;
  }

  /// Incrementa o contador de imports de uma cifra na comunidade.
  Future<List<CommunitySong>> recordCommunitySongImport(
    CommunitySong target,
  ) async {
    final current = await fetchCommunitySongs();
    final targetKey = normAuthorSongKey(
      target.sharedByEmail,
      target.song.title,
      target.song.artist,
    );
    final updatedList = current.map((item) {
      final itemKey = normAuthorSongKey(
        item.sharedByEmail,
        item.song.title,
        item.song.artist,
      );
      if (item.id == target.id || itemKey == targetKey) {
        return item.copyWith(importCount: item.importCount + 1);
      }
      return item;
    }).toList();

    await _saveCommunityFeed(updatedList);
    return updatedList;
  }
}

