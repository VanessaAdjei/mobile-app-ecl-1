String bookingDisplayDate(Map<String, dynamic> b) {
  final d = b['date'];
  if (d != null && d.toString().isNotEmpty) return d.toString();
  final sd = b['session_date'];
  if (sd != null && sd.toString().isNotEmpty) return sd.toString();
  return '';
}

String bookingDisplayTime(Map<String, dynamic> b) {
  final t = b['time'];
  if (t != null && t.toString().isNotEmpty) return t.toString();
  final start = b['start_time']?.toString() ?? '';
  final end = b['end_time']?.toString() ?? '';
  if (start.isEmpty && end.isEmpty) return '';
  String s = start.split(':').take(2).join(':');
  String e = end.split(':').take(2).join(':');
  return e.isEmpty ? s : '$s - $e';
}

String bookingDisplayName(Map<String, dynamic> b) =>
    (b['name'] ?? b['full_name'] ?? '').toString();

String bookingDisplayConsultationType(Map<String, dynamic> b) =>
    (b['consultationType'] ?? b['type'] ?? '').toString();

String bookingDisplayPlatform(Map<String, dynamic> b) =>
    (b['preferredPlatform'] ?? b['platform'] ?? 'Not specified').toString();

String bookingDisplaySymptoms(Map<String, dynamic> b) =>
    (b['symptoms'] ?? b['reason'] ?? '').toString();

const String bookingStatusUpcoming = 'Upcoming';
const String bookingStatusPastDue = 'Past due';
const String bookingStatusCompleted = 'Completed';
const String bookingStatusCancelled = 'Cancelled';

enum BookingListSection { upcoming, notDone, completed, cancelled }

bool isBookingUpcoming(Map<String, dynamic> b) =>
    getBookingStatus(b) == bookingStatusUpcoming;

bool isBookingPastDue(Map<String, dynamic> b) =>
    getBookingStatus(b) == bookingStatusPastDue;

bool isBookingCompleted(Map<String, dynamic> b) =>
    getBookingStatus(b) == bookingStatusCompleted;

bool isBookingCancelled(Map<String, dynamic> b) =>
    getBookingStatus(b) == bookingStatusCancelled;

BookingListSection getBookingListSection(Map<String, dynamic> b) {
  switch (getBookingStatus(b)) {
    case bookingStatusUpcoming:
      return BookingListSection.upcoming;
    case bookingStatusPastDue:
      return BookingListSection.notDone;
    case bookingStatusCompleted:
      return BookingListSection.completed;
    case bookingStatusCancelled:
      return BookingListSection.cancelled;
    default:
      return BookingListSection.notDone;
  }
}

/// Parses session date/time for sorting (newest first within a section).
DateTime? bookingDateTime(Map<String, dynamic> b) {
  try {
    final now = DateTime.now();
    final sessionDate = b['session_date']?.toString();
    final startTime = b['start_time']?.toString();
    if (sessionDate != null &&
        sessionDate.isNotEmpty &&
        startTime != null &&
        startTime.isNotEmpty) {
      final dateParts = sessionDate.split('-');
      final timeParts = startTime.split(':');
      if (dateParts.length >= 3 && timeParts.length >= 2) {
        return DateTime(
          int.tryParse(dateParts[0]) ?? now.year,
          int.tryParse(dateParts[1]) ?? 1,
          int.tryParse(dateParts[2]) ?? 1,
          int.tryParse(timeParts[0]) ?? 0,
          int.tryParse(timeParts[1]) ?? 0,
        );
      }
    }
    final parts = (b['date'] ?? '').toString().split('/');
    final timeStr = (b['time'] ?? '').toString();
    if (parts.length == 3 && timeStr.isNotEmpty) {
      final day = int.tryParse(parts[0]) ?? 1;
      final month = int.tryParse(parts[1]) ?? 1;
      final year = int.tryParse(parts[2]) ?? 2000;
      final timeParts = timeStr.split(' ');
      final hm = timeParts[0].split(':');
      int hour = int.tryParse(hm[0]) ?? 0;
      int minute = hm.length > 1 ? (int.tryParse(hm[1]) ?? 0) : 0;
      if (timeParts.length > 1 &&
          timeParts[1].toUpperCase() == 'PM' &&
          hour < 12) {
        hour += 12;
      }
      if (timeParts.length > 1 &&
          timeParts[1].toUpperCase() == 'AM' &&
          hour == 12) {
        hour = 0;
      }
      return DateTime(year, month, day, hour, minute);
    }
  } catch (_) {}
  return null;
}

