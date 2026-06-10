import 'package:eclapp/utils/prescription_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('prescriptionsFromResponse', () {
    test('normalizes createdAt onto created_at', () {
      final rows = prescriptionsFromResponse({
        'data': [
          {'id': 1, 'status': 'pending', 'createdAt': '2026-06-02T10:15:00Z'},
        ],
      });

      expect(rows, hasLength(1));
      expect(rows.first['created_at'], '2026-06-02T10:15:00Z');
    });

    test('reads nested prescription timestamps', () {
      final rows = prescriptionsFromResponse({
        'data': [
          {
            'id': 2,
            'prescription': {'uploaded_at': '2026-05-20 08:30:00'},
          },
        ],
      });

      expect(rows.first['created_at'], '2026-05-20 08:30:00');
    });

    test('supports prescriptions nested under data map', () {
      final rows = prescriptionsFromResponse({
        'data': {
          'prescriptions': [
            {'id': 3, 'submission_date': '2026-04-01'},
          ],
        },
      });

      expect(rows, hasLength(1));
      expect(rows.first['created_at'], '2026-04-01');
    });

    test('merges locally stored submission dates by id', () {
      final rows = prescriptionsFromResponse(
        {
          'data': [
            {'id': 42, 'status': 'pending'},
          ],
        },
        localSubmissionDates: {
          '42': '2026-06-04T12:00:00.000Z',
        },
      );

      expect(rows.first['created_at'], '2026-06-04T12:00:00.000Z');
    });
  });

  group('partitionPrescriptionsByQueue', () {
    test('splits pending and served by status', () {
      final split = partitionPrescriptionsByQueue([
        {'id': 1, 'status': 'pending'},
        {'id': 2, 'status': 'served'},
        {'id': 3, 'status': 'approved'},
      ]);

      expect(split.pending.map((e) => e['id']), [1]);
      expect(split.served.map((e) => e['id']), [2, 3]);
    });
  });

  group('extractPrescriptionId', () {
    test('reads top-level and nested ids', () {
      expect(extractPrescriptionId({'id': 7}), '7');
      expect(
        extractPrescriptionId({'data': {'prescription_id': 'abc'}}),
        'abc',
      );
    });
  });

  group('formatPrescriptionSubmissionDate', () {
    test('formats ISO timestamps for display', () {
      final label = formatPrescriptionSubmissionDate('2026-06-02T10:15:00Z');
      expect(label, contains('2026'));
      expect(label, isNotEmpty);
    });

    test('returns empty string for missing values', () {
      expect(formatPrescriptionSubmissionDate(null), '');
      expect(formatPrescriptionSubmissionDate(''), '');
    });
  });
}
