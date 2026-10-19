import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/api_login_request.dart';
import '../models/api_login_response.dart';

class ApiAuthException implements Exception {
  final String message;

  const ApiAuthException(this.message);

  @override
  String toString() => message;
}

class ApiAuthService {
  final http.Client _client;
  final Uri _loginUri;

  ApiAuthService({required this._client, required this._loginUri}) {
    if (_loginUri.scheme != 'https' ||
        _loginUri.host.isEmpty ||
        _loginUri.userInfo.isNotEmpty ||
        _loginUri.hasQuery ||
        _loginUri.hasFragment) {
      throw ArgumentError('A valid HTTPS login URL is required.');
    }
  }

  Future<ApiLoginResponse> login({
    required String schoolId,
    required String password,
  }) async {
    final id = schoolId.trim();

    if (!RegExp(r'^\d{2}-\d{6}$').hasMatch(id)) {
      throw const ApiAuthException('Enter a valid School ID (00-000000).');
    }

    if (password.isEmpty) {
      throw const ApiAuthException('Please enter your password.');
    }

    final request = ApiLoginRequest(schoolId: id, password: password);

    late final http.Response response;

    try {
      response = await _client
          .post(
            _loginUri,
            headers: const {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
              'ngrok-skip-browser-warning': 'true',
            },
            body: jsonEncode(request.toJson()),
          )
          .timeout(const Duration(seconds: 20));
    } on TimeoutException {
      throw const ApiAuthException('Connection timed out. Try again.');
    } on SocketException catch (error) {
      if (kDebugMode) {
        debugPrint('EVENTEASE NETWORK ERROR: $error');
        debugPrint('EVENTEASE LOGIN HOST: ${_loginUri.host}');
      }

      throw ApiAuthException(
        'Cannot reach ${_loginUri.host}. '
        'Check your internet connection and ngrok tunnel.',
      );
    } on http.ClientException {
      throw const ApiAuthException('Network connection failed.');
    }

    Map<String, dynamic> data = {};

    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));

      if (decoded is Map<String, dynamic>) {
        data = decoded;
      }
    } on FormatException {
      // Handled as an unexpected response below.
    }

    if (response.statusCode == 401) {
      throw const ApiAuthException('Incorrect School ID or password.');
    }

    if (response.statusCode == 422) {
      String message = 'Please check your login details.';

      final errors = data['errors'];
      if (errors is Map) {
        for (final entry in errors.values) {
          if (entry is List && entry.isNotEmpty) {
            message = entry.first.toString();
            break;
          }
        }
      } else if (data['message'] is String) {
        message = data['message'];
      }

      throw ApiAuthException(message);
    }

    if (response.statusCode == 403) {
      throw const ApiAuthException(
        'Your account is inactive or access is denied.',
      );
    }

    if (response.statusCode == 404) {
      throw const ApiAuthException('Laravel login endpoint was not found.');
    }

    if (response.statusCode != 200) {
      throw ApiAuthException('Login failed (HTTP ${response.statusCode}).');
    }

    try {
      final session = ApiLoginResponse.fromJson(data);

      if (session.isExpired) {
        throw const ApiAuthException('The server returned an expired session.');
      }

      return session;
    } on FormatException {
      throw const ApiAuthException(
        'Laravel returned an unexpected login response.',
      );
    }
  }
}
