part of 'main.dart';

// ======================================================
// TMC EVENTEASE - NOTIFICATION CENTER
// LIGHT AND DARK MODE SUPPORTED
// ======================================================

class _EventEaseNotification {
  final String id;
  final String title;
  final String message;
  final IconData icon;
  final String category;
  final Event? event;

  const _EventEaseNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.icon,
    required this.category,
    this.event,
  });
}

// ======================================================
// ANNOUNCEMENTS PAGE
// ======================================================

class AnnouncementsPage extends StatefulWidget {
  const AnnouncementsPage({super.key});

  @override
  State<AnnouncementsPage> createState() => _AnnouncementsPageState();
}

class _AnnouncementsPageState extends State<AnnouncementsPage> {
  String _filter = 'All';

  // ====================================================
  // LIGHT AND DARK MODE COLORS
  // ====================================================

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  Color get _pageBackground =>
      _isDark ? const Color(0xFF101B2D) : const Color(0xFFF5F8FC);

  Color get _cardBackground => _isDark ? const Color(0xFF19283D) : Colors.white;

  Color get _unreadBackground =>
      _isDark ? const Color(0xFF223A58) : const Color(0xFFEAF2FB);

  Color get _primaryText =>
      _isDark ? const Color(0xFFF0F5FF) : const Color(0xFF17283E);

  Color get _secondaryText =>
      _isDark ? const Color(0xFFB7C5D8) : const Color(0xFF69798C);

  Color get _outline =>
      _isDark ? const Color(0xFF344861) : const Color(0xFFE1E8F2);

  Color get _accent => _isDark ? yellow : navy;

  Color get _iconBackground =>
      _isDark ? const Color(0xFF39412F) : const Color(0xFFFFF5D8);

  // ====================================================
  // BUILD NOTIFICATION DATA
  // EXISTING NOTIFICATION LOGIC PRESERVED
  // ====================================================

  List<_EventEaseNotification> _notifications() {
    final items = <_EventEaseNotification>[
      const _EventEaseNotification(
        id: 'announcement_techtalk',
        title: 'TechTalk Registration Open',
        message: 'Registration for TechTalk 2026 is now open.',
        icon: Icons.campaign_rounded,
        category: 'Announcements',
      ),

      const _EventEaseNotification(
        id: 'announcement_reminder',
        title: 'Event Reminder',
        message:
            'Please arrive 15 minutes before '
            'your registered event.',
        icon: Icons.alarm_rounded,
        category: 'Announcements',
      ),

      const _EventEaseNotification(
        id: 'announcement_qr',
        title: 'Bring Your QR Code',
        message:
            'Your QR code will be used during '
            'attendance checking.',
        icon: Icons.qr_code_2_rounded,
        category: 'Announcements',
      ),
    ];

    // Event-related notifications
    for (final event in registeredEvents) {
      final key = eventKey(event);

      items.add(
        _EventEaseNotification(
          id: 'registration_$key',
          title: 'Registration Confirmed',
          message: 'You are registered for ${event.title}.',
          icon: Icons.how_to_reg_rounded,
          category: 'Events',
          event: event,
        ),
      );

      if (attendanceStatus[key] == 'Present') {
        items.add(
          _EventEaseNotification(
            id: 'attendance_$key',
            title: 'Attendance Confirmed',
            message:
                'Your attendance for ${event.title} '
                'was recorded.',
            icon: Icons.check_circle_rounded,
            category: 'Events',
            event: event,
          ),
        );

        if ((eventRatings[key] ?? 0) > 0) {
          items.add(
            _EventEaseNotification(
              id: 'certificate_$key',
              title: 'E-Certificate Available',
              message:
                  'Your certificate for ${event.title} '
                  'is ready to view.',
              icon: Icons.workspace_premium_rounded,
              category: 'Certificates',
              event: event,
            ),
          );
        } else {
          items.add(
            _EventEaseNotification(
              id: 'evaluation_$key',
              title: 'Complete Your Evaluation',
              message:
                  'Evaluate ${event.title} to unlock '
                  'your E-Certificate.',
              icon: Icons.rate_review_rounded,
              category: 'Events',
              event: event,
            ),
          );
        }
      }
    }

    return items.reversed.toList();
  }

  // ====================================================
  // OPEN NOTIFICATION
  // SHARED READ / UNREAD HANDLING PRESERVED
  // ====================================================

  Future<void> _openNotification(_EventEaseNotification notification) async {
    markNotificationAsRead(notification.id);

    if (notification.event != null) {
      await Navigator.push(
        context,
        animatedRoute(EventDetailsPage(event: notification.event!)),
      );

      if (mounted) {
        setState(() {});
      }
    }
  }

  // ====================================================
  // HEADER CARD
  // ====================================================

