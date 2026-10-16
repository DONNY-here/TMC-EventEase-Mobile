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
    // Until the backend supports session validation or
    // token refresh, require a fresh login after restart.
    if (ApiConfig.useRealApi) {
      try {
        await authTokenStorage.clear();
      } catch (error) {
        debugPrint(
          'Unable to clear old API token: '
          '${error.runtimeType}',
        );
      }

      return false;
    }

    // DEMO MODE:
    // Restore only the remembered student demo account.
    try {
      final rememberStudent = await demoSessionStorage.shouldRestoreStudent();

      if (!rememberStudent) {
        return false;
      }

      final user = await authService.login(
        email: 'student@test.local',
        password: 'StudentDemo123!',
      );

      if (user == null || !user.isStudent) {
        await demoSessionStorage.clear();
        return false;
      }

      savedUserRole = 'student';

      return true;
    } catch (error) {
      debugPrint(
        'Demo session restoration failed: '
        '${error.runtimeType}',
      );

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
            body: Center(child: CircularProgressIndicator(color: navy)),
          );
        }

        final restored = snapshot.data ?? false;

        if (restored) {
          return const MainPage();
        }

        return const LoginPage();
      },
    );
  }
}
