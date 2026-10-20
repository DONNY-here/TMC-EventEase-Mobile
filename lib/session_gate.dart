part of 'main.dart';

// ======================================================
// TMC EVENTEASE - SESSION GATE
// ======================================================

class SessionGate extends StatefulWidget {
  const SessionGate({super.key});

  @override
  State<SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends State<SessionGate> {
  late final Future<bool> _restoreFuture;

  @override
  void initState() {
    super.initState();
    _restoreFuture = _restoreSession();
  }

  // ======================================================
  // RESTORE SESSION
  // ======================================================

  Future<bool> _restoreSession() async {
    // REAL API MODE: restore only a valid, server-verified identity.
    if (ApiConfig.useRealApi) {
      try {
        final token = await authTokenStorage.readValidToken();
        if (token == null || token.isEmpty) return false;
        final user = await fetchEventEaseLaravelProfile(token);
        applyEventEaseLaravelProfile(user);
        return true;
      } catch (error) {
        // Network failures should not destroy a still-valid stored token.
        // A subsequent explicit sign-in can recover the session.
        debugPrint('API session restoration failed: ${error.runtimeType}');
        return false;
      }
    }

    // DEMO MODE:
    // Restore only an explicitly remembered student.
    try {
      final rememberStudent =
      await demoSessionStorage.shouldRestoreStudent();

      if (!rememberStudent) {
        return false;
      }

      final profile = await authService.loadStudentProfile();

      if (profile == null) {
        await demoSessionStorage.clear();
        return false;
      }

      final schoolId = profile['school_id'] ?? '';

      if (!RegExp(r'^\d{2}-\d{6}$').hasMatch(schoolId)) {
        await demoSessionStorage.clear();
        return false;
      }

      // Restore the in-memory authentication identity
      // without automatically reusing a stored password.
      authService.startLocalStudentSession(
        name: profile['name'] ?? 'Student',
        email: profile['email'] ?? '',
      );

      savedName = profile['name'] ?? 'Student';
      savedEmail = profile['email'] ?? '';
      savedStudentId = schoolId;
      savedDepartment = profile['department'] ?? '';
      savedCourse = profile['course'] ?? '';
      savedYear = profile['year'] ?? '';
      savedBlock = profile['block'] ?? '';
      savedPassword = '';
      savedUserRole = 'student';
      demoScannerName = 'TMC Event Officer';

      return true;
    } catch (error) {
      debugPrint(
        'Demo session restoration failed: ${error.runtimeType}',
      );

      authService.logout();

      try {
        await demoSessionStorage.clear();
      } catch (_) {}

      return false;
    }
  }

  // ======================================================
  // BUILD STARTUP SCREEN
  // ======================================================

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _restoreFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: navy),
            ),
          );
        }

        if (snapshot.data == true) {
          return const MainPage();
        }

        return const LoginPage();
      },
    );
  }
}

// Authenticated Laravel identity. Do not use demo data in Real API Mode.
Future<Map<String, dynamic>> fetchEventEaseLaravelProfile(String token) async {
  final base = Uri.tryParse(ApiConfig.baseUrl.trim());
  if (base == null ||
      base.scheme != 'https' ||
      base.host.isEmpty ||
      base.userInfo.isNotEmpty ||
      base.hasQuery ||
      base.hasFragment ||
      (base.path.isNotEmpty && base.path != '/')) {
    throw const FormatException('A valid HTTPS Laravel API URL is required.');
  }

  final response = await http.get(
    base.replace(path: '/api/auth/me', query: null, fragment: null),
    headers: {
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
      'ngrok-skip-browser-warning': 'true',
    },
  ).timeout(const Duration(seconds: 20));

  if (response.statusCode == 401) {
    throw StateError('Your session has expired. Sign in again.');
  }
  if (response.statusCode != 200) {
    throw StateError('Unable to load student profile (HTTP ${response.statusCode}).');
  }

  final decoded = jsonDecode(response.body);
  if (decoded is! Map) {
    throw const FormatException('Invalid Laravel profile response.');
  }
  final payload = Map<String, dynamic>.from(decoded);
  final nested = payload['user'] ?? payload['data'];
  final profile = nested is Map
      ? Map<String, dynamic>.from(nested)
      : payload;
  if ('${profile['name'] ?? ''}'.trim().isEmpty ||
      '${profile['role'] ?? ''}'.trim().isEmpty) {
    throw const FormatException('Laravel returned incomplete account information.');
  }
  final role = '${profile['role']}'.trim().toLowerCase();
  if (role != 'student' && role != 'scanner') {
    throw StateError('This account cannot access the mobile application.');
  }
  return profile;
}

void applyEventEaseLaravelProfile(Map<String, dynamic> profile) {
  String value(Object? raw) => raw?.toString().trim() ?? '';
  final role = value(profile['role']).toLowerCase();
  // Clear all fields before assigning the current authenticated account.
  savedName = value(profile['name']);
  savedEmail = value(profile['email']);
  savedStudentId = value(profile['student_id'] ?? profile['school_id']);
  savedCourse = value(profile['course']);
  savedYear = value(profile['year']);
  savedBlock = value(profile['block_no'] ?? profile['block']);
  final department = profile['department'];
  savedDepartment = department is Map
      ? value(department['name'] ?? department['code'])
      : value(profile['department_name'] ?? department);
  savedUserRole = role;
  savedPassword = '';
  demoScannerName = role == 'scanner' ? savedName : 'TMC Event Officer';
}
