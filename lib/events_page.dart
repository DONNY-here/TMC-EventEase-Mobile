part of 'main.dart';

// TMC EventEase — Events discovery screen.
// In Demo Mode, eventList is preview data. The Laravel events endpoint
// will be integrated here later; local events are never represented as live.
class EventsPage extends StatefulWidget {
  const EventsPage({super.key});

  @override
  State<EventsPage> createState() => _EventsPageState();
}

class _EventsPageState extends State<EventsPage> {
  final TextEditingController _searchController = TextEditingController();
  String _search = '';
  String _scope = 'All Events';
  String _department = 'All Departments';
  String _status = 'All';
  bool _showFilters = false;

  static const _deepBlue = Color(0xFF102A4C);
  static const _blue = Color(0xFF215B99);
  static const _gold = Color(0xFFFFCB4D);
  static const _mint = Color(0xFF168566);

  ColorScheme get _colors => Theme.of(context).colorScheme;

  bool _registered(Event event) =>
      registeredEvents.any((item) => eventKey(item) == eventKey(event));

  DateTime? _eventDate(String raw) {
    final text = raw.trim();
    final iso = DateTime.tryParse(text);
    if (iso != null) return DateTime(iso.year, iso.month, iso.day);
    final match = RegExp(
      r'^(January|February|March|April|May|June|July|August|September|October|November|December)\s+(\d{1,2}),?\s+(\d{4})$',
      caseSensitive: false,
    ).firstMatch(text);
    if (match == null) return null;
    const names = [
      'january',
      'february',
      'march',
      'april',
      'may',
      'june',
      'july',
      'august',
      'september',
      'october',
      'november',
      'december',
    ];
    final month = names.indexOf(match.group(1)!.toLowerCase()) + 1;
    final day = int.parse(match.group(2)!);
    final year = int.parse(match.group(3)!);
    final parsed = DateTime(year, month, day);
    if (parsed.year != year || parsed.month != month || parsed.day != day) {
      return null;
    }
    return parsed;
  }

  bool _isPast(Event event) {
    final date = _eventDate(event.date);
    if (date == null) return false;
    final now = DateTime.now();
    return date.isBefore(DateTime(now.year, now.month, now.day));
  }

  List<String> get _departments {
    final values =
        eventList
            .where((e) => e.scope == 'Department-Specific')
            .map((e) => e.department.trim())
            .where((v) => v.isNotEmpty && v != 'All Departments')
            .toSet()
            .toList()
          ..sort();
    return ['All Departments', ...values];
  }

  List<Event> get _filteredEvents {
    // Never display bundled eventList entries as official Laravel records.
    if (ApiConfig.useRealApi) return [];
    final query = _search.trim().toLowerCase();
    final events = eventList.where((event) {
      final matchesText =
          query.isEmpty ||
          '${event.title} ${event.venue} ${event.description} ${event.department}'
              .toLowerCase()
              .contains(query);
      final matchesScope = _scope == 'All Events' || event.scope == _scope;
      final matchesDepartment =
          _department == 'All Departments' || event.department == _department;
      final isRegistered = _registered(event);
      final past = _isPast(event);
      final matchesStatus = switch (_status) {
        'Registered' => isRegistered,
        'Upcoming' => !past && _eventDate(event.date) != null,
        'Past' => past,
        _ => true,
      };
      return matchesText && matchesScope && matchesDepartment && matchesStatus;
    }).toList();
    events.sort((a, b) {
      final aDate = _eventDate(a.date);
      final bDate = _eventDate(b.date);
      if (aDate == null && bDate == null) return a.title.compareTo(b.title);
      if (aDate == null) return 1;
      if (bDate == null) return -1;
      return aDate.compareTo(bDate);
    });
    return events;
  }

