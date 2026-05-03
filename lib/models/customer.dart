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

  /// Legacy: comma-separated tags string, kept for backward compatibility;
  /// prefer [persistentTagList] from the customer_tags join table.
  String? tags;

  /// Legacy: pipe-separated photo paths string, kept for backward compatibility;
  /// prefer [persistentPhotoList] from the customer_photos table.
  String? photos;

  String? nextFollowUpDate;
  String? createdAt;

  /// Tags loaded from the customer_tags join table (persistent storage).
  List<String> persistentTagList;

  /// Photos loaded from the customer_photos table (persistent storage).
  List<String> persistentPhotoList;

  // v9 new fields
  String? wechatId; // 微信账号 (WeChat ID / account)
  String? idCardNumber; // 身份证号 (Identity Card Number)
  String? occupation;
  String? source;
  String? notes; // 客户备注
  int? purchaseIntentionLevel; // 购买意向等级 (1-5 scale)

  // Cached computed lists to avoid repeated string splitting
  List<String>? _cachedTagList;
  List<String>? _cachedPhotoList;

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
    List<String>? phones,
    List<String>? addresses,
    List<Map<String, dynamic>>? visits,
    List<Map<String, dynamic>>? products,
    List<Map<String, dynamic>>? relationships,
    this.birthday,
    this.tags,
    this.photos,
    this.nextFollowUpDate,
    this.createdAt,
    List<String>? persistentTagList,
    List<String>? persistentPhotoList,
    this.wechatId,
    this.idCardNumber,
    this.occupation,
    this.source,
    this.notes,
    this.purchaseIntentionLevel,
  })  : phones = phones ?? [],
        addresses = addresses ?? [],
        visits = visits ?? [],
        products = products ?? [],
        relationships = relationships ?? [],
        persistentTagList = persistentTagList ?? [],
        persistentPhotoList = persistentPhotoList ?? [];

  /// Unified tag list: prefers persistentTagList (from separate table), falls back to tags string.
  /// Results are cached to avoid repeated string splitting on every access.
  List<String> get tagList {
    if (_cachedTagList != null) return _cachedTagList!;
    if (persistentTagList.isNotEmpty) {
      _cachedTagList = persistentTagList;
    } else if (tags == null || tags!.isEmpty) {
      _cachedTagList = const [];
    } else {
      _cachedTagList = tags!.split(',').where((t) => t.isNotEmpty).toList();
    }
    return _cachedTagList!;
  }

  /// Unified photo list: prefers persistentPhotoList, falls back to legacy photos string.
  /// Results are cached to avoid repeated string splitting on every access.
  List<String> get photoList {
    if (_cachedPhotoList != null) return _cachedPhotoList!;
    if (persistentPhotoList.isNotEmpty) {
      _cachedPhotoList = persistentPhotoList;
    } else if (photos == null || photos!.isEmpty) {
      _cachedPhotoList = const [];
    } else {
      _cachedPhotoList = photos!.split('|').where((p) => p.isNotEmpty).toList();
    }
    return _cachedPhotoList!;
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
      'next_follow_up_date': nextFollowUpDate,
      'created_at': createdAt,
      'wechat': wechatId,
      'id_number': idCardNumber,
      'occupation': occupation,
      'source': source,
      'remark': notes,
      'purchase_intention': purchaseIntentionLevel,
      'tags': tags,
      'photos': photos,
    };
  }

  factory Customer.fromMap(Map<String, dynamic> map, {
    List<String> phones = const [],
    List<String> addresses = const [],
    List<Map<String, dynamic>> visits = const [],
    List<Map<String, dynamic>> products = const [],
    List<Map<String, dynamic>> relationships = const [],
    List<String> persistentTagList = const [],
    List<String> persistentPhotoList = const [],
  }) {
    return Customer(
      id: (map['id'] as num?)?.toInt(),
      name: map['name'] as String? ?? '',
      alias: map['alias'] as String?,
      age: (map['age'] as num?)?.toInt(),
      gender: map['gender'] as String?,
      rating: ((map['rating'] as num?)?.toInt())?.clamp(0, 5),
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      address: map['address'] as String?,
      phones: phones,
      addresses: addresses,
      visits: visits,
      products: products,
      relationships: relationships,
      birthday: map['birthday'] as String?,
      tags: map['tags'] as String?,
      photos: map['photos'] as String?,
      nextFollowUpDate: map['next_follow_up_date'] as String?,
      createdAt: map['created_at'] as String?,
      persistentTagList: persistentTagList,
      persistentPhotoList: persistentPhotoList,
      wechatId: map['wechat'] as String?,
      idCardNumber: map['id_number'] as String?,
      occupation: map['occupation'] as String?,
      source: map['source'] as String?,
      notes: map['remark'] as String?,
      purchaseIntentionLevel: ((map['purchase_intention'] as num?)?.toInt())?.clamp(0, 5),
    );
  }
}
