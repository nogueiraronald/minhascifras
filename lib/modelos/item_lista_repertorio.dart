/// Música dentro de uma setlist, com posição e tom próprios.
/// [transpose] = semitons em relação à cifra original (ex.: +2).
class SetlistItem {
  SetlistItem({
    required this.id,
    required this.setlistId,
    required this.songId,
    required this.position,
    this.transpose = 0,
    DateTime? updatedAt,
    this.deleted = false,
  }) : updatedAt = updatedAt ?? DateTime.now();

  final String id;
  final String setlistId;
  final String songId;
  final int position;
  final int transpose;
  final DateTime updatedAt;
  final bool deleted;

  SetlistItem copyWith({int? position, int? transpose, bool? deleted}) => SetlistItem(
        id: id,
        setlistId: setlistId,
        songId: songId,
        position: position ?? this.position,
        transpose: transpose ?? this.transpose,
        updatedAt: DateTime.now(),
        deleted: deleted ?? this.deleted,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'setlistId': setlistId,
        'songId': songId,
        'position': position,
        'transpose': transpose,
        'updatedAt': updatedAt.toIso8601String(),
        'deleted': deleted,
      };

  factory SetlistItem.fromJson(Map<String, dynamic> j) => SetlistItem(
        id: j['id'] as String,
        setlistId: j['setlistId'] as String,
        songId: j['songId'] as String,
        position: (j['position'] as int?) ?? 0,
        transpose: (j['transpose'] as int?) ?? 0,
        updatedAt: DateTime.tryParse((j['updatedAt'] as String?) ?? ''),
        deleted: (j['deleted'] as bool?) ?? false,
      );
}
