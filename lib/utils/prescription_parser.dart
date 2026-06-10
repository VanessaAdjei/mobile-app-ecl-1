import 'package:intl/intl.dart';

import 'order_timestamp_parser.dart';

/// Whether a prescription is still awaiting pharmacist action or already handled.
enum PrescriptionQueue { pending, served }

/// Status values treated as completed / served by the pharmacy team.
const _servedStatuses = {
  'approved',
  'processed',
  'completed',
  'complete',
  'active',
  'served',
  'fulfilled',
  'dispensed',
  'rejected',
  'declined',
  'cancelled',
  'canceled',
};

/// Maps API status strings into pending vs served buckets for the history UI.
PrescriptionQueue prescriptionQueueFor(String? status) {
  final normalized = status?.toLowerCase().trim() ?? '';
  if (normalized.isEmpty || normalized == 'null') {
    return PrescriptionQueue.pending;
  }
  if (_servedStatuses.contains(normalized)) {
    return PrescriptionQueue.served;
  }
  return PrescriptionQueue.pending;
}

bool isPrescriptionServed(String? status) =>
    prescriptionQueueFor(status) == PrescriptionQueue.served;

/// Splits prescription rows into pending and served lists (newest first).
({List<Map<String, dynamic>> pending, List<Map<String, dynamic>> served})
    partitionPrescriptionsByQueue(List<Map<String, dynamic>> prescriptions) {
  final pending = <Map<String, dynamic>>[];
  final served = <Map<String, dynamic>>[];
  for (final row in prescriptions) {
    final status = row['status']?.toString();
    if (isPrescriptionServed(status)) {
      served.add(row);
    } else {
      pending.add(row);
    }
  }
  sortPrescriptionsNewestFirst(pending);
  sortPrescriptionsNewestFirst(served);
  return (pending: pending, served: served);
}

void sortPrescriptionsNewestFirst(List<Map<String, dynamic>> prescriptions) {
  prescriptions.sort((a, b) {
    final aDate = parseOrderTimestamp(
      a['created_at'] ?? readPrescriptionSubmissionRaw(a),
    );
    final bDate = parseOrderTimestamp(
      b['created_at'] ?? readPrescriptionSubmissionRaw(b),
    );
    if (aDate == null && bDate == null) return 0;
    if (aDate == null) return 1;
    if (bDate == null) return -1;
    return bDate.compareTo(aDate);
  });
}

/// Human-readable status chip label.
String prescriptionStatusLabel(String? status) {
  final normalized = status?.toLowerCase().trim() ?? '';
  if (normalized.isEmpty || normalized == 'null') return 'Pending';
  switch (normalized) {
    case 'approved':
      return 'Approved';
    case 'served':
      return 'Served';
    case 'processed':
      return 'Processed';
    case 'completed':
    case 'complete':
      return 'Completed';
    case 'rejected':
    case 'declined':
      return 'Rejected';
    case 'cancelled':
    case 'canceled':
      return 'Cancelled';
    case 'pending':
      return 'Pending';
    default:
      if (normalized.length == 1) return normalized.toUpperCase();
      return '${normalized[0].toUpperCase()}${normalized.substring(1)}';
  }
}

/// Known API keys for prescription submission / upload timestamps.
const _submissionDateKeys = [
  'created_at',
  'createdAt',
  'created',
  'created_on',
  'createdOn',
  'date',
  'uploaded_at',
  'uploadedAt',
  'upload_date',
  'uploadDate',
  'submission_date',
  'submissionDate',
  'submitted_at',
  'submittedAt',
  'date_submitted',
  'timestamp',
  'datetime',
  'updated_at',
  'updatedAt',
];

/// Pulls prescription rows from `/view-prescription` (and similar) bodies.
List<dynamic> prescriptionRowsFromBody(Map<String, dynamic> body) {
  final data = body['data'];
  if (data is List) return data;
  if (data is Map) {
    for (final key in const [
      'prescriptions',
      'history',
      'items',
      'records',
      'results',
    ]) {
      final nested = data[key];
      if (nested is List) return nested;
    }
  }

  for (final key in const ['prescriptions', 'history', 'items']) {
    final top = body[key];
    if (top is List) return top;
  }

  return const [];
}

/// Reads the first non-empty submission timestamp from [map] (including nested maps).
dynamic readPrescriptionSubmissionRaw(Map<String, dynamic> map) {
  for (final key in _submissionDateKeys) {
    final value = map[key];
    if (_hasDateValue(value)) return value;
  }

  for (final nestedKey in const ['prescription', 'attributes', 'meta', 'data']) {
    final nested = map[nestedKey];
    if (nested is Map) {
      final fromNested = readPrescriptionSubmissionRaw(
        Map<String, dynamic>.from(nested),
      );
      if (_hasDateValue(fromNested)) return fromNested;
    }
  }

  return null;
}

bool _hasDateValue(dynamic value) {
  if (value == null) return false;
  if (value is Map || value is List) return false;
  final text = value.toString().trim();
  return text.isNotEmpty && text.toLowerCase() != 'null';
}

/// Ensures each row exposes `created_at` when the API uses another key.
Map<String, dynamic> normalizePrescriptionRecord(
  Map<String, dynamic> raw, {
  Map<String, String>? localSubmissionDates,
}) {
  final map = Map<String, dynamic>.from(raw);
  final submissionRaw = readPrescriptionSubmissionRaw(map);
  if (submissionRaw != null) {
    map['created_at'] ??= submissionRaw;
  }

  if (!_hasDateValue(map['created_at']) && localSubmissionDates != null) {
    final id = map['id']?.toString().trim();
    if (id != null && id.isNotEmpty) {
      final local = localSubmissionDates[id];
      if (_hasDateValue(local)) {
        map['created_at'] = local;
      }
    }
  }

  return map;
}

/// Reads prescription id from create/upload API bodies.
String? extractPrescriptionId(dynamic body) {
  if (body is! Map) return null;
  final map = Map<String, dynamic>.from(body);

  for (final key in const ['id', 'prescription_id']) {
    final value = map[key];
    if (value != null && value.toString().trim().isNotEmpty) {
      return value.toString().trim();
    }
  }

  final data = map['data'];
  if (data is Map) {
    for (final key in const ['id', 'prescription_id']) {
      final value = data[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }
  }

  return null;
}

/// User-facing label for a prescription submission date.
String formatPrescriptionSubmissionDate(dynamic raw) {
  if (!_hasDateValue(raw)) return '';

  final parsed = parseOrderTimestamp(raw);
  if (parsed != null) {
    final local = parsed.toLocal();
    final now = DateTime.now();
    final sameDay = local.year == now.year &&
        local.month == now.month &&
        local.day == now.day;
    if (sameDay) {
      return 'Today · ${DateFormat('h:mm a').format(local)}';
    }
    return DateFormat('MMM d, y').format(local);
  }

  final text = raw.toString().trim();
  if (text.contains('T')) {
    final datePart = text.split('T').first.trim();
    final fallback = DateTime.tryParse(datePart);
    if (fallback != null) {
      return DateFormat('MMM d, y').format(fallback.toLocal());
    }
    return datePart;
  }
  return text;
}

/// Parses prescription list from view-prescription API body.
List<Map<String, dynamic>> prescriptionsFromResponse(
  Map<String, dynamic> body, {
  Map<String, String>? localSubmissionDates,
}) {
  return prescriptionRowsFromBody(body)
      .whereType<Map>()
      .map(
        (e) => normalizePrescriptionRecord(
          Map<String, dynamic>.from(e),
          localSubmissionDates: localSubmissionDates,
        ),
      )
      .toList();
}
