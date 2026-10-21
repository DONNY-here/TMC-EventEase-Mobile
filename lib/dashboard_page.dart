part of 'main.dart';

// EventEase Campus Pulse - student dashboard.
// Local preview data is never presented as server-verified data.
class DashboardPage extends StatefulWidget {
  final ValueChanged<int>? onTabSelected;
  const DashboardPage({super.key, this.onTabSelected});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage>
    with WidgetsBindingObserver {
  static const _ink = Color(0xFF102A4C);
  static const _blue = Color(0xFF215B99);
  static const _gold = Color(0xFFFFCB4D);
  static const _mint = Color(0xFF168566);

  // Real API Mode never falls back to in-memory demo event records.
  bool get _realApiMode => ApiConfig.useRealApi;

  bool _loadingLive = false;
  String? _registrationError;
  String? _eventError;
  List<Map<String, dynamic>> _liveRegistrations = [];
  List<Map<String, dynamic>> _liveCampusEvents = [];
  int _serial = 0;
  int _badgeSerial = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (_realApiMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _refreshDashboardAndBadge();
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted && _realApiMode) {
      _refreshDashboardAndBadge();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Invalidate any pending async data updates after disposal.
    _serial++;
    _badgeSerial++;
    super.dispose();
  }

  Uri _endpoint(String path, int page) {
    final origin = Uri.tryParse(ApiConfig.baseUrl.trim());
    if (origin == null ||
        origin.scheme != 'https' ||
        origin.host.isEmpty ||
        origin.userInfo.isNotEmpty ||
        (origin.path.isNotEmpty && origin.path != '/')) {
      throw StateError('The secure API URL is not configured.');
    }
    return origin.replace(
      path: path,
      queryParameters: {'page': '$page'},
      fragment: null,
    );
  }

  Future<List<Map<String, dynamic>>> _fetchAll(
    String path,
    String token,
  ) async {
    final rows = <Map<String, dynamic>>[];
    var page = 1;
    var lastPage = 1;
    do {
      final response = await http
          .get(
            _endpoint(path, page),
            headers: {
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
              'ngrok-skip-browser-warning': 'true',
            },
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode == 401) {
        throw StateError('Your session has expired. Please sign in again.');
      }
      if (response.statusCode == 403) {
        throw StateError('Denied access to this resource.');
      }
      if (response.statusCode != 200) {
        throw StateError('eventEase returned HTTP ${response.statusCode}.');
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map || decoded['data'] is! List) {
        throw const FormatException('eventEase returned unexpected pagination.');
      }
      for (final entry in decoded['data'] as List) {
        if (entry is! Map) {
          throw const FormatException('An event record was invalid.');
        }
        rows.add(Map<String, dynamic>.from(entry));
      }
      lastPage = int.tryParse('${decoded['last_page'] ?? 1}') ?? 1;
      if (lastPage > 50) {
        throw StateError('Too many event pages to load in the dashboard.');
      }
      page++;
    } while (page <= lastPage);
    return rows;
  }

  String _requestError(Object error) {
    if (error is StateError) return error.message.toString();
    if (error is FormatException) {
      return 'eventEase returned an unexpected data format.';
    }
    return 'Could not reach. Check the internet connection and try again.';
  }

  // Update the dashboard and unread badge independently so a slow notices
  // request never delays registered-event statistics.
  Future<void> _refreshDashboardAndBadge() async {
    if (!_realApiMode) return;
    await Future.wait<void>([_refreshLive(), _refreshUnreadBadge()]);
  }

  // Only IDs from Laravel's student-readable, audience-filtered endpoint
  // are counted. Never count the hardcoded Demo Mode notifications here.
  Future<void> _refreshUnreadBadge() async {
    if (!_realApiMode) return;
    final requestId = ++_badgeSerial;
    try {
      final token = await authTokenStorage.readValidToken();
      if (token == null || token.trim().isEmpty) {
        throw StateError('Your session has expired. Please sign in again.');
      }
      final announcements = await _fetchAll('/api/my/announcements', token);
      if (!mounted || requestId != _badgeSerial) return;

      final ids = <String>{};
      for (final announcement in announcements) {
        // Must match AnnouncementsPage._parseAnnouncement ID exactly.
        final reference = _field(announcement, 'reference').isNotEmpty
            ? _field(announcement, 'reference')
            : _field(announcement, 'id');
        if (reference.isNotEmpty) {
          ids.add('laravel_announcement_$reference');
        }
      }
      _liveAnnouncementIds
        ..clear()
        ..addAll(ids);
      // ValueNotifier tells the AppBar badge to rebuild immediately.
      refreshNotifications();
    } catch (_) {
      if (!mounted || requestId != _badgeSerial) return;
      // If the student feed is unavailable, avoid displaying stale
      // unread numbers from a previous successful request.
      _liveAnnouncementIds.clear();
      refreshNotifications();
    }
  }

  Future<void> _refreshLive() async {
    if (!_realApiMode) return;
    final serial = ++_serial;
    if (mounted) {
      setState(() {
        _loadingLive = true;
        _registrationError = null;
        _eventError = null;
      });
    }
    List<Map<String, dynamic>> registrations = [];
    List<Map<String, dynamic>> campusEvents = [];
    String? registrationError;
    String? eventError;
    try {
      final token = await authTokenStorage.readValidToken();
      if (token == null || token.trim().isEmpty) {
        throw StateError('Your session has expired. Please sign in again.');
      }
      try {
        registrations = await _fetchAll('/api/registrations/my', token);
      } catch (error) {
        registrationError = _requestError(error);
      }
      try {
        campusEvents = await _fetchAll('/api/events', token);
      } catch (error) {
        eventError = _requestError(error);
      }
    } catch (error) {
      registrationError = _requestError(error);
      eventError = registrationError;
    }
    if (!mounted || serial != _serial) return;
    setState(() {
      _liveRegistrations = registrations;
      _liveCampusEvents = campusEvents;
      _registrationError = registrationError;
      _eventError = eventError;
      _loadingLive = false;
    });
  }

  String _field(
    Map<String, dynamic> item,
    String field, [
    String fallback = '',
  ]) {
    final value = item[field];
    return value == null ? fallback : value.toString().trim();
  }

  // Only active registrations count toward student dashboard activity.
  // Some Laravel controllers return cancelled rows in registration history.
  bool _activeRegistration(Map<String, dynamic> record) {
    final status = _field(
      record,
      'registration_status',
      _field(record, 'status'),
    ).toLowerCase();
    return status != 'cancelled' && status != 'canceled';
  }

  Widget _liveTile(
    BuildContext context,
    Map<String, dynamic> item, {
    required bool registered,
  }) {
    final c = Theme.of(context).colorScheme;
    final title = _field(
      item,
      registered ? 'event_title' : 'title',
      'Campus event',
    );
    final date = _field(item, 'event_date');
    final venue = _field(item, 'venue', 'Venue not announced');
    final attendance = _field(item, 'attendance').toLowerCase();
    final scanned =
        attendance == 'present' ||
        attendance == 'late' ||
        attendance == 'complete';
    final label = scanned
        ? 'ATTENDED'
        : registered
        ? 'REGISTERED'
        : 'APPROVED EVENT';
    final accent = scanned ? _mint : _blue;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: c.surface,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          onTap: () => _tab(context, registered ? 2 : 1),
          borderRadius: BorderRadius.circular(22),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              border: Border.all(color: c.outlineVariant),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Row(
              children: [
                Container(
                  width: 66,
                  height: 72,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [_ink, Color(0xFF2765A0)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.calendar_month_rounded,
                    color: _gold,
                    size: 29,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: c.onSurface,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${date.isEmpty ? 'Date not published' : date} • $venue',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: c.onSurfaceVariant,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 7),
                      _tag(label, accent, accent.withValues(alpha: .10)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _liveState(BuildContext context, String? error, String emptyText) {
    if (_loadingLive) {
      return const Padding(
        padding: EdgeInsets.all(30),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (error != null) {
      return EventEaseStatusPanel(
        icon: Icons.cloud_off_rounded,
        title: 'Unable to load campus records',
        message: error,
        actionLabel: 'Try again',
        onAction: _refreshDashboardAndBadge,
      );
    }
    return _serverPlaceholder(context, emptyText);
  }

  Widget _sourceNotice(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final color = _realApiMode ? const Color(0xFFAD6513) : _blue;
    return Semantics(
      label: _realApiMode
          ? 'Live student dashboard data.'
          : 'Preview mode. Dashboard values are local sample data.',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .09),
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: color.withValues(alpha: .24)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              _realApiMode ? Icons.cloud_done_outlined : Icons.science_outlined,
              size: 21,
              color: color,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _realApiMode
                        ? (_loadingLive
                              ? 'Loading records'
                              : (_registrationError != null ||
                                    _eventError != null)
                              ? 'Some information could not load'
                              : 'Connected!')
                        : 'Preview data',
                    style: TextStyle(
                      color: colors.onSurface,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _realApiMode
                        ? 'Your registered-event statistics and campus event lists are loaded from the API. Pull down to refresh.'
                        : "Event counts, attendance and cards are based on this device's local data, not verified records.",
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      height: 1.35,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _serverPlaceholder(BuildContext context, String description) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Icon(Icons.event_available_outlined, color: colors.primary, size: 36),
          const SizedBox(height: 10),
          Text(
            'No upcoming events yet',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.onSurface,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.onSurfaceVariant,
              fontSize: 12,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => _tab(context, 1),
            icon: const Icon(Icons.arrow_forward_rounded, size: 17),
            label: const Text('Browse events'),
          ),
        ],
      ),
    );
  }

  void _tab(BuildContext context, int index) {
    if (widget.onTabSelected != null) {
      widget.onTabSelected!(index);
    } else {
      Navigator.push(
        context,
        animatedRoute(index == 2 ? const MyEventsPage() : const EventsPage()),
      );
    }
  }

  Future<void> _updates(BuildContext context) async {
    await Navigator.push(context, animatedRoute(const AnnouncementsPage()));
    if (!mounted) return;
    // Keep the dashboard badge consistent with the current Laravel feed.
    // Demo notifications already use the shared readNotificationIds notifier.
    if (_realApiMode) await _refreshUnreadBadge();
  }

  // Rebuilds when a notice is opened or "Mark all as read" is tapped.
  // This is the same shared ValueNotifier used by AnnouncementsPage.
  Widget _notificationBell(BuildContext context) {
    return ValueListenableBuilder<Set<String>>(
      valueListenable: readNotificationIds,
      builder: (context, readIds, child) {
        final count = getUnreadNotificationCount();
        return Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton.filledTonal(
              tooltip: count == 0
                  ? 'Campus updates'
                  : '$count unread notification${count == 1 ? '' : 's'}',
              onPressed: () => _updates(context),
              icon: const Icon(Icons.notifications_none_rounded),
            ),
            if (count > 0)
              Positioned(
                top: -3,
                right: -4,
                child: IgnorePointer(
                  child: Container(
                    constraints: const BoxConstraints(
                      minWidth: 19,
                      minHeight: 19,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _gold,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.surface,
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      count > 99 ? '99+' : '$count',
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  DateTime? _date(String raw) {
    final parsed = DateTime.tryParse(raw.trim());
    if (parsed != null) return DateTime(parsed.year, parsed.month, parsed.day);
    const months = {
      'jan': 1,
      'feb': 2,
      'mar': 3,
      'apr': 4,
      'may': 5,
      'jun': 6,
      'jul': 7,
      'aug': 8,
      'sep': 9,
      'oct': 10,
      'nov': 11,
      'dec': 12,
    };
    final parts = raw.replaceAll(',', '').trim().split(RegExp(r'\s+'));
    if (parts.length != 3 || parts.first.length < 3) return null;
    final month = months[parts.first.substring(0, 3).toLowerCase()];
    final day = int.tryParse(parts[1].replaceAll(RegExp(r'\D'), ''));
    final year = int.tryParse(parts[2]);
    if (month == null || day == null || year == null) return null;
    final result = DateTime(year, month, day);
    return result.year == year && result.month == month && result.day == day
        ? result
        : null;
  }

  Widget _tag(String label, Color foreground, Color background) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(30),
    ),
    child: Text(
      label,
      style: TextStyle(
        color: foreground,
        fontSize: 10,
        fontWeight: FontWeight.w800,
        letterSpacing: .5,
      ),
    ),
  );

  Widget _heading(
    BuildContext context,
    String title,
    String subtitle,
    VoidCallback action,
  ) {
    final c = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: c.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -.35,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: TextStyle(fontSize: 11.5, color: c.onSurfaceVariant),
              ),
            ],
          ),
        ),
        TextButton(
          onPressed: action,
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'View all',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
              ),
              SizedBox(width: 3),
              Icon(Icons.arrow_forward_rounded, size: 16),
            ],
          ),
        ),
      ],
    );
  }

  // Compact mobile-first greeting and one prominent action.
  Widget _hero(
    BuildContext context,
    String firstName,
    int upcoming,
    Event? nextEvent, {
    Map<String, dynamic>? liveNext,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_ink, Color(0xFF20537D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Hi, $firstName 👋',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const Icon(Icons.school_outlined, color: _gold, size: 25),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            upcoming > 0
                ? 'You have $upcoming upcoming ${upcoming == 1 ? 'event' : 'events'}.'
                : 'Find your next campus experience.',
            style: const TextStyle(color: Color(0xFFDCE8F4), fontSize: 13),
          ),
          const SizedBox(height: 17),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () => _tab(context, 1),
              icon: const Icon(Icons.explore_rounded, size: 20),
              label: const Text('Explore campus events'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _gold,
                foregroundColor: _ink,
                elevation: 0,
                textStyle: const TextStyle(fontWeight: FontWeight.w800),
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

  Widget _shortcut(
    BuildContext context,
    String label,
    String description,
    IconData icon,
    Color accent,
    VoidCallback onTap,
  ) {
    final c = Theme.of(context).colorScheme;
    return Expanded(
      child: Material(
        color: c.surface,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: c.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: .11),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(icon, color: accent, size: 23),
                ),
                const SizedBox(height: 12),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: c.onSurface,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: c.onSurfaceVariant,
                    fontSize: 10,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _metric(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color accent,
  ) {
    final c = Theme.of(context).colorScheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: c.surface,
          border: Border.all(color: c.outlineVariant),
          borderRadius: BorderRadius.circular(19),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: accent, size: 20),
                const Spacer(),
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: accent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              value,
              style: TextStyle(
                color: c.onSurface,
                fontSize: 27,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: c.onSurfaceVariant,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _eventTile(
    BuildContext context,
    Event event,
    DateTime today, {
    bool registered = false,
  }) {
    final c = Theme.of(context).colorScheme;
    final date = _date(event.date);
    final past = date != null && date.isBefore(today);
    final attended = attendanceStatus[eventKey(event)] == 'Present';
    final status = attended
        ? 'ATTENDED'
        : registered
        ? 'REGISTERED'
        : past
        ? 'PAST'
        : 'UPCOMING';
    final statusColor = attended
        ? _mint
        : registered
        ? _blue
        : past
        ? c.onSurfaceVariant
        : _mint;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: c.surface,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () => Navigator.push(
            context,
            animatedRoute(EventDetailsPage(event: event)),
          ),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: c.outlineVariant),
            ),
            child: Row(
              children: [
                Container(
                  width: 68,
                  height: 78,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [_ink, Color(0xFF2765A0)],
                    ),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(
                    Icons.celebration_rounded,
                    color: _gold,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: c.onSurface,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${event.date}  •  ${event.venue}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: c.onSurfaceVariant,
                          fontSize: 11,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _tag(
                        status,
                        statusColor,
                        statusColor.withValues(alpha: .10),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.chevron_right_rounded, color: c.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _empty(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: c.outlineVariant),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: _blue.withValues(alpha: .09),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.event_note_rounded, color: _blue, size: 29),
          ),
          const SizedBox(height: 10),
          Text(
            'Your calendar is wide open',
            style: TextStyle(
              color: c.onSurface,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Find an event you love and make the most of campus life.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: c.onSurfaceVariant,
              fontSize: 12,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: () => _tab(context, 1),
            icon: const Icon(Icons.arrow_forward_rounded, size: 16),
            label: const Text('Browse events'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final firstName = savedName.trim().isEmpty
        ? 'Student'
        : savedName.trim().split(RegExp(r'\s+')).first;
    final upcomingRegistered = registeredEvents.where((e) {
      final date = _date(e.date);
      return date != null && !date.isBefore(today);
    }).toList()..sort((a, b) => _date(a.date)!.compareTo(_date(b.date)!));
    final aroundCampus = eventList.where((e) => _date(e.date) != null).toList()
      ..sort((a, b) => _date(b.date)!.compareTo(_date(a.date)!));
    final attended = registeredEvents
        .where((e) => attendanceStatus[eventKey(e)] == 'Present')
        .length;
    final liveUpcomingRegistrations =
        _liveRegistrations.where((r) {
          final date = _date(_field(r, 'event_date'));
          return _activeRegistration(r) &&
              date != null &&
              !date.isBefore(today);
        }).toList()..sort(
          (a, b) => _date(
            _field(a, 'event_date'),
          )!.compareTo(_date(_field(b, 'event_date'))!),
        );
    final liveUpcomingCampus =
        _liveCampusEvents.where((e) {
          final date = _date(_field(e, 'event_date'));
          return date != null && !date.isBefore(today);
        }).toList()..sort(
          (a, b) => _date(
            _field(a, 'event_date'),
          )!.compareTo(_date(_field(b, 'event_date'))!),
        );
    final liveAttended = _liveRegistrations.where((r) {
      if (!_activeRegistration(r)) return false;
      final status = _field(r, 'attendance').toLowerCase();
      return status == 'present' || status == 'late' || status == 'complete';
    }).length;
    final activeLiveRegistrations = _liveRegistrations
        .where(_activeRegistration)
        .length;
    final c = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: c.surface,
        foregroundColor: c.onSurface,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 18,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'eventEase.',
              style: TextStyle(
                color: c.onSurface,
                fontSize: 23,
                fontWeight: FontWeight.w900,
                letterSpacing: -1.1,
              ),
            ),
            Text(
              'TMC  /  YOUR CAMPUS, CONNECTED',
              style: TextStyle(
                color: c.onSurfaceVariant,
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                letterSpacing: .6,
              ),
            ),
          ],
        ),
        actions: [_notificationBell(context), const SizedBox(width: 14)],
      ),
      body: RefreshIndicator(
        onRefresh: _realApiMode ? _refreshDashboardAndBadge : () async {},
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 30),
          children: [
            _hero(
              context,
              firstName,
              _realApiMode
                  ? liveUpcomingRegistrations.length
                  : upcomingRegistered.length,
              _realApiMode || upcomingRegistered.isEmpty
                  ? null
                  : upcomingRegistered.first,
              liveNext: liveUpcomingRegistrations.isEmpty
                  ? null
                  : liveUpcomingRegistrations.first,
            ),
            const SizedBox(height: 14),
            if (!_realApiMode ||
                _registrationError != null ||
                _eventError != null) ...[
              _sourceNotice(context),
              const SizedBox(height: 16),
            ] else
              const SizedBox(height: 8),
            _heading(
              context,
              'Quick access',
              'Where would you like to go?',
              () => _tab(context, 1),
            ),
            const SizedBox(height: 11),
            Row(
              children: [
                _shortcut(
                  context,
                  'Events',
                  'Browse campus',
                  Icons.explore_rounded,
                  _blue,
                  () => _tab(context, 1),
                ),
                const SizedBox(width: 9),
                _shortcut(
                  context,
                  'My passes',
                  'QR & tickets',
                  Icons.qr_code_2_rounded,
                  const Color(0xFFBE830B),
                  () => _tab(context, 2),
                ),
                const SizedBox(width: 9),
                _shortcut(
                  context,
                  'Notices',
                  'Campus updates',
                  Icons.campaign_rounded,
                  _mint,
                  () => _updates(context),
                ),
              ],
            ),
            const SizedBox(height: 15),
            Material(
              color: c.surface,
              borderRadius: BorderRadius.circular(19),
              child: InkWell(
                borderRadius: BorderRadius.circular(19),
                onTap: () => Navigator.push(
                  context,
                  animatedRoute(const RegisteredEventFinesPage()),
                ),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: c.outlineVariant),
                    borderRadius: BorderRadius.circular(19),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.fact_check_outlined,
                        color: Color(0xFF711B38),
                        size: 27,
                      ),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Attendance & fines',
                              style: TextStyle(
                                color: c.onSurface,
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'View attendance records and fines',
                              style: TextStyle(
                                color: c.onSurfaceVariant,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: c.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 25),
            _heading(
              context,
              'At a glance',
              'Your EventEase journey',
              () => _tab(context, 2),
            ),
            const SizedBox(height: 11),
            Row(
              children: [
                _metric(
                  context,
                  'Registered',
                  _realApiMode
                      ? (_loadingLive || _registrationError != null
                            ? '—'
                            : '$activeLiveRegistrations')
                      : '${registeredEvents.length}',
                  Icons.confirmation_number_outlined,
                  _blue,
                ),
                const SizedBox(width: 9),
                _metric(
                  context,
                  'Upcoming',
                  _realApiMode
                      ? (_loadingLive || _registrationError != null
                            ? '—'
                            : '${liveUpcomingRegistrations.length}')
                      : '${upcomingRegistered.length}',
                  Icons.calendar_today_rounded,
                  const Color(0xFFCD9700),
                ),
                const SizedBox(width: 9),
                _metric(
                  context,
                  'Attended',
                  _realApiMode
                      ? (_loadingLive || _registrationError != null
                            ? '—'
                            : '$liveAttended')
                      : '$attended',
                  Icons.verified_rounded,
                  _mint,
                ),
              ],
            ),
            const SizedBox(height: 25),
            _heading(
              context,
              'Your next event',
              'Your upcoming registered activity',
              () => _tab(context, 2),
            ),
            const SizedBox(height: 11),
            if (_realApiMode && liveUpcomingRegistrations.isNotEmpty)
              _liveTile(
                context,
                liveUpcomingRegistrations.first,
                registered: true,
              )
            else if (_realApiMode)
              _liveState(
                context,
                _registrationError,
                'Register for an event to see it here.',
              )
            else if (upcomingRegistered.isEmpty)
              _empty(context)
            else
              _eventTile(
                context,
                upcomingRegistered.first,
                today,
                registered: true,
              ),
            const SizedBox(height: 24),
            _heading(
              context,
              'Around campus',
              'See what’s happening at TMC',
              () => _tab(context, 1),
            ),
            const SizedBox(height: 11),
            if (_realApiMode && liveUpcomingCampus.isNotEmpty)
              ...liveUpcomingCampus
                  .take(3)
                  .map((e) => _liveTile(context, e, registered: false))
            else if (_realApiMode)
              _liveState(
                context,
                _eventError,
                'No upcoming campus events have been published yet.',
              )
            else if (aroundCampus.isEmpty)
              _empty(context)
            else
              ...aroundCampus
                  .take(3)
                  .map(
                    (e) => _eventTile(
                      context,
                      e,
                      today,
                      registered: registeredEvents.any(
                        (r) => eventKey(r) == eventKey(e),
                      ),
                    ),
                  ),
            const SizedBox(height: 21),
            _heading(
              context,
              'Campus bulletin',
              'Announcements and reminders',
              () => _updates(context),
            ),
            const SizedBox(height: 11),
            Material(
              color: c.surface,
              borderRadius: BorderRadius.circular(22),
              child: InkWell(
                onTap: () => _updates(context),
                borderRadius: BorderRadius.circular(22),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: c.outlineVariant),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(13),
                        decoration: BoxDecoration(
                          color: _gold.withValues(alpha: .18),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.campaign_rounded,
                          color: Color(0xFFB27B00),
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Stay in the loop',
                              style: TextStyle(
                                color: c.onSurface,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Important event news, notices and schedule changes.',
                              style: TextStyle(
                                color: c.onSurfaceVariant,
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: c.onSurfaceVariant,
                        size: 15,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 22),
          ],
        ),
      ),
    );
  }
}
