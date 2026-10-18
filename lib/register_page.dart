part of 'main.dart';

// Student ID: exactly 2 digits, a dash, then up to 6 digits.
// Accepts pasted IDs and preserves the caret when editing in the middle.
class StudentIdFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue,
      TextEditingValue newValue,
      ) {
    final beforeCaret = newValue.selection.baseOffset
        .clamp(0, newValue.text.length)
        .toInt();
    final digitsBeforeCaret = newValue.text
        .substring(0, beforeCaret)
        .replaceAll(RegExp(r'\D'), '')
        .length
        .clamp(0, 8)
        .toInt();
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final limited = digits.length > 8 ? digits.substring(0, 8) : digits;
    final formatted = limited.length >= 2
        ? '${limited.substring(0, 2)}-${limited.substring(2)}'
        : limited;
    var caret = digitsBeforeCaret;
    if (limited.length >= 2 && digitsBeforeCaret >= 2) caret++;
    if (caret > formatted.length) caret = formatted.length;
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: caret),
    );
  }
}

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final studentIdController = TextEditingController();
  final blockController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  final _stepForms = List.generate(3, (_) => GlobalKey<FormState>());

  final Map<String, List<String>> departmentCourses = {
    'College of Computer Studies': ['BSIT'],
    'College of Education': ['BEED', 'BSED'],
    'College of Criminal Justice Education': ['BSCRIM'],
    'College of Office Administration': ['BSOA'],
    'College of Arts and Sciences': [
      'AB Political Science',
      'AB Communication',
    ],
  };

  String selectedDepartment = 'College of Computer Studies';
  String selectedCourse = 'BSIT';
  String selectedYear = '1st Year';
  int currentStep = 0;
  bool hidePassword = true;
  bool hideConfirmPassword = true;
  bool acceptedTerms = false;
  bool triedTerms = false;
  bool isSubmitting = false;

  bool hasMinLength(String value) => value.length >= 8;
  bool hasUppercase(String value) => RegExp(r'[A-Z]').hasMatch(value);
  bool hasLowercase(String value) => RegExp(r'[a-z]').hasMatch(value);
  bool hasNumber(String value) => RegExp(r'[0-9]').hasMatch(value);
  bool hasSpecialCharacter(String value) =>
      RegExp(r'[!@#$%^&*(),.?":{}|<>_\-+=]').hasMatch(value);

  int passwordStrength(String value) => [
    hasMinLength(value),
    hasUppercase(value),
    hasLowercase(value),
    hasNumber(value),
    hasSpecialCharacter(value),
  ].where((satisfied) => satisfied).length;

  bool isStrongPassword(String value) => passwordStrength(value) == 5;

  String? validateEmail(String? value) {
    final email = (value ?? '').trim();
    if (email.isEmpty) return 'Please enter your email address.';
    if (!RegExp(
      r'^[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$',
    ).hasMatch(email)) {
      return 'Enter a valid email address.';
    }
    return null;
  }

  void nextStep() {
    FocusScope.of(context).unfocus();
    if (!(_stepForms[currentStep].currentState?.validate() ?? false)) return;
    if (currentStep < 2) {
      setState(() => currentStep++);
    } else {
      registerUser();
    }
  }

  // Parse Laravel's JSON validation errors without exposing internal details.
  String _registrationErrorMessage(http.Response response) {
    if (response.statusCode == 429) {
      return 'Too many registration attempts. Please try again later.';
    }
    if (response.statusCode >= 500) {
      return 'Laravel encountered a server error. Please try again later.';
    }

    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map) {
        final errors = decoded['errors'];
        if (errors is Map) {
          for (final value in errors.values) {
            if (value is List && value.isNotEmpty) {
              final message = value.first;
              if (message is String && message.trim().isNotEmpty) {
                return message;
              }
            }
            if (value is String && value.trim().isNotEmpty) {
              return value;
            }
          }
        }

        final message = decoded['message'];
        if (message is String && message.trim().isNotEmpty) {
          return message;
        }
      }
    } catch (_) {
      // A proxy or network gateway may return HTML instead of JSON.
    }

    return 'Registration failed (HTTP ${response.statusCode}). Please try again.';
  }

  Future<void> registerUser() async {
    if (isSubmitting) return;
    if (!(_stepForms[2].currentState?.validate() ?? false)) return;

    setState(() => triedTerms = true);
    if (!acceptedTerms) return;

    final name = nameController.text.trim();
    final email = emailController.text.trim();
    final studentId = studentIdController.text.trim();
    final password = passwordController.text;
    final block = normalizeTmcBlock(blockController.text);

    if (block == null) {
      showMessage(context, 'Enter a valid block number from 1 to 11.');
      return;
    }

    if (ApiConfig.useRealApi) {
      setState(() => isSubmitting = true);
      try {
        // Reuse the validated HTTPS origin from the existing API config.
        final loginUri = ApiConfig.loginUri;
        if (loginUri == null) {
          showMessage(context, 'The Laravel API URL is not configured.');
          return;
        }
        final registerUri = loginUri.replace(path: '/api/auth/register');

        // AuthController expects block_no, not 'block'.
        // Store the number on Laravel, but retain 'Block N' in demo UI.
        final response = await http.post(
          registerUri,
          headers: const {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'name': name,
            'school_id': studentId,
            'email': email,
            'course': selectedCourse,
            'year': selectedYear,
            'block_no': block.substring('Block '.length),
            'password': password,
          }),
        ).timeout(const Duration(seconds: 20));

        if (!mounted) return;

        if (response.statusCode != 201) {
          showMessage(context, _registrationErrorMessage(response));
          return;
        }

        // Laravel registers new accounts as Pending. No token is issued.
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Registration Submitted'),
            content: const Text(
              'Your student account was created successfully. '
                  'It is currently Pending and must be activated '
                  'by an administrator before you can sign in.',
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Return to Sign In'),
              ),
            ],
          ),
        );

        if (mounted) Navigator.pop(context);
      } catch (error) {
        debugPrint('Laravel registration failed: ${error.runtimeType}');
        if (mounted) {
          showMessage(
            context,
            'Could not reach Laravel. Check your HTTPS URL, '
                'internet connection, and server status.',
          );
        }
      } finally {
        if (mounted) setState(() => isSubmitting = false);
      }
      return;
    }

    // Existing Demo Mode registration is unchanged except for block format.
    setState(() => isSubmitting = true);
    try {
      await authService.registerStudent(
        name: name,
        email: email,
        schoolId: studentId,
        department: selectedDepartment,
        course: selectedCourse,
        year: selectedYear,
        block: block,
        password: password,
      );

      if (!mounted) return;

      if (savedStudentId != studentId ||
          savedEmail.toLowerCase() != email.toLowerCase()) {
        clearStudentActivityData();
      }

      savedName = name;
      savedEmail = email;
      savedStudentId = studentId;
      savedDepartment = selectedDepartment;
      savedCourse = selectedCourse;
      savedYear = selectedYear;
      savedBlock = block;
      savedPassword = '';

      showMessage(context, 'Demo account created! Please sign in.');
      Navigator.pop(context);
    } catch (error) {
      debugPrint('Demo registration failed: ${error.runtimeType}');
      if (mounted) {
        showMessage(context, 'Unable to save your demo account.');
      }
    } finally {
      if (mounted) setState(() => isSubmitting = false);
    }
  }

  Widget field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    String? helper,
    TextInputType? keyboard,
    TextCapitalization capitalization = TextCapitalization.none,
    List<TextInputFormatter>? formatters,
    String? Function(String?)? validator,
    bool obscure = false,
    Widget? suffix,
    void Function(String)? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboard,
      textCapitalization: capitalization,
      inputFormatters: formatters,
      obscureText: obscure,
      onChanged: onChanged,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        helperText: helper,
        prefixIcon: Icon(icon),
        suffixIcon: suffix,
      ),
    );
  }

  Widget sectionHeading(String title, String description) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: textDark,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          description,
          style: const TextStyle(fontSize: 13, color: textGrey),
        ),
      ],
    ),
  );

  Widget requirement(String label, bool satisfied) => Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: Row(
      children: [
        Icon(
          satisfied ? Icons.check_circle_rounded : Icons.circle_outlined,
          size: 17,
          color: satisfied ? Colors.green.shade700 : textGrey,
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: satisfied ? Colors.green.shade700 : textGrey,
            ),
          ),
        ),
      ],
    ),
  );

  Widget personalStep() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      sectionHeading(
        'Personal information',
        'Use your official student details for your account.',
      ),
      field(
        controller: nameController,
        label: 'Full name',
        hint: 'Juan Dela Cruz',
        icon: Icons.person_outline_rounded,
        capitalization: TextCapitalization.words,
        validator: (v) =>
        (v ?? '').trim().isEmpty ? 'Please enter your full name.' : null,
      ),
      const SizedBox(height: 16),
      field(
        controller: studentIdController,
        label: 'Student ID',
        hint: '00-000000',
        helper: 'Two digits, a dash, then six digits',
        icon: Icons.badge_outlined,
        keyboard: TextInputType.number,
        formatters: [StudentIdFormatter()],
        validator: (v) => RegExp(r'^\d{2}-\d{6}$').hasMatch(v ?? '')
            ? null
            : 'Enter the full ID: 00-000000',
      ),
      const SizedBox(height: 16),
      field(
        controller: emailController,
        label: 'Email address',
        hint: 'student@example.com',
        helper: 'An email verification step will be added with Laravel.',
        icon: Icons.mail_outline_rounded,
        keyboard: TextInputType.emailAddress,
        validator: validateEmail,
      ),
    ],
  );

  Widget academicStep() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      sectionHeading(
        'Academic information',
        'Tell us where you belong within Trinidad Municipal College.',
      ),
      DropdownButtonFormField<String>(
        initialValue: selectedDepartment,
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'Department',
          prefixIcon: Icon(Icons.account_balance_outlined),
        ),
        items: departmentCourses.keys
            .map(
              (d) => DropdownMenuItem(
            value: d,
            child: Text(d, overflow: TextOverflow.ellipsis),
          ),
        )
            .toList(),
        onChanged: (v) {
          if (v == null) return;
          setState(() {
            selectedDepartment = v;
            selectedCourse = departmentCourses[v]!.first;
          });
        },
      ),
      const SizedBox(height: 16),
      DropdownButtonFormField<String>(
        key: ValueKey(selectedDepartment),
        initialValue: selectedCourse,
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'Course / Program',
          prefixIcon: Icon(Icons.school_outlined),
        ),
        items: departmentCourses[selectedDepartment]!
            .map((c) => DropdownMenuItem(value: c, child: Text(c)))
            .toList(),
        onChanged: (v) {
          if (v != null) setState(() => selectedCourse = v);
        },
      ),
      const SizedBox(height: 16),
      DropdownButtonFormField<String>(
        initialValue: selectedYear,
        decoration: const InputDecoration(
          labelText: 'Year level',
          prefixIcon: Icon(Icons.calendar_month_outlined),
        ),
        items: [
          '1st Year',
          '2nd Year',
          '3rd Year',
          '4th Year',
        ].map((y) => DropdownMenuItem(value: y, child: Text(y))).toList(),
        onChanged: (v) {
          if (v != null) setState(() => selectedYear = v);
        },
      ),
      const SizedBox(height: 16),
      field(
        controller: blockController,
        label: 'Block / Section',
        hint: 'e.g. 1',
        helper: 'Enter a block number from 1 to 11',
        icon: Icons.groups_outlined,
        keyboard: TextInputType.number,
        formatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(2),
        ],
        validator: (value) => normalizeTmcBlock(value) == null
            ? 'Enter a valid block number from 1 to 11.'
            : null,
      ),
    ],
  );

  Widget securityStep() {
    final password = passwordController.text;
    final strength = passwordStrength(password);
    final strengthColor = strength == 5
        ? Colors.green.shade700
        : strength >= 3
        ? Colors.orange.shade800
        : Colors.red.shade700;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        sectionHeading(
          'Account security',
          'Create a strong password and confirm it before registering.',
        ),
        field(
          controller: passwordController,
          label: 'Password',
          icon: Icons.lock_outline,
          obscure: hidePassword,
          onChanged: (_) => setState(() {}),
          suffix: IconButton(
            tooltip: hidePassword ? 'Show password' : 'Hide password',
            onPressed: () => setState(() => hidePassword = !hidePassword),
            icon: Icon(
              hidePassword
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
            ),
          ),
          validator: (v) => isStrongPassword(v ?? '')
              ? null
              : 'Password must meet all requirements.',
        ),
        const SizedBox(height: 14),
        if (password.isNotEmpty) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Password strength',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
              ),
              Text(
                strength == 5
                    ? 'Strong'
                    : strength >= 3
                    ? 'Moderate'
                    : 'Weak',
                style: TextStyle(fontSize: 12, color: strengthColor),
              ),
            ],
          ),
          const SizedBox(height: 7),
          LinearProgressIndicator(
            value: strength / 5,
            color: strengthColor,
            backgroundColor: borderColor,
            minHeight: 6,
            borderRadius: BorderRadius.circular(6),
          ),
          const SizedBox(height: 15),
        ],
        requirement('At least 8 characters', hasMinLength(password)),
        requirement('An uppercase letter', hasUppercase(password)),
        requirement('A lowercase letter', hasLowercase(password)),
        requirement('A number', hasNumber(password)),
        requirement('A special character', hasSpecialCharacter(password)),
        const SizedBox(height: 14),
        field(
          controller: confirmPasswordController,
          label: 'Confirm password',
          icon: Icons.verified_user_outlined,
          obscure: hideConfirmPassword,
          suffix: IconButton(
            tooltip: hideConfirmPassword ? 'Show password' : 'Hide password',
            onPressed: () =>
                setState(() => hideConfirmPassword = !hideConfirmPassword),
            icon: Icon(
              hideConfirmPassword
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
            ),
          ),
          validator: (v) {
            if ((v ?? '').isEmpty) return 'Please confirm your password.';
            if (v != passwordController.text) return 'Passwords do not match.';
            return null;
          },
        ),
        const SizedBox(height: 14),
        CheckboxListTile(
          value: acceptedTerms,
          activeColor: navy,
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          title: const Text(
            'I agree to use my details for this demo registration.',
            style: TextStyle(fontSize: 13),
          ),
          onChanged: (v) => setState(() => acceptedTerms = v ?? false),
        ),
        if (triedTerms && !acceptedTerms)
          const Padding(
            padding: EdgeInsets.only(left: 12),
            child: Text(
              'Please accept before continuing.',
              style: TextStyle(color: Colors.red, fontSize: 12),
            ),
          ),
      ],
    );
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    studentIdController.dispose();
    blockController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const steps = ['Personal', 'Academic', 'Security'];
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(title: const Text('Student Registration')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(22),
                      decoration: const BoxDecoration(
                        gradient: appGradient,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(23),
                        ),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.how_to_reg_rounded,
                            color: yellow,
                            size: 35,
                          ),
                          SizedBox(height: 12),
                          Text(
                            'Join TMC EventEase',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 23,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 5),
                          Text(
                            'Create your student account in three easy steps.',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(22),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: List.generate(3, (i) {
                              final active = i <= currentStep;
                              return Expanded(
                                child: Padding(
                                  padding: EdgeInsets.only(
                                    right: i == 2 ? 0 : 6,
                                  ),
                                  child: Column(
                                    children: [
                                      Container(
                                        height: 6,
                                        decoration: BoxDecoration(
                                          color: active ? navy : borderColor,
                                          borderRadius: BorderRadius.circular(
                                            5,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 7),
                                      Text(
                                        steps[i],
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: active
                                              ? FontWeight.w700
                                              : FontWeight.w400,
                                          color: active ? navy : textGrey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                          ),
                          const SizedBox(height: 24),
                          Form(
                            key: _stepForms[currentStep],
                            child: currentStep == 0
                                ? personalStep()
                                : currentStep == 1
                                ? academicStep()
                                : securityStep(),
                          ),
                          const SizedBox(height: 28),
                          Row(
                            children: [
                              if (currentStep > 0) ...[
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () =>
                                        setState(() => currentStep--),
                                    icon: const Icon(Icons.arrow_back_rounded),
                                    label: const Text('Back'),
                                  ),
                                ),
                                const SizedBox(width: 10),
                              ],
                              Expanded(
                                flex: 2,
                                child: ElevatedButton.icon(
                                  onPressed: isSubmitting ? null : nextStep,
                                  icon: Icon(
                                    currentStep == 2
                                        ? Icons.person_add_alt_1_rounded
                                        : Icons.arrow_forward_rounded,
                                  ),
                                  label: Text(
                                    currentStep == 2
                                        ? (isSubmitting ? 'Creating Account...' : 'Create Account')
                                        : 'Continue',
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Already registered? Log in'),
                          ),
                          if (!ApiConfig.useRealApi)
                            const Text(
                              'Demo Mode · Account stays on this device session',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 11, color: textGrey),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
