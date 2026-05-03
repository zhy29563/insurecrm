class Colleague {
  int? id;
  String name;
  String? phone;
  String? email;
  String? departmentAndRole; // 部门与职务 (Department and role, e.g. "销售经理", "市场专员")

  Colleague({
    this.id,
    required this.name,
    this.phone,
    this.email,
    this.departmentAndRole,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'email': email,
      'specialty': departmentAndRole,
    };
  }

  factory Colleague.fromMap(Map<String, dynamic> map) {
    return Colleague(
      id: (map['id'] as num?)?.toInt(),
      name: map['name'] as String? ?? '',
      phone: map['phone'] as String?,
      email: map['email'] as String?,
      departmentAndRole: map['specialty'] as String?,
    );
  }
}
