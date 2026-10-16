part of 'main.dart';

// ======================================================
// TMC EVENTEASE - MY EVENTS PAGE
// WITH ALL, UPCOMING, ATTENDED, COMPLETED FILTERS
// ======================================================

class MyEventsPage extends StatefulWidget {
  const MyEventsPage({super.key});

  @override
  State<MyEventsPage> createState() => _MyEventsPageState();
}

class _MyEventsPageState extends State<MyEventsPage> {
  // ====================================================
  // LIGHT AND DARK MODE COLORS
  // ====================================================

  Color get _cardSurface => Theme.of(context).colorScheme.surface;

  Color get _primaryText => Theme.of(context).colorScheme.onSurface;

  Color get _secondaryText => Theme.of(context).colorScheme.onSurfaceVariant;

  Color get _cardBorder => Theme.of(context).colorScheme.outlineVariant;

  bool get _isDarkMode => Theme.of(context).brightness == Brightness.dark;

  // ====================================================
  // EVENT FILTERS
  // ====================================================

  String selectedFilter = 'All';

  static const List<String> filters = [
    'All',
    'Upcoming',
    'Attended',
    'Completed',
  ];

  // ====================================================
  // PARSE EVENT DATE
  // Supports:
  // October 15, 2026
  // Oct 15, 2026
  // 2026-10-15
  // ====================================================

  DateTime? _parseEventDate(String rawDate) {
    final value = rawDate.trim();

    if (value.isEmpty) return null;

    final isoDate = DateTime.tryParse(value);

    if (isoDate != null) {
      return DateTime(isoDate.year, isoDate.month, isoDate.day);
    }

    final match = RegExp(
      r'^([A-Za-z]+)\.?\s+(\d{1,2}),?\s+(\d{4})$',
      caseSensitive: false,
    ).firstMatch(value);

    if (match == null) return null;

    const months = <String, int>{
      'jan': 1,
      'january': 1,
      'feb': 2,
      'february': 2,
      'mar': 3,
      'march': 3,
      'apr': 4,
      'april': 4,
      'may': 5,
      'jun': 6,
      'june': 6,
      'jul': 7,
      'july': 7,
      'aug': 8,
      'august': 8,
      'sep': 9,
      'sept': 9,
      'september': 9,
      'oct': 10,
      'october': 10,
      'nov': 11,
      'november': 11,
      'dec': 12,
      'december': 12,
    };

    final month = months[match.group(1)!.toLowerCase()];
    final day = int.tryParse(match.group(2)!);
    final year = int.tryParse(match.group(3)!);

    if (month == null || day == null || year == null) {
      return null;
    }

    final parsed = DateTime(year, month, day);

    if (parsed.year != year || parsed.month != month || parsed.day != day) {
      return null;
    }

    return parsed;
  }

  // ====================================================
  // FILTER REGISTERED EVENTS
  // ====================================================

  List<Event> _getFilteredEvents() {
    final now = DateTime.now();

    final today = DateTime(now.year, now.month, now.day);

    return registeredEvents.where((event) {
      final key = eventKey(event);
      final attendance = attendanceStatus[key] ?? 'Not Recorded';

      final eventDate = _parseEventDate(event.date);

      switch (selectedFilter) {
        case 'Upcoming':
          // Include today and future events.
          return eventDate != null && !eventDate.isBefore(today);

        case 'Attended':
          // Attendance must be marked Present.
          return attendance == 'Present';

        case 'Completed':
          // Event date has already passed.
          return eventDate != null && eventDate.isBefore(today);

        case 'All':
        default:
          return true;
      }
    }).toList();
  }

  // ====================================================
  // FILTER SECTION
  // ====================================================

