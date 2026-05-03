class Visit {
  int? id;
  int customerId;
  String visitDate; // 拜访日期
  String? location;
  String? accompanyingPersons; // 随行人员
  String? productsPresented; // 已介绍产品 (Products presented/introduced to customer)
  String? interestedProducts; // 感兴趣产品
  String? competitors; // 竞品信息
  String? notes; // 拜访备注

  Visit({
    this.id,
    required this.customerId,
    required this.visitDate,
    this.location,
    this.accompanyingPersons,
    this.productsPresented,
    this.interestedProducts,
    this.competitors,
    this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'customer_id': customerId,
      'date': visitDate,
      'location': location,
      'accompanying_persons': accompanyingPersons,
      'introduced_products': productsPresented,
      'interested_products': interestedProducts,
      'competitors': competitors,
      'notes': notes,
    };
  }

  factory Visit.fromMap(Map<String, dynamic> map) {
    return Visit(
      id: (map['id'] as num?)?.toInt(),
      customerId: (map['customer_id'] as num?)?.toInt() ?? 0,
      visitDate: map['date'] as String? ?? '',
      location: map['location'] as String?,
      accompanyingPersons: map['accompanying_persons'] as String?,
      productsPresented: map['introduced_products'] as String?,
      interestedProducts: map['interested_products'] as String?,
      competitors: map['competitors'] as String?,
      notes: map['notes'] as String?,
    );
  }
}
