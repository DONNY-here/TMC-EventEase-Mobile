
part of 'main.dart';

// ======================================================
// TMC EVENTEASE - ENHANCED EVENTS PAGE
// LIGHT AND DARK MODE SUPPORTED
// ======================================================

class EventsPage extends StatefulWidget {
  const EventsPage({super.key});

  @override
  State<EventsPage> createState() => _EventsPageState();
}

class _EventsPageState extends State<EventsPage> {
  final TextEditingController searchController =
  TextEditingController();

  String searchText = '';
  String selectedScope = 'All Events';
  String selectedDepartment = 'All Departments';

  bool showFilters = true;

  static const Color darkBlue = Color(0xFF0D3062);
  static const Color mediumBlue = Color(0xFF194E91);

  // ====================================================
  // LIGHT / DARK MODE COLORS
  // ====================================================

  bool get _isDark =>
      Theme.of(context).brightness == Brightness.dark;

  Color get _pageBackground =>
      Theme.of(context).scaffoldBackgroundColor;

  Color get _surface =>
      Theme.of(context).colorScheme.surface;

  Color get _primaryText =>
      Theme.of(context).colorScheme.onSurface;

  Color get _secondaryText =>
      Theme.of(context).colorScheme.onSurfaceVariant;

  Color get _outline =>
      Theme.of(context).colorScheme.outlineVariant;

  Color get _accent =>
      _isDark ? yellow : navy;

  Color get _softBlue =>
      _isDark
          ? const Color(0xFF253A57)
          : const Color(0xFFEAF2FB);

  Color get _softYellow =>
      _isDark
          ? const Color(0xFF35425A)
          : const Color(0xFFFFF3CF);

  // ====================================================
  // FILTER OPTIONS
  // ====================================================

  final List<String> scopeOptions = const [
    'All Events',
    'School-Wide',
    'Department-Specific',
  ];

  List<String> get departmentOptions {
    final departments = eventList
        .where(
          (event) =>
      event.scope.toLowerCase() ==
          'department-specific',
    )
        .map((event) => event.department.trim())
        .where(
          (department) =>
      department.isNotEmpty &&
          department != 'All Departments',
    )
        .toSet()
        .toList()
      ..sort();

    return ['All Departments', ...departments];
  }

  // ====================================================
  // SEARCH AND FILTER EVENTS
  // ====================================================

  List<Event> get filteredEvents {
    return eventList.where((event) {
      final matchesSearch =
      event.title.toLowerCase().contains(
        searchText.toLowerCase(),
      );

      final matchesScope =
          selectedScope == 'All Events' ||
              event.scope == selectedScope;

      final matchesDepartment =
          selectedDepartment == 'All Departments' ||
              event.department == selectedDepartment;

      return matchesSearch &&
          matchesScope &&
          matchesDepartment;
    }).toList();
  }

  void clearFilters() {
    searchController.clear();

    setState(() {
      searchText = '';
      selectedScope = 'All Events';
      selectedDepartment = 'All Departments';
    });
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  // ====================================================
  // PAGE HEADER
  // ====================================================

  Widget buildHeader() {
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            darkBlue,
            mediumBlue,
            darkBlue,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(28),
        ),
      ),
      child: Stack(
        children: [
          // Decorative blue circle
          Positioned(
            right: -80,
            top: -75,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(
                  alpha: 0.035,
                ),
              ),
            ),
          ),

          // Decorative yellow accent
          Positioned(
            right: -55,
            bottom: -70,
            child: Container(
              width: 150,
              height: 150,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: yellow,
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(
              22, 20, 22, 30,
            ),
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(
                          alpha: 0.12,
                        ),
                        borderRadius:
                        BorderRadius.circular(13),
                      ),
                      child: const Icon(
                        Icons.event_note_rounded,
                        color: yellow,
                        size: 28,
                      ),
                    ),

                    const SizedBox(width: 11),

