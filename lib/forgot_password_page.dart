part of 'main.dart';

// TMC EventEase - email-only password recovery.
// IMPORTANT: These are proposed Laravel routes and request contracts.
// The backend must implement them before real password resets will work.
class ForgotPasswordPage extends StatefulWidget {
  final String initialEmail;
  const ForgotPasswordPage({super.key, this.initialEmail = ''});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  static const _requestPath = '/api/auth/forgot-password';
  static const _verifyPath = '/api/auth/verify-reset-code';
  static const _resetPath = '/api/auth/reset-password';
  static const _navy = Color(0xFF102A4C);
  static const _gold = Color(0xFFFFCB4D);

  late final TextEditingController emailController;
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  // 0: email, 1: OTP, 2: new password, 3: done.
  int _step = 0;
  bool _busy = false;
  bool _passwordVisible = false;
  bool _confirmVisible = false;
  String? _error;
  DateTime? _nextResendAt;
  String _requestedEmail = '';

  @override
  void initState() {
    super.initState();
    emailController = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Uri _endpoint(String path) {
    final base = Uri.tryParse(ApiConfig.baseUrl.trim());
    if (base == null ||
        base.scheme != 'https' ||
        base.host.isEmpty ||
        base.userInfo.isNotEmpty ||
        base.hasQuery ||
        base.hasFragment ||
        (base.path.isNotEmpty && base.path != '/')) {
      throw StateError('A secure server address is not configured.');
    }
    return base.replace(path: path, query: null, fragment: null);
  }

  Future<http.Response> _post(String path, Map<String, dynamic> body) {
    return http
        .post(
          _endpoint(path),
          headers: const {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
            'ngrok-skip-browser-warning': 'true',
          },
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 20));
  }

  String _errorMessage(http.Response response) {
    if (response.statusCode == 429) {
      return 'Too many requests. Please wait before trying again.';
    }
    if (response.statusCode == 404) {
      return 'Password recovery is not available. Contact the administrator.';
    }
    if (response.statusCode >= 500) {
      return 'The server is temporarily unavailable. Try again later.';
    }
    try {
      final data = jsonDecode(response.body);
      if (data is Map) {
        final errors = data['errors'];
        if (errors is Map && errors.isNotEmpty) {
          final first = errors.values.first;
          if (first is List && first.isNotEmpty) return first.first.toString();
          if (first is String) return first;
        }
        if (data['message'] is String) return data['message'] as String;
      }
    } catch (_) {}
    return 'Unable to complete the request (HTTP ${response.statusCode}).';
  }

