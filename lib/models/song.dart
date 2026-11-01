class Song {
  Song({
    required this.id,
    required this.title,
    required this.content,
    this.artist = '',
    this.originalKey = '',
    DateTime? updatedAt,
    this.deleted = false,
  }) : updatedAt = updatedAt ?? DateTime.now();

  final String id;
  final String title;
  final String artist;
  final String content;
  final String originalKey;
  final DateTime updatedAt;
  final bool deleted;

  Song copyWith({
    String? title,
    String? artist,
    String? content,
    String? originalKey,
    bool? deleted,
  }) {
    return Song(
      id: id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      content: content ?? this.content,
      originalKey: originalKey ?? this.originalKey,
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
        'updatedAt': updatedAt.toIso8601String(),
        'deleted': deleted,
      };

  factory Song.fromJson(Map<String, dynamic> j) => Song(
        id: j['id'] as String,
        title: j['title'] as String,
        artist: (j['artist'] as String?) ?? '',
        content: (j['content'] as String?) ?? '',
        originalKey: (j['originalKey'] as String?) ?? '',
        updatedAt: DateTime.tryParse((j['updatedAt'] as String?) ?? ''),
        deleted: (j['deleted'] as bool?) ?? false,
      );
}