  Widget _buildEventFilters() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Filter My Events',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
          ),

          const SizedBox(height: 10),

          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: filters.map((filter) {
                final isSelected = selectedFilter == filter;

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(filter),
                    selected: isSelected,
                    showCheckmark: false,
                    selectedColor: navy,
                    backgroundColor: Theme.of(context).colorScheme.surface,
                    side: BorderSide(color: isSelected ? navy : borderColor),
                    shape: const StadiumBorder(),
                    labelStyle: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : Theme.of(context).colorScheme.onSurface,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                    onSelected: (_) {
                      setState(() {
                        selectedFilter = filter;
                      });
                    },
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // ====================================================
  // EMPTY STATE MESSAGES
  // ====================================================

  String _emptyTitle() {
    if (registeredEvents.isEmpty) {
      return 'No registered events yet';
    }

    switch (selectedFilter) {
      case 'Upcoming':
        return 'No upcoming events';

      case 'Attended':
        return 'No attended events yet';

      case 'Completed':
        return 'No completed events yet';

      default:
        return 'No registered events yet';
    }
  }

  String _emptyMessage() {
    if (registeredEvents.isEmpty) {
      return 'Register for an event and it will appear here.';
    }

    switch (selectedFilter) {
      case 'Upcoming':
        return 'You have no registered events '
            'scheduled for today or a future date.';

      case 'Attended':
        return 'Events with recorded attendance '
            'will appear here.';

      case 'Completed':
        return 'Registered events with past '
            'dates will appear here.';

      default:
        return 'Register for an event and it will appear here.';
    }
  }

  // ====================================================
  // CANCEL REGISTRATION
  // ====================================================

  Future<void> cancelRegistration(Event event) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          icon: const Icon(
            Icons.warning_amber_rounded,
            color: Colors.orange,
            size: 34,
          ),
          title: const Text('Cancel registration?'),
          content: Text(
            'Are you sure you want to cancel your '
            'registration for ${event.title}?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('No'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Yes, Cancel'),
            ),
          ],
        );
      },
    );

    if (confirm != true || !mounted) return;

    final key = eventKey(event);

    setState(() {
      registeredEvents.remove(event);
      attendanceStatus.remove(key);
      eventRatings.remove(key);
      eventComments.remove(key);
      qrTokens.remove(key);
      attendanceCheckInTime.remove(key);
    });

    if (!mounted) return;

    showMessage(context, 'Registration cancelled.');
  }

  // ====================================================
  // EVENT ICON
  // ====================================================

  IconData _eventIcon(Event event) {
    final title = event.title.toLowerCase();

    if (title.contains('leadership')) {
      return Icons.groups_rounded;
    } else if (title.contains('workshop') || title.contains('web')) {
      return Icons.code_rounded;
    } else if (title.contains('esport')) {
      return Icons.sports_esports_rounded;
    } else if (title.contains('programming')) {
      return Icons.terminal_rounded;
    }

    return Icons.confirmation_num_rounded;
  }

  // ====================================================
  // ATTENDANCE COLORS
  // ====================================================

  Color _attendanceColor(String status) {
    switch (status) {
      case 'Present':
        return _isDarkMode ? const Color(0xFF78E6A0) : const Color(0xFF27834A);

      case 'Absent':
        return _isDarkMode ? const Color(0xFFFF9696) : Colors.red;

      default:
        return _secondaryText;
    }
  }

  Color _attendanceBg(String status) {
    switch (status) {
      case 'Present':
        return _isDarkMode ? const Color(0xFF183C2A) : const Color(0xFFEAF7EE);

      case 'Absent':
        return _isDarkMode ? const Color(0xFF452629) : const Color(0xFFFFECEC);

      default:
        return _isDarkMode ? const Color(0xFF293445) : const Color(0xFFF4F6F9);
    }
  }

  // ====================================================
  // ATTENDANCE LABEL
  // ====================================================

  String _attendanceLabel(String status, String? time) {
    if (status == 'Present' && time != null && time.isNotEmpty) {
      return 'Present • $time';
    }

    if (status == 'Absent' && time != null && time.isNotEmpty) {
      return 'Absent • $time';
    }

    return status;
  }

  // ====================================================
  // HEADER
  // ====================================================

  Widget _sectionHeader() {
    final presentCount = registeredEvents.where((event) {
      final key = eventKey(event);

      return attendanceStatus[key] == 'Present';
    }).length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      decoration: const BoxDecoration(
        gradient: appGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'My Events',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.4,
            ),
          ),

          const SizedBox(height: 6),

          const Text(
            'Manage your registrations, attendance, '
            'and evaluation status.',
            style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: _summaryCard(
                  icon: Icons.confirmation_num_rounded,
                  label: 'Registered',
                  value: '${registeredEvents.length}',
                ),
              ),

              const SizedBox(width: 10),

              Expanded(
                child: _summaryCard(
                  icon: Icons.verified_rounded,
                  label: 'Present',
                  value: '$presentCount',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ====================================================
  // SUMMARY CARD
  // ====================================================

  Widget _summaryCard({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: yellow),
          ),

          const SizedBox(width: 12),

          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
              Text(
                label,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ====================================================
  // REUSABLE ACTION BUTTON
  // ====================================================

  Widget _actionButton({
    required VoidCallback? onPressed,
    required IconData icon,
    required String label,
    bool outlined = false,
    Color? foregroundColor,
    Color? borderColorOverride,
  }) {
    if (outlined) {
      return OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: foregroundColor ?? navy,
          side: BorderSide(color: borderColorOverride ?? borderColor),
        ),
      );
    }

    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
    );
  }

  // ====================================================
  // REGISTERED EVENT CARD
  // ====================================================

  Widget _buildEventCard(Event event) {
    final key = eventKey(event);

    final status = attendanceStatus[key] ?? 'Not Recorded';

    final checkInTime = attendanceCheckInTime[key];

    final canEvaluate = status == 'Present';
    final canCancel = status != 'Present';

    return Container(
      decoration: BoxDecoration(
        color: _cardSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _cardBorder),

        boxShadow: [
          BoxShadow(
            color: navy.withValues(alpha: 0.045),
            blurRadius: 16,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ============================================
          // EVENT INFORMATION
          // ============================================
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 66,
                height: 66,
                decoration: BoxDecoration(
                  gradient: appGradient,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(_eventIcon(event), color: yellow, size: 30),
              ),

              const SizedBox(width: 13),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title,

                      style: TextStyle(
                        color: _primaryText,
                        fontSize: 16.8,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                    ),

                    const SizedBox(height: 6),

                    Text(
                      '${event.date} • ${event.venue}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,

                      style: TextStyle(
                        color: _secondaryText,
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF7EE),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Registered',
                  style: TextStyle(
                    color: Color(0xFF27834A),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // ============================================
          // ATTENDANCE STATUS
          // ============================================
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              color: _attendanceBg(status),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _attendanceBg(status)),
            ),
            child: Row(
              children: [
                Icon(
                  status == 'Present'
                      ? Icons.verified_rounded
                      : status == 'Absent'
                      ? Icons.cancel_rounded
                      : Icons.schedule_rounded,
                  size: 18,
                  color: _attendanceColor(status),
                ),

                const SizedBox(width: 8),

                Expanded(
                  child: Text(
                    _attendanceLabel(status, checkInTime),
                    style: TextStyle(
                      color: _attendanceColor(status),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ============================================
          // EVALUATE EVENT
          // ============================================
          _actionButton(
            onPressed: canEvaluate
                ? () {
                    Navigator.push(
                      context,
                      animatedRoute(EvaluationPage(event: event)),
                    );
                  }
                : null,
            icon: canEvaluate ? Icons.star_rounded : Icons.lock_outline_rounded,
            label: canEvaluate ? 'Evaluate Event' : 'Evaluation Locked',
          ),

          const SizedBox(height: 10),

          // ============================================
          // VIEW QR PASS
          // ============================================
          _actionButton(
            onPressed: () {
              Navigator.push(
                context,
                animatedRoute(StudentQrPassPage(event: event)),
              );
            },
            icon: Icons.qr_code_2_rounded,
            label: 'View QR Pass',
          ),

          const SizedBox(height: 10),

          // ============================================
          // CANCEL REGISTRATION
          // ============================================
          if (canCancel)
            _actionButton(
              onPressed: () => cancelRegistration(event),
              icon: Icons.cancel_outlined,
              label: 'Cancel Registration',
              outlined: true,
              foregroundColor: Colors.red,
              borderColorOverride: const Color(0xFFF1CFCF),
            )
          else
            OutlinedButton.icon(
              onPressed: null,
              icon: const Icon(Icons.lock_outline_rounded),
              label: const Text('Cancellation Unavailable'),
              style: OutlinedButton.styleFrom(
                foregroundColor: textGrey,
                side: BorderSide(color: _cardBorder),
              ),
            ),

          const SizedBox(height: 8),

          Text(
            canCancel
                ? 'You may cancel while attendance '
                      'has not yet been recorded.'
                : 'Cancellation is unavailable because '
                      'attendance has already been recorded.',

            style: TextStyle(
              color: _secondaryText,
              fontSize: 12.5,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  // ====================================================
  // MAIN PAGE
  // ====================================================

  @override
  Widget build(BuildContext context) {
    final filteredEvents = _getFilteredEvents();

    return Scaffold(
      body: Column(
        children: [
          // HEADER
          _sectionHeader(),

          // NEW EVENT FILTERS
          _buildEventFilters(),

          // FILTERED EVENT LIST
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: filteredEvents.isEmpty
                  ? Center(
                      key: ValueKey('empty-$selectedFilter'),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: EmptyState(
                          icon: Icons.event_busy_rounded,
                          title: _emptyTitle(),
                          message: _emptyMessage(),
                        ),
                      ),
                    )
                  : ListView.separated(
                      key: ValueKey('events-$selectedFilter'),
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 26),
                      itemCount: filteredEvents.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 14),
                      itemBuilder: (context, index) {
                        final event = filteredEvents[index];

                        return TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: 1),
                          duration: Duration(milliseconds: 300 + index * 70),
                          curve: Curves.easeOutCubic,
                          builder: (context, value, child) {
                            return Opacity(
                              opacity: value,
                              child: Transform.translate(
                                offset: Offset(0, 14 * (1 - value)),
                                child: child,
                              ),
                            );
                          },
                          child: _buildEventCard(event),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
