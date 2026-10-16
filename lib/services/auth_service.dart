import '../models/auth_user.dart';

// ======================================================
// TMC EVENTEASE - MOCK AUTHENTICATION SERVICE
// ======================================================

class AuthService {
  AuthUser? _currentUser;

  AuthUser? get currentUser => _currentUser;

  bool get isLoggedIn => _currentUser != null;
  void startLocalStudentSession({required String name, required String email}) {
    final normalizedEmail = email.trim().toLowerCase();

    _currentUser = AuthUser(
      id: 'local-student:$normalizedEmail',
      name: name.trim().isEmpty ? 'Student' : name.trim(),
      email: normalizedEmail,
      role: 'student',
    );
  }

  Future<AuthUser?> login({
    required String email,
    required String password,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));

    final normalizedEmail = email.trim().toLowerCase();

    // STUDENT DEMO ACCOUNT
    if (normalizedEmail == 'student@test.local' &&
        password == 'StudentDemo123!') {
      _currentUser = const AuthUser(
        id: 'student-demo-001',
        name: 'Demo Student',
        email: 'student@test.local',
        role: 'student',
      );

      return _currentUser;
    }

    // SCANNER DEMO ACCOUNT
    if (normalizedEmail == 'scanner@test.local' &&
        password == 'ScannerDemo123!') {
      _currentUser = const AuthUser(
        id: 'scanner-demo-001',
        name: 'TMC Event Officer',
        email: 'scanner@test.local',
        role: 'scanner',
      );

      return _currentUser;
    }

    // INVALID ACCOUNT
    _currentUser = null;
    return null;
  }

  void logout() {
    _currentUser = null;
  }
}
