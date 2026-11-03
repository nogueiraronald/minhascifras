class Setlist {
  Setlist({
    required this.id,
    required this.name,
    this.notes = '',
    DateTime? updatedAt,
    this.deleted = false,
  }) : updatedAt = updatedAt ?? DateTime.now();

  final String id;
  final String name;
  final String notes;
  final DateTime updatedAt;
  final bool deleted;

  Setlist copyWith({String? name, String? notes, bool? deleted}) => Setlist(
        id: id,
        name: name ?? this.name,
        notes: notes ?? this.notes,
        updatedAt: DateTime.now(),
        deleted: deleted ?? this.deleted,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'notes': notes,
        'updatedAt': updatedAt.toIso8601String(),
        'deleted': deleted,
      };

  factory Setlist.fromJson(Map<String, dynamic> j) => Setlist(
        id: j['id'] as String,
        name: (j['name'] as String?) ?? '',
        notes: (j['notes'] as String?) ?? '',
        updatedAt: DateTime.tryParse((j['updatedAt'] as String?) ?? ''),
        deleted: (j['deleted'] as bool?) ?? false,
      );
}
