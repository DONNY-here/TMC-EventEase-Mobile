import 'package:shared_preferences/shared_preferences.dart';

// ======================================================
// TMC EVENTEASE - DEMO SESSION STORAGE
// Student demo only. Not production authentication.
// ======================================================

class DemoSessionStorage {
  static const String _rememberKey = 'eventease_remember_demo_student';

  final SharedPreferencesAsync _prefs = SharedPreferencesAsync();

  Future<bool> shouldRestoreStudent() async {
    return await _prefs.getBool(_rememberKey) ?? false;
  }

  Future<void> setRememberStudent(bool remember) async {
    if (remember) {
      await _prefs.setBool(_rememberKey, true);
    } else {
      await clear();
    }
  }

  Future<void> clear() async {
    await _prefs.remove(_rememberKey);
  }
}
