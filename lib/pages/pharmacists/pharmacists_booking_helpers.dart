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

String getBookingStatus(Map<String, dynamic> b) {
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
        return bookingDate.isAfter(now) ? 'Upcoming' : 'Completed';
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
      return bookingDate.isAfter(now) ? 'Upcoming' : 'Completed';
    }
  } catch (_) {}
  return 'Upcoming';
}
