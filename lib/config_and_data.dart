part of 'main.dart';

// ======================================================
// COLORS
// ======================================================

const Color navy = Color(0xFF0B2D5C);
const Color blue = Color(0xFF174C8F);
const Color yellow = Color(0xFFFFC83D);

const Color lightBg = Color(0xFFF5F7FA);
const Color lightNavy = Color(0xFFEAF1FA);

const Color textDark = Color(0xFF172033);
const Color textGrey = Color(0xFF748095);
const Color borderColor = Color(0xFFE5EAF0);

const LinearGradient appGradient = LinearGradient(
  colors: [navy, blue],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

const List<String> courseOptions = [
  'BSIT',
  'BSCrim',
  'BSOA',
  'BSEd - English',
  'BEEd',
  'BA - PolSci',
  'BA - Comm',
];

const List<String> blockOptions = [
  'Block 1',
  'Block 2',
  'Block 3',
  'Block 4',
  'Block 5',
  'Block 6',
  'Block 7',
  'Block 8',
  'Block 9',
  'Block 10',
  'Block 11',
];

// Normalize block input for Student Registration, Edit Profile, and Events.
// Accepts 1, 01, Block 1, block 1, and integer values from 1 through 11.
// Returns null when the block is not valid.
String? normalizeTmcBlock(Object? input) {
  final value = (input ?? '').toString().trim();

  final match = RegExp(
    r'^(?:block\s*)?(\d+)$',
    caseSensitive: false,
  ).firstMatch(value);

  if (match == null) return null;

  final number = int.tryParse(match.group(1)!);

  // Allow any positive block number.
  if (number == null || number < 1) {
    return null;
  }

  return 'Block $number';
}



bool isValidEmail(String email) {
  final value = email.trim();
  return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value);
}

String eventKey(Event event) =>
    '${event.title}|${event.date}|${event.time}|${event.venue}';

String createLocalQrToken() {
  const chars =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
  final random = Random.secure();
  return List.generate(40, (_) => chars[random.nextInt(chars.length)]).join();
}

const String studentQrPrefix = 'EVENTEASE_STUDENT:';

// Temporary student QR credential for development.
// The API will issue registration tokens in the final system.
String createStudentEventQr(Event event) {
  final key = eventKey(event);

  // Generate the token only once for this registration.
  final token = qrTokens.putIfAbsent(key, () => createLocalQrToken());

  return '$studentQrPrefix$token';
}

// Extract the token from a student QR code.
String? decodeStudentEventQr(String rawValue) {
  if (!rawValue.startsWith(studentQrPrefix)) {
    return null;
  }

  final token = rawValue.substring(studentQrPrefix.length);

  // The local generator uses 40 alphanumeric characters.
  if (!RegExp(r'^[A-Za-z0-9]{40}$').hasMatch(token)) {
    return null;
  }

  return token;
}

const String attendanceQrPrefix = 'EVENTEASE_ATTENDANCE:';
const Duration attendanceQrValidity = Duration(minutes: 5);

String createAdminAttendanceQr(Event event) {
  final payload = <String, dynamic>{
    'eventKey': eventKey(event),
    'eventTitle': event.title,
    'issuedAt': DateTime.now().millisecondsSinceEpoch,
    'session': createLocalQrToken(),
  };

  final encoded = base64Url.encode(utf8.encode(jsonEncode(payload)));
  return '$attendanceQrPrefix$encoded';
}

Map<String, dynamic>? decodeAdminAttendanceQr(String rawValue) {
  if (!rawValue.startsWith(attendanceQrPrefix)) return null;

  try {
    final encoded = rawValue.substring(attendanceQrPrefix.length);
    final normalized = base64Url.normalize(encoded);
    final decodedText = utf8.decode(base64Url.decode(normalized));
    final decoded = jsonDecode(decodedText);
    if (decoded is! Map) return null;
    return Map<String, dynamic>.from(decoded);
  } catch (_) {
    return null;
  }
}

