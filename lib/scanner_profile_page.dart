part of 'main.dart';

class ScannerProfilePage extends StatelessWidget {
  const ScannerProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scanner Profile')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: appGradient,
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Column(
              children: [
                Icon(
                  Icons.admin_panel_settings_rounded,
                  size: 65,
                  color: yellow,
                ),
                SizedBox(height: 12),
                Text(
                  'TMC Event Officer',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Authorized Attendance Scanner',
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          sectionTitle('Officer Information'),

          const SizedBox(height: 12),

          ProfileInfo(
            icon: Icons.badge_outlined,
            title: 'Account Role',
            value: 'Scanner',
          ),

          const SizedBox(height: 10),

          ProfileInfo(
            icon: Icons.verified_user_outlined,
            title: 'Scanner Status',
            value: 'Demo Mode',
          ),

          const SizedBox(height: 24),

          ElevatedButton.icon(
            onPressed: () async {
              await logoutEventEaseUser(context);
            },
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}
