import 'package:eclapp/pages/pharmacists/pharmacists_booking_helpers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('bookingIdsMatch compares string and int ids', () {
    expect(bookingIdsMatch(12, '12'), isTrue);
    expect(bookingIdsMatch(12, 13), isFalse);
  });

  test('indexOfBooking finds booking by id', () {
    final bookings = [
      {'id': 1, 'name': 'A'},
      {'id': '2', 'name': 'B'},
    ];
    expect(indexOfBooking(bookings, {'id': '2'}), 1);
    expect(indexOfBooking(bookings, {'id': 99}), -1);
  });

  test('activeBookingsForPharmacistsPage excludes cancelled and past due', () {
    final bookings = [
      {
        'id': 1,
        'session_date': '2099-12-01',
        'start_time': '10:00',
        'status': 'Upcoming',
      },
      {
        'id': 2,
        'session_date': '2099-12-02',
        'start_time': '10:00',
        'status': 'cancelled',
      },
      {
        'id': 3,
        'session_date': '2020-01-01',
        'start_time': '10:00',
      },
    ];
    final active = activeBookingsForPharmacistsPage(bookings);
    expect(active.length, 1);
    expect(active.first['id'], 1);
  });
}
