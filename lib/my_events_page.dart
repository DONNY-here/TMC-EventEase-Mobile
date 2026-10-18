part of 'main.dart';

// ======================================================
// TMC EVENTEASE - MY EVENTS 2.0
// Student registrations, QR passes and demo attendance.
// Local demo data is never presented as Laravel data.
// ======================================================

class MyEventsPage extends StatefulWidget {
  const MyEventsPage({super.key});

  @override
  State<MyEventsPage> createState() => _MyEventsPageState();
}

class _MyEventsPageState extends State<MyEventsPage> {
  static const List<String> _filters = [
    'All',
    'Upcoming',
    'Attended',
    'Completed',
  ];

  String _selectedFilter = 'All';

  Color get _surface => Theme.of(context).colorScheme.surface;
  Color get _onSurface => Theme.of(context).colorScheme.onSurface;
  Color get _subtle => Theme.of(context).colorScheme.onSurfaceVariant;
  Color get _outline => Theme.of(context).colorScheme.outlineVariant;
  bool get _dark => Theme.of(context).brightness == Brightness.dark;

  // A date-only parser for the two event formats currently used by EventEase.
  DateTime? _eventDate(String value) {
    final raw = value.trim();
    if (raw.isEmpty) return null;

    final iso = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(raw);
    if (iso != null) {
      final year = int.parse(iso.group(1)!);
      final month = int.parse(iso.group(2)!);
      final day = int.parse(iso.group(3)!);
      final result = DateTime(year, month, day);
      return result.year == year && result.month == month && result.day == day
          ? result
          : null;
    }

    final match = RegExp(
      r'^([A-Za-z]+)\.?\s+(\d{1,2}),?\s+(\d{4})$',
      caseSensitive: false,
    ).firstMatch(raw);
    if (match == null) return null;

    const months = <String, int>{
      'jan': 1, 'january': 1,
      'feb': 2, 'february': 2,
      'mar': 3, 'march': 3,
      'apr': 4, 'april': 4,
      'may': 5,
      'jun': 6, 'june': 6,
      'jul': 7, 'july': 7,
      'aug': 8, 'august': 8,
      'sep': 9, 'sept': 9, 'september': 9,
      'oct': 10, 'october': 10,
      'nov': 11, 'november': 11,
      'dec': 12, 'december': 12,
    };

    final month = months[match.group(1)!.toLowerCase()];
    final day = int.tryParse(match.group(2)!);
    final year = int.tryParse(match.group(3)!);
    if (month == null || day == null || year == null) return null;

    final result = DateTime(year, month, day);
    return result.year == year && result.month == month && result.day == day
        ? result
        : null;
  }

