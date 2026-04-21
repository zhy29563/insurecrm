class Visit {
  int? id;
  int customerId;
  String date;
  String? location;
  String? accompanyingPersons;
  String? introducedProducts;
  String? interestedProducts;
  String? competitors;
  String? notes;

  Visit({
    this.id,
    required this.customerId,
    required this.date,
    this.location,
    this.accompanyingPersons,
    this.introducedProducts,
    this.interestedProducts,
    this.competitors,
    this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'customer_id': customerId,
      'date': date,
      'location': location,
      'accompanying_persons': accompanyingPersons,
      'introduced_products': introducedProducts,
      'interested_products': interestedProducts,
      'competitors': competitors,
      'notes': notes,
    };
  }

  factory Visit.fromMap(Map<String, dynamic> map) {
    return Visit(
      id: map['id'],
      customerId: map['customer_id'],
      date: map['date'],
      location: map['location'],
      accompanyingPersons: map['accompanying_persons'],
      introducedProducts: map['introduced_products'],
      interestedProducts: map['interested_products'],
      competitors: map['competitors'],
      notes: map['notes'],
    );
  }
}
