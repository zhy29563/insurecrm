class CustomerTag {
  int? id;
  int customerId;
  int tagId;
  DateTime assignedAt;

  CustomerTag({
    this.id,
    required this.customerId,
    required this.tagId,
    DateTime? assignedAt,
  }) : assignedAt = assignedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'customer_id': customerId,
      'tag_id': tagId,
      'assigned_at': assignedAt.toIso8601String(),
    };
  }

  factory CustomerTag.fromMap(Map<String, dynamic> map) {
    return CustomerTag(
      id: map['id'],
      customerId: map['customer_id'],
      tagId: map['tag_id'],
      assignedAt: DateTime.parse(map['assigned_at']),
    );
  }
}