                    Expanded(
                      child: RichText(
                        text: const TextSpan(
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                          children: [
                            TextSpan(
                              text: 'TMC ',
                              style: TextStyle(
                                color: Colors.white,
                              ),
                            ),
                            TextSpan(
                              text: 'EventEase',
                              style: TextStyle(
                                color: yellow,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    IconButton(
                      tooltip: 'Announcements',
                      onPressed: () {
                        Navigator.push(
                          context,
                          animatedRoute(
                            const AnnouncementsPage(),
                          ),
                        );
                      },
                      icon: const Icon(
                        Icons.notifications_outlined,
                        color: Colors.white,
                        size: 27,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 26),

                const Text(
                  'Events',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ====================================================
  // SEARCH FIELD
  // ====================================================

  Widget buildSearchField() {
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: _outline),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: _isDark ? 0.20 : 0.045,
            ),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: TextField(
        controller: searchController,
        style: TextStyle(
          color: _primaryText,
          fontSize: 14,
        ),
        cursorColor: _accent,
        onChanged: (value) {
          setState(() {
            searchText = value;
          });
        },
        decoration: InputDecoration(
          hintText: 'Search event by title...',
          hintStyle: TextStyle(
            color: _secondaryText,
            fontSize: 14,
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: _secondaryText,
            size: 25,
          ),
          suffixIcon: IconButton(
            tooltip: 'Show or hide filters',
            onPressed: () {
              setState(() {
                showFilters = !showFilters;
              });
            },
            icon: Icon(
              Icons.tune_rounded,
              color: showFilters
                  ? _accent
                  : _secondaryText,
            ),
          ),
          filled: true,
          fillColor: _surface,
          contentPadding:
          const EdgeInsets.symmetric(
            horizontal: 15,
            vertical: 18,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(19),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(19),
            borderSide: BorderSide(
              color: _outline,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(19),
            borderSide: BorderSide(
              color: _accent,
              width: 1.5,
            ),
          ),
        ),
      ),
    );
  }

  // ====================================================
  // REUSABLE DROPDOWN DESIGN
  // ====================================================

  InputDecoration _dropdownDecoration({
    required String label,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
        color: _secondaryText,
      ),
      prefixIcon: Icon(
        icon,
        color: _secondaryText,
        size: 20,
      ),
      filled: true,
      fillColor: _surface,
      contentPadding:
      const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 15,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(17),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(17),
        borderSide: BorderSide(
          color: _outline,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(17),
        borderSide: BorderSide(
          color: _accent,
          width: 1.5,
        ),
      ),
    );
  }

  // ====================================================
  // EVENT TYPE FILTER
  // ====================================================

  Widget buildScopeFilter() {
    return DropdownButtonFormField<String>(
      key: ValueKey('scope-$selectedScope'),
      initialValue: selectedScope,
      isExpanded: true,
      dropdownColor: _surface,
      style: TextStyle(
        color: _primaryText,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      decoration: _dropdownDecoration(
        label: 'Event Type',
        icon: Icons.category_outlined,
      ),
      items: scopeOptions.map((scope) {
        return DropdownMenuItem<String>(
          value: scope,
          child: Text(
            scope,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            style: TextStyle(
              fontSize: 12,
              color: _primaryText,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      }).toList(),
      onChanged: (value) {
        if (value == null) return;

        setState(() {
          selectedScope = value;
        });
      },
    );
  }

  // ====================================================
  // DEPARTMENT FILTER
  // ====================================================

  Widget buildDepartmentFilter() {
    return DropdownButtonFormField<String>(
      key: ValueKey(
        'department-$selectedDepartment',
      ),
      initialValue: selectedDepartment,
      isExpanded: true,
      dropdownColor: _surface,
      style: TextStyle(
        color: _primaryText,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      decoration: _dropdownDecoration(
        label: 'Department',
        icon: Icons.account_balance_outlined,
      ),
      items: departmentOptions.map((department) {
        return DropdownMenuItem<String>(
          value: department,
          child: Text(
            department,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              color: _primaryText,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      }).toList(),
      onChanged: (value) {
        if (value == null) return;

        setState(() {
          selectedDepartment = value;
        });
      },
    );
  }

  // ====================================================
  // FILTER SECTION
  // ====================================================

  Widget buildFilters() {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 350) {
          return Row(
            children: [
              Expanded(
                child: buildScopeFilter(),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: buildDepartmentFilter(),
              ),
            ],
          );
        }

        return Column(
          children: [
            buildScopeFilter(),
            const SizedBox(height: 11),
            buildDepartmentFilter(),
          ],
        );
      },
    );
  }

  // ====================================================
  // EVENT ICON
  // ====================================================

  IconData eventIcon(Event event) {
    final title = event.title.toLowerCase();

    if (title.contains('esport') ||
        title.contains('gaming')) {
      return Icons.sports_esports_rounded;
    }

    if (title.contains('web') ||
        title.contains('programming') ||
        title.contains('coding')) {
      return Icons.code_rounded;
    }

    if (title.contains('leadership')) {
      return Icons.groups_rounded;
    }

    if (title.contains('sports')) {
      return Icons.emoji_events_rounded;
    }

    return Icons.event_note_rounded;
  }

  // ====================================================
  // EVENT INFORMATION ROW
  // ====================================================

  Widget eventInfo({
    required IconData icon,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 5),
      child: Row(
        children: [
          Icon(
            icon,
            size: 15,
            color: _secondaryText,
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: _secondaryText,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ====================================================
  // ENHANCED EVENT CARD
  // ====================================================

  Widget buildEventCard(Event event) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(23),
        border: Border.all(color: _outline),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: _isDark ? 0.20 : 0.06,
            ),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(23),
        child: InkWell(
          borderRadius: BorderRadius.circular(23),
          onTap: () {
            Navigator.push(
              context,
              animatedRoute(
                EventDetailsPage(event: event),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(13),
            child: Row(
              children: [
                // EVENT ICON TILE
                Container(
                  width: 82,
                  height: 105,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        darkBlue,
                        mediumBlue,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius:
                    BorderRadius.circular(19),
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        left: -25,
                        bottom: -38,
                        child: Container(
                          width: 85,
                          height: 85,
                          decoration:
                          const BoxDecoration(
                            shape: BoxShape.circle,
                            color: yellow,
                          ),
                        ),
                      ),
                      Center(
                        child: Icon(
                          eventIcon(event),
                          color: yellow,
                          size: 37,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 13),

                // EVENT DETAILS
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _primaryText,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),

                      const SizedBox(height: 8),

                      eventInfo(
                        icon:
                        Icons.calendar_today_outlined,
                        value: event.date,
                      ),

                      eventInfo(
                        icon: Icons.access_time_rounded,
                        value: event.time,
                      ),

                      eventInfo(
                        icon:
                        Icons.location_on_outlined,
                        value: event.venue,
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 6),

                // ARROW INDICATOR
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _softYellow,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    color: _accent,
                    size: 26,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ====================================================
  // EMPTY RESULTS
  // ====================================================

  Widget buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 38,
      ),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _outline),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _softBlue,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.event_busy_outlined,
              color: _accent,
              size: 43,
            ),
          ),

          const SizedBox(height: 15),

          Text(
            'No Events Found',
            style: TextStyle(
              color: _primaryText,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            'Try adjusting your search or '
                'selecting different filters.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _secondaryText,
              fontSize: 13,
              height: 1.5,
            ),
          ),

          const SizedBox(height: 13),

          TextButton.icon(
            onPressed: clearFilters,
            style: TextButton.styleFrom(
              foregroundColor: _accent,
            ),
            icon: const Icon(
              Icons.refresh_rounded,
            ),
            label: const Text(
              'Clear Filters',
            ),
          ),
        ],
      ),
    );
  }

  // ====================================================
  // MAIN EVENTS PAGE UI
  // ====================================================

  @override
  Widget build(BuildContext context) {
    final events = filteredEvents;

    return Scaffold(
      backgroundColor: _pageBackground,
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // BLUE HEADER
            buildHeader(),

            // DISCOVER EVENTS
            Padding(
              padding: const EdgeInsets.fromLTRB(
                19, 25, 19, 16,
              ),
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  Text(
                    'Discover Events',
                    style: TextStyle(
                      color: _primaryText,
                      fontSize: 25,
                      fontWeight: FontWeight.w900,
                    ),
                  ),

                  const SizedBox(height: 5),

                  Text(
                    'Find activities, workshops, '
                        'and campus events.',
                    style: TextStyle(
                      fontSize: 13,
                      color: _secondaryText,
                    ),
                  ),

                  const SizedBox(height: 22),

                  // SEARCH FIELD
                  buildSearchField(),

                  // EVENT TYPE / DEPARTMENT FILTERS
                  if (showFilters) ...[
                    const SizedBox(height: 15),
                    buildFilters(),
                  ],
                ],
              ),
            ),

            // EVENT RESULTS
            Container(
              padding: const EdgeInsets.fromLTRB(
                19, 21, 19, 28,
              ),
              decoration: BoxDecoration(
                color: _pageBackground,
                border: Border(
                  top: BorderSide(
                    color: _outline,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(
                      bottom: 15,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.event_available_rounded,
                          color: _accent,
                          size: 20,
                        ),

                        const SizedBox(width: 8),

                        Text(
                          '${events.length} '
                              '${events.length == 1 ? 'Event' : 'Events'} Found',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: _primaryText,
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (events.isEmpty)
                    buildEmptyState()
                  else
                    ...events.map(
                          (event) =>
                          buildEventCard(event),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
