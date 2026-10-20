part of 'main.dart';

// ======================================================
// TMC EVENTEASE - ROLE-BASED MAIN NAVIGATION
// ======================================================

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int selectedIndex = 0;

  bool get isScanner {
    final role = savedUserRole.trim().toLowerCase();
    return role == 'scanner' || role == 'admin';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final selectedColor = isDark ? yellow : navy;
    final unselectedColor = scheme.onSurfaceVariant;
    final indicatorColor = isDark ? const Color(0xFF283F60) : lightNavy;

    final pages = isScanner
        ? <Widget>[const QRCodePage(), const ScannerProfilePage()]
        : <Widget>[
            DashboardPage(
              onTabSelected: (index) {
                if (index >= 0 && index < 4) {
                  setState(() => selectedIndex = index);
                }
              },
            ),
            const EventsPage(),
            const MyEventsPage(),
            const ProfilePage(),
          ];

    final destinations = isScanner
        ? <NavigationDestination>[
            const NavigationDestination(
              icon: Icon(Icons.qr_code_scanner_outlined),
              selectedIcon: Icon(Icons.qr_code_scanner_rounded),
              label: 'Scan QR',
            ),
            const NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person_rounded),
              label: 'Profile',
            ),
          ]
        : <NavigationDestination>[
            const NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            const NavigationDestination(
              icon: Icon(Icons.event_outlined),
              selectedIcon: Icon(Icons.event_rounded),
              label: 'Events',
            ),
            const NavigationDestination(
              icon: Icon(Icons.confirmation_num_outlined),
              selectedIcon: Icon(Icons.confirmation_num_rounded),
              label: 'My Passes',
            ),
            const NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person_rounded),
              label: 'Profile',
            ),
          ];

    final safeIndex = selectedIndex >= 0 && selectedIndex < pages.length
        ? selectedIndex
        : 0;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,

      // Scanner tabs are unmounted when inactive so the camera controller
      // is disposed; student tabs retain their UI state.
      body: isScanner
          ? AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: KeyedSubtree(
                key: ValueKey('scanner-tab-$safeIndex'),
                child: pages[safeIndex],
              ),
            )
          : IndexedStack(index: safeIndex, children: pages),

      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: scheme.surface,
          border: Border(
            top: BorderSide(color: scheme.outlineVariant, width: 0.5),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.06),
              blurRadius: 18,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: NavigationBarTheme(
          data: NavigationBarThemeData(
            labelTextStyle: WidgetStateProperty.resolveWith<TextStyle>((
              states,
            ) {
              final selected = states.contains(WidgetState.selected);

              return TextStyle(
                color: selected ? selectedColor : unselectedColor,
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              );
            }),
          ),
          child: NavigationBar(
            height: 68,
            selectedIndex: safeIndex,
            backgroundColor: scheme.surface,
            surfaceTintColor: Colors.transparent,
            indicatorColor: indicatorColor,
            animationDuration: const Duration(milliseconds: 250),
            onDestinationSelected: (index) {
              if (index != safeIndex) {
                setState(() => selectedIndex = index);
              }
            },
            destinations: destinations,
          ),
        ),
      ),
    );
  }
}