  void _clearFilters() {
    _searchController.clear();
    setState(() {
      _search = '';
      _scope = 'All Events';
      _department = 'All Departments';
      _status = 'All';
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Widget _header() => Container(
    padding: const EdgeInsets.fromLTRB(20, 22, 20, 28),
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [_deepBlue, _blue],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.event_available_rounded, color: _gold, size: 28),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'eventease.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 23,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Campus announcements',
              onPressed: () => Navigator.push(
                context,
                animatedRoute(const AnnouncementsPage()),
              ),
              icon: const Icon(
                Icons.notifications_none_rounded,
                color: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        const Text(
          'Explore events',
          style: TextStyle(
            color: Colors.white,
            fontSize: 29,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Discover activities and opportunities across TMC.',
          style: TextStyle(color: Color(0xFFD9E6F4), fontSize: 13),
        ),
      ],
    ),
  );

  Widget _sourceNotice() {
    final real = ApiConfig.useRealApi;
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: _colors.surface,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: _colors.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(
            real ? Icons.cloud_off_outlined : Icons.science_outlined,
            color: real ? _colors.onSurfaceVariant : _blue,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              real
                  ? 'Live events are not connected yet. No server data is available on this screen.'
                  : 'Demo Mode · These are sample events stored in the app, not verified campus records.',
              style: TextStyle(
                color: _colors.onSurfaceVariant,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dropdown({
    required String label,
    required String value,
    required List<String> options,
    required ValueChanged<String> onChanged,
  }) => DropdownButtonFormField<String>(
    key: ValueKey('$label:$value'),
    initialValue: options.contains(value) ? value : options.first,
    isExpanded: true,
    decoration: InputDecoration(
      labelText: label,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    ),
    items: options
        .map(
          (option) => DropdownMenuItem<String>(
            value: option,
            child: Text(
              option,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        )
        .toList(),
    onChanged: (value) {
      if (value != null) onChanged(value);
    },
  );

  Widget _filters() => Column(
    children: [
      LayoutBuilder(
        builder: (context, constraints) {
          final children = [
            _dropdown(
              label: 'Event scope',
              value: _scope,
              options: const [
                'All Events',
                'School-Wide',
                'Department-Specific',
              ],
              onChanged: (v) => setState(() => _scope = v),
            ),
            _dropdown(
              label: 'Department',
              value: _department,
              options: _departments,
              onChanged: (v) => setState(() => _department = v),
            ),
          ];
          if (constraints.maxWidth < 360) {
            return Column(
              children: [children[0], const SizedBox(height: 10), children[1]],
            );
          }
          return Row(
            children: [
              Expanded(child: children[0]),
              const SizedBox(width: 9),
              Expanded(child: children[1]),
            ],
          );
        },
      ),
      const SizedBox(height: 8),
      Align(
        alignment: Alignment.centerRight,
        child: TextButton.icon(
          onPressed: _clearFilters,
          icon: const Icon(Icons.restart_alt_rounded, size: 17),
          label: const Text('Reset filters'),
        ),
      ),
    ],
  );

  Widget _statusFilters() => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: [
        for (final status in const ['All', 'Upcoming', 'Registered', 'Past'])
          Padding(
            padding: const EdgeInsets.only(right: 7),
            child: ChoiceChip(
              label: Text(status),
              selected: _status == status,
              onSelected: (_) => setState(() => _status = status),
            ),
          ),
      ],
    ),
  );

  IconData _icon(Event event) {
    final title = event.title.toLowerCase();
    if (title.contains('esport') || title.contains('gaming')) {
      return Icons.sports_esports_rounded;
    }
    if (title.contains('code') ||
        title.contains('program') ||
        title.contains('web')) {
      return Icons.code_rounded;
    }
    if (title.contains('sport') || title.contains('athletic')) {
      return Icons.emoji_events_rounded;
    }
    if (title.contains('leadership')) return Icons.groups_rounded;
    return Icons.event_rounded;
  }

  Widget _pill(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(30),
      color: color.withValues(alpha: .12),
    ),
    child: Text(
      label,
      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: color),
    ),
  );

  Widget _detailLine(IconData icon, String value) => Padding(
    padding: const EdgeInsets.only(top: 5),
    child: Row(
      children: [
        Icon(icon, size: 15, color: _colors.onSurfaceVariant),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: _colors.onSurfaceVariant, fontSize: 12),
          ),
        ),
      ],
    ),
  );

