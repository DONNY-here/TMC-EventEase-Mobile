
part of 'main.dart';

// ======================================================
// MAIN PAGE / ROLE-BASED BOTTOM NAVIGATION
// LIGHT AND DARK MODE SUPPORTED
// ======================================================

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int selectedIndex = 0;

  bool get isScanner =>
      savedUserRole == 'scanner' || savedUserRole == 'admin';

  @override
  Widget build(BuildContext context) {
    // ==================================================
    // LIGHT AND DARK MODE COLORS
    // ==================================================

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final isDarkMode = theme.brightness == Brightness.dark;

    final Color navigationBackground = colorScheme.surface;

    final Color selectedIconColor =
    isDarkMode ? yellow : navy;

    final Color unselectedIconColor =
        colorScheme.onSurfaceVariant;

    final Color navigationIndicatorColor = isDarkMode
        ? const Color(0xFF283F60)
        : lightNavy;

    final Color navigationBorderColor =
        colorScheme.outlineVariant;

    // ==================================================
    // ROLE-BASED PAGES
    // ==================================================

    final List<Widget> pages = isScanner
        ? const [
      QRCodePage(),
      ScannerProfilePage(),
    ]
        : [
      DashboardPage(
        onTabSelected: (index) {
          setState(() {
            selectedIndex = index;
          });
        },
      ),
      const EventsPage(),
      const MyEventsPage(),
      const ProfilePage(),
    ];

    // ==================================================
    // ROLE-BASED NAVIGATION DESTINATIONS
    // ==================================================

    final List<NavigationDestination> destinations = isScanner
        ? [
      NavigationDestination(
        icon: Icon(
          Icons.qr_code_scanner_outlined,
          color: unselectedIconColor,
        ),
        selectedIcon: Icon(
          Icons.qr_code_scanner_rounded,
          color: selectedIconColor,
        ),
        label: 'Scan QR',
      ),
      NavigationDestination(
        icon: Icon(
          Icons.person_outline,
          color: unselectedIconColor,
        ),
        selectedIcon: Icon(
          Icons.person_rounded,
          color: selectedIconColor,
        ),
        label: 'Profile',
      ),
    ]
        : [
      NavigationDestination(
        icon: Icon(
          Icons.home_outlined,
          color: unselectedIconColor,
        ),
        selectedIcon: Icon(
          Icons.home_rounded,
          color: selectedIconColor,
        ),
        label: 'Home',
      ),
      NavigationDestination(
        icon: Icon(
          Icons.event_outlined,
          color: unselectedIconColor,
        ),
        selectedIcon: Icon(
          Icons.event_rounded,
          color: selectedIconColor,
        ),
        label: 'Events',
      ),
      NavigationDestination(
        icon: Icon(
          Icons.confirmation_num_outlined,
          color: unselectedIconColor,
        ),
        selectedIcon: Icon(
          Icons.confirmation_num_rounded,
          color: selectedIconColor,
        ),
        label: 'My Passes',
      ),
      NavigationDestination(
        icon: Icon(
          Icons.person_outline,
          color: unselectedIconColor,
        ),
        selectedIcon: Icon(
          Icons.person_rounded,
          color: selectedIconColor,
        ),
        label: 'Profile',
      ),
    ];

    // ==================================================
    // SAFE NAVIGATION INDEX
    // ==================================================

    final safeIndex =
    selectedIndex < pages.length ? selectedIndex : 0;

    // ==================================================
    // MAIN SCAFFOLD
    // ==================================================

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,

      // ================================================
      // PAGE CONTENT
      // ================================================

      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        child: KeyedSubtree(
          key: ValueKey('${savedUserRole}_$safeIndex'),
          child: pages[safeIndex],
        ),
      ),

      // ================================================
      // LIGHT AND DARK MODE BOTTOM NAVIGATION
      // ================================================

      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: navigationBackground,

          border: Border(
            top: BorderSide(
              color: navigationBorderColor,
              width: 0.5,
            ),
          ),

          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: isDarkMode ? 0.22 : 0.06,
              ),
              blurRadius: 18,
              offset: const Offset(0, -5),
            ),
          ],
        ),

        child: NavigationBarTheme(
          data: NavigationBarThemeData(
            labelTextStyle:
            WidgetStateProperty.resolveWith<TextStyle>(
                  (states) {
                final isSelected =
                states.contains(WidgetState.selected);

                return TextStyle(
                  color: isSelected
                      ? selectedIconColor
                      : unselectedIconColor,
                  fontSize: 12,
                  fontWeight: isSelected
                      ? FontWeight.w700
                      : FontWeight.w500,
                );
              },
            ),
          ),

          child: NavigationBar(
            height: 68,
            selectedIndex: safeIndex,

            backgroundColor: navigationBackground,
            surfaceTintColor: Colors.transparent,

            indicatorColor: navigationIndicatorColor,

            animationDuration:
            const Duration(milliseconds: 250),

            onDestinationSelected: (index) {
              setState(() {
                selectedIndex = index;
              });
            },

            destinations: destinations,
          ),
        ),
      ),
    );
  }
}
