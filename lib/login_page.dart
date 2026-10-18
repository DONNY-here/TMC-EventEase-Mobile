part of 'main.dart';

// ======================================================
// TMC EVENTEASE - SCHOOL ID LOGIN PAGE
// ======================================================

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final schoolIdController = TextEditingController();
  final passwordController = TextEditingController();

  bool hidePassword = true;
  bool isLoggingIn = false;
  bool rememberDemoStudent = false;

  // ======================================================
  // SCHOOL ID FORMATTER
  // ======================================================

  void formatSchoolId(String value) {
    String digits = value.replaceAll(RegExp(r'\D'), '');

    if (digits.length > 8) {
      digits = digits.substring(0, 8);
    }

    String formatted = digits;

    if (digits.length > 2) {
      formatted = '${digits.substring(0, 2)}-${digits.substring(2)}';
    }

    if (schoolIdController.text != formatted) {
      schoolIdController.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }
  }

  // ======================================================
  // LOGIN USER
  // ======================================================

  Future<void> loginUser() async {
    if (isLoggingIn) return;

    final schoolId = schoolIdController.text.trim();
    final password = passwordController.text;

    // Validate required fields
    if (schoolId.isEmpty || password.isEmpty) {
      showMessage(context, 'Please enter your School ID and password.');
      return;
    }

    // Validate School ID format
    final schoolIdPattern = RegExp(r'^\d{2}-\d{6}$');

    if (!schoolIdPattern.hasMatch(schoolId)) {
      showMessage(context, 'Invalid School ID. Use XX-XXXXXX.');
      return;
    }

    setState(() {
      isLoggingIn = true;
    });

    try {
      // ================================================
      // REAL API AUTHENTICATION
      // ================================================

      if (ApiConfig.useRealApi) {
        final loginUri = ApiConfig.loginUri;

        if (loginUri == null) {
          throw const ApiAuthException(
            'API URL is not configured. Contact the developer.',
          );
        }

        await authTokenStorage.clear();

        final client = http.Client();

        try {
          final apiService = ApiAuthService(client: client, loginUri: loginUri);

          // Compatibility with existing ApiAuthService.
          // The service currently requires the "email"
          // parameter. This sends the School ID as its
          // value until ApiAuthService is updated to
          // submit the "school_id" JSON field.
          final session = await apiService.login(
            schoolId: schoolId,
            password: password,
          );

          if (!session.user.isStudent && !session.user.isScanner) {
            throw const ApiAuthException(
              'This account cannot access the mobile app.',
            );
          }

          await demoSessionStorage.clear();
          await authTokenStorage.save(session);

          if (!mounted) return;

          authService.logout();
          clearTemporaryAccountData();

          savedName = session.user.name;
          savedEmail = session.user.email;
          savedUserRole = session.user.role;

          demoScannerName = session.user.isScanner
              ? session.user.name
              : 'TMC Event Officer';

          Navigator.pushReplacement(context, animatedRoute(const MainPage()));

          return;
        } finally {
          client.close();
        }
      }

      // ================================================
      // DEMO AUTHENTICATION - SCHOOL ID
      // ================================================

      final user = await authService.loginWithSchoolId(
        schoolId: schoolId,
        password: password,
      );

      if (!mounted) return;

      if (user != null && user.isStudent) {
        final profile = await authService.loadStudentProfile();

        if (!mounted) return;

        if (profile != null) {
          savedName = profile['name'] ?? '';
          savedEmail = profile['email'] ?? '';
          savedStudentId = profile['school_id'] ?? '';
          savedDepartment = profile['department'] ?? '';
          savedCourse = profile['course'] ?? '';
          savedYear = profile['year'] ?? '';
          savedBlock = profile['block'] ?? '';
        }

        savedPassword = '';
        savedUserRole = 'student';
        demoScannerName = 'TMC Event Officer';

        // Remembering locally registered accounts will be
        // implemented separately from the built-in demo session.
        await demoSessionStorage.setRememberStudent(
          rememberDemoStudent,
        );

        if (!mounted) return;

        Navigator.pushReplacement(context, animatedRoute(const MainPage()));

        return;
      }

      showMessage(context, 'Incorrect School ID or password.');
    } on ApiAuthException catch (error) {
      if (ApiConfig.useRealApi) {
        try {
          await authTokenStorage.clear();
        } catch (_) {}
      }

      if (mounted) {
        showMessage(context, error.message);
      }
    } catch (error) {
      if (ApiConfig.useRealApi) {
        try {
          await authTokenStorage.clear();
        } catch (_) {}
      } else {
        authService.logout();
      }

      debugPrint('Login failed: ${error.runtimeType}');

      if (mounted) {
        showMessage(context, 'Unable to sign in. Please try again.');
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoggingIn = false;
        });
      }
    }
  }

  // ======================================================
  // DISPOSE
  // ======================================================

  @override
  void dispose() {
    schoolIdController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  // ======================================================
  // LOGIN PAGE DESIGN
  // ======================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: appGradient),
        child: SafeArea(
          child: Stack(
            children: [
              // Top background circle
              Positioned(
                top: -70,
                right: -60,
                child: Container(
                  width: 190,
                  height: 190,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.07),
                  ),
                ),
              ),

              // Bottom background circle
              Positioned(
                bottom: -90,
                left: -70,
                child: Container(
                  width: 220,
                  height: 220,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: yellow.withValues(alpha: 0.09),
                  ),
                ),
              ),

              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(22),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, child) {
                      return Opacity(
                        opacity: value,
                        child: Transform.translate(
                          offset: Offset(0, 24 * (1 - value)),
                          child: child,
                        ),
                      );
                    },
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 460),
                      padding: const EdgeInsets.fromLTRB(26, 28, 26, 22),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.16),
                            blurRadius: 34,
                            offset: const Offset(0, 18),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // APP ICON
                          Center(
                            child: Container(
                              width: 88,
                              height: 88,
                              decoration: BoxDecoration(
                                gradient: appGradient,
                                borderRadius: BorderRadius.circular(26),
                                boxShadow: [
                                  BoxShadow(
                                    color: navy.withValues(alpha: 0.18),
                                    blurRadius: 18,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.event_available_rounded,
                                size: 46,
                                color: yellow,
                              ),
                            ),
                          ),

                          const SizedBox(height: 16),

                          const Text(
                            'TMC EventEase',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              color: textDark,
                              letterSpacing: -0.6,
                            ),
                          ),

                          const SizedBox(height: 4),

                          const Text(
                            'Your Events, Easy Access.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: textGrey),
                          ),

                          const SizedBox(height: 30),

                          const Text(
                            'Welcome back',
                            style: TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.w800,
                              color: textDark,
                            ),
                          ),

                          const SizedBox(height: 4),

                          const Text(
                            'Sign in using your School ID.',
                            style: TextStyle(color: textGrey, fontSize: 13),
                          ),

                          const SizedBox(height: 18),

                          // ==================================
                          // SCHOOL ID
                          // ==================================
                          TextField(
                            controller: schoolIdController,
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.next,
                            maxLength: 9,
                            onChanged: formatSchoolId,
                            decoration: InputDecoration(
                              labelText: 'School ID',
                              hintText: '00-000000',
                              counterText: '',
                              prefixIcon: const Icon(Icons.badge_outlined),
                              helperText: 'Enter your 8-digit School ID',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),

                          const SizedBox(height: 14),

                          // ==================================
                          // PASSWORD
                          // ==================================
                          TextField(
                            controller: passwordController,
                            obscureText: hidePassword,
                            autofillHints: const [AutofillHints.password],
                            onSubmitted: (_) => loginUser(),
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                onPressed: () {
                                  setState(() {
                                    hidePassword = !hidePassword;
                                  });
                                },
                                icon: Icon(
                                  hidePassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 4),

                          // ==================================
                          // FORGOT PASSWORD
                          // ==================================
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: isLoggingIn
                                  ? null
                                  : () {
                                Navigator.push(
                                  context,
                                  animatedRoute(
                                    const ForgotPasswordPage(
                                      initialEmail: '',
                                    ),
                                  ),
                                );
                              },
                              child: const Text(
                                'Forgot Password?',
                                style: TextStyle(
                                  color: navy,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),

                          // ==================================
                          // DEMO REMEMBER ME
                          // ==================================
                          if (!ApiConfig.useRealApi) ...[
                            const SizedBox(height: 8),
                            CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                              controlAffinity: ListTileControlAffinity.leading,
                              activeColor: navy,
                              value: rememberDemoStudent,
                              onChanged: isLoggingIn
                                  ? null
                                  : (value) {
                                setState(() {
                                  rememberDemoStudent = value ?? false;
                                });
                              },
                              title: const Text(
                                'Keep me signed in',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: textDark,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],

                          const SizedBox(height: 20),

                          // ==================================
                          // LOGIN BUTTON
                          // ==================================
                          ElevatedButton.icon(
                            onPressed: isLoggingIn ? null : loginUser,
                            icon: isLoggingIn
                                ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: navy,
                              ),
                            )
                                : const Icon(Icons.login_rounded),
                            label: Text(
                              isLoggingIn ? 'Signing In...' : 'Sign In',
                            ),
                          ),

                          // ==================================
                          // REGISTRATION
                          // ==================================
                          // Display the Register action in both modes.
                          // Laravel registration uses /api/auth/register.
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: isLoggingIn
                                ? null
                                : () {
                              Navigator.push(
                                context,
                                animatedRoute(const RegisterPage()),
                              );
                            },
                            child: const Text(
                              "Don't have an account? Register",
                              style: TextStyle(
                                color: navy,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
