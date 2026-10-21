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
  bool _unreadOnly = false;
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
    if (origin == null ||
        origin.scheme != 'https' ||
        origin.host.isEmpty ||
        origin.userInfo.isNotEmpty ||
        (origin.path.isNotEmpty && origin.path != '/')) {
      throw StateError('The secure API URL is not configured.');
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
      throw const FormatException('Announcement has no reference.');
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
      return 'eventEase returned an unexpected announcement response.';
    }
    return 'Cannot reach. Check the connection and try again.';
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
        final response = await http
            .get(
          _announcementEndpoint(page),
          headers: {
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
            'ngrok-skip-browser-warning': 'true',
          },
        )
            .timeout(const Duration(seconds: 20));
        if (response.statusCode == 401) {
          throw StateError('Your session expired. Sign in again.');
        }
        if (response.statusCode == 403) {
          throw StateError('Denied access to student announcements.');
        }
        if (response.statusCode == 404) {
          throw StateError(
            'Student announcements route is missing.',
          );
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
            message: 'Your attendance for ${event.title} was recorded.',
            icon: Icons.check_circle_rounded,
            category: 'Attendance',
            event: event,
          ),
        );

        if ((eventRatings[key] ?? 0) > 0) {
          items.add(
            _EventEaseNotification(
              id: 'certificate_$key',
              title: 'E-Certificate Available',
              message: 'Your certificate for ${event.title} is ready to view.',
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
              message: 'Evaluate ${event.title} to unlock your E-Certificate.',
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

  static const Color _navy = Color(0xFF102A4C);
  static const Color _gold = Color(0xFFFFCB4D);

  Future<void> _openNotification(_EventEaseNotification notification) async {
    markNotificationAsRead(notification.id);
    if (notification.event != null && !ApiConfig.useRealApi) {
      await Navigator.push(
        context,
        animatedRoute(EventDetailsPage(event: notification.event!)),
      );
      if (mounted) setState(() {});
      return;
    }
    if (!mounted) return;
    final scheme = Theme.of(context).colorScheme;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        contentPadding: const EdgeInsets.fromLTRB(22, 22, 22, 8),
        actionsPadding: const EdgeInsets.fromLTRB(22, 0, 22, 18),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: _gold.withValues(alpha: .18),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(notification.icon, color: _navy, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        notification.category,
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close notification',
                      onPressed: () => Navigator.pop(dialogContext),
                      icon: Icon(Icons.close_rounded, color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  notification.title,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                SelectableText(
                  notification.message.isEmpty
                      ? 'No additional information was provided.'
                      : notification.message,
                  style: TextStyle(color: scheme.onSurface, height: 1.55, fontSize: 14),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              style: FilledButton.styleFrom(
                backgroundColor: _navy,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Got it'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background = isDark ? const Color(0xFF0B1424) : const Color(0xFFF4F6FA);
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: _navy,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
      ),
      body: RefreshIndicator(
        onRefresh: ApiConfig.useRealApi
            ? _loadLiveAnnouncements
            : () async { if (mounted) setState(() {}); },
        child: ValueListenableBuilder<Set<String>>(
          valueListenable: readNotificationIds,
          builder: (context, readIds, _) {
            final notifications = _notifications();
            final unread = notifications.where((n) => !readIds.contains(n.id)).length;
            final visible = notifications.where((n) =>
            (_filter == 'All' || n.category == _filter) &&
                (!_unreadOnly || !readIds.contains(n.id))
            ).toList();
            final isBusy = ApiConfig.useRealApi && _liveLoading;
            final hasError = ApiConfig.useRealApi && _liveError != null;

            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
                  decoration: BoxDecoration(
                    gradient: appGradient,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48, height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .13),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: const Icon(Icons.notifications_active_rounded, color: _gold, size: 27),
                      ),
                      const SizedBox(width: 13),
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Stay updated', style: TextStyle(
                              color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 3),
                          Text(isBusy ? 'Loading your updates…' :
                          unread == 0 ? 'You’re all caught up' :
                          '$unread unread notification${unread == 1 ? '' : 's'}',
                              style: const TextStyle(color: Colors.white70, fontSize: 12.5)),
                        ],
                      )),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Row(children: [
                  Expanded(child: Text('Recent updates', style: TextStyle(
                      fontSize: 17, color: scheme.onSurface, fontWeight: FontWeight.w800))),
                  TextButton(
                    onPressed: unread == 0 || isBusy || hasError ? null : () {
                      readNotificationIds.value = {
                        ...readNotificationIds.value,
                        ...notifications.map((notice) => notice.id),
                      };
                    },
                    child: const Text('Mark all read', style: TextStyle(fontSize: 12)),
                  ),
                ]),
                const SizedBox(height: 6),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: [
                    for (final category in const ['All', 'Announcements', 'Events', 'Attendance', 'Certificates'])
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(category),
                          selected: _filter == category,
                          showCheckmark: false,
                          onSelected: (_) => setState(() => _filter = category),
                          selectedColor: isDark ? const Color(0xFF284B71) : const Color(0xFFE4EDF8),
                          labelStyle: TextStyle(
                            color: scheme.onSurface,
                            fontSize: 12,
                            fontWeight: _filter == category ? FontWeight.w800 : FontWeight.w500,
                          ),
                          side: BorderSide(color: scheme.outlineVariant),
                        ),
                      ),
                  ]),
                ),
                const SizedBox(height: 6),
                Row(children: [
                  FilterChip(
                    label: const Text('Unread only'),
                    selected: _unreadOnly,
                    showCheckmark: true,
                    onSelected: (v) => setState(() => _unreadOnly = v),
                  ),
                  const Spacer(),
                  if (!ApiConfig.useRealApi)
                    Text('DEMO', style: TextStyle(color: scheme.onSurfaceVariant,
                        fontSize: 11, fontWeight: FontWeight.w800)),
                ]),
                const SizedBox(height: 10),
                if (ApiConfig.useRealApi)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Text(
                      'Announcements from the campus server. Read indicators are managed locally.',
                      style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
                    ),
                  ),
                if (isBusy)
                  const Padding(padding: EdgeInsets.symmetric(vertical: 42),
                      child: Center(child: CircularProgressIndicator()))
                else if (hasError)
                  _notificationEmptyState(
                    icon: Icons.wifi_off_rounded,
                    title: 'Could not load notifications',
                    subtitle: _liveError!,
                    scheme: scheme,
                    onRetry: _loadLiveAnnouncements,
                  )
                else if (visible.isEmpty)
                    _notificationEmptyState(
                      icon: _unreadOnly ? Icons.mark_email_read_outlined : Icons.notifications_none_rounded,
                      title: _unreadOnly ? 'No unread updates' : 'Nothing here yet',
                      subtitle: _unreadOnly
                          ? 'You have no unread notifications in this category.'
                          : 'New campus updates will appear here.',
                      scheme: scheme,
                    )
                  else
                    for (final notification in visible)
                      _notificationTile(notification, !readIds.contains(notification.id), scheme, isDark),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _notificationTile(_EventEaseNotification notice, bool unread,
      ColorScheme scheme, bool isDark) {
    final border = scheme.outlineVariant;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(17),
        child: InkWell(
          onTap: () => _openNotification(notice),
          borderRadius: BorderRadius.circular(17),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(17),
              border: Border.all(color: unread ? _gold.withValues(alpha: .65) : border),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 45, height: 45,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF314057) : const Color(0xFFFFF3D2),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(notice.icon, color: isDark ? _gold : _navy, size: 23),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(child: Text(notice.title, maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800,
                              color: scheme.onSurface))),
                      if (unread) ...[
                        const SizedBox(width: 8),
                        const CircleAvatar(radius: 4, backgroundColor: _gold),
                      ],
                    ]),
                    const SizedBox(height: 5),
                    Text(notice.message.isEmpty ? 'Tap to read this notification' : notice.message,
                        maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12.5, height: 1.4,
                            color: scheme.onSurfaceVariant)),
                    const SizedBox(height: 8),
                    Text(notice.category, style: TextStyle(fontSize: 11,
                        fontWeight: FontWeight.w700, color: scheme.primary)),
                  ],
                )),
                const SizedBox(width: 4),
                Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _notificationEmptyState({required IconData icon, required String title,
    required String subtitle, required ColorScheme scheme,
    VoidCallback? onRetry}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 35),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(children: [
        Icon(icon, color: scheme.onSurfaceVariant, size: 38),
        const SizedBox(height: 11),
        Text(title, textAlign: TextAlign.center,
            style: TextStyle(color: scheme.onSurface, fontWeight: FontWeight.w800, fontSize: 15)),
        const SizedBox(height: 7),
        Text(subtitle, textAlign: TextAlign.center,
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5)),
        if (onRetry != null) ...[
          const SizedBox(height: 15),
          OutlinedButton.icon(onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded), label: const Text('Try again')),
        ],
      ]),
    );
  }
}

