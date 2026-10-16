class AuthUser {
  final String id;
  final String name;
  final String email;
  final String role;

  const AuthUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
  });

  bool get isStudent => role == 'student';

  bool get isScanner => role == 'scanner' || role == 'admin';

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id'].toString(),
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      role: json['role'] as String? ?? 'student',
    );
  }
}
