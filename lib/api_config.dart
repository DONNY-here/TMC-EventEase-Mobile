

// ======================================================
// TMC EVENTEASE - API CONFIGURATION
// ======================================================

class ApiConfig {
  // Release builds must never use demo authentication.
  static const bool useRealApi = true;

  // Actual server address will be supplied at launch.
  static const String baseUrl = String.fromEnvironment(
    'EVENTEASE_API_BASE_URL',
    defaultValue: '',
  );

  // Confirm endpoint with backend developer.
  static const String loginPath = String.fromEnvironment(
    'EVENTEASE_LOGIN_PATH',
    defaultValue: '/api/auth/login',
  );

  static Uri? get loginUri {
    if (baseUrl.trim().isEmpty) {
      return null;
    }

    final base = Uri.tryParse(baseUrl.trim());

    if (base == null ||
        base.scheme != 'https' ||
        base.host.isEmpty ||
        base.userInfo.isNotEmpty ||
        base.hasQuery ||
        base.hasFragment ||
        (base.path.isNotEmpty && base.path != '/')) {
      throw const FormatException('API base URL must be a valid HTTPS origin.');
    }

    if (!loginPath.startsWith('/') ||
        loginPath.startsWith('//') ||
        loginPath.contains('?') ||
        loginPath.contains('#')) {
      throw const FormatException('Invalid login API path.');
    }

    return base.replace(path: loginPath);
  }

  // ======================================================
  // FORGOT PASSWORD API CONFIGURATION
  // ======================================================

  static const String forgotPasswordPath = String.fromEnvironment(
    'EVENTEASE_FORGOT_PASSWORD_PATH',
    defaultValue: '/api/auth/forgot-password',
  );

  static Uri? get forgotPasswordUri {
    final login = loginUri;

    if (login == null) {
      return null;
    }

    if (!forgotPasswordPath.startsWith('/') ||
        forgotPasswordPath.startsWith('//') ||
        forgotPasswordPath.contains('?') ||
        forgotPasswordPath.contains('#')) {
      throw const FormatException('Invalid password recovery path.');
    }

    return login.replace(path: forgotPasswordPath);
  }


  // ======================================================
  // EVENTS API CONFIGURATION
  // ======================================================

  static const String eventsPath = String.fromEnvironment(
    'EVENTEASE_EVENTS_PATH',
    defaultValue: '/api/events',
  );

  static Uri? get eventsUri {
    final login = loginUri;

    if (login == null) {
      return null;
    }

    if (!eventsPath.startsWith('/') ||
        eventsPath.startsWith('//') ||
        eventsPath.contains('?') ||
        eventsPath.contains('#')) {
      throw const FormatException('Invalid events API path.');
    }

    return login.replace(path: eventsPath);
  }

}
