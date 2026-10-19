part of 'main.dart';

// ======================================================
// NOTIFICATION CENTER
// Uses shared notification state in config_and_data.dart.
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

class AnnouncementsPage extends StatefulWidget {
  const AnnouncementsPage({super.key});

  @override
  State<AnnouncementsPage> createState() => _AnnouncementsPageState();
}

// Cached IDs for the optional navbar notification badge adjustment.
// Populated only after a successful student announcements API fetch.
final Set<String> _liveAnnouncementIds = <String>{};

class _AnnouncementsPageState extends State<AnnouncementsPage> {
  String _filter = 'All';
  bool _liveLoading = false;
  String? _liveError;
  int _liveRequest = 0;
  List<_EventEaseNotification> _liveNotices = [];

  @override
  void initState() {
    super.initState();
    if (ApiConfig.useRealApi) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadLiveAnnouncements();
      });
    }
  }

  Uri _announcementEndpoint(int page) {
    final origin = Uri.tryParse(ApiConfig.baseUrl.trim());
    if (origin == null || origin.scheme != 'https' ||
        origin.host.isEmpty || origin.userInfo.isNotEmpty ||
        (origin.path.isNotEmpty && origin.path != '/')) {
      throw StateError('The secure Laravel API URL is not configured.');
    }
    return origin.replace(
      path: '/api/my/announcements',
      queryParameters: {'page': '$page'},
      fragment: null,
    );
  }

  static _EventEaseNotification _parseAnnouncement(Map<String, dynamic> row) {
    final reference = (row['reference'] ?? row['id'] ?? '').toString().trim();
    if (reference.isEmpty) {
      throw const FormatException('A Laravel announcement has no reference.');
    }
    final title = (row['title'] ?? '').toString().trim();
    final message = (row['message'] ?? '').toString().trim();
    final category = (row['category'] ?? 'General').toString().trim();
    IconData icon;
    switch (category.toLowerCase()) {
      case 'event':
        icon = Icons.event_note_rounded;
        break;
      case 'emergency':
        icon = Icons.warning_amber_rounded;
        break;
      case 'maintenance':
        icon = Icons.build_circle_outlined;
        break;
      default:
        icon = Icons.campaign_rounded;
    }
    return _EventEaseNotification(
      id: 'laravel_announcement_$reference',
      title: title.isEmpty ? 'Campus notice' : title,
      message: message,
      icon: icon,
      category: category.toLowerCase() == 'event' ? 'Events' : 'Announcements',
    );
  }

  String _errorMessage(Object error) {
    if (error is StateError) return error.message.toString();
    if (error is FormatException) {
      return 'Laravel returned an unexpected announcement response.';
    }
    return 'Cannot reach Laravel. Check the connection and try again.';
  }

  Future<void> _loadLiveAnnouncements() async {
    if (!ApiConfig.useRealApi) return;
    final requestId = ++_liveRequest;
    if (mounted) {
      setState(() {
        _liveLoading = true;
        _liveError = null;
        _liveNotices = [];
      });
    }
    final fetched = <_EventEaseNotification>[];
    String? failure;
    try {
      final token = await authTokenStorage.readValidToken();
      if (token == null || token.trim().isEmpty) {
        throw StateError('Your session expired. Sign in again.');
      }
      var page = 1;
      var lastPage = 1;
      do {
        final response = await http.get(
          _announcementEndpoint(page),
          headers: {
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
            'ngrok-skip-browser-warning': 'true',
          },
        ).timeout(const Duration(seconds: 20));
        if (response.statusCode == 401) {
          throw StateError('Your session expired. Sign in again.');
        }
        if (response.statusCode == 403) {
          throw StateError('Laravel denied access to student announcements.');
        }
        if (response.statusCode == 404) {
          throw StateError('Student announcements route is missing on Laravel.');
        }
        if (response.statusCode != 200) {
          throw StateError('Laravel returned HTTP ${response.statusCode}.');
        }
        final decoded = jsonDecode(response.body);
        if (decoded is! Map || decoded['data'] is! List) {
          throw const FormatException('Invalid announcement pagination.');
        }
        for (final item in decoded['data'] as List) {
          if (item is! Map) {
            throw const FormatException('Invalid announcement record.');
          }
          fetched.add(_parseAnnouncement(Map<String, dynamic>.from(item)));
        }
        lastPage = int.tryParse('${decoded['last_page'] ?? 1}') ?? 1;
        if (lastPage < 1 || lastPage > 50) {
          throw StateError('Too many announcement pages to load.');
        }
        page++;
      } while (page <= lastPage);
    } catch (error) {
      failure = _errorMessage(error);
    }
    if (!mounted || requestId != _liveRequest) return;
    setState(() {
      _liveError = failure;
      _liveNotices = failure == null ? fetched : [];
      _liveLoading = false;
    });
    _liveAnnouncementIds
      ..clear()
      ..addAll(_liveNotices.map((notice) => notice.id));
    refreshNotifications();
  }


  List<_EventEaseNotification> _notifications() {
    if (ApiConfig.useRealApi) return _liveNotices;
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
        message: 'Please arrive 15 minutes before your registered event.',
        icon: Icons.alarm_rounded,
        category: 'Announcements',
      ),
      const _EventEaseNotification(
        id: 'announcement_qr',
        title: 'Bring Your QR Code',
        message: 'Your QR code will be used during attendance checking.',
        icon: Icons.qr_code_2_rounded,
        category: 'Announcements',
      ),
    ];

    for (final event in registeredEvents) {
      final key = eventKey(event);
      items.add(_EventEaseNotification(
        id: 'registration_$key',
        title: 'Registration Confirmed',
        message: 'You are registered for ${event.title}.',
        icon: Icons.how_to_reg_rounded,
        category: 'Events',
        event: event,
      ));

      if (attendanceStatus[key] == 'Present') {
        items.add(_EventEaseNotification(
          id: 'attendance_$key',
          title: 'Attendance Confirmed',
          message: 'Your attendance for ${event.title} was recorded.',
          icon: Icons.check_circle_rounded,
          category: 'Events',
          event: event,
        ));

        if ((eventRatings[key] ?? 0) > 0) {
          items.add(_EventEaseNotification(
            id: 'certificate_$key',
            title: 'E-Certificate Available',
            message: 'Your certificate for ${event.title} is ready to view.',
            icon: Icons.workspace_premium_rounded,
            category: 'Certificates',
            event: event,
          ));
        } else {
          items.add(_EventEaseNotification(
            id: 'evaluation_$key',
            title: 'Complete Your Evaluation',
            message: 'Evaluate ${event.title} to unlock your E-Certificate.',
            icon: Icons.rate_review_rounded,
            category: 'Events',
            event: event,
          ));
        }
      }
    }

    return items.reversed.toList();
  }

  Future<void> _openNotification(_EventEaseNotification notification) async {
    markNotificationAsRead(notification.id);
    if (notification.event != null) {
      await Navigator.push(
        context,
        animatedRoute(EventDetailsPage(event: notification.event!)),
      );
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: RefreshIndicator(
        onRefresh: ApiConfig.useRealApi
            ? _loadLiveAnnouncements
            : () async { if (mounted) setState(() {}); },
        child: ValueListenableBuilder<Set<String>>(
          valueListenable: readNotificationIds,
          builder: (context, readIds, _) {
            final notifications = _notifications();
            final unread = notifications.where((n) => !readIds.contains(n.id)).length;
            final visible = notifications
                .where((n) => _filter == 'All' || n.category == _filter)
                .toList();

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: appGradient,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.notifications_active_rounded,
                          color: yellow, size: 30),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Stay Updated',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                )),
                            const SizedBox(height: 3),
                            Text('$unread unread notification${unread == 1 ? '' : 's'}',
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 12.5)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Expanded(
                      child: Text('Recent Updates',
                          style: TextStyle(
                              color: textDark, fontWeight: FontWeight.w800,
                              fontSize: 16)),
                    ),
                    TextButton(
                      onPressed: unread == 0 ? null : () {
                        readNotificationIds.value = {
                          ...readNotificationIds.value,
                          ...notifications.map((notice) => notice.id),
                        };
                      },
                      child: const Text('Mark all as read'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: ['All', 'Events', 'Certificates', 'Announcements']
                        .map((category) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(category),
                        selected: _filter == category,
                        onSelected: (_) =>
                            setState(() => _filter = category),
                      ),
                    ))
                        .toList(),
                  ),
                ),
                const SizedBox(height: 14),
                if (ApiConfig.useRealApi)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 10),
                    child: Text(
                      'Read status is saved in this app session. Pull down to refresh live announcements.',
                      style: TextStyle(fontSize: 11, color: textGrey),
                    ),
                  ),
                if (ApiConfig.useRealApi && _liveLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 35),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (ApiConfig.useRealApi && _liveError != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 27),
                    child: Column(children: [
                      const Icon(Icons.cloud_off_rounded, size: 35),
                      const SizedBox(height: 10),
                      Text(_liveError!, textAlign: TextAlign.center),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: _loadLiveAnnouncements,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Retry'),
                      ),
                    ]),
                  )
                else if (visible.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: Text('No notifications in this category.',
                            style: TextStyle(color: textGrey)),
                      ),
                    ),
                if (!_liveLoading && _liveError == null)
                  ...visible.map((notification) {
                    final isUnread = !readIds.contains(notification.id);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Material(
                        color: isUnread ? lightNavy : Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: () => _openNotification(notification),
                          child: Container(
                            padding: const EdgeInsets.all(15),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: borderColor),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 45,
                                  height: 45,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFF5D8),
                                    borderRadius: BorderRadius.circular(13),
                                  ),
                                  child: Icon(notification.icon,
                                      color: navy, size: 23),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(notification.title,
                                          style: const TextStyle(
                                              color: textDark,
                                              fontWeight: FontWeight.w800)),
                                      const SizedBox(height: 4),
                                      Text(notification.message,
                                          style: const TextStyle(
                                              color: textGrey, fontSize: 12.5)),
                                    ],
                                  ),
                                ),
                                if (isUnread)
                                  const Padding(
                                    padding: EdgeInsets.only(left: 8),
                                    child: CircleAvatar(
                                        radius: 4, backgroundColor: yellow),
                                  )
                                else
                                  const Icon(Icons.chevron_right_rounded,
                                      color: textGrey),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
              ],
            );
          },
        ),
      ),
    );
  }
}
