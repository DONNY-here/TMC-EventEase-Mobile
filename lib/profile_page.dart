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

class _ProfilePageState extends State<ProfilePage> with WidgetsBindingObserver {
  bool _loadingProfile = false;
  String? _profileError;
  int _profileRequestId = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (ApiConfig.useRealApi) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _fetchLaravelProfile();
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted && ApiConfig.useRealApi) {
      _fetchLaravelProfile();
    }
  }

  @override
  void dispose() {
    _profileRequestId++;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  String _value(Object? raw) => raw == null ? '' : raw.toString().trim();

  Future<void> _fetchLaravelProfile() async {
    if (!ApiConfig.useRealApi || _loadingProfile) return;
    final requestId = ++_profileRequestId;
    setState(() {
      _loadingProfile = true;
      _profileError = null;
    });
    try {
      final base = Uri.tryParse(ApiConfig.baseUrl.trim());
      if (base == null || base.scheme != 'https' || base.host.isEmpty ||
          base.userInfo.isNotEmpty || base.hasQuery || base.hasFragment ||
          (base.path.isNotEmpty && base.path != '/')) {
        throw StateError('Configure your active HTTPS Laravel/ngrok URL.');
      }
      final token = await authTokenStorage.readValidToken();
      if (token == null || token.trim().isEmpty) {
        throw StateError('Your session expired. Sign in again.');
      }
      final response = await http.get(
        base.replace(path: '/api/auth/me', query: null, fragment: null),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
          'ngrok-skip-browser-warning': 'true',
        },
      ).timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) {
        if (response.statusCode == 401) {
          throw StateError('Your session expired. Sign in again.');
        }
        if (response.statusCode == 404) {
          throw StateError('Laravel profile endpoint /api/auth/me was not found.');
        }
        throw StateError('Unable to load profile (HTTP ${response.statusCode}).');
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) {
        throw const FormatException('Invalid Laravel profile response.');
      }
      final payload = Map<String, dynamic>.from(decoded);
      final nested = payload['user'] ?? payload['data'];
      final user = nested is Map ? Map<String, dynamic>.from(nested) : payload;
      if (!user.containsKey('name')) {
        throw const FormatException('Laravel profile response has no name.');
      }
      if (!mounted || requestId != _profileRequestId) return;
      setState(() {
        savedName = _value(user['name']);
        savedEmail = _value(user['email']);
        savedStudentId = _value(user['student_id'] ?? user['school_id']);
        savedCourse = _value(user['course']);
        savedYear = _value(user['year']);
        savedBlock = _value(user['block_no'] ?? user['block']);
        final department = user['department'];
        if (department is Map) {
          savedDepartment = _value(department['name'] ?? department['code']);
        } else {
          savedDepartment = _value(user['department_name'] ?? department);
        }
        // No demo data is substituted if Laravel returns missing fields.
        _profileError = null;
      });
    } catch (error) {
      if (!mounted || requestId != _profileRequestId) return;
      setState(() {
        _profileError = error is StateError ? error.message.toString()
            : error is FormatException ? error.message
            : 'Unable to connect to Laravel. Check ngrok and retry.';
      });
    } finally {
      if (mounted && requestId == _profileRequestId) {
        setState(() => _loadingProfile = false);
      }
    }
  }

  // ====================================================
  // OPEN EDIT PROFILE
  // ====================================================

  Future<void> openEditProfile() async {
    await Navigator.push(
      context,
      animatedRoute(const EditProfilePage()),
    );

    if (!mounted) return;

    // Refresh the authenticated Laravel record after editing.
    setState(() {});
    if (ApiConfig.useRealApi) await _fetchLaravelProfile();
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
    return Stack(
      children: [
        EventEaseProfileView(

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
        ),
        if (_loadingProfile)
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(minHeight: 3),
          ),
        if (_profileError != null)
          Positioned(
            top: 0,
            left: 10,
            right: 10,
            child: SafeArea(
              child: Material(
                elevation: 3,
                borderRadius: BorderRadius.circular(12),
                color: Theme.of(context).colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(_profileError!,
                          style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
                        ),
                      ),
                      TextButton(
                        onPressed: _fetchLaravelProfile,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
