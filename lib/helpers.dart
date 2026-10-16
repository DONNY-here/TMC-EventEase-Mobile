part of 'main.dart';

// ======================================================
// HELPERS
// ======================================================

Route<T> animatedRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    transitionDuration: const Duration(milliseconds: 300),
    reverseTransitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (_, animation, _) => page,
    transitionsBuilder: (_, animation, _, child) {
      final curve = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );

      return FadeTransition(
        opacity: curve,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.05, 0),
            end: Offset.zero,
          ).animate(curve),
          child: child,
        ),
      );
    },
  );
}

void showMessage(BuildContext context, String text) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
  );
}

Widget sectionTitle(String text) {
  return Text(
    text,
    style: const TextStyle(
      color: textDark,
      fontSize: 20,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.3,
    ),
  );
}

// ======================================================
// TMC EVENTEASE - LOGOUT MANAGEMENT
// ======================================================

// ======================================================
// TMC EVENTEASE - LOGOUT MANAGEMENT
// ======================================================

// ======================================================
// TMC EVENTEASE - LOGOUT
// ======================================================

Future<void> logoutEventEaseUser(BuildContext context) async {
  try {
    // REAL API MODE:
    // Delete the locally stored access token.
    if (ApiConfig.useRealApi) {
      await authTokenStorage.clear();
    }

    // Clear remembered demo login.
    await demoSessionStorage.clear();
  } catch (error) {
    debugPrint('Logout error: ${error.runtimeType}');

    if (context.mounted) {
      showMessage(context, 'Unable to complete logout. Please retry.');
    }

    return;
  }

  // Clear mock authentication session.
  authService.logout();

  // Reset temporary account role.
  savedUserRole = 'student';
  demoScannerName = 'TMC Event Officer';

  // Remove previous scan history.
  scanHistory.clear();

  // Clear temporary account data when using API.
  if (ApiConfig.useRealApi) {
    clearTemporaryAccountData();
  }

  if (!context.mounted) return;

  // Return to login and remove previous pages.
  Navigator.of(
    context,
  ).pushAndRemoveUntil(animatedRoute(const LoginPage()), (route) => false);
}

// ======================================================
// CLEAR TEMPORARY ACCOUNT DATA
// ======================================================

void clearTemporaryAccountData() {
  // Clear local event and attendance information.
  registeredEvents.clear();
  qrTokens.clear();
  attendanceStatus.clear();
  attendanceCheckInTime.clear();

  // Clear local evaluation information.
  eventRatings.clear();
  eventComments.clear();

  // Clear scanner history.
  scanHistory.clear();

  // Clear temporary profile information.
  savedName = '';
  savedEmail = '';
  savedPassword = '';
  savedDepartment = '';
  savedCourse = '';
  savedYear = '';
  savedBlock = '';
}
