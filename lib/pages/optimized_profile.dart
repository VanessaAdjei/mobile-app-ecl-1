// pages/optimized_profile.dart
// pages/optimized_profile.dart
// pages/optimized_profile.dart
import 'package:flutter/material.dart';

import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import 'signinpage.dart';
import 'settings.dart';
import 'purchases.dart';
import 'prescription_history.dart';
import 'app_back_button.dart';
import '../services/universal_page_optimization_service.dart';

class OptimizedProfile extends StatefulWidget {
  const OptimizedProfile({super.key});

  @override
  OptimizedProfileState createState() => OptimizedProfileState();
}

class OptimizedProfileState extends State<OptimizedProfile> {
  final UniversalPageOptimizationService _optimizationService =
      UniversalPageOptimizationService();

  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _userProfile;
  List<dynamic>? _orderHistory;
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _initializeProfile();
  }

  Future<void> _initializeProfile() async {
    _optimizationService.trackPagePerformance('profile', 'initialization');

    try {
      // Check auth status and load profile data concurrently
      await Future.wait([
        _checkAuthStatus(),
        _loadProfileData(),
      ]);

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = _optimizationService.getErrorMessage(e);
        });
      }
    } finally {
      _optimizationService.stopPagePerformanceTracking(
          'profile', 'initialization');
    }
  }

  Future<void> _checkAuthStatus() async {
    try {
      final isLoggedIn = await AuthService.isLoggedIn();
      if (mounted) {
        setState(() {
          _isLoggedIn = isLoggedIn;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoggedIn = false;
        });
      }
    }
  }

  Future<void> _loadProfileData() async {
    if (!_isLoggedIn) return;

    try {
      final data = await _optimizationService.optimizeProfilePage(
        fetchUserProfile: _fetchUserProfile,
        fetchOrderHistory: _fetchOrderHistory,
      );

      if (mounted) {
        setState(() {
          _userProfile = data['user_profile'];
          _orderHistory = data['order_history'];
        });
      }
    } catch (e) {
      developer.log('Failed to load profile data: $e', name: 'Profile');
    }
  }

  Future<Map<String, dynamic>> _fetchUserProfile() async {
    try {
      final token = await AuthService.getToken();
      if (token == null) throw Exception('No auth token');

      final response = await http.get(
        Uri.parse('https://eclcommerce.ernestchemists.com.gh/api/user-profile'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to load profile');
      }
    } catch (e) {
      throw Exception('Failed to load profile: $e');
    }
  }

  Future<List<dynamic>> _fetchOrderHistory() async {
    try {
      final token = await AuthService.getToken();
      if (token == null) throw Exception('No auth token');

      final response = await http.get(
        Uri.parse('https://eclcommerce.ernestchemists.com.gh/api/orders'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['orders'] ?? [];
      } else {
        throw Exception('Failed to load orders');
      }
    } catch (e) {
      throw Exception('Failed to load orders: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        leading: BackButtonUtils.simple(),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return _optimizationService.buildLoadingWidget(
        message: 'Loading profile...',
      );
    }

    if (_error != null) {
      return _optimizationService.buildErrorWidget(
        message: _error!,
        onRetry: () {
          setState(() {
            _isLoading = true;
            _error = null;
          });
          _initializeProfile();
        },
      );
    }

    if (!_isLoggedIn) {
      return _optimizationService.buildEmptyStateWidget(
        message: 'Please sign in to view your profile',
        icon: Icons.person_outline,
        onAction: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const SignInScreen()),
        ),
        actionText: 'Sign In',
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildProfileHeader(),
          const SizedBox(height: 24),
          _buildProfileMenu(),
        ],
      ),
    );
  }

  Widget _buildProfileHeader() {
    final name = _userProfile?['name'] ?? 'User';
    final email = _userProfile?['email'] ?? '';
    final avatar = _userProfile?['avatar'] ?? '';

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Profile avatar
            CircleAvatar(
              radius: 40,
              backgroundColor: Colors.grey[200],
              child: avatar.isNotEmpty
                  ? ClipOval(
                      child: _optimizationService.getOptimizedImage(
                        imageUrl:
                            _optimizationService.getOptimizedImageUrl(avatar),
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => const Icon(
                          Icons.person,
                          size: 40,
                          color: Colors.grey,
                        ),
                        errorWidget: (context, url, error) => const Icon(
                          Icons.person,
                          size: 40,
                          color: Colors.grey,
                        ),
                      ),
                    )
                  : const Icon(
                      Icons.person,
                      size: 40,
                      color: Colors.grey,
                    ),
            ),

            const SizedBox(width: 16),

            // Profile info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    email,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${_orderHistory?.length ?? 0} orders',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileMenu() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Account',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        _buildMenuItem(
          icon: Icons.shopping_bag_outlined,
          title: 'My Orders',
          subtitle: 'View your order history',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const PurchaseScreen()),
          ),
        ),
        _buildMenuItem(
          icon: Icons.medical_services_outlined,
          title: 'Prescriptions',
          subtitle: 'Manage your prescriptions',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => const PrescriptionHistoryScreen()),
          ),
        ),
        _buildMenuItem(
          icon: Icons.settings_outlined,
          title: 'Settings',
          subtitle: 'App preferences and account settings',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const SettingsScreen()),
          ),
        ),
        const Divider(height: 32),
        _buildMenuItem(
          icon: Icons.logout,
          title: 'Sign Out',
          subtitle: 'Sign out of your account',
          onTap: _signOut,
          isDestructive: true,
        ),
      ],
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 1,
      child: ListTile(
        leading: Icon(
          icon,
          color: isDestructive ? Colors.red : Colors.green[600],
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: isDestructive ? Colors.red : null,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  Future<void> _signOut() async {
    try {
      await AuthService.logout();
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const SignInScreen()),
        );
      }
    } catch (e) {
      _optimizationService.showErrorSnackBar(
        context,
        'Failed to sign out. Please try again.',
      );
    }
  }
}
