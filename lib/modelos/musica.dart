class Song {
  Song({
    required this.id,
    required this.title,
    required this.content,
    this.artist = '',
    this.originalKey = '',
    this.isFavorite = false,
    this.tags = const [],
    this.audioUrl,
    this.audioDurationSeconds,
    DateTime? updatedAt,
    this.deleted = false,
  }) : updatedAt = updatedAt ?? DateTime.now();

  final String id;
  final String title;
  final String artist;
  final String content;
  final String originalKey;
  final bool isFavorite;
  final List<String> tags;
  final String? audioUrl;
  final int? audioDurationSeconds;
  final DateTime updatedAt;
  final bool deleted;

  bool get hasAudio => audioUrl != null && audioUrl!.trim().isNotEmpty;

  /// Retorna o tipo de áudio ('youtube', 'mp3', ou 'none')
  String get audioType {
    if (!hasAudio) return 'none';
    final u = audioUrl!.trim();
    if (extractYoutubeVideoId(u) != null ||
        u.toLowerCase().contains('youtube.com') ||
        u.toLowerCase().contains('youtu.be')) {
      return 'youtube';
    }
    return 'mp3';
  }

  /// Extrai o ID do vídeo do YouTube de qualquer formato de link (incluindo redirecionamentos do Google)
  static String? extractYoutubeVideoId(String input) {
    var raw = input.trim();
    if (raw.isEmpty) return null;

    if (raw.contains('google.com/url') && raw.contains('url=')) {
      try {
        final uri = Uri.parse(raw);
        final targetUrl = uri.queryParameters['url'];
        if (targetUrl != null && targetUrl.isNotEmpty) {
          raw = Uri.decodeFull(targetUrl);
        }
      } catch (_) {}
    }

    final regExp = RegExp(
      r'(?:youtube\.com\/(?:[^\/]+\/.+\/|(?:v|e(?:mbed)?|shorts)\/|.*[?&]v=)|youtu\.be\/)([^"&?\/\s]{11})',
      caseSensitive: false,
    );
    final match = regExp.firstMatch(raw);
    if (match != null && match.groupCount >= 1) {
      return match.group(1);
    }

    if (RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(raw)) {
      return raw;
    }
    return null;
  }

  /// Limpa e normaliza a URL de áudio (desempacota redirects do Google para URLs diretas)
  static String? cleanAudioUrl(String? input) {
    if (input == null) return null;
    final trimmed = input.trim();
    if (trimmed.isEmpty) return null;
    final ytId = extractYoutubeVideoId(trimmed);
    if (ytId != null) {
      return 'https://www.youtube.com/watch?v=$ytId';
    }
    return trimmed;
  }

  /// Retorna o nome amigável do serviço
  String get audioServiceName {
    switch (audioType) {
      case 'youtube':
        return 'YouTube';
      case 'mp3':
        return 'Arquivo MP3';
      default:
        return 'Nenhum';
    }
  }

  /// Formata duração em segundos para mm:ss (ex: 215 -> "03:35")
  static String formatDuration(int? totalSeconds) {
    if (totalSeconds == null || totalSeconds <= 0) return '--:--';
    final m = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  /// Converte texto "mm:ss" ou segundos numéricos para inteiro em segundos
  static int? parseDuration(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.contains(':')) {
      final parts = trimmed.split(':');
      if (parts.length == 2) {
        final m = int.tryParse(parts[0]) ?? 0;
        final s = int.tryParse(parts[1]) ?? 0;
        return m * 60 + s;
      }
    }
    return int.tryParse(trimmed);
  }

  Song copyWith({
    String? title,
    String? artist,
    String? content,
    String? originalKey,
    bool? isFavorite,
    List<String>? tags,
    String? audioUrl,
    int? audioDurationSeconds,
    bool? deleted,
  }) {
    return Song(
      id: id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      content: content ?? this.content,
      originalKey: originalKey ?? this.originalKey,
      isFavorite: isFavorite ?? this.isFavorite,
      tags: tags ?? this.tags,
      audioUrl: audioUrl ?? this.audioUrl,
      audioDurationSeconds: audioDurationSeconds ?? this.audioDurationSeconds,
      updatedAt: DateTime.now(),
      deleted: deleted ?? this.deleted,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'artist': artist,
        'content': content,
        'originalKey': originalKey,
        'isFavorite': isFavorite,
        'tags': tags,
        if (audioUrl != null) 'audioUrl': audioUrl,
        if (audioDurationSeconds != null) 'audioDurationSeconds': audioDurationSeconds,
        'updatedAt': updatedAt.toIso8601String(),
        'deleted': deleted,
      };

  factory Song.fromJson(Map<String, dynamic> j) => Song(
        id: j['id'] as String,
        title: j['title'] as String,
        artist: (j['artist'] as String?) ?? '',
        content: (j['content'] as String?) ?? '',
        originalKey: (j['originalKey'] as String?) ?? '',
        isFavorite: (j['isFavorite'] as bool?) ?? false,
        tags: (j['tags'] as List?)?.map((e) => e.toString()).toList() ?? const [],
        audioUrl: j['audioUrl'] as String?,
        audioDurationSeconds: (j['audioDurationSeconds'] as num?)?.toInt(),
        updatedAt: DateTime.tryParse((j['updatedAt'] as String?) ?? ''),
        deleted: (j['deleted'] as bool?) ?? false,
      );
}
