import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Shared theme controller for the entire EventEase app.
final appThemeController = AppThemeController();

class AppThemeController extends ChangeNotifier {
  static const String _storageKey = 'eventease_theme';

  final SharedPreferencesAsync _preferences = SharedPreferencesAsync();

  ThemeMode _themeMode = ThemeMode.light;

  ThemeMode get themeMode => _themeMode;

  bool get isDarkMode => _themeMode == ThemeMode.dark;

  // Load the previously selected theme when the app starts.
  Future<void> loadTheme() async {
    try {
      final saved = await _preferences.getString(_storageKey);

      _themeMode = saved == 'dark' ? ThemeMode.dark : ThemeMode.light;

      notifyListeners();
    } catch (error) {
      debugPrint('Could not load theme: $error');
    }
  }

  // Update immediately and save for the next launch.
  Future<void> setDarkMode(bool enabled) async {
    _themeMode = enabled ? ThemeMode.dark : ThemeMode.light;

    notifyListeners();

    try {
      await _preferences.setString(_storageKey, enabled ? 'dark' : 'light');
    } catch (error) {
      debugPrint('Could not save theme: $error');
    }
  }

  // ======================================================
  // TMC EVENTEASE - DARK MODE THEME
  // ======================================================

  ThemeData get eventEaseDarkTheme {
    const darkBackground = Color(0xFF101B2D);
    const darkSurface = Color(0xFF19283D);
    const darkBorder = Color(0xFF30445F);
    const darkNavy = Color(0xFF0E3062);
    const gold = Color(0xFFFFCA40);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,

      scaffoldBackgroundColor: darkBackground,

      colorScheme: ColorScheme.fromSeed(
        seedColor: gold,
        brightness: Brightness.dark,
        surface: darkSurface,
      ),

      // APP BAR
      appBarTheme: const AppBarTheme(
        backgroundColor: darkNavy,
        foregroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),

      // CARDS
      cardTheme: CardThemeData(
        color: darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: darkBorder),
        ),
      ),

      // INPUT FIELDS
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkSurface,

        labelStyle: const TextStyle(color: Color(0xFFBCCAE0)),

        hintStyle: const TextStyle(color: Color(0xFF91A1B9)),

        prefixIconColor: const Color(0xFFBCCAE0),

        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),

        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: darkBorder),
        ),

        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: gold, width: 1.6),
        ),
      ),

      // BOTTOM NAVIGATION
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: darkSurface,
        indicatorColor: Color(0xFF2B496D),
      ),

      // BUTTONS
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: gold,
          foregroundColor: darkNavy,
          minimumSize: const Size(double.infinity, 54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),

      // DIALOG BOXES
      dialogTheme: DialogThemeData(
        backgroundColor: darkSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),

      // DIVIDERS
      dividerTheme: const DividerThemeData(color: darkBorder),
    );
  }
}
