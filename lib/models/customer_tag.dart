class CustomerTag {
  int? id;
  int customerId;
  String tag;

  CustomerTag({
    this.id,
    required this.customerId,
    required this.tag,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'customer_id': customerId,
      'tag': tag,
    };
  }

  factory CustomerTag.fromMap(Map<String, dynamic> map) {
    return CustomerTag(
      id: (map['id'] as num?)?.toInt(),
      customerId: (map['customer_id'] as num?)?.toInt() ?? 0,
      tag: map['tag'] as String? ?? '',
    );
  }
}
