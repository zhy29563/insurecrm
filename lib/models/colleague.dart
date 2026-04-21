class Colleague {
  int? id;
  String name;
  String? phone;
  String? email;
  String? specialty;

  Colleague({
    this.id,
    required this.name,
    this.phone,
    this.email,
    this.specialty,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'email': email,
      'specialty': specialty,
    };
  }

  factory Colleague.fromMap(Map<String, dynamic> map) {
    return Colleague(
      id: map['id'],
      name: map['name'],
      phone: map['phone'],
      email: map['email'],
      specialty: map['specialty'],
    );
  }
}