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
  String _searchQuery = '';

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
      final search = _searchQuery.trim().toLowerCase();
      if (search.isNotEmpty &&
          !'${event.title} ${event.venue} ${event.date}'
              .toLowerCase().contains(search)) {
        return false;
      }
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
          const SizedBox(height: 12),
          TextField(
            onChanged: (value) => setState(() => _searchQuery = value),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Search event title, venue, or date',
              prefixIcon: const Icon(Icons.search_rounded),
              filled: true,
              fillColor: _surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: _outline),
              ),
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

// Demo-only journey. A rating is not proof a certificate was issued.
  Widget _eventProgress({required bool present, required bool evaluated}) {
    final stages = <({String label, bool done})>[
      (label: 'Registered', done: true),
      (label: 'Attended', done: present),
      (label: 'Evaluated', done: present && evaluated),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('EVENT PROGRESS · DEMO',
            style: TextStyle(color: _subtle, fontSize: 11,
                fontWeight: FontWeight.w800)),
        const SizedBox(height: 9),
        Row(
          children: [
            for (var i = 0; i < stages.length; i++) ...[
              if (i > 0) Expanded(child: Container(height: 2,
                  color: stages[i].done ? const Color(0xFF248250) : _outline)),
              Icon(stages[i].done ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
                  size: 19,
                  color: stages[i].done ? const Color(0xFF248250) : _subtle),
              const SizedBox(width: 4),
              Text(stages[i].label,
                  style: TextStyle(fontSize: 10, color: _onSurface,
                      fontWeight: stages[i].done ? FontWeight.w800 : FontWeight.w500)),
            ],
          ],
        ),
      ],
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
          _eventProgress(present: present, evaluated: rated),
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
  String _searchQuery = '';
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

// The registration status is separate from the event status.
// Laravel may expose either key depending on controller serialization.
  static bool _isCancelled(Map<String, dynamic> record) {
    final registrationStatus = _str(record, 'registration_status',
        _str(record, 'status')).toLowerCase();
    return registrationStatus == 'cancelled' ||
        registrationStatus == 'canceled';
  }

  bool _attended(Map<String, dynamic> record) {
    final status = _str(record, 'attendance').toLowerCase();
    return status == 'present' || status == 'late';
  }

  List<Map<String, dynamic>> get _filtered {
    final search = _searchQuery.trim().toLowerCase();
    final matching = _records.where((record) {
      if (search.isEmpty) return true;
      return [
        _str(record, 'event_title'),
        _str(record, 'venue'),
        _str(record, 'event_date'),
        _str(record, 'reference'),
      ].join(' ').toLowerCase().contains(search);
    }).toList();
    switch (_filter) {
      case 'Upcoming':
        return matching.where((item) => !_isPast(item) && !_isCancelled(item)).toList();
      case 'Attended':
        return matching.where((item) => !_isCancelled(item) && _attended(item)).toList();
      case 'Past':
        return matching.where(_isPast).toList();
      default:
        return matching;
    }
  }

  int _count(String filter) {
    switch (filter) {
      case 'Upcoming':
        return _records.where((r) => !_isPast(r) && !_isCancelled(r)).length;
      case 'Attended':
        return _records.where((r) => !_isCancelled(r) && _attended(r)).length;
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
    final cancelled = _isCancelled(record);
    final title = _str(record, 'event_title', 'Untitled event');
    final venue = _str(record, 'venue', 'Venue not provided');
    final canCancel = !cancelled && !isPast && !isLateOrPresent &&
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
          Chip(label: Text(cancelled ? 'CANCELLED' : 'REGISTERED'),
              avatar: Icon(cancelled ? Icons.cancel_outlined : Icons.verified_rounded, size: 16),
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
            onPressed: cancelled || qr.isEmpty ? null : () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) =>
                  _LaravelRegistrationQrPage(registration: record)),
            ),
            icon: const Icon(Icons.qr_code_2_rounded),
            label: Text(cancelled ? 'Registration cancelled' : qr.isEmpty ? 'QR pass not available'
                : 'View event QR pass'),
            style: FilledButton.styleFrom(backgroundColor: _gold,
                foregroundColor: _navy),
          ),
        ),
