class Product {
  int? id;
  String company;
  String name;
  String? description;
  String? advantages;
  String? category;
  String? startDate;
  String? endDate;
  String? createdAt;
  List<Map<String, dynamic>> attachments; // 产品附件列表

  Product({
    this.id,
    required this.company,
    required this.name,
    this.description,
    this.advantages,
    this.category,
    this.startDate,
    this.endDate,
    this.createdAt,
    List<Map<String, dynamic>>? attachments,
  }) : attachments = attachments ?? [];

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'company': company,
      'name': name,
      'description': description,
      'advantages': advantages,
      'category': category,
      'start_date': startDate,
      'end_date': endDate,
      'created_at': createdAt,
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'],
      company: map['company'],
      name: map['name'],
      description: map['description'],
      advantages: map['advantages'],
      category: map['category'],
      startDate: map['start_date'],
      endDate: map['end_date'],
      createdAt: map['created_at'],
    );
  }
}
