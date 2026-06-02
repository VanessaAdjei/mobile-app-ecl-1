import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_colors.dart';
import '../config/app_routes.dart';
import '../services/auth_service.dart';
import '../services/booking_service.dart';
import '../widgets/booking_appointment_card.dart';
import '../utils/app_error_utils.dart';
import '../widgets/error_display.dart';
import '../widgets/ecl_expandable_sliver_app_bar.dart';
import 'pharmacists/pharmacists_booking_helpers.dart';

const Color _kPageBg = Color(0xFFF6F8FA);

class MyAppointmentsPage extends StatefulWidget {
  const MyAppointmentsPage({super.key});

  @override
  State<MyAppointmentsPage> createState() => _MyAppointmentsPageState();
}

class _MyAppointmentsPageState extends State<MyAppointmentsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  List<Map<String, dynamic>> _bookings = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadBookings();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadBookings({bool forceRefresh = false}) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final isLoggedIn = await AuthService.isLoggedIn();
      if (isLoggedIn) {
        final result = await BookingService.getHistory();
        if (result['success'] == true && result['data'] is List) {
          final list = result['data'] as List<dynamic>;
          final items = list
              .map((e) =>
                  Map<String, dynamic>.from(e as Map<dynamic, dynamic>))
              .toList();
          await _saveBookings(items);
          if (mounted) {
            setState(() {
              _bookings = items;
              _isLoading = false;
            });
          }
          return;
        }
        if (mounted) {
          setState(() {
            _error = result['message']?.toString() ??
                'Could not load appointments';
            _isLoading = false;
          });
        }
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final bookingsJson = prefs.getStringList('pharmacist_bookings') ?? [];
      final items = <Map<String, dynamic>>[];
      for (final entry in bookingsJson) {
        try {
          final decoded = jsonDecode(entry);
          if (decoded is Map) {
            items.add(Map<String, dynamic>.from(decoded));
          }
        } catch (e) {
          debugPrint('Skipping invalid local booking entry: $e');
        }
      }
      if (mounted) {
        setState(() {
          _bookings = items;
          _isLoading = false;
        });
      }
    } catch (e, st) {
      AppErrorUtils.log('MyAppointmentsPage._loadBookings', e, st);
      if (mounted) {
        setState(() {
          _error = AppErrorUtils.userMessage(
            e,
            fallback: 'Could not load appointments',
          );
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveBookings(List<Map<String, dynamic>> items) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = items.map((e) => jsonEncode(e)).toList();
    await prefs.setStringList('pharmacist_bookings', encoded);
  }

  Future<bool> _cancelBooking(Map<String, dynamic> booking) async {
    final id = booking['id'];
    if (id == null) {
      setState(() => _bookings.remove(booking));
      await _saveBookings(_bookings);
      return true;
    }
    final result = await BookingService.cancel(id.toString());
    if (!mounted) return false;
    if (result['success'] == true) {
      setState(() {
        _bookings.removeWhere(
          (e) => e['id'] == id || identical(e, booking),
        );
      });
      await _saveBookings(_bookings);
      if (mounted) {
        AppErrorUtils.showSnack(context, 'Appointment cancelled',
            isError: false);
      }
      return true;
    }
    if (!mounted) return false;
    AppErrorUtils.showSnack(
      context,
      result['message']?.toString() ?? 'Failed to cancel appointment',
      isError: true,
    );
    return false;
  }

  void _openBookConsultation() {
    Navigator.pushNamed(context, AppRoutes.pharmacists);
  }

  @override
  Widget build(BuildContext context) {
    final upcoming =
        filterBookingsBySection(_bookings, BookingListSection.upcoming);
    final pastDue =
        filterBookingsBySection(_bookings, BookingListSection.notDone);
    final completed = [
      ...filterBookingsBySection(_bookings, BookingListSection.completed),
      ...filterBookingsBySection(_bookings, BookingListSection.cancelled),
    ]..sort(compareBookingsNewestFirst);

    return Scaffold(
      backgroundColor: _kPageBg,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          EclExpandableSliverAppBar(
            toolbarTitle: 'My Appointments',
            heroTitle: 'My Appointments',
            onBack: () => Navigator.maybePop(context),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: IconButton(
                    tooltip: 'Book consultation',
                    icon: const Icon(Icons.add_circle_outline,
                        color: Colors.white),
                    onPressed: _openBookConsultation,
                  ),
                ),
              ),
            ],
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _AppointmentsTabBarDelegate(
              tabController: _tabController,
              upcomingCount: upcoming.length,
              pastDueCount: pastDue.length,
              completedCount: completed.length,
            ),
          ),
        ],
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? ErrorDisplay(
                    title: 'Could not load appointments',
                    message: _error!,
                    showRetry: true,
                    onRetry: () => _loadBookings(forceRefresh: true),
                    isFullScreen: true,
                  )
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _AppointmentListTab(
                        items: upcoming,
                        emptyTitle: 'No upcoming appointments',
                        emptySubtitle:
                            'Book a pharmacist consultation to see it here.',
                        onCancel: _cancelBooking,
                        onBook: _openBookConsultation,
                        onRefresh: () => _loadBookings(forceRefresh: true),
                      ),
                      _AppointmentListTab(
                        items: pastDue,
                        emptyTitle: 'No overdue or past due appointments',
                        emptySubtitle:
                            'Appointments show here when the scheduled time has passed without completion.',
                        onBook: _openBookConsultation,
                        onRefresh: () => _loadBookings(forceRefresh: true),
                      ),
                      _AppointmentListTab(
                        items: completed,
                        emptyTitle: 'No completed appointments yet',
                        emptySubtitle:
                            'Finished or cancelled consultations show here.',
                        onBook: _openBookConsultation,
                        onRefresh: () => _loadBookings(forceRefresh: true),
                      ),
                    ],
                  ),
      ),
    );
  }
}

