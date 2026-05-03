class Product {
  int? id;
  String company; // 保险公司名称
  String name; // 产品名称
  String? description;
  String? sellingPoints; // 产品卖点/优势 (Key advantages / selling points)
  String? category; // 产品类别
  String? salesStartDate; // 产品销售开始日期
  String? salesEndDate; // 产品销售结束日期
  String? createdAt;
  List<Map<String, dynamic>> attachments; // 产品附件列表

  Product({
    this.id,
    required this.company,
    required this.name,
    this.description,
    this.sellingPoints,
    this.category,
    this.salesStartDate,
    this.salesEndDate,
    this.createdAt,
    List<Map<String, dynamic>>? attachments,
  }) : attachments = attachments ?? [];

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'company': company,
      'name': name,
      'description': description,
      'advantages': sellingPoints,
      'category': category,
      'start_date': salesStartDate,
      'end_date': salesEndDate,
      'created_at': createdAt,
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: (map['id'] as num?)?.toInt(),
      company: map['company'] as String? ?? '',
      name: map['name'] as String? ?? '',
      description: map['description'] as String?,
      sellingPoints: map['advantages'] as String?,
      category: map['category'] as String?,
      salesStartDate: map['start_date'] as String?,
      salesEndDate: map['end_date'] as String?,
      createdAt: map['created_at'] as String?,
    );
  }
}
