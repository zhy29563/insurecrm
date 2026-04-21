class Customer {
  int? id;
  String name;
  String? alias;
  int? age;
  String? gender;
  int? rating;
  double? latitude;
  double? longitude;
  String? address;
  List<String> phones;
  List<String> addresses;
  List<Map<String, dynamic>> visits;
  List<Map<String, dynamic>> products;
  List<Map<String, dynamic>> relationships;
  String? birthday;
  String? tags;
  String? photos;
  String? nextFollowUpDate;
  String? createdAt;
  List<String> tagListFromDb; // Tags loaded from customer_tags table

  Customer({
    this.id,
    required this.name,
    this.alias,
    this.age,
    this.gender,
    this.rating,
    this.latitude,
    this.longitude,
    this.address,
    this.phones = const [],
    this.addresses = const [],
    this.visits = const [],
    this.products = const [],
    this.relationships = const [],
    this.birthday,
    this.tags,
    this.photos,
    this.nextFollowUpDate,
    this.createdAt,
    this.tagListFromDb = const [],
  });

  /// Unified tag list: prefers tagListFromDb (from separate table), falls back to tags string
  List<String> get tagList {
    if (tagListFromDb.isNotEmpty) return tagListFromDb;
    if (tags == null || tags!.isEmpty) return [];
    return tags!.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList();
  }

  List<String> get photoList {
    if (photos == null || photos!.isEmpty) return [];
    return photos!.split('|').where((p) => p.isNotEmpty).toList();
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'alias': alias,
      'age': age,
      'gender': gender,
      'rating': rating,
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'birthday': birthday,
      'tags': tags,
      'photos': photos,
      'next_follow_up_date': nextFollowUpDate,
      'created_at': createdAt,
    };
  }

  factory Customer.fromMap(Map<String, dynamic> map, {
    List<String> phones = const [],
    List<String> addresses = const [],
    List<Map<String, dynamic>> visits = const [],
    List<Map<String, dynamic>> products = const [],
    List<Map<String, dynamic>> relationships = const [],
    List<String> tagListFromDb = const [],
  }) {
    return Customer(
      id: map['id'],
      name: map['name'],
      alias: map['alias'],
      age: map['age'],
      gender: map['gender'],
      rating: map['rating'],
      latitude: map['latitude'],
      longitude: map['longitude'],
      address: map['address'],
      phones: phones,
      addresses: addresses,
      visits: visits,
      products: products,
      relationships: relationships,
      birthday: map['birthday'],
      tags: map['tags'],
      photos: map['photos'],
      nextFollowUpDate: map['next_follow_up_date'],
      createdAt: map['created_at'],
      tagListFromDb: tagListFromDb,
    );
  }
}
