import 'auth_user.dart';

// ======================================================
// TMC EVENTEASE - API LOGIN RESPONSE
// ======================================================

class ApiLoginResponse {
  final String accessToken;
  final DateTime expiresAt;
  final AuthUser user;

  const ApiLoginResponse({
    required this.accessToken,
    required this.expiresAt,
    required this.user,
  });

  factory ApiLoginResponse.fromJson(Map<String, dynamic> json) {
    final token = json['access_token'];
    final expiry = json['expires_at'];
    final userData = json['user'];

    if (token is! String || token.isEmpty) {
      throw const FormatException('Missing access token.');
    }

    if (expiry is! String) {
      throw const FormatException('Missing token expiration.');
    }

    final parsedExpiry = DateTime.tryParse(expiry);

    if (parsedExpiry == null || !parsedExpiry.isUtc) {
      throw const FormatException('Invalid UTC expiration.');
    }

    if (userData is! Map<String, dynamic>) {
      throw const FormatException('Missing user information.');
    }

    final user = AuthUser.fromJson(userData);

    if (user.id.isEmpty ||
        user.name.isEmpty ||
        user.email.isEmpty ||
        (user.role != 'student' && user.role != 'scanner')) {
      throw const FormatException('Invalid mobile account information.');
    }

    return ApiLoginResponse(
      accessToken: token,
      expiresAt: parsedExpiry,
      user: user,
    );
  }

  bool get isExpired => !expiresAt.isAfter(DateTime.now().toUtc());
}