  Widget _eventCard(Event event) {
    final registered = _registered(event);
    final past = _isPast(event);
    final dateKnown = _eventDate(event.date) != null;
    final status = registered
        ? 'REGISTERED'
        : past
        ? 'PAST'
        : dateKnown
        ? 'UPCOMING'
        : 'DATE UNCONFIRMED';
    final statusColor = registered
        ? _blue
        : past
        ? _colors.onSurfaceVariant
        : _mint;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: _colors.surface,
        borderRadius: BorderRadius.circular(21),
        child: InkWell(
          borderRadius: BorderRadius.circular(21),
          onTap: () async {
            await Navigator.push(
              context,
              animatedRoute(EventDetailsPage(event: event)),
            );
            if (mounted) setState(() {});
          },
          child: Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(21),
              border: Border.all(color: _colors.outlineVariant),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 70,
                  height: 95,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [_deepBlue, _blue]),
                    borderRadius: BorderRadius.circular(17),
                  ),
                  child: Icon(_icon(event), size: 32, color: _gold),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _colors.onSurface,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 7),
                      _detailLine(Icons.calendar_month_outlined, event.date),
                      _detailLine(Icons.schedule_outlined, event.time),
                      _detailLine(Icons.place_outlined, event.venue),
                      const SizedBox(height: 9),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _pill(status, statusColor),
                          _pill(
                            event.scope == 'School-Wide'
                                ? 'SCHOOL-WIDE'
                                : 'DEPARTMENT',
                            _colors.onSurfaceVariant,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: _colors.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _empty({required bool liveMode}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(26),
    decoration: BoxDecoration(
      color: _colors.surface,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: _colors.outlineVariant),
    ),
    child: Column(
      children: [
        Icon(
          liveMode ? Icons.cloud_off_outlined : Icons.event_busy_outlined,
          size: 42,
          color: _blue,
        ),
        const SizedBox(height: 12),
        Text(
          liveMode ? 'Live events unavailable' : 'No matching events',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 17,
            color: _colors.onSurface,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          liveMode
              ? 'Laravel event loading has not been connected. Switch to Demo Mode to preview the event list.'
              : 'Try a different keyword or reset your filters.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            height: 1.4,
            color: _colors.onSurfaceVariant,
          ),
        ),
        if (!liveMode) ...[
          const SizedBox(height: 9),
          TextButton.icon(
            onPressed: _clearFilters,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Clear filters'),
          ),
        ],
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final events = _filteredEvents;
    final realMode = ApiConfig.useRealApi;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: ListView(
          children: [
            _header(),
            Padding(
              padding: const EdgeInsets.fromLTRB(17, 20, 17, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sourceNotice(),
                  const SizedBox(height: 18),
                  TextField(
                    controller: _searchController,
                    onChanged: (value) => setState(() => _search = value),
                    enabled: !realMode,
                    decoration: InputDecoration(
                      hintText: 'Search titles, venues, or keywords',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: IconButton(
                        tooltip: 'Show or hide filters',
                        onPressed: realMode
                            ? null
                            : () =>
                                  setState(() => _showFilters = !_showFilters),
                        icon: const Icon(Icons.tune_rounded),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                  if (!realMode) ...[
                    const SizedBox(height: 13),
                    _statusFilters(),
                    if (_showFilters) ...[
                      const SizedBox(height: 12),
                      _filters(),
                    ],
                  ],
                  const SizedBox(height: 19),
                  Row(
                    children: [
                      Icon(
                        Icons.event_note_rounded,
                        size: 19,
                        color: _colors.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        realMode ? 'Events' : '${events.length} events found',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: _colors.onSurface,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (events.isEmpty)
                    _empty(liveMode: realMode)
                  else
                    ...events.map(_eventCard),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
