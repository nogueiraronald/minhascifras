import 'musica.dart';

/// Representa uma cifra compartilhada na Comunidade para acesso online.
class CommunitySong {
  CommunitySong({
    required this.id,
    required this.song,
    required this.sharedByNickname,
    required this.sharedByEmail,
    DateTime? sharedAt,
    String? imageUrl,
    this.importCount = 0,
  })  : sharedAt = sharedAt ?? DateTime.now(),
        imageUrl = imageUrl ?? song.imageUrl;

  final String id;
  final Song song;
  final String sharedByNickname;
  final String sharedByEmail;
  final DateTime sharedAt;
  final String? imageUrl;
  final int importCount;

  bool get hasImage => imageUrl != null && imageUrl!.trim().isNotEmpty;

  /// Formata a data de disponibilização no padrão brasileiro (dd/MM/yyyy)
  String get formattedDate {
    final local = sharedAt.toLocal();
    final d = local.day.toString().padLeft(2, '0');
    final m = local.month.toString().padLeft(2, '0');
    final y = local.year.toString();
    return '$d/$m/$y';
  }

  /// Formata data e hora da disponibilização (dd/MM/yyyy às HH:mm)
  String get formattedDateTime {
    final local = sharedAt.toLocal();
    final d = local.day.toString().padLeft(2, '0');
    final m = local.month.toString().padLeft(2, '0');
    final y = local.year.toString();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$d/$m/$y às $hh:$mm';
  }

  CommunitySong copyWith({
    String? id,
    Song? song,
    String? sharedByNickname,
    String? sharedByEmail,
    DateTime? sharedAt,
    String? imageUrl,
    int? importCount,
  }) {
    return CommunitySong(
      id: id ?? this.id,
      song: song ?? this.song,
      sharedByNickname: sharedByNickname ?? this.sharedByNickname,
      sharedByEmail: sharedByEmail ?? this.sharedByEmail,
      sharedAt: sharedAt ?? this.sharedAt,
      imageUrl: imageUrl ?? this.imageUrl,
      importCount: importCount ?? this.importCount,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'song': song.toJson(),
        'sharedByNickname': sharedByNickname,
        'sharedByEmail': sharedByEmail,
        'sharedAt': sharedAt.toUtc().toIso8601String(),
        'imageUrl': imageUrl,
        'importCount': importCount,
      };

  factory CommunitySong.fromJson(Map<String, dynamic> json) {
    final songMap = json['song'] as Map<String, dynamic>? ?? {};
    return CommunitySong(
      id: (json['id'] as String?) ?? '',
      song: Song.fromJson(songMap),
      sharedByNickname: (json['sharedByNickname'] as String?) ?? 'Músico',
      sharedByEmail: (json['sharedByEmail'] as String?) ?? '',
      sharedAt: DateTime.tryParse((json['sharedAt'] as String?) ?? '') ??
          DateTime.now(),
      imageUrl: json['imageUrl'] as String?,
      importCount: (json['importCount'] as num?)?.toInt() ?? 0,
    );
  }
}

