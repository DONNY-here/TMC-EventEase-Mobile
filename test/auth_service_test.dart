
import 'package:flutter_test/flutter_test.dart';
import 'package:clone/services/auth_service.dart';

void main() {
  late AuthService authService;

  setUp(() {
    authService = AuthService();
  });

  // TEST 1: STUDENT LOGIN
  test('Student demo account can log in', () async {
    final user = await authService.login(
      email: 'student@test.local',
      password: 'StudentDemo123!',
    );

    expect(user, isNotNull);
    expect(user!.role, 'student');
    expect(user.isStudent, true);
    expect(authService.isLoggedIn, true);
  });

  // TEST 2: SCANNER LOGIN
  test('Scanner demo account can log in', () async {
    final user = await authService.login(
      email: 'scanner@test.local',
      password: 'ScannerDemo123!',
    );

    expect(user, isNotNull);
    expect(user!.role, 'scanner');
    expect(user.isScanner, true);
  });

  // TEST 3: INVALID LOGIN
  test('Invalid credentials are rejected', () async {
    final user = await authService.login(
      email: 'unknown@test.local',
      password: 'wrong-password',
    );

    expect(user, isNull);
    expect(authService.isLoggedIn, false);
  });

  // TEST 4: LOGOUT
  test('Logout clears the current user', () async {
    await authService.login(
      email: 'student@test.local',
      password: 'StudentDemo123!',
    );

    authService.logout();

    expect(authService.currentUser, isNull);
    expect(authService.isLoggedIn, false);
  });

  // TEST 5: LOCAL STUDENT SESSION
  test('Local student session is created and cleared', () {
    authService.startLocalStudentSession(
      name: 'TMC Student',
      email: 'student@example.com',
    );

    expect(authService.isLoggedIn, true);
    expect(authService.currentUser, isNotNull);
    expect(authService.currentUser!.isStudent, true);
    expect(
      authService.currentUser!.email,
      'student@example.com',
    );

    authService.logout();

    expect(authService.isLoggedIn, false);
    expect(authService.currentUser, isNull);
  });
}