class _AppointmentsTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabController tabController;
  final int upcomingCount;
  final int pastDueCount;
  final int completedCount;

  const _AppointmentsTabBarDelegate({
    required this.tabController,
    required this.upcomingCount,
    required this.pastDueCount,
    required this.completedCount,
  });

  @override
  double get minExtent => 48;

  @override
  double get maxExtent => 48;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0D3D18),
            AppColors.primary,
            AppColors.accent,
          ],
          stops: [0.0, 0.5, 1.0],
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: TabBar(
        controller: tabController,
        indicatorSize: TabBarIndicatorSize.tab,
        indicatorPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        indicator: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        dividerColor: Colors.transparent,
        labelColor: AppColors.primaryDark,
        unselectedLabelColor: Colors.white.withValues(alpha: 0.78),
        labelStyle: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          height: 1.0,
        ),
        unselectedLabelStyle: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          height: 1.0,
        ),
        tabs: [
          Tab(text: 'Upcoming ($upcomingCount)'),
          Tab(text: 'Overdue ($pastDueCount)'),
          Tab(text: 'Completed ($completedCount)'),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _AppointmentsTabBarDelegate oldDelegate) {
    return upcomingCount != oldDelegate.upcomingCount ||
        pastDueCount != oldDelegate.pastDueCount ||
        completedCount != oldDelegate.completedCount;
  }
}

class _AppointmentListTab extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final String emptyTitle;
  final String emptySubtitle;
  final Future<bool> Function(Map<String, dynamic> booking)? onCancel;
  final VoidCallback onBook;
  final Future<void> Function() onRefresh;

  const _AppointmentListTab({
    required this.items,
    required this.emptyTitle,
    required this.emptySubtitle,
    required this.onBook,
    required this.onRefresh,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return RefreshIndicator(
        color: AppColors.primary,
        onRefresh: onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 48),
            Icon(Icons.event_busy_outlined,
                size: 56, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              emptyTitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              emptySubtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: Colors.grey.shade600,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: FilledButton.icon(
                onPressed: onBook,
                icon: const Icon(Icons.calendar_month_outlined, size: 18),
                label: Text(
                  'Book consultation',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: onRefresh,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 14),
        itemBuilder: (context, i) => BookingAppointmentCard(
          booking: items[i],
          onCancel: onCancel,
        ),
      ),
    );
  }
}
