import 'package:intl/intl.dart';

/// Parses order/status timestamps from the API for display and elapsed math.
DateTime? parseOrderTimestamp(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value.toLocal();
  if (value is int) {
    final ms = value > 9999999999 ? value : value * 1000;
    return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true).toLocal();
  }

  final raw = value.toString().trim();
  if (raw.isEmpty) return null;

  final hasOffset = raw.endsWith('Z') ||
      RegExp(r'[+-]\d{2}(:?\d{2})?$').hasMatch(raw);

  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return null;

  if (hasOffset) return parsed.toLocal();

  // Naive server datetime (e.g. "2025-06-04 14:30:00") — treat as UTC then local.
  final normalized = raw.contains('T') ? raw : raw.replaceFirst(' ', 'T');
  final utc = DateTime.tryParse('${normalized}Z');
  return (utc ?? parsed).toLocal();
}

/// Whole minutes elapsed from [start] to now (rounded to nearest minute).
int elapsedMinutesRounded(DateTime start) {
  final seconds = DateTime.now().difference(start.toLocal()).inSeconds;
  if (seconds < 45) return 0;
  return (seconds + 30) ~/ 60;
}

/// User-facing duration for the active timeline step.
String formatStepDuration(DateTime startedAt) {
  final minutes = elapsedMinutesRounded(startedAt);
  if (minutes < 1) return 'Just now';
  if (minutes < 60) {
    return minutes == 1 ? '1 minute' : '$minutes minutes';
  }
  final hours = (DateTime.now().difference(startedAt.toLocal()).inSeconds + 1800) ~/
      3600;
  if (hours < 24) {
    return hours == 1 ? '1 hour' : '$hours hours';
  }
  final days = (DateTime.now().difference(startedAt.toLocal()).inSeconds + 43200) ~/
      86400;
  return days == 1 ? '1 day' : '$days days';
}

/// Wall-clock time when a step completed (local timezone).
String formatStepClockTime(DateTime at) {
  final local = at.toLocal();
  final now = DateTime.now();
  final sameDay =
      local.year == now.year && local.month == now.month && local.day == now.day;
  if (sameDay) {
    return DateFormat('h:mm a').format(local);
  }
  return DateFormat('MMM d · h:mm a').format(local);
}