  List<Event> _filteredEvents() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return registeredEvents.where((event) {
      final date = _eventDate(event.date);
      final attendance = attendanceStatus[eventKey(event)] ?? 'Not Recorded';

      switch (_selectedFilter) {
        case 'Upcoming':
        // A registered event scheduled for today or a future date.
          return date != null && !date.isBefore(today);
        case 'Attended':
          return attendance == 'Present';
        case 'Completed':
        // Completed here means the event date has passed, not checked in.
          return date != null && date.isBefore(today);
        default:
          return true;
      }
    }).toList();
  }

  int _filterCount(String filter) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (filter) {
      case 'Upcoming':
        return registeredEvents.where((e) {
          final date = _eventDate(e.date);
          return date != null && !date.isBefore(today);
        }).length;
      case 'Attended':
        return registeredEvents.where(
              (e) => attendanceStatus[eventKey(e)] == 'Present',
        ).length;
      case 'Completed':
        return registeredEvents.where((e) {
          final date = _eventDate(e.date);
          return date != null && date.isBefore(today);
        }).length;
      default:
        return registeredEvents.length;
    }
  }

  Future<void> cancelRegistration(Event event) async {
    // A local cancellation must never be mistaken for a Laravel update.
    if (ApiConfig.useRealApi) {
      showMessage(context, 'Online cancellation is not connected yet.');
      return;
    }

    final key = eventKey(event);
    if (attendanceStatus[key] == 'Present') {
      showMessage(context, 'Cancellation is unavailable after check-in.');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.event_busy_outlined, size: 32),
        title: const Text('Cancel registration?'),
        content: Text(
          'Your demo registration and QR pass for ${event.title} '
              'will be removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep Registration'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Cancel Registration'),
          ),
        ],
      ),
    );

    if (!mounted || confirmed != true) return;

    // Check again after the user has interacted with the dialog.
    if (attendanceStatus[key] == 'Present') {
      showMessage(context, 'Attendance was recorded. Cancellation blocked.');
      return;
    }

    final stillRegistered = registeredEvents.any(
          (entry) => eventKey(entry) == key,
    );
    if (!stillRegistered) return;

    setState(() {
      registeredEvents.removeWhere((entry) => eventKey(entry) == key);
      attendanceStatus.remove(key);
      attendanceCheckInTime.remove(key);
      qrTokens.remove(key);
      eventRatings.remove(key);
      eventComments.remove(key);
    });

    refreshNotifications();
    if (mounted) showMessage(context, 'Demo registration cancelled.');
  }

  IconData _eventIcon(Event event) {
    final title = event.title.toLowerCase();
    if (title.contains('leadership')) return Icons.groups_rounded;
    if (title.contains('workshop') || title.contains('web')) {
      return Icons.code_rounded;
    }
    if (title.contains('esport')) return Icons.sports_esports_rounded;
    if (title.contains('programming')) return Icons.terminal_rounded;
    return Icons.event_available_rounded;
  }

  Color _attendanceColor(String status) {
    if (status == 'Present') {
      return _dark ? const Color(0xFF86E2AA) : const Color(0xFF248250);
    }
    if (status == 'Absent') {
      return _dark ? const Color(0xFFFFA0A0) : const Color(0xFFC94747);
    }
    return _dark ? const Color(0xFFF9D583) : const Color(0xFF9A6C1A);
  }

  Color _attendanceBackground(String status) {
    if (status == 'Present') {
      return _dark ? const Color(0xFF193B2D) : const Color(0xFFE7F6EC);
    }
    if (status == 'Absent') {
      return _dark ? const Color(0xFF46282C) : const Color(0xFFFFEEEE);
    }
    return _dark ? const Color(0xFF3A3425) : const Color(0xFFFFF6E4);
  }

  Widget _metric({
    required String number,
    required String label,
    required IconData icon,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 13),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.19)),
          borderRadius: BorderRadius.circular(17),
        ),
        child: Column(
          children: [
            Icon(icon, color: yellow, size: 20),
            const SizedBox(height: 7),
            Text(
              number,
              maxLines: 1,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    final attended = _filterCount('Attended');
    final pending = registeredEvents.length - attended;

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
      decoration: const BoxDecoration(
        gradient: appGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.confirmation_number_outlined,
                  color: yellow, size: 17),
              const SizedBox(width: 7),
              const Expanded(
                child: Text(
                  'MY EVENT ACTIVITY',
                  style: TextStyle(
                    color: Color(0xFFFFD975),
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.3,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: const Text(
                  'DEMO',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'My Events',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Your registrations, event passes, and attendance in one place.',
            style: TextStyle(color: Colors.white70, height: 1.4, fontSize: 12.5),
          ),
          const SizedBox(height: 19),
          Row(
            children: [
              _metric(
                number: '${registeredEvents.length}',
                label: 'Registered',
                icon: Icons.local_activity_outlined,
              ),
              const SizedBox(width: 9),
              _metric(
                number: '$attended',
                label: 'Checked in',
                icon: Icons.verified_outlined,
              ),
              const SizedBox(width: 9),
              _metric(
                number: '$pending',
                label: 'Not checked in',
                icon: Icons.schedule_rounded,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _filtersBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 11),
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your registrations',
            style: TextStyle(
              color: _onSurface,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _filters.map((filter) {
                final selected = _selectedFilter == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    showCheckmark: false,
                    selected: selected,
                    selectedColor: navy,
                    backgroundColor: _surface,
                    side: BorderSide(color: selected ? navy : _outline),
                    label: Text('$filter  ${_filterCount(filter)}'),
                    labelStyle: TextStyle(
                      color: selected ? Colors.white : _onSurface,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                    onSelected: (_) => setState(() => _selectedFilter = filter),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detail(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Icon(icon, color: _subtle, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: _subtle, fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _eventCard(Event event) {
    final key = eventKey(event);
    final status = attendanceStatus[key] ?? 'Not Recorded';
    final present = status == 'Present';
    final canCancel = !present;
    final checkedInTime = attendanceCheckInTime[key];
    final rated = eventRatings.containsKey(key);
    final token = qrTokens[key];
    final hasPass = token != null &&
        RegExp(r'^[A-Za-z0-9]{40}$').hasMatch(token);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _outline),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: _dark ? 0.0 : 0.035),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 56,
                width: 56,
                decoration: BoxDecoration(
                  gradient: appGradient,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(_eventIcon(event), color: yellow, size: 27),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title,
                      style: TextStyle(
                        color: _onSurface,
                        fontSize: 16,
                        height: 1.25,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    _detail(Icons.calendar_month_outlined, event.date),
                    _detail(Icons.schedule_outlined, event.time),
                    _detail(Icons.location_on_outlined, event.venue),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              _pill(
                'REGISTERED',
                Icons.check_circle_outline,
                _dark ? const Color(0xFF86E2AA) : const Color(0xFF267F50),
              ),
              if (rated)
                _pill('EVALUATED', Icons.star_rounded,
                    _dark ? const Color(0xFFFFD377) : const Color(0xFF94640C)),
            ],
          ),
          const SizedBox(height: 13),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _attendanceBackground(status),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Row(
              children: [
                Icon(
                  present
                      ? Icons.verified_rounded
                      : status == 'Absent'
                      ? Icons.cancel_outlined
                      : Icons.pending_actions_outlined,
                  color: _attendanceColor(status),
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        present
                            ? 'Attendance confirmed (demo)'
                            : status == 'Absent'
                            ? 'Marked absent (demo)'
                            : 'Attendance not recorded',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: _attendanceColor(status),
                          fontSize: 12.5,
                        ),
                      ),
                      if (present && checkedInTime != null &&
                          checkedInTime.isNotEmpty)
                        Text(
                          'Check-in time: $checkedInTime',
                          style: TextStyle(
                            color: _attendanceColor(status),
                            fontSize: 11.5,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 13),
          SizedBox(
            height: 46,
            child: FilledButton.icon(
              onPressed: hasPass
                  ? () async {
                await Navigator.push(
                  context,
                  animatedRoute(StudentQrPassPage(event: event)),
                );
                if (mounted) setState(() {});
              }
                  : null,
              icon: const Icon(Icons.qr_code_2_rounded),
              label: Text(hasPass ? 'View My QR Pass' : 'QR Pass Unavailable'),
              style: FilledButton.styleFrom(
                backgroundColor: navy,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
            ),
          ),
          const SizedBox(height: 9),
          SizedBox(
            height: 44,
            child: OutlinedButton.icon(
              onPressed: present
                  ? () async {
                await Navigator.push(
                  context,
                  animatedRoute(EvaluationPage(event: event)),
                );
                if (mounted) setState(() {});
              }
                  : null,
              icon: Icon(present ? Icons.star_outline_rounded : Icons.lock_outline),
              label: Text(
                present
                    ? (rated ? 'Open Evaluation' : 'Evaluate Event')
                    : 'Evaluation Locked Until Check-in',
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: _onSurface,
                side: BorderSide(color: _outline),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
            ),
          ),
          if (canCancel) ...[
            const SizedBox(height: 7),
            Align(
              alignment: Alignment.center,
              child: TextButton.icon(
                onPressed: () => cancelRegistration(event),
                icon: const Icon(Icons.close_rounded, size: 17),
                label: const Text('Cancel Demo Registration'),
                style: TextButton.styleFrom(
                  foregroundColor: _dark
                      ? const Color(0xFFFFA7A7)
                      : const Color(0xFFB83D3D),
                ),
              ),
            ),
          ] else ...[
            const SizedBox(height: 10),
            Center(
              child: Text(
                'Cancellation locked after check-in',
                style: TextStyle(color: _subtle, fontSize: 11.5),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _pill(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: _dark ? 0.16 : 0.09),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.25,
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    final noRegistrations = registeredEvents.isEmpty;
    String title;
    String message;

    if (noRegistrations) {
      title = 'No registered events yet';
      message = 'Explore Events and register to see your passes here.';
    } else {
      switch (_selectedFilter) {
        case 'Upcoming':
          title = 'No upcoming events';
          message = 'No registrations are scheduled for today or later.';
          break;
        case 'Attended':
          title = 'No attendance recorded yet';
          message = 'Once an authorized demo scan is recorded, it appears here.';
          break;
        case 'Completed':
          title = 'No past events';
          message = 'Registered events with past dates will appear here.';
          break;
        default:
          title = 'No events found';
          message = 'Try choosing another filter.';
      }
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: EmptyState(
          icon: Icons.event_note_outlined,
          title: title,
          message: message,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Official server records are fetched securely, never from demo lists.
    if (ApiConfig.useRealApi) {
      return const _LaravelMyPassesView();
    }

    final events = _filteredEvents();

    return Scaffold(
      body: Column(
        children: [
          _header(),
          _filtersBar(),
          Expanded(
            child: events.isEmpty
                ? _emptyState()
                : ListView.separated(
              key: ValueKey('my-events-$_selectedFilter'),
              padding: const EdgeInsets.fromLTRB(16, 7, 16, 25),
              itemCount: events.length,
              separatorBuilder: (_, _) => const SizedBox(height: 13),
              itemBuilder: (context, index) => _eventCard(events[index]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: Text(
              'Local demo records only • Not synced with Laravel',
              style: TextStyle(color: _subtle, fontSize: 10.5),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}


// ============================================================
// REAL API — MY PASSES
// Requires GET /api/registrations/my added in Laravel (see PHP patch).
// Registration QR = Registration.qr_code (PASS-*), server-issued.
// Student attendance QR is a DIFFERENT, account-level credential,
// retrieved from GET /api/my/attendance-qr.
// No demo registration, QR, or attendance data is ever used here.
// ============================================================
class _LaravelMyPassesView extends StatefulWidget {
  const _LaravelMyPassesView();

  @override
  State<_LaravelMyPassesView> createState() => _LaravelMyPassesViewState();
}

class _LaravelMyPassesViewState extends State<_LaravelMyPassesView> {
  static const Color _navy = Color(0xFF102A4C);
  static const Color _blue = Color(0xFF215B99);
  static const Color _gold = Color(0xFFFFCB4D);
  final List<Map<String, dynamic>> _records = [];
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  int _page = 0;
  int _lastPage = 1;
  String _filter = 'All';
  int _requestSerial = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  static String _str(Map<String, dynamic> record, String field,
      [String fallback = '']) {
    final value = record[field];
    return value == null ? fallback : value.toString().trim();
  }

  static DateTime? _eventDay(Map<String, dynamic> record) {
    final iso = _str(record, 'event_date');
    return DateTime.tryParse(iso);
  }

  static String _dateLabel(Map<String, dynamic> record) {
    final date = _eventDay(record);
    if (date == null) return 'Event date unavailable';
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  bool _isPast(Map<String, dynamic> record) {
    final date = _eventDay(record);
    if (date == null) return false;
    final now = DateTime.now();
    return date.isBefore(DateTime(now.year, now.month, now.day));
  }

  bool _attended(Map<String, dynamic> record) {
    final status = _str(record, 'attendance').toLowerCase();
    return status == 'present' || status == 'late';
  }

  List<Map<String, dynamic>> get _filtered {
    switch (_filter) {
      case 'Upcoming':
        return _records.where((item) => !_isPast(item)).toList();
      case 'Attended':
        return _records.where(_attended).toList();
      case 'Past':
        return _records.where(_isPast).toList();
      default:
        return List.of(_records);
    }
  }

  int _count(String filter) {
    switch (filter) {
      case 'Upcoming':
        return _records.where((r) => !_isPast(r)).length;
      case 'Attended':
        return _records.where(_attended).length;
      case 'Past':
        return _records.where(_isPast).length;
      default:
        return _records.length;
    }
  }

  static Uri _endpoint(String path, {Map<String, String>? query}) {
    final base = Uri.tryParse(ApiConfig.baseUrl.trim());
    if (base == null || base.scheme != 'https' || base.host.isEmpty ||
        base.userInfo.isNotEmpty ||
        (base.path.isNotEmpty && base.path != '/')) {
      throw StateError('The secure Laravel server URL is not configured.');
    }
    return base.replace(path: path, queryParameters: query, fragment: null);
  }

  static Future<String> _token() async {
    final token = await authTokenStorage.readValidToken();
    if (token == null || token.trim().isEmpty) {
      throw StateError('Your session has expired. Please log in again.');
    }
    return token;
  }

  static String _httpError(http.Response response) {
    if (response.statusCode == 404) {
      return 'Laravel GET /api/registrations/my has not been added yet. '
          'Ask your web partner to apply the registration-history API patch.';
    }
    if (response.statusCode == 401) {
      return 'Your login has expired. Please sign in again.';
    }
    if (response.statusCode == 403) {
      return 'The server has not authorized this student to view passes. '
          'Confirm that this route uses student Sanctum authentication.';
    }
    try {
      final result = jsonDecode(response.body);
      if (result is Map && result['message'] is String) {
        return result['message'] as String;
      }
    } catch (_) {}
    return 'Laravel returned HTTP ${response.statusCode}.';
  }

  Future<void> _load({bool more = false}) async {
    if (more && (_loadingMore || _loading || _page >= _lastPage)) return;
    final serial = ++_requestSerial;
    final wantedPage = more ? _page + 1 : 1;
    if (mounted) {
      setState(() {
        if (more) {
          _loadingMore = true;
        } else {
          _loading = true;
          _error = null;
        }
      });
    }
    try {
      final token = await _token();
      final uri = _endpoint('/api/registrations/my',
          query: {'page': '$wantedPage'});
      final response = await http.get(uri, headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
        'ngrok-skip-browser-warning': 'true',
      }).timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) {
        throw StateError(_httpError(response));
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map || decoded['data'] is! List) {
        throw const FormatException('Unexpected registration list from Laravel.');
      }
      final rows = (decoded['data'] as List).map((item) {
        if (item is! Map) {
          throw const FormatException('Invalid registration record.');
        }
        return Map<String, dynamic>.from(item);
      }).toList();
      final last = int.tryParse('${decoded['last_page'] ?? 1}') ?? 1;
      if (!mounted || serial != _requestSerial) return;
      setState(() {
        if (!more) _records.clear();
        _records.addAll(rows);
        _page = wantedPage;
        _lastPage = last < wantedPage ? wantedPage : last;
        _error = null;
      });
    } catch (error) {
      if (!mounted || serial != _requestSerial) return;
      setState(() {
        _error = error is StateError
            ? error.message.toString()
            : error is FormatException
            ? error.message
            : 'Unable to load My Passes. Check your connection and try again.';
      });
    } finally {
      if (mounted && serial == _requestSerial) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  Future<void> _cancel(Map<String, dynamic> record) async {
    final id = int.tryParse(_str(record, 'id'));
    if (id == null) return;
    final approved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel registration?'),
        content: Text('Cancel your registration for '
            '"${_str(record, 'event_title', 'this event')}"? '
            'Your event registration QR will stop being valid.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Keep registration')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancel registration'),
          ),
        ],
      ),
    );
    if (!mounted || approved != true) return;
    try {
      final token = await _token();
      final response = await http.delete(
        _endpoint('/api/registrations/$id/cancel'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
          'ngrok-skip-browser-warning': 'true',
        },
      ).timeout(const Duration(seconds: 20));
      if (response.statusCode != 200 && response.statusCode != 204) {
        throw StateError(_httpError(response));
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Laravel confirmed your registration was cancelled.'),
      ));
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(error is StateError
            ? error.message.toString()
            : 'Cancellation failed. Please try again.'),
      ));
    }
  }

  Widget _stat(String value, String label, IconData icon) {
    return Expanded(child: Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(children: [
        Icon(icon, size: 20, color: _gold),
        const SizedBox(height: 6),
        Text(value, style: const TextStyle(color: Colors.white,
            fontSize: 23, fontWeight: FontWeight.w900)),
        Text(label, style: const TextStyle(color: Colors.white70,
            fontSize: 10), textAlign: TextAlign.center),
      ]),
    ));
  }

  Widget _card(Map<String, dynamic> record) {
    final scheme = Theme.of(context).colorScheme;
    final status = _str(record, 'attendance', 'Not Yet Recorded');
    final isLateOrPresent = _attended(record);
    final isPast = _isPast(record);
    final qr = _str(record, 'qr_code');
    final title = _str(record, 'event_title', 'Untitled event');
    final venue = _str(record, 'venue', 'Venue not provided');
    final canCancel = !isPast && !isLateOrPresent &&
        _str(record, 'event_status').toLowerCase() != 'completed' &&
        _str(record, 'event_status').toLowerCase() != 'cancelled';
    return Container(
      margin: const EdgeInsets.only(bottom: 13),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [_navy, _blue]),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.event_available_rounded, color: _gold),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.w900,
                    fontSize: 16, color: scheme.onSurface)),
                const SizedBox(height: 6),
                Text('${_dateLabel(record)}  •  ${_str(record, 'start_time', 'Time TBA')}',
                    style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                const SizedBox(height: 4),
                Text(venue, style: TextStyle(fontSize: 12,
                    color: scheme.onSurfaceVariant)),
              ])),
        ]),
        const SizedBox(height: 13),
        Wrap(spacing: 7, runSpacing: 7, children: [
          Chip(label: const Text('REGISTERED'),
              avatar: const Icon(Icons.verified_rounded, size: 16),
              visualDensity: VisualDensity.compact),
          Chip(label: Text(status), visualDensity: VisualDensity.compact),
          if (isPast) const Chip(label: Text('PAST EVENT'),
              visualDensity: VisualDensity.compact),
        ]),
        const SizedBox(height: 10),
        Text('Registration: ${_str(record, 'reference', '—')}',
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
        const SizedBox(height: 12),
        SizedBox(width: double.infinity, height: 48,
          child: FilledButton.icon(
            onPressed: qr.isEmpty ? null : () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) =>
                  _LaravelRegistrationQrPage(registration: record)),
            ),
            icon: const Icon(Icons.qr_code_2_rounded),
            label: Text(qr.isEmpty ? 'QR pass not available'
                : 'View event QR pass'),
            style: FilledButton.styleFrom(backgroundColor: _gold,
                foregroundColor: _navy),
          ),
        ),
        if (canCancel) ...[
          const SizedBox(height: 5),
          Align(alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => _cancel(record),
              icon: const Icon(Icons.event_busy_rounded, size: 18),
              label: const Text('Cancel registration'),
            ),
          ),
        ],
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final filtered = _filtered;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(children: [
        Container(
          padding: const EdgeInsets.fromLTRB(17, 18, 17, 19),
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [_navy, _blue]),
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.confirmation_number_rounded,
                      color: _gold, size: 23),
                  const SizedBox(width: 8),
                  const Expanded(child: Text('MY PASSES  •  LARAVEL',
                      style: TextStyle(color: Colors.white,
                          fontSize: 12, fontWeight: FontWeight.w900))),
                  IconButton(
                    tooltip: 'Refresh my passes',
                    onPressed: _loading ? null : () => _load(),
                    icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                  ),
                ]),
                const SizedBox(height: 7),
                const Text('My Events', style: TextStyle(color: Colors.white,
                    fontWeight: FontWeight.w900, fontSize: 27)),
                const SizedBox(height: 4),
                const Text('Your registrations, passes and attendance records',
                    style: TextStyle(color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 17),
                Row(children: [
                  _stat('${_records.length}', 'Loaded registrations',
                      Icons.confirmation_number_outlined),
                  const SizedBox(width: 8),
                  _stat('${_count('Attended')}', 'Present / Late',
                      Icons.fact_check_outlined),
                  const SizedBox(width: 8),
                  _stat('${_count('Upcoming')}', 'Upcoming',
                      Icons.calendar_today_outlined),
                ]),
              ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 3),
          child: SizedBox(width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => const _LaravelStudentAttendanceQrPage())),
              icon: const Icon(Icons.badge_outlined),
              label: const Text('View student attendance QR'),
            ),
          ),
        ),
        SizedBox(height: 53,
          child: ListView(scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            children: ['All', 'Upcoming', 'Attended', 'Past'].map((filter) =>
                Padding(padding: const EdgeInsets.only(right: 7),
                  child: ChoiceChip(
                    selected: _filter == filter,
                    label: Text('$filter (${_count(filter)})'),
                    onSelected: (_) => setState(() => _filter = filter),
                  ),
                )).toList(),
          ),
        ),
        Expanded(child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null && _records.isEmpty
            ? Center(child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.cloud_off_rounded, size: 47,
                color: scheme.onSurfaceVariant),
            const SizedBox(height: 14),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.icon(onPressed: () => _load(),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry')),
          ]),
        ))
            : RefreshIndicator(
          onRefresh: () => _load(),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 22),
            children: [
              if (_error != null) Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(_error!, style: TextStyle(color: scheme.error)),
              ),
              if (filtered.isEmpty) Padding(
                padding: const EdgeInsets.symmetric(vertical: 65),
                child: Center(child: Text(_records.isEmpty
                    ? 'No registrations found for this student account.'
                    : 'No registrations in this category.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: scheme.onSurfaceVariant))),
              ),
              ...filtered.map(_card),
              if (_page < _lastPage)
                Padding(padding: const EdgeInsets.only(top: 5),
                  child: OutlinedButton.icon(
                    onPressed: _loadingMore ? null : () => _load(more: true),
                    icon: _loadingMore
                        ? const SizedBox(width: 17, height: 17,
                        child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.expand_more_rounded),
                    label: Text(_loadingMore ? 'Loading...' : 'Load more'),
                  ),
                ),
            ],
          ),
        )),
      ]),
    );
  }
}