String formatCheckInTime(DateTime value) {
  final hour12 = value.hour == 0
      ? 12
      : value.hour > 12
      ? value.hour - 12
      : value.hour;
  final minute = value.minute.toString().padLeft(2, '0');
  final period = value.hour >= 12 ? 'PM' : 'AM';
  return '$hour12:$minute $period';
}

// ======================================================
// TEMPORARY DATA
// ======================================================

String savedName = '';
String savedEmail = '';
String savedStudentId = '';
String savedDepartment = '';
String savedCourse = '';
String savedYear = '';
String savedBlock = '';
String savedPassword = '';

// Temporary local role for development.
// Later this value must come from the authenticated API.
String savedUserRole = 'scanner';

// Temporary scanner identity for demonstration.
// Replace with the authenticated user's identity from the API.
String demoScannerName = 'TMC Event Officer';

class Event {
  final String title;
  final String date;
  final String time;
  final String venue;
  final String description;

  // Event classification
  final String scope;
  final String department;

  // Eligibility and registration rules
  final String eligibleParticipants;
  final List<String> allowedCourses;
  final List<String> allowedYears;
  final List<String> allowedBlocks;

  final int capacity;
  final int currentParticipants;
  final String registrationDeadline;
  final bool registrationOpen;

  const Event({
    required this.title,
    required this.date,
    required this.time,
    required this.venue,
    required this.description,

    // Optional to preserve existing event declarations
    this.scope = 'School-Wide',
    this.department = 'All Departments',

    required this.eligibleParticipants,
    required this.allowedCourses,
    required this.allowedYears,
    this.allowedBlocks = blockOptions,
    required this.capacity,
    required this.currentParticipants,
    required this.registrationDeadline,
    this.registrationOpen = true,
  });
}

const List<String> allYearLevels = [
  '1st Year',
  '2nd Year',
  '3rd Year',
  '4th Year',
];

const List<Event> eventList = [
  Event(
    title: 'TechTalk 2026',
    date: 'September 5, 2026',
    time: '9:00 AM - 12:00 PM',
    venue: 'TMC Auditorium',
    description:
    'A technology seminar where students can learn '
        'about the latest trends in information technology.',

    scope: 'School-Wide',
    department: 'All Departments',

    eligibleParticipants: 'All TMC College Students',
    allowedCourses: courseOptions,
    allowedYears: allYearLevels,
    capacity: 200,
    currentParticipants: 124,
    registrationDeadline: 'September 3, 2026',
  ),

  Event(
    title: 'Web Development Workshop',
    date: 'September 12, 2026',
    time: '1:00 PM - 4:00 PM',
    venue: 'Computer Laboratory',
    description: 'A beginner-friendly workshop about website development.',

    scope: 'School-Wide',
    department: 'All Departments',

    eligibleParticipants: 'BSIT and BSOA Students',
    allowedCourses: ['BSIT', 'BSOA'],
    allowedYears: allYearLevels,
    capacity: 80,
    currentParticipants: 58,
    registrationDeadline: 'September 10, 2026',
  ),

  Event(
    title: 'Inter-College Esports',
    date: 'September 20, 2026',
    time: '8:00 AM - 5:00 PM',
    venue: 'TMC Covered Court',
    description:
    'An esports competition for students from different departments.',

    scope: 'School-Wide',
    department: 'All Departments',

    eligibleParticipants: 'All TMC College Students',
    allowedCourses: courseOptions,
    allowedYears: allYearLevels,
    capacity: 120,
    currentParticipants: 91,
    registrationDeadline: 'September 18, 2026',
  ),


  Event(
    title: 'TMC Leadership Training',
    date: 'October 20, 2026',
    time: '9:00 AM',
    venue: 'TMC Campus',
    description: 'Leadership seminar for TMC students.',

    scope: 'School-Wide',
    department: 'All Departments',

    eligibleParticipants: 'All TMC Students',
    allowedCourses: courseOptions,
    allowedYears: allYearLevels,
    allowedBlocks: blockOptions,

    capacity: 200,
    currentParticipants: 0,
    registrationDeadline: 'October 19, 2026',
    registrationOpen: true,
  ),


  Event(
    title: 'CCS Programming Competition',
    date: 'November 10, 2026',
    time: '8:00 AM - 12:00 PM',
    venue: 'TMC Computer Laboratory',
    description:
    'A programming competition exclusively for '
        'College of Computer Studies students.',

    scope: 'Department-Specific',
    department: 'College of Computer Studies',

    eligibleParticipants: 'CCS Students Only',
    allowedCourses: ['BSIT'],
    allowedYears: allYearLevels,
    capacity: 50,
    currentParticipants: 0,
    registrationDeadline: 'November 8, 2026',
  ),
];

