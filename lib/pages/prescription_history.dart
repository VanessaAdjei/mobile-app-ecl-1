// pages/prescription_history.dart
import 'package:eclapp/pages/bottomnav.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:eclapp/pages/auth_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'homepage.dart';
import 'cart.dart';
import 'profile.dart';
import 'AppBackButton.dart';
import 'package:shimmer/shimmer.dart';
import 'package:eclapp/widgets/error_display.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:eclapp/widgets/optimized_image_widget.dart';

class PrescriptionHistoryScreen extends StatefulWidget {
  const PrescriptionHistoryScreen({super.key});

  @override
  _PrescriptionHistoryScreenState createState() =>
      _PrescriptionHistoryScreenState();
}

class _PrescriptionHistoryScreenState extends State<PrescriptionHistoryScreen> {
  List<Map<String, dynamic>> _prescriptions = [];
  final Map<int, Map<String, dynamic>> _productDetails = {};
  bool _isLoading = true;
  String? _error;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchPrescriptions();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchPrescriptions() async {
    try {
      if (mounted) {
        setState(() {
          _isLoading = true;
          _error = null;
        });
      }

      final token = await AuthService.getToken();
      if (token == null) {
        throw Exception('Please sign in to view your prescriptions');
      }

      final response = await http.post(
        Uri.parse(
            'https://eclcommerce.ernestchemists.com.gh/api/view-prescription'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['data'] != null) {
          if (mounted) {
            setState(() {
              _prescriptions = List<Map<String, dynamic>>.from(data['data']);
              _isLoading = false;
            });
          }
        } else {
          throw Exception('No prescription data found');
        }
      } else if (response.statusCode == 401) {
        throw Exception('Your session has expired. Please log in again.');
      } else {
        throw Exception('Unable to connect to the server');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _showPrescriptionImage(String fileUrl) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Stack(
            children: [
              InteractiveViewer(
                child: OptimizedImageWidget.large(
                  imageUrl: fileUrl,
                  fit: BoxFit.contain,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.green.shade700,
                Colors.green.shade800,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        ),
        leading: AppBackButton(
          backgroundColor: Colors.white.withValues(alpha: 0.2),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Uploaded Prescriptions',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
            letterSpacing: 0.5,
          ),
        ),
      ),
      body: _isLoading
          ? _buildLoadingState()
          : _error != null
              ? _buildErrorState()
              : _prescriptions.isEmpty
                  ? _buildEmptyState()
                  : _buildPrescriptionsList(),
    );
  }

  Widget _buildLoadingState() {
    return ListView.builder(
      itemCount: 5,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: Colors.grey[300]!,
          highlightColor: Colors.grey[100]!,
          child: Container(
            height: 100,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      },
    );
  }

  Widget _buildErrorState() {
    return ErrorDisplay(
      title: 'Error Loading Prescriptions',
      message: _error ?? 'An error occurred while loading your prescriptions',
      onRetry: () {
        setState(() {
          _isLoading = true;
          _error = null;
        });
        _fetchPrescriptions();
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.medical_services_outlined,
              size: 100,
              color: Colors.green[200],
            ),
            const SizedBox(height: 30),
            Text(
              'No Prescriptions Yet',
              style: TextStyle(
                fontSize: 24,
                color: Colors.green[700],
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'You haven\'t uploaded any prescriptions yet.',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrescriptionsList() {
    return RefreshIndicator(
      onRefresh: _fetchPrescriptions,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: _prescriptions.length,
        itemBuilder: (context, index) {
          final prescription = _prescriptions[index];

          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: GestureDetector(
                onTap: () {
                  if (prescription['file'] != null) {
                    _showPrescriptionImage(prescription['file']);
                  }
                },
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.grey[200],
                  ),
                  child: prescription['file'] != null
                      ? OptimizedImageWidget.thumbnail(
                          imageUrl: prescription['file'],
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                          borderRadius: BorderRadius.circular(8),
                        )
                      : Icon(
                          Icons.medical_services_outlined,
                          size: 30,
                          color: Colors.green.shade700,
                        ),
                ),
              ),
              title: Text(
                'Prescription #${prescription['id']}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text(
                    'Status: ${prescription['status'] ?? 'Pending'}',
                    style: TextStyle(
                      color: _getStatusColor(prescription['status']),
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (prescription['file'] != null)
                    Text(
                      'Image: Available',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                ],
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                if (prescription['file'] != null) {
                  _showPrescriptionImage(prescription['file']);
                }
              },
            ),
          );
        },
      ),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'pending':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }
}
