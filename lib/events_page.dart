part of 'main.dart';

// TMC EventEase — Events discovery screen.
// Demo Mode uses local eventList previews. Real API Mode uses only
// authenticated Laravel GET /api/events records (never local demo events).
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
  // Real API event state. Kept separate from the in-memory demo Event model.
  List<Map<String, dynamic>> _liveEvents = [];
  bool _loadingLive = false;
  String? _liveError;
  int _livePage = 1;
  int _liveLastPage = 1;
  int _liveTotal = 0;
  int _liveRequestNumber = 0;
  String _liveAudience = 'All Audiences';

  @override
  void initState() {
    super.initState();
    if (ApiConfig.useRealApi) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadLiveEvents();
      });
    }
  }

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

  // ====================================================
  // LARAVEL LIVE EVENT LOADING (READ-ONLY IN STEP 4)
  // ====================================================

  String _liveString(Object? value) => value?.toString().trim() ?? '';

  int _liveInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(_liveString(value)) ?? 0;
  }

  Future<void> _loadLiveEvents({int page = 1}) async {
    if (!ApiConfig.useRealApi || !mounted) return;
    final requestNumber = ++_liveRequestNumber;
    setState(() {
      _loadingLive = true;
      _liveError = null;
    });

    try {
      final token = await authTokenStorage.readValidToken();
      if (token == null || token.isEmpty) {
        throw StateError('Your session has expired. Please sign in again.');
      }

      final base = Uri.tryParse(ApiConfig.baseUrl.trim());
      if (base == null ||
          base.scheme != 'https' ||
          base.host.isEmpty ||
          base.userInfo.isNotEmpty ||
          (base.path.isNotEmpty && base.path != '/')) {
        throw StateError('The secure Laravel API address is not configured.');
      }

      // Always construct a fresh HTTPS URL rather than following an
      // untrusted next_page_url (Laravel may generate HTTP pagination links).
      final uri = base.replace(
        path: '/api/events',
        queryParameters: {'page': '$page'},
      );

      final response = await http
          .get(
        uri,
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
          'ngrok-skip-browser-warning': 'true',
        },
      )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 401) {
        throw StateError(
          'Your session is no longer valid. Please sign in again.',
        );
      }
      if (response.statusCode == 403) {
        throw StateError(
          'Your account cannot access events. Contact the administrator.',
        );
      }
      if (response.statusCode != 200) {
        throw StateError(
          'Could not load events (HTTP ${response.statusCode}).',
        );
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map || decoded['data'] is! List) {
        throw const FormatException(
          'Unexpected Laravel events response format.',
        );
      }

      final rawEvents = decoded['data'] as List;
      final events = <Map<String, dynamic>>[];
      for (final rawEvent in rawEvents) {
        if (rawEvent is! Map) {
          throw const FormatException('Invalid event record received.');
        }
        events.add(Map<String, dynamic>.from(rawEvent));
      }

      if (!mounted || requestNumber != _liveRequestNumber) return;
      setState(() {
        _liveEvents = events;
        _livePage = _liveInt(decoded['current_page']).clamp(1, 1000000).toInt();
        _liveLastPage = _liveInt(
          decoded['last_page'],
        ).clamp(1, 1000000).toInt();
        _liveTotal = _liveInt(decoded['total']);
        _loadingLive = false;
      });
    } catch (error) {
      if (!mounted || requestNumber != _liveRequestNumber) return;
      setState(() {
        _liveError = error is StateError
            ? error.message.toString()
            : error is FormatException
            ? error.message
            : 'Could not load live events. Check Laravel, ngrok and your connection.';
        _loadingLive = false;
        _liveEvents = [];
      });
    }
  }

  DateTime? _liveDate(Map<String, dynamic> event) =>
      _eventDate(_liveString(event['end_date'] ?? event['event_date']));

  bool _liveIsPast(Map<String, dynamic> event) {
    final date = _liveDate(event);
    if (date == null) return false;
    final now = DateTime.now();
    return date.isBefore(DateTime(now.year, now.month, now.day));
  }

  String _friendlyDate(Object? value) {
    final raw = _liveString(value);
    final date = _eventDate(raw);
    if (date == null) return raw.isEmpty ? 'Date to be confirmed' : raw;
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  String _friendlyTime(Object? value) {
    final raw = _liveString(value);
    final match = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(raw);
    if (match == null) return raw.isEmpty ? 'Time to be confirmed' : raw;
    final hour = int.parse(match.group(1)!);
    final minute = int.parse(match.group(2)!);
    if (hour > 23 || minute > 59) return raw;
    final twelve = hour % 12 == 0 ? 12 : hour % 12;
    return '$twelve:${minute.toString().padLeft(2, '0')} ${hour >= 12 ? 'PM' : 'AM'}';
  }

  bool _liveTargeted(Map<String, dynamic> event) {
    for (final field in [
      'target_course',
      'target_department',
      'target_year',
      'target_block',
    ]) {
      if (_liveString(event[field]).isNotEmpty) return true;
    }
    final role = _liveString(event['target_role']);
    return role.isNotEmpty && role.toLowerCase() != 'all';
  }

  List<String> get _liveDepartments {
    final values =
    _liveEvents
        .map((event) => _liveString(event['target_department']))
        .where((department) => department.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return ['All Departments', ...values];
  }

  List<Map<String, dynamic>> get _filteredLiveEvents {
    final query = _search.trim().toLowerCase();
    return _liveEvents.where((event) {
      final text = [
        event['title'],
        event['description'],
        event['venue'],
        event['organizer'],
        event['reference'],
        event['target_department'],
      ].map(_liveString).join(' ').toLowerCase();
      if (query.isNotEmpty && !text.contains(query)) return false;
      if (_status == 'Upcoming' &&
          (_liveIsPast(event) || _liveDate(event) == null)) {
        return false;
      }
      if (_status == 'Past' && !_liveIsPast(event)) return false;
      if (_liveAudience == 'General' && _liveTargeted(event)) return false;
      if (_liveAudience == 'Targeted' && !_liveTargeted(event)) return false;
      if (_department != 'All Departments' &&
          _liveString(event['target_department']) != _department) {
        return false;
      }
      return true;
    }).toList();
  }

  void _resetLiveFilters() {
    _searchController.clear();
    setState(() {
      _search = '';
      _status = 'All';
      _department = 'All Departments';
      _liveAudience = 'All Audiences';
    });
  }

  Widget _liveFilters() => Column(
    children: [
      const SizedBox(height: 12),
      _dropdown(
        label: 'Audience',
        value: _liveAudience,
        options: const ['All Audiences', 'General', 'Targeted'],
        onChanged: (value) => setState(() => _liveAudience = value),
      ),
      const SizedBox(height: 10),
      _dropdown(
        label: 'Target department',
        value: _department,
        options: _liveDepartments,
        onChanged: (value) => setState(() => _department = value),
      ),
      Align(
        alignment: Alignment.centerRight,
        child: TextButton.icon(
          onPressed: _resetLiveFilters,
          icon: const Icon(Icons.restart_alt_rounded),
          label: const Text('Reset filters'),
        ),
      ),
    ],
  );

  // Display live Laravel events as a normal full-screen page, rather than
  // the temporary bottom sheet used in the initial API connection test.
  void _showLiveDetails(Map<String, dynamic> event) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => _liveEventDetailsPage(event)),
    );
  }

  Widget _liveEventDetailsPage(Map<String, dynamic> event) {
    final colors = Theme.of(context).colorScheme;
    final title = _liveString(event['title']);
    final date = _friendlyDate(event['event_date']);
    final time = _friendlyTime(event['start_time']);
    final venue = _liveString(event['venue']);
    final organizer = _liveString(event['organizer']);
    final description = _liveString(event['description']);
    final reference = _liveString(event['reference']);
    final status = _liveString(event['status']);
    final id = _liveString(event['id']);
    final participants = _liveInt(event['participants']);
    final capacity = _liveInt(event['capacity']);
    final past = _liveIsPast(event);
    final targets = <String, String>{
      'Role': _liveString(event['target_role']),
      'Department': _liveString(event['target_department']),
      'Course': _liveString(event['target_course']),
      'Year level': _liveString(event['target_year']),
      'Block': _liveString(event['target_block']),
    }..removeWhere((_, value) => value.isEmpty);

    Widget detailRow(IconData icon, String label, String value) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _blue.withValues(alpha: .10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 20, color: _blue),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    value,
                    style: TextStyle(
                      color: colors.onSurface,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    Widget sectionCard({required Widget child}) => Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: child,
    );

    Widget sectionTitle(String text) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w900,
          color: colors.onSurface,
        ),
      ),
    );

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Event Details'),
        backgroundColor: _deepBlue,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 30),
          children: [
            Container(
              height: 180,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: const LinearGradient(
                  colors: [_deepBlue, _blue],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: -50,
                    right: -28,
                    child: Container(
                      width: 175,
                      height: 175,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: .07),
                      ),
                    ),
                  ),
                  const Center(
                    child: Icon(
                      Icons.event_available_rounded,
                      size: 80,
                      color: _gold,
                    ),
                  ),
                  Positioned(
                    left: 16,
                    bottom: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .14),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Text(
                        'LIVE LARAVEL EVENT',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            Text(
              title,
              style: TextStyle(
                color: colors.onSurface,
                fontSize: 25,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 9),
            Text(
              'Reference: $reference  •  Event ID: $id',
              style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _pill(status.isEmpty ? 'LIVE' : status.toUpperCase(), _blue),
                _pill(
                  past ? 'PAST EVENT' : 'SCHEDULED',
                  past ? colors.onSurfaceVariant : _mint,
                ),
                if (_liveTargeted(event))
                  _pill('TARGETED', colors.onSurfaceVariant),
              ],
            ),
            const SizedBox(height: 24),
            sectionTitle('Event information'),
            sectionCard(
              child: Column(
                children: [
                  detailRow(Icons.calendar_month_rounded, 'Date', date),
                  Divider(height: 1, color: colors.outlineVariant),
                  detailRow(Icons.schedule_rounded, 'Time', time),
                  Divider(height: 1, color: colors.outlineVariant),
                  detailRow(
                    Icons.place_outlined,
                    'Venue',
                    venue.isEmpty ? 'Venue to be confirmed' : venue,
                  ),
                  if (organizer.isNotEmpty) ...[
                    Divider(height: 1, color: colors.outlineVariant),
                    detailRow(Icons.groups_outlined, 'Organizer', organizer),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),
            sectionTitle('Participants'),
            sectionCard(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 13),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      capacity > 0
                          ? '$participants of $capacity registered'
                          : '$participants registered',
                      style: TextStyle(
                        color: colors.onSurface,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    if (capacity > 0) ...[
                      const SizedBox(height: 11),
                      LinearProgressIndicator(
                        value: (participants / capacity)
                            .clamp(0.0, 1.0)
                            .toDouble(),
                        minHeight: 7,
                        borderRadius: BorderRadius.circular(7),
                        backgroundColor: colors.outlineVariant,
                        color: _blue,
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      'Participant counts provided by Laravel.',
                      style: TextStyle(
                        fontSize: 11,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            sectionTitle('About this event'),
            sectionCard(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 13),
                child: Text(
                  description.isEmpty
                      ? 'No description has been provided.'
                      : description,
                  style: TextStyle(
                    color: colors.onSurface,
                    fontSize: 14,
                    height: 1.55,
                  ),
                ),
              ),
            ),
            if (targets.isNotEmpty) ...[
              const SizedBox(height: 24),
              sectionTitle('Who can join'),
              sectionCard(
                child: Column(
                  children: [
                    for (final entry in targets.entries) ...[
                      detailRow(
                        Icons.fact_check_outlined,
                        entry.key,
                        entry.value,
                      ),
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: 22),
            _LiveLaravelRegistrationActions(
              event: event,
              onSuccessfulRegistration: () {
                if (mounted) _loadLiveEvents(page: _livePage);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _liveCard(Map<String, dynamic> event) {
    final past = _liveIsPast(event);
    final status = _liveString(event['status']);
    final date = _friendlyDate(event['event_date']);
    final time = _friendlyTime(event['start_time']);
    final venue = _liveString(event['venue']);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: _colors.surface,
        borderRadius: BorderRadius.circular(21),
        child: InkWell(
          borderRadius: BorderRadius.circular(21),
          onTap: () => _showLiveDetails(event),
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
                  height: 105,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [_deepBlue, _blue]),
                    borderRadius: BorderRadius.circular(17),
                  ),
                  child: const Icon(
                    Icons.event_rounded,
                    size: 33,
                    color: _gold,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _liveString(event['title']),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _colors.onSurface,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      _detailLine(Icons.calendar_month_outlined, date),
                      _detailLine(Icons.schedule_outlined, time),
                      _detailLine(
                        Icons.place_outlined,
                        venue.isEmpty ? 'Venue to be confirmed' : venue,
                      ),
                      const SizedBox(height: 9),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _pill(
                            past ? 'PAST' : 'SCHEDULED',
                            past ? _colors.onSurfaceVariant : _mint,
                          ),
                          if (status.isNotEmpty)
                            _pill(status.toUpperCase(), _blue),
                          if (_liveTargeted(event))
                            _pill('TARGETED', _colors.onSurfaceVariant),
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

  Widget _buildLiveEvents() {
    final events = _filteredLiveEvents;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => _loadLiveEvents(page: _livePage),
          child: ListView(
            children: [
              _header(),
              Padding(
                padding: const EdgeInsets.fromLTRB(17, 20, 17, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(13),
                      decoration: BoxDecoration(
                        color: _colors.surface,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: _colors.outlineVariant),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.cloud_done_outlined, color: _mint),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Live Laravel events · Page $_livePage of $_liveLastPage · $_liveTotal total records',
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.4,
                                color: _colors.onSurfaceVariant,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Refresh live events',
                            onPressed: _loadingLive
                                ? null
                                : () => _loadLiveEvents(page: _livePage),
                            icon: const Icon(Icons.refresh_rounded),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 17),
                    TextField(
                      controller: _searchController,
                      enabled: !_loadingLive,
                      onChanged: (value) => setState(() => _search = value),
                      decoration: InputDecoration(
                        hintText: 'Search events on this page',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: IconButton(
                          tooltip: 'Audience filters',
                          onPressed: () =>
                              setState(() => _showFilters = !_showFilters),
                          icon: const Icon(Icons.tune_rounded),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 13),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final status in const [
                            'All',
                            'Upcoming',
                            'Past',
                          ])
                            Padding(
                              padding: const EdgeInsets.only(right: 7),
                              child: ChoiceChip(
                                label: Text(status),
                                selected: _status == status,
                                onSelected: (_) =>
                                    setState(() => _status = status),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (_showFilters) _liveFilters(),
                    const SizedBox(height: 19),
                    if (_loadingLive) ...[
                      const LinearProgressIndicator(),
                      const SizedBox(height: 16),
                      const Center(
                        child: Text('Loading events from Laravel...'),
                      ),
                    ] else if (_liveError != null) ...[
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: _colors.surface,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: _colors.outlineVariant),
                        ),
                        child: Column(
                          children: [
                            const Icon(Icons.cloud_off_outlined, size: 36),
                            const SizedBox(height: 8),
                            Text(_liveError!, textAlign: TextAlign.center),
                            const SizedBox(height: 8),
                            TextButton.icon(
                              onPressed: () => _loadLiveEvents(page: _livePage),
                              icon: const Icon(Icons.refresh_rounded),
                              label: const Text('Try again'),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      Text(
                        '${events.length} shown on this page',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: _colors.onSurface,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (events.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(26),
                          decoration: BoxDecoration(
                            color: _colors.surface,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Text(
                            'No events match these filters on this page. '
                                'Try All or refresh the list.',
                            textAlign: TextAlign.center,
                          ),
                        )
                      else
                        ...events.map(_liveCard),
                      if (_liveLastPage > 1) ...[
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            OutlinedButton.icon(
                              onPressed: _livePage > 1
                                  ? () => _loadLiveEvents(page: _livePage - 1)
                                  : null,
                              icon: const Icon(Icons.chevron_left_rounded),
                              label: const Text('Previous'),
                            ),
                            Text('$_livePage / $_liveLastPage'),
                            OutlinedButton.icon(
                              onPressed: _livePage < _liveLastPage
                                  ? () => _loadLiveEvents(page: _livePage + 1)
                                  : null,
                              icon: const Icon(Icons.chevron_right_rounded),
                              label: const Text('Next'),
                            ),
                          ],
                        ),
                      ],
                    ],
                    const SizedBox(height: 10),
                    Text(
                      'Live filters and search apply to the current page. '
                          'Use a future approved event to test student self-registration.',
                      style: TextStyle(
                        fontSize: 11,
                        color: _colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (ApiConfig.useRealApi) return _buildLiveEvents();
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

// =============================================================
// REAL LARAVEL STUDENT EVENT REGISTRATION (STEP 5)
// This is intentionally NOT the demo registeredEvents / qrTokens flow.
// Laravel must approve and persist the registration. The exact
// selfRegister() request schema should be verified with the web partner.
// =============================================================
class _LiveLaravelRegistrationActions extends StatefulWidget {
  final Map<String, dynamic> event;
  final VoidCallback onSuccessfulRegistration;

  const _LiveLaravelRegistrationActions({
    required this.event,
    required this.onSuccessfulRegistration,
  });

  @override
  State<_LiveLaravelRegistrationActions> createState() =>
      _LiveLaravelRegistrationActionsState();
}

class _LiveLaravelRegistrationActionsState
    extends State<_LiveLaravelRegistrationActions> {
  static const navy = Color(0xFF102A4C);
  static const gold = Color(0xFFFFCB4D);

  bool _isSubmitting = false;
  bool _serverAccepted = false;
  bool _alreadyRegistered = false;
  bool _checkingRegistration = true;
  bool _registrationCheckFailed = false;
  String? _feedback;
  bool _feedbackIsError = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _checkExistingRegistration();
    });
  }

  // Check the real student-owned Laravel registrations before offering
  // registration again. This avoids a duplicate request on each visit.
  Future<void> _checkExistingRegistration() async {
    if (!mounted) return;
    setState(() {
      _checkingRegistration = true;
      _registrationCheckFailed = false;
      _feedback = null;
      _feedbackIsError = false;
    });
    try {
      final token = await authTokenStorage.readValidToken();
      if (token == null || token.trim().isEmpty) {
        throw StateError('Your session expired. Sign in again to check registration.');
      }
      final base = Uri.tryParse(ApiConfig.baseUrl.trim());
      if (base == null ||
          base.scheme != 'https' ||
          base.host.isEmpty ||
          base.userInfo.isNotEmpty ||
          (base.path.isNotEmpty && base.path != '/')) {
        throw StateError('The secure Laravel API URL is not configured.');
      }
      var page = 1;
      var lastPage = 1;
      while (page <= lastPage && page <= 100) {
        final uri = base.replace(
          path: '/api/registrations/my',
          queryParameters: {'page': '$page'},
          fragment: null,
        );
        final response = await http.get(uri, headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
          'ngrok-skip-browser-warning': 'true',
        }).timeout(const Duration(seconds: 20));
        if (response.statusCode != 200) {
          throw StateError('Could not verify existing registrations '
              '(HTTP ${response.statusCode}).');
        }
        final decoded = jsonDecode(response.body);
        if (decoded is! Map || decoded['data'] is! List) {
          throw const FormatException('Unexpected registrations response from Laravel.');
        }
        for (final item in decoded['data'] as List) {
          if (item is! Map) continue;
          final eventId = item['event_id']?.toString() ?? '';
          final eventRef = item['event_reference']?.toString() ?? '';
          if ((eventId.isNotEmpty && eventId == _eventId?.toString()) ||
              (eventRef.isNotEmpty && eventRef == _eventReference)) {
            final status = (item['registration_status'] ?? item['status'] ?? '')
                .toString().toLowerCase().trim();
            if (status == 'cancelled' || status == 'canceled') continue;
            if (mounted) {
              setState(() => _alreadyRegistered = true);
            }
            return;
          }
        }
        lastPage = int.tryParse('${decoded['last_page'] ?? 1}') ?? 1;
        if (lastPage > 100) {
          throw StateError('Too many registration pages to verify.');
        }
        page++;
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _registrationCheckFailed = true;
        _feedbackIsError = true;
        _feedback = error is StateError
            ? error.message.toString()
            : error is FormatException
            ? error.message
            : 'Could not verify your registration. Check the connection and retry.';
      });
    } finally {
      if (mounted) {
        setState(() => _checkingRegistration = false);
      }
    }
  }

  String _field(String name) => (widget.event[name] ?? '').toString().trim();

  int? get _eventId => int.tryParse(_field('id'));

  String get _eventReference => _field('reference');

  DateTime? _date(String key) {
    final raw = _field(key);
    if (raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  String? get _unavailableReason {
    final eventDate = _date('end_date') ?? _date('event_date');
    if (eventDate == null) return 'Event date is not available.';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final eventDay = DateTime(eventDate.year, eventDate.month, eventDate.day);
    if (eventDay.isBefore(today)) return 'This event has already ended.';

    if (_field('status').toLowerCase() != 'approved') {
      return 'This event is not approved for registration.';
    }
    if (widget.event['registration_open'] != true) {
      return 'Registration is closed by the organizer.';
    }

    final deadlineRaw = _field('registration_deadline');
    if (deadlineRaw.isNotEmpty) {
      final deadline = _date('registration_deadline');
      if (deadline != null) {
        // Date-only values mean the whole listed deadline date.
        final dateOnly = RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(deadlineRaw);
        if (dateOnly) {
          final lastDay = DateTime(deadline.year, deadline.month, deadline.day);
          if (lastDay.isBefore(today)) {
            return 'The registration deadline has passed.';
          }
        } else if (deadline.isBefore(now)) {
          return 'The registration deadline has passed.';
        }
      }
    }

    final capacity = int.tryParse(_field('capacity'));
    final participants = int.tryParse(_field('participants'));
    if (capacity != null &&
        capacity > 0 &&
        participants != null &&
        participants >= capacity) {
      return 'This event has reached its participant capacity.';
    }
    if (_eventId == null) return 'Missing Laravel event ID.';
    if (_eventReference.isEmpty) return 'Missing Laravel event reference.';
    return null;
  }

  String _errorFromResponse(http.Response response) {
    String message =
        'Laravel rejected this registration (HTTP '
        '${response.statusCode}).';
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map) {
        final fromServer = decoded['message'];
        if (fromServer is String && fromServer.trim().isNotEmpty) {
          message = fromServer.trim();
        }
        final errors = decoded['errors'];
        if (errors is Map && errors.isNotEmpty) {
          final first = errors.values.first;
          if (first is List && first.isNotEmpty) {
            message = first.first.toString();
          } else if (first is String) {
            message = first;
          }
        }
      }
    } catch (_) {
      // Keep the HTTP error; do not expose raw HTML or secrets.
    }
    return message;
  }

  Future<void> _submitRegistration() async {
    if (_isSubmitting ||
        _serverAccepted ||
        _alreadyRegistered ||
        _checkingRegistration ||
        _registrationCheckFailed ||
        _unavailableReason != null) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirm registration'),
        content: Text(
          'Submit your student account to Laravel for '
              '"${_field('title')}"? The server will check eligibility, '
              'capacity, and duplicate registrations.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _isSubmitting = true;
      _feedback = null;
      _feedbackIsError = false;
    });

    try {
      final token = await authTokenStorage.readValidToken();
      if (token == null || token.isEmpty) {
        throw StateError('Your session expired. Log in again.');
      }
      final base = Uri.tryParse(ApiConfig.baseUrl.trim());
      if (base == null ||
          base.scheme != 'https' ||
          base.host.isEmpty ||
          base.userInfo.isNotEmpty ||
          (base.path.isNotEmpty && base.path != '/')) {
        throw StateError('The secure Laravel API address is not configured.');
      }

      final uri = base.replace(
        path: '/api/registrations/self',
        query: null,
        fragment: null,
      );
      // Laravel validation returned "The event reference field is required."
      // Submit the actual reference supplied by GET /api/events (EVE-xxxx),
      // not the numeric database ID. Backend determines eligibility and status.
      final response = await http
          .post(
        uri,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
          'ngrok-skip-browser-warning': 'true',
        },
        body: jsonEncode({'event_reference': _eventReference}),
      )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Treat only a server success as successful registration.
        if (!mounted) return;
        setState(() {
          _serverAccepted = true;
          _feedbackIsError = false;
          _feedback =
          'Laravel accepted your registration. '
              'The registration and any QR credential are managed by the server.';
        });
        widget.onSuccessfulRegistration();
      } else {
        final message = _errorFromResponse(response);
        if (!mounted) return;
        final duplicate =
            message.toLowerCase().contains('already registered') ||
                message.toLowerCase().contains('already enrolled');
        setState(() {
          if (duplicate) _alreadyRegistered = true;
          _feedback = duplicate
              ? 'Laravel confirms you are already registered for this event.'
              : message;
          _feedbackIsError = !duplicate;
        });
      }
    } on StateError catch (error) {
      if (!mounted) return;
      setState(() {
        _feedback = error.message.toString();
        _feedbackIsError = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _feedback =
        'Could not submit registration. Check your Internet, '
            'Laravel server, and ngrok tunnel, then try again.';
        _feedbackIsError = true;
      });
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final reason = _unavailableReason;
    final canRegister =
        !_serverAccepted &&
            !_alreadyRegistered &&
            !_checkingRegistration &&
            !_registrationCheckFailed &&
            reason == null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Informational eligibility requirements from the Laravel event.
        // These never replace server-side registration authorization.
        Builder(
          builder: (context) {
            final requirements =
            <String, String>{
              'Course': _field('target_course'),
              'Year level': _field('target_year'),
              'Block': _field('target_block'),
              'Department': _field('target_department'),
              'Role': _field('target_role'),
            }..removeWhere(
                  (key, value) => value.isEmpty || value.toLowerCase() == 'all',
            );
            if (requirements.isEmpty) {
              return const SizedBox.shrink();
            }
            final scheme = Theme.of(context).colorScheme;
            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: scheme.outlineVariant),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.fact_check_outlined, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Who can register?',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  for (final entry in requirements.entries)
                    Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Text('${entry.key}: ${entry.value}'),
                    ),
                  const SizedBox(height: 10),
                  Text(
                    'Your eligibility is checked by Laravel when you register. '
                        'Course, year and block values here are event requirements, '
                        'not confirmation that your account qualifies.',
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        Text(
          'Event registration',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: colors.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.surface,
            border: Border.all(color: colors.outlineVariant),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_serverAccepted || _alreadyRegistered)
                const Text(
                  'Already registered in Laravel',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF168566),
                  ),
                ),
              if (reason != null && !_serverAccepted && !_alreadyRegistered)
                Text(
                  reason,
                  style: TextStyle(color: colors.onSurfaceVariant, height: 1.4),
                ),
              if (reason != null || _serverAccepted || _alreadyRegistered)
                const SizedBox(height: 12),
              SizedBox(
                height: 52,
                child: FilledButton.icon(
                  onPressed: canRegister && !_isSubmitting
                      ? _submitRegistration
                      : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: gold,
                    foregroundColor: navy,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  icon: (_isSubmitting || _checkingRegistration)
                      ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : Icon(
                    (_serverAccepted || _alreadyRegistered)
                        ? Icons.check_circle_rounded
                        : reason != null
                        ? Icons.event_busy_rounded
                        : Icons.how_to_reg_rounded,
                  ),
                  label: Text(
                    _isSubmitting
                        ? 'Submitting...'
                        : _checkingRegistration
                        ? 'Checking registration...'
                        : (_serverAccepted || _alreadyRegistered)
                        ? 'Already registered'
                        : _registrationCheckFailed
                        ? 'Verification required'
                        : reason != null
                        ? 'Registration unavailable'
                        : 'Register for this event',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              if (_alreadyRegistered || _serverAccepted) ...[
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => Scaffold(
                        appBar: AppBar(title: const Text('My Passes')),
                        body: const MyEventsPage(),
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.qr_code_2_rounded),
                  label: const Text('Open My Passes'),
                ),
              ],
              if (_registrationCheckFailed) ...[
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _checkingRegistration ? null : _checkExistingRegistration,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Retry registration check'),
                ),
              ],
              if (_feedback != null) ...[
                const SizedBox(height: 12),
                Text(
                  _feedback!,
                  style: TextStyle(
                    color: _feedbackIsError
                        ? colors.error
                        : const Color(0xFF168566),
                    height: 1.45,
                    fontSize: 13,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Text(
                'Registration decisions and attendance QR passes are '
                    'controlled by Laravel. This page does not issue demo '
                    'passes or mark you as attended.',
                style: TextStyle(
                  color: colors.onSurfaceVariant,
                  height: 1.4,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
