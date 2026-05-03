class Tag {
  int? id;
  String name;
  String color; // 颜色值，如 #FF5733
  String? description;
  DateTime createdAt;
  DateTime updatedAt;

  Tag({
    this.id,
    required this.name,
    required this.color,
    this.description,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'color': color,
      'description': description,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory Tag.fromMap(Map<String, dynamic> map) {
    return Tag(
      id: (map['id'] as num?)?.toInt(),
      name: map['name'] as String? ?? '',
      color: map['color'] as String? ?? '#1565C0',
      description: map['description'] as String?,
      createdAt: DateTime.tryParse(map['created_at'] as String? ?? '') ?? DateTime(2000),
      updatedAt: DateTime.tryParse(map['updated_at'] as String? ?? '') ?? DateTime(2000),
    );
  }
}
