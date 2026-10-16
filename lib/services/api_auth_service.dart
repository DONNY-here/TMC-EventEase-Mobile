import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/api_login_request.dart';
import '../models/api_login_response.dart';

// ======================================================
// TMC EVENTEASE - API AUTHENTICATION ERRORS
// ======================================================

class ApiAuthException implements Exception {
  final String message;

  const ApiAuthException(this.message);

  @override
  String toString() => message;
}

// ======================================================
// TMC EVENTEASE - REAL API AUTHENTICATION SERVICE
// Not connected to LoginPage yet.
// ======================================================

class ApiAuthService {
  final http.Client _client;
  final Uri _loginUri;

  ApiAuthService({required this._client, required this._loginUri}) {
    // Real credentials must be sent over HTTPS.
    if (_loginUri.scheme != 'https' ||
        _loginUri.host.isEmpty ||
        _loginUri.userInfo.isNotEmpty ||
        _loginUri.hasQuery ||
        _loginUri.hasFragment) {
      throw ArgumentError('A valid HTTPS login URL is required.');
    }
  }

  // ======================================================
  // LOGIN THROUGH THE WEB API
  // ======================================================

  Future<ApiLoginResponse> login({
    required String email,
    required String password,
  }) async {
    if (email.trim().isEmpty || password.isEmpty) {
      throw const ApiAuthException('Please enter your email and password.');
    }

    final request = ApiLoginRequest(email: email, password: password);

    late final http.Response response;

    try {
      response = await _client
          .post(
            _loginUri,
            headers: const {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(request.toJson()),
          )
          .timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw const ApiAuthException('Connection timed out. Please try again.');
    } on http.ClientException {
      throw const ApiAuthException('Unable to connect to the server.');
    }

    // ======================================================
    // HANDLE HTTP RESPONSE STATUS
    // ======================================================

    if (response.statusCode == 401) {
      throw const ApiAuthException('Incorrect email or password.');
    }

    if (response.statusCode == 403) {
      throw const ApiAuthException('This account is not allowed to sign in.');
    }

    if (response.statusCode != 200) {
      throw const ApiAuthException(
        'Login service is unavailable. Try again later.',
      );
    }

    // ======================================================
    // PARSE SUCCESSFUL RESPONSE
    // ======================================================

    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));

      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Unexpected response structure.');
      }

      final result = ApiLoginResponse.fromJson(decoded);

      if (result.isExpired) {
        throw const ApiAuthException('The server returned an expired session.');
      }

      return result;
    } on FormatException {
      throw const ApiAuthException('Unexpected response from the server.');
    }
  }
}