  Widget _headerCard(int unread) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: appGradient,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: navy.withValues(alpha: 0.12),
            blurRadius: 17,
            offset: const Offset(0, 7),
          ),
        ],
      ),

      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(15),
            ),

            child: const Icon(
              Icons.notifications_active_rounded,
              color: yellow,
              size: 28,
            ),
          ),

          const SizedBox(width: 13),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Stay Updated',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  '$unread unread notification'
                  '${unread == 1 ? '' : 's'}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12.5),
                ),
              ],
            ),
          ),

          if (unread > 0)
            Container(
              constraints: const BoxConstraints(minWidth: 31, minHeight: 31),
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: yellow,
                shape: BoxShape.circle,
              ),
              child: Text(
                '$unread',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: navy,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ====================================================
  // NOTIFICATION CATEGORY FILTERS
  // ====================================================

  Widget _filterChips() {
    const categories = ['All', 'Events', 'Certificates', 'Announcements'];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,

      child: Row(
        children: categories.map((category) {
          final selected = _filter == category;

          return Padding(
            padding: const EdgeInsets.only(right: 8),

            child: ChoiceChip(
              label: Text(category),

              selected: selected,

              backgroundColor: _cardBackground,

              selectedColor: _isDark ? yellow : navy,

              side: BorderSide(
                color: selected ? (_isDark ? yellow : navy) : _outline,
              ),

              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),

              labelStyle: TextStyle(
                color: selected
                    ? (_isDark ? navy : Colors.white)
                    : _primaryText,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                fontSize: 12,
              ),

              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),

              onSelected: (_) {
                setState(() {
                  _filter = category;
                });
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  // ====================================================
  // NOTIFICATION CARD
  // ====================================================

  Widget _notificationCard({
    required _EventEaseNotification notification,
    required bool unread,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: unread ? _unreadBackground : _cardBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _outline),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: _isDark ? 0.10 : 0.035),
            blurRadius: 13,
            offset: const Offset(0, 4),
          ),
        ],
      ),

      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),

        child: InkWell(
          borderRadius: BorderRadius.circular(18),

          onTap: () {
            _openNotification(notification);
          },

          child: Padding(
            padding: const EdgeInsets.all(15),

            child: Row(
              children: [
                // NOTIFICATION ICON
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _iconBackground,
                    borderRadius: BorderRadius.circular(14),
                  ),

                  child: Icon(
                    notification.icon,
                    color: _isDark ? yellow : navy,
                    size: 24,
                  ),
                ),

                const SizedBox(width: 12),

                // NOTIFICATION INFORMATION
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [
                      Text(
                        notification.title,
                        style: TextStyle(
                          color: _primaryText,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),

                      const SizedBox(height: 5),

                      Text(
                        notification.message,
                        style: TextStyle(
                          color: _secondaryText,
                          fontSize: 12.5,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                if (unread)
                  Container(
                    width: 9,
                    height: 9,
                    decoration: const BoxDecoration(
                      color: yellow,
                      shape: BoxShape.circle,
                    ),
                  )
                else
                  Icon(
                    Icons.chevron_right_rounded,
                    color: _secondaryText,
                    size: 22,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ====================================================
  // EMPTY NOTIFICATIONS
  // ====================================================

  Widget _emptyState() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 35),
      decoration: BoxDecoration(
        color: _cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _outline),
      ),

      child: Column(
        children: [
          Icon(Icons.notifications_off_outlined, color: _accent, size: 42),

          const SizedBox(height: 12),

          Text(
            'No Notifications',
            style: TextStyle(
              color: _primaryText,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 7),

          Text(
            'No notifications in this category.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _secondaryText, fontSize: 13),
          ),
        ],
      ),
    );
  }

  // ====================================================
  // MAIN NOTIFICATION PAGE
  // ====================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageBackground,

      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: navy,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),

      body: ValueListenableBuilder<Set<String>>(
        valueListenable: readNotificationIds,

        builder: (context, readIds, _) {
          final notifications = _notifications();

          final unread = notifications
              .where((notice) => !readIds.contains(notice.id))
              .length;

          final visible = notifications.where((notice) {
            return _filter == 'All' || notice.category == _filter;
          }).toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),

            children: [
              // ==================================
              // NOTIFICATION HEADER
              // ==================================
              _headerCard(unread),

              const SizedBox(height: 20),

              // ==================================
              // RECENT UPDATES
              // ==================================
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Recent Updates',
                      style: TextStyle(
                        color: _primaryText,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),

                  TextButton(
                    onPressed: unread == 0 ? null : markAllNotificationsAsRead,

                    style: TextButton.styleFrom(foregroundColor: _accent),

                    child: const Text(
                      'Mark all as read',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // ==================================
              // CATEGORY FILTERS
              // ==================================
              _filterChips(),

              const SizedBox(height: 17),

              // ==================================
              // NOTIFICATION LIST
              // ==================================
              if (visible.isEmpty)
                _emptyState()
              else
                ...visible.map((notification) {
                  final unread = !readIds.contains(notification.id);

                  return _notificationCard(
                    notification: notification,
                    unread: unread,
                  );
                }),
            ],
          );
        },
      ),
    );
  }
}
