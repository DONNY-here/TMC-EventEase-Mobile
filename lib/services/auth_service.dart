import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/auth_user.dart';

class AuthService {
  AuthUser? _currentUser;

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  final SharedPreferencesAsync _prefs = SharedPreferencesAsync();

  static const _prefix = 'eventease_local_student_';
  static const _passwordKey = 'eventease_local_password';

  AuthUser? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;

  // Existing temporary student-session support.
  void startLocalStudentSession({required String name, required String email}) {
    final normalizedEmail = email.trim().toLowerCase();

    _currentUser = AuthUser(
      id: 'local-student:$normalizedEmail',
      name: name.trim().isEmpty ? 'Student' : name.trim(),
      email: normalizedEmail,
      role: 'student',
    );
  }

  // Save one local demo account on this device.
  Future<void> registerStudent({
    required String name,
    required String email,
    required String schoolId,
    required String department,
    required String course,
    required String year,
    required String block,
    required String password,
  }) async {
    final id = schoolId.trim();

    if (!RegExp(r'^\d{2}-\d{6}$').hasMatch(id)) {
      throw ArgumentError('Invalid School ID.');
    }

    if (password.isEmpty) {
      throw ArgumentError('Password is required.');
    }

    // Save non-secret profile information.
    final profile = {
      'name': name.trim(),
      'email': email.trim().toLowerCase(),
      'school_id': id,
      'department': department,
      'course': course,
      'year': year,
      'block': block.trim(),
    };

    // Save the password separately in secure storage.
    // This is still a local demo, not production
    // authentication. Only one account is supported.
    await _secureStorage.write(key: _passwordKey, value: password);

    for (final entry in profile.entries) {
      await _prefs.setString('$_prefix${entry.key}', entry.value);
    }
  }

  // Read the locally registered profile.
  Future<Map<String, String>?> loadStudentProfile() async {
    final id = await _prefs.getString('${_prefix}school_id');

    if (id == null || id.isEmpty) return null;

    const fields = [
      'name',
      'email',
      'school_id',
      'department',
      'course',
      'year',
      'block',
    ];

    final profile = <String, String>{};

    for (final field in fields) {
      profile[field] = await _prefs.getString('$_prefix$field') ?? '';
    }

    return profile;
  }

  // School ID login for locally registered students.
  Future<AuthUser?> loginWithSchoolId({
    required String schoolId,
    required String password,
  }) async {
    _currentUser = null;

    final profile = await loadStudentProfile();
    if (profile == null) return null;

    final storedPassword = await _secureStorage.read(key: _passwordKey);

    if (profile['school_id'] != schoolId.trim() ||
        storedPassword == null ||
        storedPassword != password) {
      return null;
    }

    _currentUser = AuthUser(
      id: 'local-student:${profile['school_id']}',
      name: profile['name'] ?? 'Student',
      email: profile['email'] ?? '',
      role: 'student',
    );

    return _currentUser;
  }

  // Preserve the existing demo email accounts.
  Future<AuthUser?> login({
    required String email,
    required String password,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));

    final normalizedEmail = email.trim().toLowerCase();

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

    _currentUser = null;
    return null;
  }

  void logout() {
    _currentUser = null;
  }
}