  Future<void> _run(Future<void> Function() operation) async {
    if (_busy) return;
    if (!ApiConfig.useRealApi) {
      setState(
        () => _error = 'Email password recovery is unavailable in Demo Mode.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await operation();
    } on StateError catch (error) {
      if (mounted) setState(() => _error = error.message.toString());
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Connection failed. Check your internet.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _requestCode({bool resend = false}) async {
    final email = emailController.text.trim().toLowerCase();
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      setState(() => _error = 'Enter a valid registered email address.');
      return;
    }
    if (resend &&
        _nextResendAt != null &&
        DateTime.now().isBefore(_nextResendAt!)) {
      setState(() => _error = 'Please wait before requesting another code.');
      return;
    }
    await _run(() async {
      final response = await _post(_requestPath, {'email': email});
      if (!mounted) return;
      if (![200, 202, 204].contains(response.statusCode)) {
        setState(() => _error = _errorMessage(response));
        return;
      }
      // The server should send this generic response even for unknown emails.
      setState(() {
        _requestedEmail = email;
        _codeController.clear();
        _nextResendAt = DateTime.now().add(const Duration(seconds: 60));
        _step = 1;
      });
    });
  }

  Future<void> _verifyCode() async {
    final code = _codeController.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      setState(() => _error = 'Enter the six-digit verification code.');
      return;
    }
    await _run(() async {
      final response = await _post(_verifyPath, {
        'email': _requestedEmail,
        'code': code,
      });
      if (!mounted) return;
      if (![200, 204].contains(response.statusCode)) {
        setState(() => _error = _errorMessage(response));
        return;
      }
      setState(() => _step = 2);
    });
  }

  Future<void> _resetPassword() async {
    final password = _passwordController.text;
    final confirmation = _confirmController.text;
    if (password.length < 8) {
      setState(() => _error = 'Choose a password with at least 8 characters.');
      return;
    }
    if (password != confirmation) {
      setState(() => _error = 'The passwords do not match.');
      return;
    }
    await _run(() async {
      // Laravel MUST recheck the OTP in the reset endpoint. Successfully
      // opening step 2 alone does not authorize a password change.
      final response = await _post(_resetPath, {
        'email': _requestedEmail,
        'code': _codeController.text.trim(),
        'password': password,
        'password_confirmation': confirmation,
      });
      if (!mounted) return;
      if (![200, 204].contains(response.statusCode)) {
        setState(() => _error = _errorMessage(response));
        return;
      }
      _codeController.clear();
      _passwordController.clear();
      _confirmController.clear();
      setState(() => _step = 3);
    });
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboard,
    bool obscure = false,
    Widget? suffix,
  }) => TextField(
    controller: controller,
    enabled: !_busy,
    keyboardType: keyboard,
    autocorrect: false,
    enableSuggestions: !obscure,
    obscureText: obscure,
    textInputAction: TextInputAction.done,
    decoration: InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      suffixIcon: suffix,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    const headings = [
      'Forgot your password?',
      'Check your email',
      'Create a new password',
      'Password updated',
    ];
    const descriptions = [
      'Enter your registered email address to receive a verification code.',
      'If the address belongs to an account, a six-digit code will be sent. Check your inbox and spam folder.',
      'Choose a new password to use with your School ID when signing in.',
      'You can now sign in with your School ID and new password.',
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Password Recovery')),
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(gradient: appGradient),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(18),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(
                        child: CircleAvatar(
                          radius: 34,
                          backgroundColor: dark
                              ? const Color(0xFF283F5B)
                              : const Color(0xFFE6F0FC),
                          child: Icon(
                            _step == 3
                                ? Icons.check_circle_outline_rounded
                                : _step == 2
                                ? Icons.lock_reset_rounded
                                : _step == 1
                                ? Icons.mark_email_unread_outlined
                                : Icons.mail_outline_rounded,
                            size: 34,
                            color: dark ? _gold : _navy,
                          ),
                        ),
                      ),
                      const SizedBox(height: 17),
                      Text(
                        headings[_step],
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 23,
                          fontWeight: FontWeight.w800,
                          color: colors.onSurface,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        descriptions[_step],
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.5,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 22),
                      if (_error != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: colors.errorContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _error!,
                            style: TextStyle(color: colors.onErrorContainer),
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],
                      if (_step == 0) ...[
                        _field(
                          controller: emailController,
                          label: 'Registered Email Address',
                          icon: Icons.email_outlined,
                          keyboard: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 17),
                        FilledButton.icon(
                          onPressed: _busy ? null : () => _requestCode(),
                          icon: const Icon(Icons.send_outlined),
                          label: Text(
                            _busy ? 'Sending...' : 'Send Verification Code',
                          ),
                        ),
                      ],
                      if (_step == 1) ...[
                        Text(
                          _requestedEmail,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: colors.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _field(
                          controller: _codeController,
                          label: 'Six-digit Code',
                          icon: Icons.pin_outlined,
                          keyboard: TextInputType.number,
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: _busy ? null : _verifyCode,
                          icon: const Icon(Icons.verified_user_outlined),
                          label: Text(_busy ? 'Verifying...' : 'Verify Code'),
                        ),
                        const SizedBox(height: 6),
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () => _requestCode(resend: true),
                          child: const Text('Resend code (after 60 seconds)'),
                        ),
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () => setState(() {
                                  _step = 0;
                                  _error = null;
                                }),
                          child: const Text('Use a different email'),
                        ),
                      ],
                      if (_step == 2) ...[
                        _field(
                          controller: _passwordController,
                          label: 'New Password',
                          icon: Icons.lock_outline_rounded,
                          obscure: !_passwordVisible,
                          suffix: IconButton(
                            tooltip: _passwordVisible
                                ? 'Hide password'
                                : 'Show password',
                            icon: Icon(
                              _passwordVisible
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                            ),
                            onPressed: () => setState(
                              () => _passwordVisible = !_passwordVisible,
                            ),
                          ),
                        ),
                        const SizedBox(height: 13),
                        _field(
                          controller: _confirmController,
                          label: 'Confirm New Password',
                          icon: Icons.lock_outline_rounded,
                          obscure: !_confirmVisible,
                          suffix: IconButton(
                            tooltip: _confirmVisible
                                ? 'Hide password'
                                : 'Show password',
                            icon: Icon(
                              _confirmVisible
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                            ),
                            onPressed: () => setState(
                              () => _confirmVisible = !_confirmVisible,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Use at least 8 characters.',
                          style: TextStyle(
                            color: colors.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 17),
                        FilledButton.icon(
                          onPressed: _busy ? null : _resetPassword,
                          icon: const Icon(Icons.lock_reset_rounded),
                          label: Text(_busy ? 'Updating...' : 'Reset Password'),
                        ),
                      ],
                      if (_step == 3)
                        FilledButton.icon(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.login_rounded),
                          label: const Text('Back to Login'),
                        ),
                      if (_step != 3) ...[
                        const SizedBox(height: 12),
                        TextButton.icon(
                          onPressed: _busy
                              ? null
                              : () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back_rounded),
                          label: const Text('Back to Login'),
                        ),
                      ],
                      if (!ApiConfig.useRealApi) ...[
                        const SizedBox(height: 10),
                        Text(
                          'Demo Mode: Password recovery requires Laravel.',
                          style: TextStyle(
                            color: colors.onSurfaceVariant,
                            fontSize: 11,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