final List<Event> registeredEvents = [];
final Map<String, String> attendanceStatus = {};
final Map<String, int> eventRatings = {};
final Map<String, String> eventComments = {};
final Map<String, String> qrTokens = {};
final Map<String, String> attendanceCheckInTime = {};

class ScanHistory {
  final String eventTitle;
  final String studentName;
  final String scannerName;
  final String status;
  final DateTime scannedAt;

  const ScanHistory({
    required this.eventTitle,
    required this.studentName,
    required this.scannerName,
    required this.status,
    required this.scannedAt,
  });
}

// Temporary scan history for local testing.
// Later, this data will come from the web API.
final List<ScanHistory> scanHistory = [];

// ======================================================
// NOTIFICATION MANAGEMENT
// ======================================================

final ValueNotifier<Set<String>> readNotificationIds =
ValueNotifier<Set<String>>(<String>{});

const List<String> generalNotificationIds = [
  'announcement_techtalk',
  'announcement_reminder',
  'announcement_qr',
];

// Builds notification IDs based on student event activity.
List<String> getAllNotificationIds() {
  // Real API Mode: the unread badge uses only Laravel announcements
  // loaded by announcements_page.dart, never local demonstration data.
  if (ApiConfig.useRealApi) {
    return _liveAnnouncementIds.toList(growable: false);
  }

  // Demo Mode: preserve the existing local notifications.
  final ids = <String>[...generalNotificationIds];

  for (final event in registeredEvents) {
    final key = eventKey(event);

    // Registration notification
    ids.add('registration_$key');

    // Attendance notification
    if (attendanceStatus[key] == 'Present') {
      ids.add('attendance_$key');

      // Certificate notification
      if ((eventRatings[key] ?? 0) > 0) {
        ids.add('certificate_$key');
      } else {
        ids.add('evaluation_$key');
      }
    }
  }

  return ids;
}

// Number displayed on the dashboard bell.
int getUnreadNotificationCount() {
  return getAllNotificationIds()
      .where((id) => !readNotificationIds.value.contains(id))
      .length;
}

// Mark one notification as read.
void markNotificationAsRead(String id) {
  readNotificationIds.value = {...readNotificationIds.value, id};
}

// Mark all current notifications as read.
void markAllNotificationsAsRead() {
  readNotificationIds.value = {
    ...readNotificationIds.value,
    ...getAllNotificationIds(),
  };
}

// Refresh notification listeners after event activity changes.

void refreshNotifications() {
  readNotificationIds.value = {...readNotificationIds.value};
}

void clearStudentActivityData() {
  registeredEvents.clear();
  attendanceStatus.clear();
  eventRatings.clear();
  eventComments.clear();
  qrTokens.clear();
  attendanceCheckInTime.clear();

  // Clear any cached server notice IDs so another student cannot
  // inherit the previous account's notification badge count.
  _liveAnnouncementIds.clear();

  // Reset read notification records for the next student.
  readNotificationIds.value = <String>{};
  scanHistory.clear();
}