// Open the real evaluation using THIS registration's event_reference.
// Laravel, not a local attendance flag, enforces check-in eligibility.
        if (!cancelled && _str(record, 'event_reference').isNotEmpty) ...[
          const SizedBox(height: 9),
          SizedBox(width: double.infinity, height: 46,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) =>
                    EvaluationPage.forLaravelRegistration(
                      laravelRegistration: record,
                    )),
              ),
              icon: const Icon(Icons.rate_review_outlined),
              label: const Text('Evaluate / Edit Evaluation'),
            ),
          ),
          const SizedBox(height: 4),
          Text('Evaluation requires a verified Laravel Time In.',
              style: TextStyle(fontSize: 11,
                  color: scheme.onSurfaceVariant)),
        ],
// Step 13: Real certificate status and authenticated PDF access.
// Laravel certificate listing is scoped to this student account.
        if (!cancelled && _str(record, 'event_title').isNotEmpty) ...[
          const SizedBox(height: 9),
          SizedBox(width: double.infinity, height: 46,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => LaravelCertificatePage(
                  eventTitle: _str(record, 'event_title'),
                  eventDate: _str(record, 'event_date'),
                ),
              )),
              icon: const Icon(Icons.workspace_premium_outlined),
              label: const Text('View E-Certificate status'),
            ),
          ),
        ],
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
    final media = MediaQuery.of(context);
    final compact = media.size.width < 390 || media.size.height < 730;
    final filtered = _filtered;

    // A single scrollable body prevents the header, search and filters from
    // squeezing the registration cards on phones with short/narrow screens.
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: RefreshIndicator(
        onRefresh: () => _load(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          children: [
            Container(
              padding: EdgeInsets.fromLTRB(
                16, compact ? 10 : 18, 16, compact ? 15 : 19,
              ),
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [_navy, _blue]),
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(24),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.confirmation_number_rounded,
                          color: _gold, size: 21),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text('MY PASSES  •  LARAVEL',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                            )),
                      ),
                      IconButton(
                        tooltip: 'Refresh my passes',
                        onPressed: _loading ? null : () => _load(),
                        icon: const Icon(Icons.refresh_rounded,
                            color: Colors.white),
                      ),
                    ],
                  ),
                  SizedBox(height: compact ? 2 : 7),
                  Text('My Events',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: compact ? 24 : 27,
                          fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  const Text('Your registrations, passes and attendance records',
                      style: TextStyle(color: Colors.white70, fontSize: 12)),
                  SizedBox(height: compact ? 12 : 17),
                  Row(
                    children: [
                      _stat('${_records.length}', 'Registrations',
                          Icons.confirmation_number_outlined),
                      const SizedBox(width: 6),
                      _stat('${_count('Attended')}', 'Present / Late',
                          Icons.fact_check_outlined),
                      const SizedBox(width: 6),
                      _stat('${_count('Upcoming')}', 'Upcoming',
                          Icons.calendar_today_outlined),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                  14, compact ? 12 : 14, 14, compact ? 7 : 8),
              child: SizedBox(
                width: double.infinity,
                height: compact ? 46 : 52,
                child: FilledButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const _LaravelStudentAttendancePage(),
                    ),
                  ),
                  icon: const Icon(Icons.fact_check_outlined, size: 20),
                  label: const Text('View My Attendance Records',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700)),
                  style: FilledButton.styleFrom(
                    backgroundColor: _navy,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 9),
              child: TextField(
                onChanged: (value) => setState(() => _searchQuery = value),
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  isDense: compact,
                  hintText: 'Search your registrations',
                  prefixIcon: const Icon(Icons.search_rounded),
                  filled: true,
                  fillColor: scheme.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: scheme.outlineVariant),
                  ),
                ),
              ),
            ),
            // Scroll the filters horizontally instead of clipping the last chip.
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: ['All', 'Upcoming', 'Attended', 'Past'].map((filter) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 7),
                    child: ChoiceChip(
                      visualDensity: compact
                          ? VisualDensity.compact
                          : VisualDensity.standard,
                      selected: _filter == filter,
                      label: Text('$filter (${_count(filter)})'),
                      onSelected: (_) => setState(() => _filter = filter),
                    ),
                  );
                }).toList(),
              ),
            ),
            if (_loading && _records.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 70),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null && _records.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Icon(Icons.cloud_off_rounded, size: 44,
                        color: scheme.onSurfaceVariant),
                    const SizedBox(height: 12),
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: () => _load(),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              )
            else ...[
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                    child: Text(_error!, style: TextStyle(color: scheme.error)),
                  ),
                if (filtered.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 60),
                    child: Text(
                      _records.isEmpty
                          ? 'No registrations found for this student account.'
                          : 'No registrations in this category.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 20),
                  child: Column(
                    children: [
                      ...filtered.map(_card),
                      if (_page < _lastPage)
                        Padding(
                          padding: const EdgeInsets.only(top: 5),
                          child: OutlinedButton.icon(
                            onPressed: _loadingMore
                                ? null
                                : () => _load(more: true),
                            icon: _loadingMore
                                ? const SizedBox(
                              width: 17,
                              height: 17,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2),
                            )
                                : const Icon(Icons.expand_more_rounded),
                            label: Text(
                                _loadingMore ? 'Loading...' : 'Load more'),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
          ],
        ),
      ),
    );
  }

}

