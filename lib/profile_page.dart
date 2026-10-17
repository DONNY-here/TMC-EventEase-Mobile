
part of 'main.dart';

// ======================================================
// TMC EVENTEASE - ENHANCED PROFILE PAGE
// LIGHT AND DARK MODE SUPPORTED
// ======================================================

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {

  // ====================================================
  // OPEN EDIT PROFILE
  // ====================================================

  Future<void> openEditProfile() async {
    await Navigator.push(
      context,
      animatedRoute(const EditProfilePage()),
    );

    if (!mounted) return;

    // Refresh profile details after editing.
    setState(() {});
  }

  // ====================================================
  // LOGOUT WITH CONFIRMATION
  // LIGHT AND DARK MODE SUPPORTED
  // ====================================================

  Future<void> logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        final colors = theme.colorScheme;

        final isDark =
            theme.brightness == Brightness.dark;

        return AlertDialog(
          backgroundColor: colors.surface,
          surfaceTintColor: Colors.transparent,

          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),

          // LOGOUT ICON
          icon: Icon(
            Icons.logout_rounded,
            color: isDark ? yellow : navy,
            size: 36,
          ),

          // DIALOG TITLE
          title: Text(
            'Logout?',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.onSurface,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),

          // CONFIRMATION MESSAGE
          content: Text(
            'Are you sure you want to end '
                'your current session?',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.onSurfaceVariant,
              fontSize: 14,
              height: 1.5,
            ),
          ),

          // ACTION BUTTONS
          actionsAlignment: MainAxisAlignment.center,

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              style: TextButton.styleFrom(
                foregroundColor:
                isDark ? yellow : navy,
              ),
              child: const Text(
                'Stay',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),

            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: isDark
                    ? const Color(0xFFBF4242)
                    : navy,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius:
                  BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              icon: const Icon(
                Icons.logout_rounded,
                size: 18,
              ),
              label: const Text(
                'Logout',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirm != true || !mounted) {
      return;
    }

    // Preserve the existing authentication cleanup,
    // logout handling and navigation.
    await logoutEventEaseUser(context);
  }

  // ====================================================
  // RESET PASSWORD
  // ====================================================

  void openResetPassword() {
    Navigator.push(
      context,
      animatedRoute(
        ForgotPasswordPage(
          initialEmail: savedEmail,
        ),
      ),
    );
  }

  // ====================================================
  // ENHANCED PROFILE USER INTERFACE
  // ====================================================

  @override
  Widget build(BuildContext context) {
    return EventEaseProfileView(

      // ================================================
      // STUDENT PERSONAL INFORMATION
      // ================================================

      name: savedName,

      email: savedEmail,

      studentId: savedStudentId,

      department: savedDepartment,

      course: savedCourse,

      year: savedYear,

      block: savedBlock,

      // ================================================
      // PROFILE ACTIONS
      // ================================================

      onEdit: openEditProfile,

      onResetPassword: openResetPassword,

      onLogout: logout,
    );
  }
}
