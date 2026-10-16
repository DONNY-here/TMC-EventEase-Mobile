part of 'main.dart';

// ======================================================
// TMC EVENTEASE - FORGOT PASSWORD PAGE
// ======================================================

class ForgotPasswordPage extends StatefulWidget {
  final String initialEmail;

  const ForgotPasswordPage({super.key, this.initialEmail = ''});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  late final TextEditingController emailController;

  bool isSending = false;
  bool requestSubmitted = false;

  @override
  void initState() {
    super.initState();
    emailController = TextEditingController(text: widget.initialEmail);
  }

  // ======================================================
  // REQUEST PASSWORD RESET
  // ======================================================

  Future<void> requestPasswordReset() async {
    if (isSending) return;

    final email = emailController.text.trim();

    if (email.isEmpty) {
      showMessage(context, 'Please enter your email.');
      return;
    }

    final emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

    if (!emailPattern.hasMatch(email)) {
      showMessage(context, 'Please enter a valid email address.');
      return;
    }

    // Demo mode does not send reset emails.
    if (!ApiConfig.useRealApi) {
      showMessage(
        context,
        'Password reset is not available for '
        'local demo accounts yet.',
      );
      return;
    }

    setState(() {
      isSending = true;
    });

    try {
      final uri = ApiConfig.forgotPasswordUri;

      if (uri == null) {
        showMessage(context, 'Password recovery API is not configured.');
        return;
      }

      final response = await http
          .post(
            uri,
            headers: const {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({'email': email}),
          )
          .timeout(const Duration(seconds: 15));

      if (!mounted) return;

      if (response.statusCode == 200 ||
          response.statusCode == 202 ||
          response.statusCode == 204) {
        setState(() {
          requestSubmitted = true;
        });
      } else if (response.statusCode == 429) {
        showMessage(context, 'Too many requests. Please try again later.');
      } else if (response.statusCode == 404) {
        showMessage(
          context,
          'Password recovery is not available '
          'on the server yet.',
        );
      } else {
        showMessage(
          context,
          'Unable to process the request. '
          'Please try again later.',
        );
      }
    } catch (error) {
      if (!mounted) return;

      debugPrint(
        'Password reset request failed: '
        '${error.runtimeType}',
      );

      showMessage(context, 'Unable to connect to the server.');
    } finally {
      if (mounted) {
        setState(() {
          isSending = false;
        });
      }
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    super.dispose();
  }

  // ======================================================
  // FORGOT PASSWORD UI
  // ======================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Forgot Password')),
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(gradient: appGradient),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(22),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 460),
              padding: const EdgeInsets.all(26),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: lightNavy,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Icon(
                        requestSubmitted
                            ? Icons.mark_email_read_rounded
                            : Icons.lock_reset_rounded,
                        size: 48,
                        color: navy,
                      ),
                    ),
                  ),

                  const SizedBox(height: 22),

                  Text(
                    requestSubmitted ? 'Check Your Email' : 'Forgot Password?',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: textDark,
                    ),
                  ),

                  const SizedBox(height: 10),

                  Text(
                    requestSubmitted
                        ? 'If your email is registered, '
                              'password reset instructions '
                              'will be sent to your inbox.'
                        : 'Enter your registered email '
                              'address to request password '
                              'reset instructions.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: textGrey,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),

                  const SizedBox(height: 26),

                  if (!requestSubmitted) ...[
                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      enabled: !isSending,
                      decoration: const InputDecoration(
                        labelText: 'Email Address',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                    ),

                    const SizedBox(height: 20),

                    ElevatedButton.icon(
                      onPressed: isSending ? null : requestPasswordReset,
                      icon: isSending
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: navy,
                              ),
                            )
                          : const Icon(Icons.mark_email_read_outlined),
                      label: Text(
                        isSending ? 'Sending Request...' : 'Send Reset Link',
                      ),
                    ),
                  ],

                  const SizedBox(height: 14),

                  TextButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.arrow_back_rounded),
                    label: const Text('Back to Login'),
                  ),

                  if (!ApiConfig.useRealApi) ...[
                    const SizedBox(height: 12),
                    const Text(
                      'Demo Mode: Email recovery '
                      'requires the web backend.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: textGrey, fontSize: 11),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
