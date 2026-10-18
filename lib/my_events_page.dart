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
    // Don't show in-memory registrations as if they came from Laravel.
    if (ApiConfig.useRealApi) {
      return const Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: EmptyState(
              icon: Icons.cloud_off_outlined,
              title: 'Online My Events Not Connected',
              message: 'Live student registrations will appear when '
                  'the Laravel registrations API is integrated.',
            ),
          ),
        ),
      );
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