// Registration-specific QR is created by Laravel selfRegister(), never locally.
class _LaravelRegistrationQrPage extends StatelessWidget {
  final Map<String, dynamic> registration;
  const _LaravelRegistrationQrPage({required this.registration});

  @override
  Widget build(BuildContext context) {
    final token = _LaravelMyPassesViewState._str(registration, 'qr_code');
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Event Registration Pass')),
      body: SafeArea(child: SingleChildScrollView(
        padding: const EdgeInsets.all(22),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(_LaravelMyPassesViewState._str(registration, 'event_title'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              Text('Registration ${_LaravelMyPassesViewState._str(registration, 'reference')}',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: scheme.onSurfaceVariant)),
              const SizedBox(height: 25),
              Center(child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: Colors.white,
                    borderRadius: BorderRadius.circular(20)),
                child: token.isEmpty
                    ? const Text('The server did not issue an event QR pass.')
                    : QrImageView(data: token,
                    version: QrVersions.auto, size: 230,
                    backgroundColor: Colors.white),
              )),
              const SizedBox(height: 24),
              const Text('Server-issued event registration credential',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              Text('This is your registration pass, not proof of attendance. '
                  'Your authorized scanner must accept Laravel registration QR '
                  'codes before this can be used for event check-in.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: scheme.onSurfaceVariant, height: 1.5)),
            ]),
      )),
    );
  }
}

