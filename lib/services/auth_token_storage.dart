import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/api_login_response.dart';

// ======================================================
// TMC EVENTEASE - AUTH TOKEN STORAGE
// For backend-issued API tokens only.
// ======================================================

class AuthTokenStorage {
  final FlutterSecureStorage _storage;

  AuthTokenStorage({FlutterSecureStorage? storage})
    : _storage = storage ?? FlutterSecureStorage();

  static const String _tokenKey = 'eventease_api_access_token';

  static const String _expiryKey = 'eventease_api_token_expiry';

  // ======================================================
  // SAVE TOKEN
  // ======================================================

  Future<void> save(ApiLoginResponse session) async {
    if (session.isExpired) {
      throw StateError('Cannot save an expired authentication session.');
    }

    await _storage.write(
      key: _expiryKey,
      value: session.expiresAt.toUtc().toIso8601String(),
    );

    await _storage.write(key: _tokenKey, value: session.accessToken);
  }

  // ======================================================
  // READ UNEXPIRED TOKEN
  // ======================================================

  Future<String?> readValidToken() async {
    final token = await _storage.read(key: _tokenKey);

    final expiryText = await _storage.read(key: _expiryKey);

    final expiry = expiryText == null ? null : DateTime.tryParse(expiryText);

    final minimumValidity = DateTime.now().toUtc().add(
      const Duration(seconds: 30),
    );

    if (token == null ||
        token.isEmpty ||
        expiry == null ||
        !expiry.toUtc().isAfter(minimumValidity)) {
      await clear();
      return null;
    }

    return token;
  }

  // ======================================================
  // CLEAR TOKEN DURING LOGOUT
  // ======================================================

  Future<void> clear() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _expiryKey);
  }
}
