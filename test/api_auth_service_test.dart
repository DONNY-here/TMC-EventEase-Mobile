import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:clone/services/api_auth_service.dart';

void main() {
  final loginUri = Uri.parse('https://example.test/api/auth/login');

  // ====================================================
  // TEST 1: SUCCESSFUL STUDENT API LOGIN
  // ====================================================

  test('API login sends JSON and reads student data', () async {
    final client = MockClient((request) async {
      expect(request.method, 'POST');
      expect(request.url, loginUri);

      final body = jsonDecode(request.body);

      expect(body['email'], 'student@test.local');
      expect(body['password'], 'test-password');

      return http.Response(
        jsonEncode({
          'access_token': 'fake-access-token',
          'expires_at': DateTime.now()
              .toUtc()
              .add(const Duration(hours: 1))
              .toIso8601String(),
          'user': {
            'id': '123',
            'name': 'Demo Student',
            'email': 'student@test.local',
            'role': 'student',
          },
        }),
        200,
      );
    });

    addTearDown(client.close);

    final service = ApiAuthService(client: client, loginUri: loginUri);

    final result = await service.login(
      email: 'student@test.local',
      password: 'test-password',
    );

    expect(result.user.id, '123');
    expect(result.user.isStudent, true);
    expect(result.isExpired, false);
    expect(result.accessToken, 'fake-access-token');
  });

  // ====================================================
  // TEST 2: INCORRECT PASSWORD
  // ====================================================

  test('API login rejects incorrect credentials', () async {
    final client = MockClient((request) async {
      return http.Response('{"message":"Invalid credentials"}', 401);
    });

    addTearDown(client.close);

    final service = ApiAuthService(client: client, loginUri: loginUri);

    await expectLater(
      service.login(email: 'student@test.local', password: 'wrong-password'),
      throwsA(isA<ApiAuthException>()),
    );
  });

  // ====================================================
  // TEST 3: REJECT INSECURE HTTP
  // ====================================================

  test('API service requires HTTPS', () {
    final client = MockClient((request) async {
      return http.Response('', 200);
    });

    addTearDown(client.close);

    expect(
      () => ApiAuthService(
        client: client,
        loginUri: Uri.parse('http://example.test/api/auth/login'),
      ),
      throwsArgumentError,
    );
  });

  // ====================================================
  // TEST 4: EXPIRED TOKEN
  // ====================================================

  test('API login rejects expired tokens', () async {
    final client = MockClient((request) async {
      return http.Response(
        jsonEncode({
          'access_token': 'expired-test-token',
          'expires_at': DateTime.now()
              .toUtc()
              .subtract(const Duration(hours: 1))
              .toIso8601String(),
          'user': {
            'id': '124',
            'name': 'TMC Event Officer',
            'email': 'scanner@test.local',
            'role': 'scanner',
          },
        }),
        200,
      );
    });

    addTearDown(client.close);

    final service = ApiAuthService(client: client, loginUri: loginUri);

    await expectLater(
      service.login(email: 'scanner@test.local', password: 'test-password'),
      throwsA(isA<ApiAuthException>()),
    );
  });
}