// Account-level student attendance QR, independent of an event registration.
class _LaravelStudentAttendanceQrPage extends StatefulWidget {
  const _LaravelStudentAttendanceQrPage();

  @override
  State<_LaravelStudentAttendanceQrPage> createState() =>
      _LaravelStudentAttendanceQrPageState();
}

class _LaravelStudentAttendanceQrPageState
    extends State<_LaravelStudentAttendanceQrPage> {
  bool _loading = true;
  String? _error;
  String? _token;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      final token = await _LaravelMyPassesViewState._token();
      final response = await http.get(
        _LaravelMyPassesViewState._endpoint('/api/my/attendance-qr'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
          'ngrok-skip-browser-warning': 'true',
        },
      ).timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) {
        throw StateError(_LaravelMyPassesViewState._httpError(response));
      }
      final payload = jsonDecode(response.body);
      if (payload is! Map || payload['qr_token'] is! String ||
          (payload['qr_token'] as String).trim().isEmpty) {
        throw StateError('No attendance QR is assigned to this student account.');
      }
      if (!mounted) return;
      setState(() => _token = payload['qr_token'] as String);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error is StateError ? error.message.toString()
          : 'Unable to load student attendance QR.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Student Attendance QR')),
      body: Center(child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.verified_user_outlined,
              color: Color(0xFF215B99), size: 42),
          const SizedBox(height: 12),
          const Text('Official Student Attendance Pass',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              textAlign: TextAlign.center),
          const SizedBox(height: 25),
          if (_loading) const CircularProgressIndicator()
          else if (_error != null) ...[
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: _load, child: const Text('Retry')),
          ] else if (_token != null) Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: Colors.white,
                borderRadius: BorderRadius.circular(20)),
            child: QrImageView(data: _token!,
                version: QrVersions.auto, size: 230,
                backgroundColor: Colors.white),
          ),
          const SizedBox(height: 20),
          Text('Issued by Laravel for this student. Present only to '
              'authorized TMC personnel. QR display does not record '
              'attendance; the web scanner must verify it.',
              style: TextStyle(color: scheme.onSurfaceVariant, height: 1.5),
              textAlign: TextAlign.center),
        ]),
      )),
    );
  }
}
