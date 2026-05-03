class User {
  int? id;
  String username;
  String passwordHash;
  String? displayName;
  String? role;
  String? securityQuestion; // 密保问题 (Password Reset Security Question)
  String? securityAnswerHash; // 密保答案哈希 (Security answer hash)
  int activeStatus; // 账号活跃状态 (Active status: 1=active, 0=disabled)
  String? createdAt;
  String? lastLogin;

  User({
    this.id,
    required this.username,
    required this.passwordHash,
    this.displayName,
    this.role = 'user',
    this.securityQuestion,
    this.securityAnswerHash,
    this.activeStatus = 1,
    this.createdAt,
    this.lastLogin,
  });

  /// 是否处于活跃状态
  bool get isActive => activeStatus == 1;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'username': username,
      'password_hash': passwordHash,
      'display_name': displayName,
      'role': role,
      'security_question': securityQuestion,
      'security_answer_hash': securityAnswerHash,
      'is_active': activeStatus,
      'created_at': createdAt,
      'last_login': lastLogin,
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: (map['id'] as num?)?.toInt(),
      username: map['username'] as String? ?? '',
      passwordHash: map['password_hash'] as String? ?? '',
      displayName: map['display_name'] as String?,
      role: map['role'] as String? ?? 'user',
      securityQuestion: map['security_question'] as String?,
      securityAnswerHash: map['security_answer_hash'] as String?,
      activeStatus: (map['is_active'] as num?)?.toInt() ?? 1,
      createdAt: map['created_at'] as String?,
      lastLogin: map['last_login'] as String?,
    );
  }

  /// Check if user is admin
  bool get isAdmin => role == 'admin';

  /// Get display name or fallback to username
  String get displayNameOrUsername => (displayName != null && displayName!.isNotEmpty)
      ? displayName! : username;
}