int compareBookingsNewestFirst(Map<String, dynamic> a, Map<String, dynamic> b) {
  final da = bookingDateTime(a);
  final db = bookingDateTime(b);
  if (da == null && db == null) return 0;
  if (da == null) return 1;
  if (db == null) return -1;
  return db.compareTo(da);
}

/// Bookings shown on the pharmacists page (excludes overdue / past due).
List<Map<String, dynamic>> activeBookingsForPharmacistsPage(
  List<Map<String, dynamic>> bookings,
) {
  final active =
      bookings.where((b) => !isBookingPastDue(b)).toList();
  active.sort((a, b) {
    final da = bookingDateTime(a);
    final db = bookingDateTime(b);
    if (da == null && db == null) return 0;
    if (da == null) return 1;
    if (db == null) return -1;
    return da.compareTo(db);
  });
  return active;
}

List<Map<String, dynamic>> filterBookingsBySection(
  List<Map<String, dynamic>> bookings,
  BookingListSection section,
) {
  final filtered = bookings
      .where((b) => getBookingListSection(b) == section)
      .toList();
  filtered.sort(compareBookingsNewestFirst);
  return filtered;
}

String getBookingStatus(Map<String, dynamic> b) {
  final apiStatus = (b['status'] ?? '').toString().trim();
  if (apiStatus.isNotEmpty) {
    final lower = apiStatus.toLowerCase();
    if (lower == 'cancelled' || lower == 'canceled') {
      return bookingStatusCancelled;
    }
    if (lower == 'completed' ||
        lower == 'complete' ||
        lower == 'done' ||
        lower == 'attended') {
      return bookingStatusCompleted;
    }
  }
  try {
    final now = DateTime.now();
    final sessionDate = b['session_date']?.toString();
    final startTime = b['start_time']?.toString();
    if (sessionDate != null &&
        sessionDate.isNotEmpty &&
        startTime != null &&
        startTime.isNotEmpty) {
      final dateParts = sessionDate.split('-');
      final timeParts = startTime.split(':');
      if (dateParts.length >= 3 && timeParts.length >= 2) {
        final year = int.tryParse(dateParts[0]) ?? now.year;
        final month = int.tryParse(dateParts[1]) ?? 1;
        final day = int.tryParse(dateParts[2]) ?? 1;
        final hour = int.tryParse(timeParts[0]) ?? 0;
        final minute = int.tryParse(timeParts[1]) ?? 0;
        final bookingDate = DateTime(year, month, day, hour, minute);
        return bookingDate.isAfter(now)
            ? bookingStatusUpcoming
            : bookingStatusPastDue;
      }
    }
    final parts = (b['date'] ?? '').toString().split('/');
    final timeStr = (b['time'] ?? '').toString();
    if (parts.length == 3 && timeStr.isNotEmpty) {
      final day = int.tryParse(parts[0]) ?? 1;
      final month = int.tryParse(parts[1]) ?? 1;
      final year = int.tryParse(parts[2]) ?? 2000;
      final timeParts = timeStr.split(' ');
      final hm = timeParts[0].split(':');
      int hour = int.tryParse(hm[0]) ?? 0;
      int minute = hm.length > 1 ? (int.tryParse(hm[1]) ?? 0) : 0;
      if (timeParts.length > 1 &&
          timeParts[1].toUpperCase() == 'PM' &&
          hour < 12) {
        hour += 12;
      }
      if (timeParts.length > 1 &&
          timeParts[1].toUpperCase() == 'AM' &&
          hour == 12) {
        hour = 0;
      }
      final bookingDate = DateTime(year, month, day, hour, minute);
      return bookingDate.isAfter(now)
          ? bookingStatusUpcoming
          : bookingStatusPastDue;
    }
  } catch (_) {}
  return bookingStatusUpcoming;
}
