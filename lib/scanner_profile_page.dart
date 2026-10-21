part of 'main.dart';

class ScannerProfilePage extends StatelessWidget {
  const ScannerProfilePage({super.key});

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Log out of EventEase?'),
        content: const Text(
          'Are you sure you want to log out? '
          'You will need to sign in again to access the attendance scanner.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFBE3446),
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.logout_rounded, size: 18),
            label: const Text('Log Out'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await logoutEventEaseUser(context);
    }
  }

  Widget _infoRow(
    IconData icon,
    String label,
    String value,
    Color ink,
    Color muted,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: ink.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: muted, size: 21),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: muted, fontSize: 12)),
              const SizedBox(height: 3),
              Text(
                value,
                style: TextStyle(
                  color: ink,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final background = isDark
        ? const Color(0xFF0B1424)
        : const Color(0xFFF4F6FA);

    final surface = isDark ? const Color(0xFF17263C) : Colors.white;

    final ink = isDark ? const Color(0xFFF1F6FD) : const Color(0xFF182A40);

    final muted = isDark ? const Color(0xFFB0BED1) : const Color(0xFF68788D);

    final border = isDark ? const Color(0xFF31445C) : const Color(0xFFE1E7F0);

    final name = savedName.trim().isNotEmpty
        ? savedName.trim()
        : 'EventEase Scanner';

    final email = savedEmail.trim();

    final role = savedUserRole.trim().isNotEmpty
        ? savedUserRole.trim()
        : 'Scanner';

    final displayRole = role[0].toUpperCase() + role.substring(1).toLowerCase();

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        foregroundColor: ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Scanner Profile',
          style: TextStyle(
            color: ink,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
        children: [
          // Compact profile header
          Container(
            padding: const EdgeInsets.all(19),
            decoration: BoxDecoration(
              gradient: appGradient,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Row(
              children: [
                Container(
                  width: 66,
                  height: 66,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.admin_panel_settings_rounded,
                    size: 38,
                    color: yellow,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Authorized Attendance Scanner',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      const SizedBox(height: 9),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.13),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '$displayRole Account',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 22),
          Text(
            'Account Information',
            style: TextStyle(
              color: ink,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 11),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(19),
              border: Border.all(color: border),
            ),
            child: Column(
              children: [
                _infoRow(
                  Icons.person_outline_rounded,
                  'Full Name',
                  name,
                  ink,
                  muted,
                ),
                if (email.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Divider(color: border, height: 1),
                  const SizedBox(height: 12),
                  _infoRow(
                    Icons.email_outlined,
                    'Email Address',
                    email,
                    ink,
                    muted,
                  ),
                ],
                const SizedBox(height: 12),
                Divider(color: border, height: 1),
                const SizedBox(height: 12),
                _infoRow(
                  Icons.badge_outlined,
                  'Account Role',
                  displayRole,
                  ink,
                  muted,
                ),
                const SizedBox(height: 12),
                Divider(color: border, height: 1),
                const SizedBox(height: 12),
                _infoRow(
                  Icons.dns_outlined,
                  'Connection Mode',
                  ApiConfig.useRealApi ? 'Laravel API' : 'Demo Mode',
                  ink,
                  muted,
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),
          Text(
            'Account Security',
            style: TextStyle(
              color: ink,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),

          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(17),
              border: Border.all(color: border),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.shield_outlined,
                  color: Color(0xFF3180B1),
                  size: 23,
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    'Scanner access and event assignments '
                    'are managed by the administrator.',
                    style: TextStyle(color: muted, fontSize: 12.5, height: 1.4),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),
          SizedBox(
            height: 50,
            child: OutlinedButton.icon(
              onPressed: () => _confirmLogout(context),
              icon: const Icon(Icons.logout_rounded, size: 20),
              label: const Text(
                'Log Out',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFD1434F),
                side: const BorderSide(color: Color(0xFFD1434F)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