// Registration-specific QR is created by Laravel selfRegister(), never locally.
class _LaravelRegistrationQrPage extends StatelessWidget {
  final Map<String, dynamic> registration;

  const _LaravelRegistrationQrPage({required this.registration});

  static const Color _navy = Color(0xFF102A4C);
  static const Color _blue = Color(0xFF215B99);
  static const Color _gold = Color(0xFFFFCB4D);

  String _value(String key, [String fallback = '']) {
    final value = registration[key];
    if (value == null || value.toString().trim().isEmpty) return fallback;
    return value.toString().trim();
  }

  String _formatDate(String raw) {
    final date = DateTime.tryParse(raw);
    if (date == null) return raw.isEmpty ? 'Date TBA' : raw;
    const months = <String>[
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  Widget _detail(IconData icon, String label, String value, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: _blue),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 11,
                  color: color.withValues(alpha: 0.65))),
              const SizedBox(height: 3),
              Text(value, style: TextStyle(fontSize: 14, color: color,
                  fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final title = _value('event_title', 'Untitled event');
    final reference = _value('reference', 'N/A');
    // The QR payload remains EXACTLY the Laravel-issued registration token.
    final token = _value('qr_code');
    final venue = _value('venue', 'Venue TBA');
    final date = _formatDate(_value('event_date'));
    final time = _value('start_time', 'Time TBA');

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: _navy,
        foregroundColor: Colors.white,
        centerTitle: true,
        title: const Text('My Event Pass',
            style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 22, 18, 30),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(22),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [_navy, _blue],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.vertical(
                          top: Radius.circular(24)),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.confirmation_number_rounded,
                            size: 38, color: _gold),
                        const SizedBox(height: 10),
                        const Text('TMC EVENTEASE', style: TextStyle(
                          color: _gold, fontSize: 12,
                          fontWeight: FontWeight.w900, letterSpacing: 2,
                        )),
                        const SizedBox(height: 12),
                        Text(title, textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white,
                                fontSize: 23, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.13),
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: Text('REGISTRATION $reference',
                              style: const TextStyle(color: Colors.white,
                                  fontSize: 12, fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: scheme.surface,
                      borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(24)),
                      border: Border.all(color: scheme.outlineVariant),
                    ),
                    child: Column(
                      children: [
                        const Text('YOUR DIGITAL EVENT PASS', style: TextStyle(
                          fontSize: 12, color: _blue,
                          fontWeight: FontWeight.w900, letterSpacing: 1,
                        )),
                        const SizedBox(height: 6),
                        Text('Present this QR code to an authorized scanner',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12,
                                color: scheme.onSurfaceVariant)),
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                                color: const Color(0xFFE2E8F0)),
                          ),
                          child: token.isEmpty
                              ? const SizedBox(
                            width: 220, height: 220,
                            child: Center(child: Text('QR pass unavailable',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: _navy))),
                          )
                              : QrImageView(
                            data: token,
                            version: QrVersions.auto,
                            size: 220,
                            backgroundColor: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.verified_user_outlined,
                                color: Color(0xFF248250), size: 19),
                            const SizedBox(width: 7),
                            Flexible(child: Text(
                              'Server-issued Registration Pass',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: scheme.onSurface,
                                  fontSize: 12, fontWeight: FontWeight.w700),
                            )),
                          ],
                        ),
                        const SizedBox(height: 23),
                        Divider(color: scheme.outlineVariant),
                        const SizedBox(height: 20),
                        _detail(Icons.calendar_month_outlined,
                            'EVENT DATE', date, scheme.onSurface),
                        const SizedBox(height: 18),
                        _detail(Icons.schedule_outlined,
                            'START TIME', time, scheme.onSurface),
                        const SizedBox(height: 18),
                        _detail(Icons.location_on_outlined,
                            'VENUE', venue, scheme.onSurface),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: scheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: scheme.outlineVariant),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline_rounded,
                            color: _blue, size: 22),
                        const SizedBox(width: 12),
                        Expanded(child: Text(
                          'This QR is your registration credential, not proof '
                              'of attendance. Attendance is recorded only after '
                              'successful verification by an authorized scanner.',
                          style: TextStyle(color: scheme.onSurfaceVariant,
                              fontSize: 12, height: 1.5),
                        )),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: FilledButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_rounded),
                      label: const Text('Back to My Events'),
                      style: FilledButton.styleFrom(
                        backgroundColor: _navy,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
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


// ================================================================
// TMC EVENTEASE — OFFICIAL STUDENT ATTENDANCE (READ-ONLY)
// /api/registrations/my  = registrations and their attendance rollup
// /api/my/attendance     = compulsory attendance obligations/sessions
// These are separate resources. Never infer attendance from a QR pass.
// ================================================================
class _LaravelStudentAttendancePage extends StatefulWidget {
  const _LaravelStudentAttendancePage();

  @override
  State<_LaravelStudentAttendancePage> createState() =>
      _LaravelStudentAttendancePageState();
}

class _LaravelStudentAttendancePageState
    extends State<_LaravelStudentAttendancePage> {
  static const _navy = Color(0xFF102A4C);
  static const _blue = Color(0xFF215B99);
  static const _gold = Color(0xFFFFCB4D);

  bool _loading = true;
  String _selectedTab = 'Registered events';
  String? _authError;
  String? _registrationError;
  String? _obligationError;
  List<Map<String, dynamic>> _registrations = [];
  List<Map<String, dynamic>> _obligations = [];
  final Set<String> _expandedRegistrations = <String>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _refresh();
    });
  }

  String _value(Map<String, dynamic> record, String field,
      [String fallback = '']) {
    final value = record[field];
    return value == null ? fallback : value.toString().trim();
  }

  Map<String, String> _headers(String token) => {
    'Accept': 'application/json',
    'Authorization': 'Bearer $token',
    'ngrok-skip-browser-warning': 'true',
  };

  String _errorFor(http.Response response, String resource) {
    if (response.statusCode == 401) {
      return 'Your session expired. Please sign in again.';
    }
    if (response.statusCode == 403) {
      return 'Laravel denied access to $resource. Check the student account permissions.';
    }
    if (response.statusCode == 404) {
      return 'The $resource endpoint was not found on Laravel.';
    }
    try {
      final json = jsonDecode(response.body);
      if (json is Map && json['message'] is String) {
        return json['message'] as String;
      }
    } catch (_) {
// Laravel may return an HTML error; never display server HTML.
    }
    return 'Unable to load $resource (HTTP ${response.statusCode}).';
  }

  Future<List<Map<String, dynamic>>> _fetchRegistrations(String token) async {
    final result = <Map<String, dynamic>>[];
    var page = 1;
    var lastPage = 1;
    do {
      final response = await http.get(
        _LaravelMyPassesViewState._endpoint(
          '/api/registrations/my',
          query: {'page': '$page'},
        ),
        headers: _headers(token),
      ).timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) {
        throw StateError(_errorFor(response, 'registration history'));
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map || decoded['data'] is! List) {
        throw const FormatException('Invalid registration history response.');
      }
      for (final item in decoded['data'] as List) {
        if (item is! Map) {
          throw const FormatException('Invalid registration item.');
        }
        result.add(Map<String, dynamic>.from(item));
      }
      lastPage = int.tryParse('${decoded['last_page'] ?? 1}') ?? 1;
      if (lastPage > 50) {
        throw StateError('Registration history is too large for this view. '
            'Contact the developer about attendance pagination.');
      }
      page++;
    } while (page <= lastPage);
    return result;
  }

  Future<List<Map<String, dynamic>>> _fetchObligations(String token) async {
    final response = await http.get(
      _LaravelMyPassesViewState._endpoint('/api/my/attendance'),
      headers: _headers(token),
    ).timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw StateError(_errorFor(response, 'compulsory attendance'));
    }
    final decoded = jsonDecode(response.body);
    final rows = decoded is List
        ? decoded
        : decoded is Map && decoded['data'] is List
        ? decoded['data'] as List
        : null;
    if (rows == null) {
      throw const FormatException('Invalid compulsory attendance response.');
    }
    return rows.map((item) {
      if (item is! Map) {
        throw const FormatException('Invalid attendance record.');
      }
      return Map<String, dynamic>.from(item);
    }).toList();
  }

  String _describeError(Object error, String resource) {
    if (error is StateError) return error.message.toString();
    if (error is FormatException) {
      return 'Laravel returned an unexpected format for $resource.';
    }
    return 'Could not load $resource. Check the Laravel/ngrok connection and retry.';
  }

  Future<void> _refresh() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _authError = null;
        _registrationError = null;
        _obligationError = null;
        _registrations = [];
        _obligations = [];
      });
    }

    try {
      if (!ApiConfig.useRealApi) {
        throw StateError('Official attendance requires Real API Mode.');
      }
      final token = await _LaravelMyPassesViewState._token();
      List<Map<String, dynamic>> registrations = [];
      List<Map<String, dynamic>> obligations = [];
      String? registrationError;
      String? obligationError;

// Each collection is independent: one failure must not hide the other.
      try {
        registrations = await _fetchRegistrations(token);
      } catch (error) {
        registrationError = _describeError(error, 'registered-event attendance');
      }
      try {
        obligations = await _fetchObligations(token);
      } catch (error) {
        obligationError = _describeError(error, 'compulsory attendance');
      }
      if (!mounted) return;
      setState(() {
        _registrations = registrations;
        _obligations = obligations;
        _registrationError = registrationError;
        _obligationError = obligationError;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _authError = _describeError(error, 'official attendance');
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _date(String raw) {
    final date = DateTime.tryParse(raw);
    if (date == null) return raw.isEmpty ? 'Date not provided' : raw;
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

// Laravel sends timestamps in UTC with a trailing Z. Show phone-local time.
// A bare HH:mm time is used as-is because no timezone was supplied.
  String _attendanceTime(Object? input) {
    if (input == null) return 'Not recorded';
    final raw = input.toString().trim();
    if (raw.isEmpty) return 'Not recorded';
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    final local = parsed.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute ${local.hour >= 12 ? 'PM' : 'AM'}';
  }

  Widget _summaryStat(String label, String value, IconData icon,
      Color foreground) {
    final c = Theme.of(context).colorScheme;
    return Expanded(child: Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(color: c.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.outlineVariant)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: foreground, size: 21),
        const SizedBox(height: 10),
        Text(value, style: TextStyle(color: c.onSurface, fontSize: 22,
            fontWeight: FontWeight.w900)),
        Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(color: c.onSurfaceVariant, fontSize: 11)),
      ]),
    ));
  }

  Widget _registrationSummary() {
    final registered = _registrations.length;
    final attended = _registrations.where((record) {
      final status = _value(record, 'attendance').toLowerCase();
      return status == 'present' || status == 'late' ||
          status == 'complete';
    }).length;
    final awaiting = _registrations.where((record) {
      final status = _value(record, 'attendance').toLowerCase();
      return status.isEmpty || status == 'not yet recorded' ||
          status == 'pending' || status == 'not recorded';
    }).length;
    return Row(children: [
      _summaryStat('Registered', '$registered',
          Icons.confirmation_number_outlined, _blue),
      const SizedBox(width: 9),
      _summaryStat('Attended', '$attended',
          Icons.verified_outlined, const Color(0xFF168566)),
      const SizedBox(width: 9),
      _summaryStat('Awaiting', '$awaiting',
          Icons.pending_actions_outlined, const Color(0xFF997022)),
    ]);
  }

  Color _statusColor(String raw) {
    final status = raw.toLowerCase().trim();
    if (status == 'present' || status == 'complete') {
      return const Color(0xFF168566);
    }
    if (status == 'late' || status == 'excused') {
      return const Color(0xFF216A9B);
    }
    if (status == 'absent') {
      return const Color(0xFFB8404C);
    }
    return const Color(0xFF9B711F);
  }

  String _statusLabel(String raw) {
    final status = raw.trim();
    if (status.isEmpty) return 'Not yet recorded';
    return status.replaceAll('_', ' ');
  }

  Widget _statusBadge(String status) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        color: color.withValues(alpha: .10),
      ),
      child: Text(
        _statusLabel(status),
        style: TextStyle(color: color, fontWeight: FontWeight.w800,
            fontSize: 12),
      ),
    );
  }

  Widget _panel({required Widget child}) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(18),
      ),
      child: child,
    );
  }

  Widget _registrationCard(Map<String, dynamic> record) {
    final colors = Theme.of(context).colorScheme;
    final status = _value(record, 'attendance', 'Not Yet Recorded');
    final reference = _value(record, 'reference');
    final key = reference.isEmpty ? '${record['id'] ?? record.hashCode}' : reference;
    final expanded = _expandedRegistrations.contains(key);
// Optional: when Laravel later exposes verified session records on the
// student-only registration route, display them without another UI change.
    final rawSessions = record['sessions'];
    final sessions = rawSessions is List
        ? rawSessions.whereType<Map>()
        .map((s) => Map<String, dynamic>.from(s)).toList()
        : <Map<String, dynamic>>[];
    return _panel(child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.event_available_outlined, color: _blue, size: 25),
          const SizedBox(width: 10),
          Expanded(child: Text(_value(record, 'event_title', 'Untitled event'),
              style: const TextStyle(fontSize: 17,
                  fontWeight: FontWeight.w900))),
        ]),
        const SizedBox(height: 10),
        Text('Event: ${_date(_value(record, 'event_date'))}',
            style: TextStyle(color: colors.onSurfaceVariant)),
        const SizedBox(height: 3),
        Text('Registration: ${reference.isEmpty ? 'Unavailable' : reference}',
            style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12)),
        const SizedBox(height: 13),
        Row(children: [
          const Expanded(child: Text('Overall attendance',
              style: TextStyle(fontWeight: FontWeight.w700))),
          _statusBadge(status),
        ]),
        const SizedBox(height: 8),
        Text('Overall status confirmed by the Laravel registration record.',
            style: TextStyle(color: colors.onSurfaceVariant, fontSize: 11)),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: () => setState(() {
            if (expanded) {
              _expandedRegistrations.remove(key);
            } else {
              _expandedRegistrations.add(key);
            }
          }),
          icon: Icon(expanded ? Icons.expand_less_rounded
              : Icons.expand_more_rounded),
          label: Text(expanded ? 'Hide scan details' : 'Session scan details'),
        ),
        if (expanded) ...[
          Divider(color: colors.outlineVariant),
          if (sessions.isNotEmpty)
            ...sessions.map(_sessionCard)
          else
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 11),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.info_outline_rounded,
                    color: colors.onSurfaceVariant, size: 19),
                const SizedBox(width: 9),
                Expanded(child: Text(
                  'Laravel currently returns overall attendance for this '
                      'registration, but not session-level Time In, Time Out, '
                      'or Late details. Those will appear after the student API '
                      'exposes verified session records.',
                  style: TextStyle(color: colors.onSurfaceVariant,
                      fontSize: 12, height: 1.5),
                )),
              ]),
            ),
        ],
      ],
    ));
  }

  Widget _sessionCard(Map<String, dynamic> session) {
    final colors = Theme.of(context).colorScheme;
    final label = _value(session, 'label', 'Attendance session');
    final timeIn = _value(session, 'time_in');
    final timeOut = _value(session, 'time_out');
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: Text(label,
                style: const TextStyle(fontWeight: FontWeight.w800))),
            _statusBadge(_value(session, 'status', 'Missing')),
          ]),
          const SizedBox(height: 6),
          Text(_date(_value(session, 'date')),
              style: TextStyle(color: colors.onSurfaceVariant,
                  fontSize: 12)),
          const SizedBox(height: 5),
          Text('Time In: ${_attendanceTime(timeIn)}',
              style: TextStyle(color: colors.onSurfaceVariant,
                  fontSize: 12)),
          Text('Time Out: ${_attendanceTime(timeOut)}',
              style: TextStyle(color: colors.onSurfaceVariant,
                  fontSize: 12)),
        ],
      ),
    );
  }

  Widget _obligationCard(Map<String, dynamic> record) {
    final colors = Theme.of(context).colorScheme;
    final status = _value(record, 'attendance_status', 'pending');
    final scansRecorded = int.tryParse(
        '${record['scans_recorded'] ?? 0}') ?? 0;
    final requiredScans = int.tryParse(
        '${record['required_scans'] ?? 0}') ?? 0;
    final rawSessions = record['attendance'];
    final sessions = rawSessions is List
        ? rawSessions.whereType<Map>()
        .map((s) => Map<String, dynamic>.from(s)).toList()
        : <Map<String, dynamic>>[];
    return _panel(child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.fact_check_outlined, color: _blue, size: 25),
          const SizedBox(width: 10),
          Expanded(child: Text(_value(record, 'title', 'Required event'),
              style: const TextStyle(fontSize: 17,
                  fontWeight: FontWeight.w900))),
        ]),
        const SizedBox(height: 10),
        Text('${_date(_value(record, 'event_date'))} · '
            '${_value(record, 'venue', 'Venue not provided')}',
            style: TextStyle(color: colors.onSurfaceVariant)),
        const SizedBox(height: 12),
        Row(children: [
          const Expanded(child: Text('Overall status',
              style: TextStyle(fontWeight: FontWeight.w700))),
          _statusBadge(status),
        ]),
        const SizedBox(height: 12),
        Text('Verified scans: $scansRecorded / $requiredScans',
            style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: requiredScans <= 0 ? 0 :
          (scansRecorded / requiredScans).clamp(0.0, 1.0).toDouble(),
          backgroundColor: colors.outlineVariant,
          color: _blue,
          borderRadius: BorderRadius.circular(12),
          minHeight: 8,
        ),
        if (sessions.isNotEmpty) ...[
          const SizedBox(height: 14),
          const Text('Sessions',
              style: TextStyle(fontWeight: FontWeight.w900)),
          ...sessions.map(_sessionCard),
        ] else ...[
          const SizedBox(height: 9),
          Text('Laravel has no sessions for this obligation yet.',
              style: TextStyle(color: colors.onSurfaceVariant,
                  fontSize: 12)),
        ],
      ],
    ));
  }

  Widget _stateMessage({required IconData icon,
    required String title, required String message}) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 55, horizontal: 14),
      child: Column(children: [
        Icon(icon, color: colors.onSurfaceVariant, size: 42),
        const SizedBox(height: 13),
        Text(title, textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
        const SizedBox(height: 7),
        Text(message, textAlign: TextAlign.center,
            style: TextStyle(color: colors.onSurfaceVariant, height: 1.4)),
      ]),
    );
  }

  Widget _body() {
    if (_authError != null) {
      return _stateMessage(icon: Icons.lock_outline,
          title: 'Unable to verify your session', message: _authError!);
    }
    final registrationTab = _selectedTab == 'Registered events';
    final error = registrationTab ? _registrationError : _obligationError;
    final records = registrationTab ? _registrations : _obligations;
    if (error != null) {
      return _stateMessage(icon: Icons.cloud_off_rounded,
          title: 'Unable to load attendance', message: error);
    }
    if (records.isEmpty) {
      return _stateMessage(icon: Icons.event_note_outlined,
          title: registrationTab ? 'No registrations yet' :
          'No compulsory attendance records',
          message: registrationTab
              ? 'Registered events and their attendance will appear here '
              'after Laravel confirms your registration.'
              : 'Laravel has not published compulsory-attendance '
              'obligations for this account. This does not mean you '
              'were marked absent.');
    }
    return Column(children: [
      if (!registrationTab) Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text('These records are created when the college finalizes '
            'the compulsory-attendance roster.',
            style: TextStyle(color: Theme.of(context)
                .colorScheme.onSurfaceVariant, fontSize: 12)),
      ),
      ...records.map(registrationTab ? _registrationCard : _obligationCard),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('My Attendance'),
        actions: [
          IconButton(
            tooltip: 'Refresh official attendance',
            onPressed: _loading ? null : _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
          children: [
            Container(
              padding: const EdgeInsets.all(19),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_navy, _blue]),
                borderRadius: BorderRadius.circular(23),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.verified_user_outlined,
                      color: _gold, size: 30),
                  const SizedBox(height: 9),
                  const Text('Official attendance records',
                      style: TextStyle(color: Colors.white,
                          fontSize: 21, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 7),
                  const Text('Live records from Laravel. Only authorized '
                      'scanners can record Time In and Time Out.',
                      style: TextStyle(color: Colors.white70,
                          height: 1.4)),
                ],
              ),
            ),
            const SizedBox(height: 15),
            Wrap(spacing: 8, runSpacing: 8, children: [
              ChoiceChip(
                selected: _selectedTab == 'Registered events',
                label: Text('Registered events (${_registrations.length})'),
                onSelected: (_) => setState(
                        () => _selectedTab = 'Registered events'),
              ),
              ChoiceChip(
                selected: _selectedTab == 'Required attendance',
                label: Text('Required attendance (${_obligations.length})'),
                onSelected: (_) => setState(
                        () => _selectedTab = 'Required attendance'),
              ),
            ]),
            const SizedBox(height: 16),
            if (_authError == null && _registrationError == null &&
                _selectedTab == 'Registered events' &&
                _registrations.isNotEmpty) ...[
              _registrationSummary(),
              const SizedBox(height: 16),
            ],
            _body(),
            const SizedBox(height: 9),
            Text('Pull down or tap refresh after an authorized QR scan. '
                'Displaying a QR code by itself does not record attendance.',
                style: TextStyle(color: colors.onSurfaceVariant,
                    fontSize: 11.5, height: 1.5),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
