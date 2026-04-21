class User {
  int? id;
  String username;
  String passwordHash;
  String? displayName;
  String? role;
  String? securityQuestion;
  int isActive;
  String? createdAt;
  String? lastLogin;

  User({
    this.id,
    required this.username,
    required this.passwordHash,
    this.displayName,
    this.role = 'user',
    this.securityQuestion,
    this.isActive = 1,
    this.createdAt,
    this.lastLogin,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'username': username,
      'password_hash': passwordHash,
      'display_name': displayName,
      'role': role,
      'security_question': securityQuestion,
      'is_active': isActive,
      'created_at': createdAt,
      'last_login': lastLogin,
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'],
      username: map['username'],
      passwordHash: map['password_hash'] ?? '',
      displayName: map['display_name'],
      role: map['role'] ?? 'user',
      securityQuestion: map['security_question'],
      isActive: map['is_active'] ?? 1,
      createdAt: map['created_at'],
      lastLogin: map['last_login'],
    );
  }

  /// Check if user is admin
  bool get isAdmin => role == 'admin';

  /// Get display name or fallback
  String get displayNameOrUsername => (displayName != null && displayName!.isNotEmpty)
      ? displayName! : username;
}
