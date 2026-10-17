
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
    // REAL API MODE:
    // Do not restore a local demo account in Laravel mode.
    if (ApiConfig.useRealApi) {
      try {
        await authTokenStorage.clear();
      } catch (error) {
        debugPrint(
          'Unable to clear API token: ${error.runtimeType}',
        );
      }

      return false;
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
