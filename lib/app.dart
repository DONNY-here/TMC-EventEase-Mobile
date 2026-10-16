part of 'main.dart';

// ======================================================
// TMC EVENTEASE - APP
// LIGHT MODE & DARK MODE SUPPORT
// ======================================================

class EventEaseApp extends StatelessWidget {
  final bool scannerDemoMode;

  const EventEaseApp({super.key, this.scannerDemoMode = false});

  @override
  Widget build(BuildContext context) {
    // ==================================================
    // LISTEN FOR THEME CHANGES
    // ==================================================

    return AnimatedBuilder(
      animation: appThemeController,

      builder: (context, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'TMC EventEase',

          // ==============================================
          // THEME MODE
          // ==============================================

          // Automatically updates when the student
          // changes Light Mode or Dark Mode.
          themeMode: appThemeController.themeMode,

          // ==============================================
          // LIGHT THEME
          // ==============================================
          theme: ThemeData(
            useMaterial3: true,

            brightness: Brightness.light,

            scaffoldBackgroundColor: lightBg,

            colorScheme: ColorScheme.fromSeed(
              seedColor: navy,
              primary: navy,
              secondary: yellow,
              surface: Colors.white,
              brightness: Brightness.light,
            ),

            // ============================================
            // APP BAR
            // ============================================
            appBarTheme: const AppBarTheme(
              backgroundColor: navy,
              foregroundColor: Colors.white,
              centerTitle: false,
              elevation: 0,
              surfaceTintColor: Colors.transparent,
              titleTextStyle: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),

            // ============================================
            // CARDS
            // ============================================
            cardTheme: CardThemeData(
              color: Colors.white,
              elevation: 0,
              shadowColor: Colors.black12,
              surfaceTintColor: Colors.transparent,
              margin: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: borderColor),
              ),
            ),

            // ============================================
            // INPUT FIELDS
            // ============================================
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: Colors.white,

              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),

              hintStyle: const TextStyle(color: textGrey),

              labelStyle: const TextStyle(color: textGrey),

              prefixIconColor: textGrey,

              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),

              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: borderColor),
              ),

              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: navy, width: 1.6),
              ),
            ),

            // ============================================
            // ELEVATED BUTTONS
            // ============================================
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: yellow,
                foregroundColor: navy,
                minimumSize: const Size(double.infinity, 54),
                elevation: 0,
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),

            // ============================================
            // OUTLINED BUTTONS
            // ============================================
            outlinedButtonTheme: OutlinedButtonThemeData(
              style: OutlinedButton.styleFrom(
                foregroundColor: navy,
                minimumSize: const Size(double.infinity, 52),
                side: const BorderSide(color: borderColor),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),

            // ============================================
            // SNACKBARS
            // ============================================
            snackBarTheme: SnackBarThemeData(
              backgroundColor: textDark,
              contentTextStyle: const TextStyle(color: Colors.white),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),

            // ============================================
            // BOTTOM NAVIGATION
            // ============================================
            navigationBarTheme: const NavigationBarThemeData(
              backgroundColor: Colors.white,
              indicatorColor: lightNavy,
              labelTextStyle: WidgetStatePropertyAll(
                TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
              ),
            ),

            // ============================================
            // DIVIDERS
            // ============================================
            dividerTheme: const DividerThemeData(
              color: borderColor,
              thickness: 1,
            ),
          ),

          // ==============================================
          // DARK MODE THEME
          // ==============================================
          darkTheme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,

            scaffoldBackgroundColor: const Color(0xFF101B2D),

            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFFFFCA40),
              brightness: Brightness.dark,
              surface: const Color(0xFF19283D),
            ),

            // APP BAR
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFF0E3062),
              foregroundColor: Colors.white,
              elevation: 0,
              surfaceTintColor: Colors.transparent,
            ),

            // CARDS
            cardTheme: CardThemeData(
              color: const Color(0xFF19283D),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: Color(0xFF30445F)),
              ),
            ),

            // INPUT FIELDS
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: const Color(0xFF19283D),

              labelStyle: const TextStyle(color: Color(0xFFBCCAE0)),

              hintStyle: const TextStyle(color: Color(0xFF91A1B9)),

              prefixIconColor: const Color(0xFFBCCAE0),

              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),

              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFF30445F)),
              ),

              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(
                  color: Color(0xFFFFCA40),
                  width: 1.6,
                ),
              ),
            ),

            // BOTTOM NAVIGATION
            navigationBarTheme: const NavigationBarThemeData(
              backgroundColor: Color(0xFF19283D),
              indicatorColor: Color(0xFF2B496D),
            ),

            // ELEVATED BUTTONS
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFCA40),
                foregroundColor: const Color(0xFF0E3062),
                minimumSize: const Size(double.infinity, 54),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),

            // DIALOG BOXES
            dialogTheme: DialogThemeData(
              backgroundColor: const Color(0xFF19283D),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),

            // DIVIDERS
            dividerTheme: const DividerThemeData(color: Color(0xFF30445F)),
          ),

          // ==============================================
          // HOME / SESSION MANAGEMENT
          // ==============================================

          // Preserve scanner demo mode and
          // existing real API session handling.
          home: scannerDemoMode && !ApiConfig.useRealApi
              ? const MainPage()
              : const SessionGate(),
        );
      },
    );
  }
}
