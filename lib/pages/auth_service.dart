// pages/auth_service.dart
import 'dart:async';
import 'package:eclapp/pages/signinpage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'product_model.dart';
import 'dart:io';

class AuthService {
  static const String baseUrl = "https://eclcommerce.ernestchemists.com.gh/api";
  static const String usersKey = "users";
  static const String loggedInUserKey = "loggedInUser";
  static const String isLoggedInKey = "isLoggedIn";
  static const String userNameKey = "userName";
  static const String userEmailKey = "userEmail";
  static const String userPhoneNumberKey = "userPhoneNumber";
  static const String authTokenKey = 'auth_token';
  static const String userDataKey = 'user_data';
  static const String userIdKey = 'user_id';
  static const String hashedLinkKey = 'hashed_link';

  List<Product> products = [];
  List<Product> filteredProducts = [];
  static final FlutterSecureStorage _secureStorage =
      const FlutterSecureStorage();
  static bool _isLoggedIn = false;
  static String? _authToken;
  static Timer? _tokenRefreshTimer;
  static Map<String, dynamic>? _cachedUserData;
  static DateTime? _lastTokenVerification;
  static const Duration _tokenVerificationInterval = Duration(minutes: 15);
  static const Duration _tokenRefreshInterval = Duration(minutes: 30);

  static Future<void> init() async {
    try {
      // Start with a quick local check first
      _authToken = await _secureStorage.read(key: authTokenKey);
      if (_authToken != null) {
        // Set logged in state optimistically, validate in background
        _isLoggedIn = true;
        // Validate token in background without blocking
        _validateTokenInBackground();
      } else {
        _isLoggedIn = false;
      }

      // Migrate data in background without blocking
      _migrateExistingData().catchError((e) {});
    } catch (e) {
      _isLoggedIn = false;
      _authToken = null;
    }
  }

  static Future<void> _migrateExistingData() async {
    try {
      // Check if we already have the new consolidated user data
      final existingUserData = await _secureStorage.read(key: userDataKey);
      if (existingUserData != null) {
        // Data already migrated
        return;
      }

      // Collect all existing user data
      final Map<String, dynamic> userData = {};

      // Migrate individual fields
      final name = await _secureStorage.read(key: userNameKey);
      final email = await _secureStorage.read(key: userEmailKey);
      final phone = await _secureStorage.read(key: userPhoneNumberKey);
      final id = await _secureStorage.read(key: userIdKey);
      final hashedLink = await _secureStorage.read(key: hashedLinkKey);

      // Only add non-null values
      if (name != null) userData['name'] = name;
      if (email != null) userData['email'] = email;
      if (phone != null) userData['phone'] = phone;
      if (id != null) userData['id'] = id;
      if (hashedLink != null) userData['hashed_link'] = hashedLink;

      // Save the consolidated data
      if (userData.isNotEmpty) {
        await _secureStorage.write(
            key: userDataKey, value: json.encode(userData));
        _cachedUserData = userData;
      }

      // Keep the old data for backward compatibility
      // It will be automatically cleaned up in a future update
    } catch (e) {
      debugPrint("Error during data migration: $e");
      // Continue with the app initialization even if migration fails
    }
  }

  static String hashPassword(String password) {
    return sha256.convert(utf8.encode(password)).toString();
  }

  Future<List<Product>> fetchProducts() async {
    try {
      final response = await http.get(
        Uri.parse(
            'https://eclcommerce.ernestchemists.com.gh/api/get-all-products'),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        final List<dynamic> dataList = responseData['data'];

        final products = dataList.map<Product>((item) {
          final productData = item['product'] as Map<String, dynamic>;
          return Product(
            id: productData['id'] ?? 0,
            name: productData['name'] ?? 'No name',
            description: productData['description'] ?? '',
            urlName: productData['url_name'] ?? '',
            status: productData['status'] ?? '',
            batch_no: productData['batch_no'] ?? '',
            price: (item['price'] ?? 0).toString(),
            thumbnail: productData['thumbnail'] ?? '',
            quantity: productData['quantity'] ?? '',
            category: productData['category'] ?? '',
            route: productData['route'] ?? '',
          );
        }).toList();

        return products;
      } else {
        throw Exception('Failed to load: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  static Future<Product> fetchProductDetails(String urlName) async {
    try {
      final response = await http.get(
        Uri.parse(
            'https://eclcommerce.ernestchemists.com.gh/api/product-details/$urlName'),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final productData = data['product'];

        return Product(
          id: productData['id'] ?? 0,
          name: productData['name'] ?? 'No name',
          description: productData['description'] ?? '',
          urlName: productData['url_name'] ?? '',
          status: productData['status'] ?? '',
          category: productData['category'] ?? '',
          route: productData['route'] ?? '',
          batch_no: productData['batch_no'] ?? '',
          price: (productData['price'] ?? 0).toString(),
          thumbnail: productData['thumbnail'] ?? '',
          quantity: productData['qty_in_stock']?.toString() ?? '',
        );
      } else {
        throw Exception('Failed to load product details');
      }
    } catch (e) {
      throw Exception('Could not load product');
    }
  }

  // Sign up  user
  static Future<bool> signUp(
      String name, String email, String password, String phoneNumber) async {
    final url = Uri.parse('$baseUrl/register');

    final payload = {
      "name": name,
      "email": email,
      "password": password,
      "phone": phoneNumber,
    };

    try {
      final response = await http
          .post(
            url,
            headers: {"Content-Type": "application/json"},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 201) {
        return true;
      } else if (response.statusCode == 422) {
        final data = json.decode(response.body);
        final errors = data['errors'] ?? {};
        if (errors['email'] != null) {
          throw Exception(
              'This email is already registered. Please use a different email or sign in.');
        } else if (errors['phone'] != null) {
          throw Exception(
              'This phone number is already registered. Please use a different number.');
        }
        throw Exception('Please check your information and try again.');
      } else if (response.statusCode >= 500) {
        throw Exception(
            'Server is currently unavailable. Please try again later.');
      }

      throw Exception('Unable to create account. Please try again.');
    } on TimeoutException {
      throw Exception(
          'The request took too long to complete. Please try again.');
    } on SocketException {
      throw Exception(
          'Unable to connect to the server. Please check your internet connection.');
    } catch (e) {
      rethrow;
    }
  }

  // OTP
  static Future<bool> verifyOTP(String email, String otp) async {
    final url = Uri.parse(
        'https://eclcommerce.ernestchemists.com.gh/api/otp-verification');

    try {
      final response = await http
          .post(
            url,
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({"email": email, "otp": otp}),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return true;
      } else if (response.statusCode == 400) {
        throw Exception('Invalid OTP. Please check and try again.');
      } else if (response.statusCode == 404) {
        throw Exception('OTP not found. Please request a new OTP.');
      } else if (response.statusCode >= 500) {
        throw Exception(
            'Server is currently unavailable. Please try again later.');
      }

      throw Exception('Unable to verify OTP. Please try again.');
    } on TimeoutException {
      throw Exception(
          'The request took too long to complete. Please try again.');
    } on SocketException {
      throw Exception(
          'Unable to connect to the server. Please check your internet connection.');
    } catch (e) {
      rethrow;
    }
  }

  // Resend OTP
  static Future<Map<String, dynamic>> resendOTP(String email) async {
    final url =
        Uri.parse('https://eclcommerce.ernestchemists.com.gh/api/resend-otp');

    try {
      final response = await http
          .post(
            url,
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({"email": email}),
          )
          .timeout(const Duration(seconds: 30));

      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': responseData['message'] ?? 'OTP resent successfully',
        };
      } else if (response.statusCode == 400) {
        return {
          'success': false,
          'message': responseData['message'] ?? 'Invalid email address',
        };
      } else if (response.statusCode == 404) {
        return {
          'success': false,
          'message': responseData['message'] ?? 'Email not found',
        };
      } else if (response.statusCode >= 500) {
        return {
          'success': false,
          'message': 'Server is currently unavailable. Please try again later.',
        };
      }

      return {
        'success': false,
        'message': responseData['message'] ??
            'Unable to resend OTP. Please try again.',
      };
    } on TimeoutException {
      return {
        'success': false,
        'message': 'The request took too long to complete. Please try again.',
      };
    } on SocketException {
      return {
        'success': false,
        'message':
            'Unable to connect to the server. Please check your internet connection.',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'An unexpected error occurred. Please try again.',
      };
    }
  }

  static Future<String?> getBearerToken() async {
    try {
      // Use cached token if available and not expired
      if (_authToken != null &&
          _lastTokenVerification != null &&
          DateTime.now().difference(_lastTokenVerification!) <=
              _tokenVerificationInterval) {
        return 'Bearer $_authToken';
      }

      // Otherwise, get fresh token
      _authToken ??= await _secureStorage.read(key: authTokenKey);
      return _authToken != null ? 'Bearer $_authToken' : null;
    } catch (e) {
      return null;
    }
  }

  static Future<void> clearToken() async {
    try {
      await _secureStorage.delete(key: authTokenKey);
      _authToken = null;
      _isLoggedIn = false;
      _cachedUserData = null;
      _lastTokenVerification = null;
      _tokenRefreshTimer?.cancel();
    } catch (e) {}
  }

  static Future<void> saveToken(String token) async {
    try {
      await _secureStorage.write(key: authTokenKey, value: token);
      _authToken = token;
      _isLoggedIn = true;
      _lastTokenVerification = DateTime.now();
      _startTokenRefreshTimer();
    } catch (e) {
      _isLoggedIn = false;
      _authToken = null;
    }
  }

  // Force update authentication state without validation
  static Future<void> forceUpdateAuthState() async {
    try {
      final token = await _secureStorage.read(key: authTokenKey);
      if (token != null) {
        _authToken = token;
        _isLoggedIn = true;
        _lastTokenVerification = DateTime.now();
      } else {
        _isLoggedIn = false;
        _authToken = null;
      }
    } catch (e) {
      _isLoggedIn = false;
      _authToken = null;
    }
  }

  // Sign in a  user
  static Future<Map<String, dynamic>> signIn(
      String email, String password) async {
    try {
      final payload = {
        'email': email,
        'password': password,
      };

      final response = await http
          .post(
            Uri.parse('$baseUrl/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 30));

      // Log the full HTTP response for debugging
      debugPrint('=== SIGN IN API RAW RESPONSE ===');
      debugPrint('Status: ${response.statusCode}');
      debugPrint('Body: ${response.body}');
      debugPrint('===============================');

      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        final token = responseData['access_token'];
        if (token == null) {
          return {
            'success': false,
            'message': 'Invalid response from server. Please try again.'
          };
        }

        // Update all state consistently
        await saveToken(token);

        // Store user data if available
        if (responseData['user'] != null) {
          final userData = responseData['user'];
          await storeUserData(userData);

          if (userData['name'] != null) {
            await _secureStorage.write(
                key: userNameKey, value: userData['name']);
          }
          if (userData['email'] != null) {
            await _secureStorage.write(
                key: userEmailKey, value: userData['email']);
          }
          if (userData['phone'] != null) {
            await _secureStorage.write(
                key: userPhoneNumberKey, value: userData['phone']);
          }
          if (userData['id'] != null) {
            await _secureStorage.write(
                key: userIdKey, value: userData['id'].toString());
          }
        }

        // Clear guest_id after successful login
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('guest_id');

        return {
          'success': true,
          'token': token,
          'user': responseData['user'],
        };
      } else if (response.statusCode == 401) {
        return {
          'success': false,
          'message': 'Invalid email or password. Please try again.'
        };
      } else if (response.statusCode == 429) {
        return {
          'success': false,
          'message':
              'Too many attempts. Please wait a few minutes before trying again.'
        };
      } else if (response.statusCode >= 500) {
        return {
          'success': false,
          'message': 'Server is currently unavailable. Please try again later.'
        };
      }

      return {
        'success': false,
        'message':
            responseData['message'] ?? 'Unable to sign in. Please try again.'
      };
    } on TimeoutException {
      return {
        'success': false,
        'message': 'The request took too long to complete. Please try again.'
      };
    } on SocketException {
      return {
        'success': false,
        'message':
            'Unable to connect to the server. Please check your internet connection.'
      };
    } on FormatException {
      return {
        'success': false,
        'message': 'Invalid response from server. Please try again.'
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'An unexpected error occurred. Please try again.'
      };
    }
  }

  static Future<bool> isLoggedIn() async {
    // First check memory state
    if (_isLoggedIn && _authToken != null) {
      // Only verify token if enough time has passed since last verification
      if (_lastTokenVerification == null ||
          DateTime.now().difference(_lastTokenVerification!) >
              _tokenVerificationInterval) {
        final isValid = await _checkTokenValidity();
        if (!isValid) {
          _isLoggedIn = false;
          return false;
        }
      }
      return true;
    }

    // If not in memory, check storage
    if (_authToken == null) {
      final token = await _secureStorage.read(key: authTokenKey);
      if (token == null) {
        _isLoggedIn = false;
        return false;
      }
      _authToken = token;
    }

    // Verify token only if it's been long enough since last verification
    if (_lastTokenVerification == null ||
        DateTime.now().difference(_lastTokenVerification!) >
            _tokenVerificationInterval) {
      final isValid = await _checkTokenValidity();
      if (!isValid) {
        _isLoggedIn = false;
        return false;
      }
    }

    _isLoggedIn = true;
    return true;
  }

  // New method to check token validity without clearing it
  static Future<bool> _checkTokenValidity() async {
    if (_authToken == null) return false;

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/verify-token'),
        headers: {
          'Authorization': 'Bearer $_authToken',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      _lastTokenVerification = DateTime.now();
      if (response.statusCode == 200) {
        return true;
      } else if (response.statusCode == 401) {
        return false;
      } else {
        // For other status codes, we'll assume the token is still valid
        // to avoid logging out users due to temporary server issues
        return true;
      }
    } on TimeoutException {
      _lastTokenVerification = DateTime.now();
      // Don't invalidate token on timeout, assume it's still valid
      return true;
    } on SocketException {
      _lastTokenVerification = DateTime.now();
      // Don't invalidate token on network errors, assume it's still valid
      return true;
    } catch (e) {
      _lastTokenVerification = DateTime.now();
      // Don't clear token on other errors, assume it's still valid
      return true;
    }
  }

  //  logout
  static Future<void> logout() async {
    try {
      if (_authToken != null) {
        try {
          await http.post(
            Uri.parse('$baseUrl/logout'),
            headers: {'Authorization': 'Bearer $_authToken'},
          ).timeout(const Duration(seconds: 10));
        } catch (e) {
          debugPrint('Server logout failed: $e');
          // Continue with local logout even if server request fails
        }
      }
    } catch (e) {
      debugPrint('Logout error: $e');
    } finally {
      _authToken = null;
      _isLoggedIn = false;
      _cachedUserData = null;
      _lastTokenVerification = null;
      _tokenRefreshTimer?.cancel();
      await _secureStorage.deleteAll();
    }
  }

  static void _startTokenRefreshTimer() {
    _tokenRefreshTimer?.cancel();
    _tokenRefreshTimer = Timer.periodic(_tokenRefreshInterval, (_) async {
      try {
        if (await isLoggedIn()) {
          // Only verify if enough time has passed since last verification
          if (_lastTokenVerification == null ||
              DateTime.now().difference(_lastTokenVerification!) >
                  _tokenVerificationInterval) {
            await _checkTokenValidity();
          }
        } else {
          _tokenRefreshTimer?.cancel();
        }
      } catch (e) {
        debugPrint('Token refresh timer error: $e');
        // Don't stop the timer on errors, just log them
      }
    });
  }

  static Future<Map<String, String>> getAuthHeaders() async {
    // Use cached token if available and not expired
    if (_authToken != null &&
        _lastTokenVerification != null &&
        DateTime.now().difference(_lastTokenVerification!) <=
            _tokenVerificationInterval) {
      return {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $_authToken',
      };
    }

    // Otherwise, get fresh token or guest_id
    final token = await getToken();
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (token != null && token.startsWith('0|')) {
      headers['X-Guest-Id'] = token;
    } else if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  static Future<void> storeUserData(Map<String, dynamic> user) async {
    try {
      // Update the in-memory cache first
      _cachedUserData = Map<String, dynamic>.from(user);

      // Save the consolidated user data
      await _secureStorage.write(key: userDataKey, value: json.encode(user));

      // Also save individual fields for backward compatibility
      if (user['name'] != null) {
        await _secureStorage.write(key: userNameKey, value: user['name']);
      }
      if (user['email'] != null) {
        await _secureStorage.write(key: userEmailKey, value: user['email']);
      }
      if (user['phone'] != null) {
        await _secureStorage.write(
            key: userPhoneNumberKey, value: user['phone']);
      }
      if (user['id'] != null) {
        await _secureStorage.write(
            key: userIdKey, value: user['id'].toString());
      }
      if (user['hashed_link'] != null) {
        await _secureStorage.write(
            key: hashedLinkKey, value: user['hashed_link']);
      }
    } catch (e) {
      rethrow;
    }
  }

  static Future<Map<String, dynamic>?> getCurrentUser() async {
    try {
      // First check the in-memory cache
      if (_cachedUserData != null) {
        return _cachedUserData;
      }

      // Try to get the consolidated user data first
      final userData = await _secureStorage.read(key: userDataKey);
      if (userData != null) {
        _cachedUserData = json.decode(userData);
        return _cachedUserData;
      }

      // If consolidated data doesn't exist, try to get individual fields
      final name = await _secureStorage.read(key: userNameKey);
      final email = await _secureStorage.read(key: userEmailKey);
      final phone = await _secureStorage.read(key: userPhoneNumberKey);
      final id = await _secureStorage.read(key: userIdKey);
      final hashedLink = await _secureStorage.read(key: hashedLinkKey);

      if (email != null) {
        final Map<String, dynamic> userData = {
          'name': name,
          'email': email,
          'phone': phone,
          'id': id,
          'hashed_link': hashedLink,
        };

        // Cache the consolidated data
        _cachedUserData = userData;

        // Save as consolidated data for future use
        await storeUserData(userData);
        return userData;
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<void> saveUserDetails(
      String name, String email, String phone) async {
    try {
      final userData = await getCurrentUser() ?? {};
      userData['name'] = name;
      userData['email'] = email;
      userData['phone'] = phone;
      await storeUserData(userData);
    } catch (e) {
      debugPrint("Error saving user details: $e");
    }
  }

  static Future<String?> getUserName() async {
    try {
      String? userName = await _secureStorage.read(key: userNameKey);
      return userName?.isNotEmpty == true ? userName : "User";
    } catch (e) {
      return "User";
    }
  }

  Future<void> saveProfileImage(String imagePath) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('profile_image', imagePath);
  }

  static Future<String?> getProfileImage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('profile_image');
  }

  static Future<String?> getCurrentUserID() async {
    final userData = await getCurrentUser();
    return userData?['id']?.toString();
  }

  static bool isValidJwt(String token) {
    final parts = token.split('.');
    return parts.length == 3;
  }

  static Future<bool> isUserSignedUp(String email) async {
    try {
      String? usersData = await _secureStorage.read(key: usersKey);
      if (usersData == null) return false;

      Map<String, dynamic> rawUsers = json.decode(usersData);
      Map<String, Map<String, String>> users = rawUsers.map(
        (key, value) => MapEntry(key, Map<String, String>.from(value)),
      );

      return users.containsKey(email);
    } catch (e) {
      return false;
    }
  }

  static Future<String?> getUserEmail() async {
    try {
      return await _secureStorage.read(key: userEmailKey);
    } catch (e) {
      return null;
    }
  }

  static Future<String?> getUserPhoneNumber() async {
    try {
      return await _secureStorage.read(key: userPhoneNumberKey);
    } catch (e) {
      return null;
    }
  }



  static Future<bool> validateCurrentPassword(String password) async {
    try {
      String? userEmail = await _secureStorage.read(key: loggedInUserKey);
      if (userEmail != null) {
        String? storedUserJson = await _secureStorage.read(key: usersKey);
        if (storedUserJson != null) {
          Map<String, dynamic> users = jsonDecode(storedUserJson);

          if (users.containsKey(userEmail)) {
            String storedHash = users[userEmail]['password'];
            String inputHash = hashPassword(password);

            return storedHash == inputHash;
          }
        }
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> updatePassword(
      String oldPassword, String newPassword) async {
    try {
      if (!(await validateCurrentPassword(oldPassword))) {
        return false;
      }

      String? userEmail = await _secureStorage.read(key: loggedInUserKey);
      if (userEmail != null) {
        String? storedUserJson = await _secureStorage.read(key: usersKey);
        if (storedUserJson != null) {
          Map<String, dynamic> users = jsonDecode(storedUserJson);
          users[userEmail]['password'] = hashPassword(newPassword);

          await _secureStorage.write(key: usersKey, value: jsonEncode(users));
          return true;
        }
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  static Future<void> saveUserName(String username) async {
    await _secureStorage.write(key: userNameKey, value: username);
  }

  static Future<void> checkAuthAndRedirect(BuildContext context,
      {VoidCallback? onSuccess}) async {
    final isLoggedIn = await AuthService.isLoggedIn();

    if (!isLoggedIn) {
      final currentRoute = ModalRoute.of(context)?.settings.name ?? '/';

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SignInScreen(returnTo: currentRoute),
        ),
      );

      final stillLoggedIn = await AuthService.isLoggedIn();
      if (stillLoggedIn && onSuccess != null) {
        onSuccess();
      }
    } else if (onSuccess != null) {
      onSuccess();
    }
  }

  static Future<bool> checkAuthStatus() async {
    try {
      final token = await _secureStorage.read(key: authTokenKey);
      if (token == null) return false;

      final response = await http.post(
        Uri.parse('$baseUrl/check-auth'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['status'] == 'success';
      }
      return false;
    } catch (e) {
      debugPrint('Auth check error: $e');
      return false;
    }
  }

  Future<bool> requireAuth(BuildContext context) async {
    if (await AuthService.isLoggedIn()) return true;

    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => SignInScreen(
          returnTo: ModalRoute.of(context)?.settings.name,
        ),
      ),
    );

    return result ?? false;
  }

  static Future<Map<String, dynamic>> checkAuthWithCart() async {
    try {
      final token = await getToken();
      if (token == null) return {'authenticated': false};

      final response = await http.post(
        Uri.parse('$baseUrl/check-auth'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({}),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'authenticated': true,
          'items': data['items'] ?? [],
          'totalPrice': data['totalPrice'] ?? 0,
        };
      }
      return {};
    } catch (e) {
      debugPrint('Auth check error: $e');
      return {'authenticated': false};
    }
  }

  static Future<Map<String, dynamic>> getServerCart() async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final response = await http.get(
        Uri.parse('$baseUrl/cart'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'cart': data['items'] ?? [],
          'lastUpdated': data['updated_at'],
        };
      } else {
        return {
          'success': false,
          'message': 'Failed to fetch cart: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Exception: $e',
      };
    }
  }

  // Add this to your AuthService class
  static Future<String?> getToken() async {
    final loggedIn = await isLoggedIn();
    if (loggedIn) {
      return await _secureStorage.read(key: authTokenKey);
    }
    // Only retrieve a persistent guest id for non-logged-in users if it already exists
    final prefs = await SharedPreferences.getInstance();
    String? guestId = prefs.getString('guest_id');
    if (!loggedIn && guestId != null) {
      debugPrint('[AuthService] Using existing guest_id: $guestId');
      return guestId;
    }
    return null;
  }

  /// Clear all guest_id keys from SharedPreferences
  static Future<void> clearAllGuestIds() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('guest_id');
  }

  /// Generate and store a new guest_id in SharedPreferences
  static Future<String> generateGuestId() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final response = await http.get(
        Uri.parse('https://eclcommerce.ernestchemists.com.gh/api/guest-id'),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final guestId = data['guest_id'] ??
            data['id'] ??
            data['guestId'] ??
            data['guestid'];
        if (guestId != null && guestId is String && guestId.isNotEmpty) {
          await prefs.setString('guest_id', guestId);
          debugPrint('[AuthService] Fetched guest_id from API: $guestId');
          return guestId;
        } else {
          throw Exception('Invalid guest_id in API response');
        }
      } else {
        throw Exception('Failed to fetch guest_id from API');
      }
    } catch (e) {
      debugPrint('[AuthService] Error fetching guest_id: $e');
      rethrow;
    }
  }

  static Future<void> syncCartOnLogin(String userId) async {
    try {
      // 1. Get server cart first
      final serverCart = await getServerCart();

      if (serverCart['success']) {
        // 2. Merge with local cart if needed
        await mergeCarts(serverCart['cart']);
      }
    } catch (e) {
      debugPrint('Cart sync error: $e');
    }
  }

  static Future<void> mergeCarts(List<dynamic> serverItems) async {
    final prefs = await SharedPreferences.getInstance();
    final localCart = prefs.getString('local_cart');

    if (localCart != null) {
      // Implement your merge logic here
      // Compare timestamps or quantities to resolve conflicts
    }

    // Save the merged cart
    await prefs.setString('local_cart', jsonEncode(serverItems));
  }

  static Future<Map<String, dynamic>> updateServerCart(
      List<Map<String, dynamic>> items) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final response = await http.post(
        Uri.parse('$baseUrl/cart/update'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'items': items,
          'last_updated': DateTime.now().toIso8601String(),
        }),
      );

      if (response.statusCode == 200) {
        return {'success': true};
      } else {
        return {
          'success': false,
          'message': 'Failed to update cart: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Exception: $e',
      };
    }
  }

  static Future<Map<String, dynamic>> mergeServerCart(
      List<Map<String, dynamic>> items) async {
    try {
      final token = await getBearerToken();
      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final response = await http.post(
        Uri.parse('$baseUrl/cart/merge'),
        headers: {
          'Authorization': token,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'items': items}),
      );

      if (response.statusCode == 200) {
        return {
          'success': true,
          'cart': json.decode(response.body),
        };
      }
      return {'success': false, 'message': 'Failed to merge cart'};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> addToCartCheckAuth({
    required int productID,
    required int quantity,
    required String batchNo,
  }) async {
    final token = await _secureStorage.read(key: authTokenKey);
    if (token == null) {
      return {'status': 'error', 'message': 'Not authenticated'};
    }

    final requestBody = {
      'productID': productID,
      'quantity': quantity,
      'batch_no': batchNo,
    };
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/check-auth'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: json.encode(requestBody),
      );

      response.headers.forEach((key, value) {});
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        debugPrint(json.encode(data));
        return data;
      } else {
        return {
          'status': 'error',
          'message': 'Failed to add to cart: ${response.statusCode}',
        };
      }
    } catch (e) {
      debugPrint('Error: $e');
      return {
        'status': 'error',
        'message': 'Exception: $e',
      };
    }
  }

  static Future<String?> getHashedLink() async {
    return await _secureStorage.read(key: 'hashed_link');
  }

  static Future<Map<String, dynamic>> getOrders() async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'status': 'error', 'message': 'Not authenticated'};
      }

      final response = await http.get(
        Uri.parse('$baseUrl/orders'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      debugPrint('Orders API response status: \\${response.statusCode}');
      debugPrint('Orders API response body: \\${response.body}');

      final data = jsonDecode(response.body);

      // Get locally stored cash on delivery orders
      final localOrders = await getLocalCashOnDeliveryOrders();

      // Combine server orders with local orders
      List<dynamic> allOrders = [];

      if (data is Map<String, dynamic> && data['data'] is List) {
        allOrders.addAll(data['data'] as List);
      }

      for (final localOrder in localOrders) {
        final localOrderId =
            localOrder['order_id'] ?? localOrder['transaction_id'] ?? '';
        final localDeliveryId = localOrder['delivery_id'] ?? '';

        bool existsOnServer = false;
        for (final serverOrder in allOrders) {
          final serverOrderId =
              serverOrder['order_id'] ?? serverOrder['transaction_id'] ?? '';
          final serverDeliveryId = serverOrder['delivery_id'] ?? '';

          if ((localOrderId.isNotEmpty && localOrderId == serverOrderId) ||
              (localDeliveryId.isNotEmpty &&
                  localDeliveryId == serverDeliveryId)) {
            existsOnServer = true;
            debugPrint(
                'Local order $localOrderId already exists on server, skipping duplicate');
            break;
          }
        }

        if (!existsOnServer) {
          allOrders.add(localOrder);
          debugPrint('Added local order $localOrderId to combined list');
        }
      }

      // Sort all orders by creation date (newest first)
      allOrders.sort((a, b) {
        final dateA =
            DateTime.tryParse(a['created_at'] ?? '') ?? DateTime(1970);
        final dateB =
            DateTime.tryParse(b['created_at'] ?? '') ?? DateTime(1970);
        return dateB.compareTo(dateA);
      });

      return {
        'status': 'success',
        'data': allOrders,
        'message': 'Orders retrieved successfully',
      };
    } catch (e) {
      debugPrint('Error fetching orders: $e');

      try {
        final localOrders = await getLocalCashOnDeliveryOrders();
        return {
          'status': 'success',
          'data': localOrders,
          'message': 'Retrieved local orders only (server unavailable)',
        };
      } catch (localError) {
        return {
          'status': 'error',
          'message': 'Exception: $e',
        };
      }
    }
  }

  /// Create a cash on delivery order in the backend
  static Future<Map<String, dynamic>> createCashOnDeliveryOrder({
    required List<Map<String, dynamic>> items,
    required double totalAmount,
    required String orderId,
    required String paymentMethod,
    String? promoCode,
  }) async {
    try {
      final userId = await getCurrentUserID();
      if (userId == null) {
        return {'status': 'error', 'message': ''};
      }

      return await _storeCashOnDeliveryOrderLocally(
        items: items,
        totalAmount: totalAmount,
        orderId: orderId,
        paymentMethod: paymentMethod,
        promoCode: promoCode,
      );
    } catch (e) {
      return {
        'status': 'error',
        'message': 'Failed to create COD order: $e',
      };
    }
  }

  static Future<Map<String, dynamic>> _storeCashOnDeliveryOrderLocally({
    required List<Map<String, dynamic>> items,
    required double totalAmount,
    required String orderId,
    required String paymentMethod,
    String? promoCode,
  }) async {
    try {
      final userId = await getCurrentUserID();
      if (userId == null) {
        return {'status': 'error', 'message': 'User ID not found'};
      }

      final now = DateTime.now();
      final timestamp = now.toIso8601String();

      // Create individual order items for each product (similar to server structure)
      final orderItems = items
          .map((item) => {
                'id':
                    DateTime.now().millisecondsSinceEpoch + items.indexOf(item),
                'user_id': userId,
                'delivery_id': orderId,
                'payment_type': paymentMethod,
                'product_name': item['name'] ?? 'Unknown Product',
                'product_id': int.tryParse(item['productId'] ?? '0') ?? 0,
                'product_img': item['imageUrl'] ?? '',
                'batch_no': item['batchNo'] ?? '',
                'restricted': null,
                'served_by': null,
                'refill': null,
                'price': (item['price'] ?? 0.0).toDouble(),
                'qty': item['quantity'] ?? 1,
                'total_price': ((item['price'] ?? 0.0).toDouble() *
                    (item['quantity'] ?? 1)),
                'status': 'Order Placed',
                'created_at': timestamp, // Use same timestamp for all items
                'updated_at': timestamp,
              })
          .toList();

      // Store the grouped order as a single entity
      final groupedOrder = {
        'order_id': orderId,
        'delivery_id': orderId,
        'transaction_id': orderId,
        'user_id': userId,
        'payment_type': paymentMethod,
        'payment_method': paymentMethod,
        'total_price': totalAmount,
        'status': 'Order Placed',
        'created_at': timestamp,
        'updated_at': timestamp,
        'items': orderItems,
        'is_multi_item': items.length > 1,
        'item_count': items.length,
      };

      // Store the grouped order
      final orderKey = 'local_grouped_order_$orderId';
      await _secureStorage.write(
        key: orderKey,
        value: jsonEncode(groupedOrder),
      );

      // Also store individual items for backward compatibility
      for (final orderItem in orderItems) {
        final itemKey = 'local_order_${orderId}_${orderItem['id']}';
        await _secureStorage.write(
          key: itemKey,
          value: jsonEncode(orderItem),
        );
      }

      return {
        'status': 'success',
        'message': 'COD order stored locally successfully',
        'data': {
          'order_id': orderId,
          'items': orderItems,
          'total_amount': totalAmount,
          'payment_method': paymentMethod,
        },
      };
    } catch (e) {
      return {
        'status': 'error',
        'message': 'Failed to store order locally: $e',
      };
    }
  }

  /// Get locally stored cash on delivery orders
  static Future<List<Map<String, dynamic>>>
      getLocalCashOnDeliveryOrders() async {
    try {
      final userId = await getCurrentUserID();
      if (userId == null) {
        return [];
      }

      final allKeys = await _secureStorage.readAll();
      final localOrders = <Map<String, dynamic>>[];
      final processedOrderIds = <String>{};

      // First, look for grouped orders
      for (final entry in allKeys.entries) {
        if (entry.key.startsWith('local_grouped_order_')) {
          try {
            final orderData = jsonDecode(entry.value);
            if (orderData['user_id'] == userId) {
              localOrders.add(orderData);
              processedOrderIds.add(orderData['order_id'] ?? '');
            }
          } catch (e) {
            // Skip invalid entries
          }
        }
      }

      // Then, look for individual items and group them by delivery_id
      final individualItems = <String, List<Map<String, dynamic>>>{};

      for (final entry in allKeys.entries) {
        if (entry.key.startsWith('local_order_')) {
          try {
            final orderData = jsonDecode(entry.value);
            if (orderData['user_id'] == userId) {
              final deliveryId =
                  orderData['delivery_id'] ?? orderData['order_id'] ?? '';

              // Only process individual items if we don't already have a grouped order for this deliveryId
              if (!processedOrderIds.contains(deliveryId)) {
                if (!individualItems.containsKey(deliveryId)) {
                  individualItems[deliveryId] = [];
                }
                individualItems[deliveryId]!.add(orderData);
              }
            }
          } catch (e) {
            // Skip invalid entries
          }
        }
      }

      // Convert grouped individual items to grouped orders
      for (final entry in individualItems.entries) {
        final deliveryId = entry.key;
        final items = entry.value;

        if (items.isNotEmpty) {
          final firstItem = items.first;
          final totalAmount = items.fold<double>(0.0, (sum, item) {
            return sum + ((item['total_price'] ?? 0.0).toDouble());
          });

          final groupedOrder = {
            'order_id': deliveryId,
            'delivery_id': deliveryId,
            'transaction_id': deliveryId,
            'user_id': firstItem['user_id'],
            'payment_type': firstItem['payment_type'],
            'payment_method': firstItem['payment_type'],
            'total_price': totalAmount,
            'status': firstItem['status'] ?? 'Order Placed',
            'created_at': firstItem['created_at'],
            'updated_at': firstItem['updated_at'],
            'items': items,
            'is_multi_item': items.length > 1,
            'item_count': items.length,
          };

          localOrders.add(groupedOrder);
        }
      }

      return localOrders;
    } catch (e) {
      return [];
    }
  }

  static Future<void> printStoredToken() async {
    final token = await _secureStorage.read(key: authTokenKey);
    debugPrint('AuthService.printStoredToken: '
        '${token != null && token.length > 20 ? '${token.substring(0, 20)}...' : token}');
  }

  static Future<void> _validateTokenInBackground() async {
    try {
      final isValid = await _checkTokenValidity();
      if (!isValid) {
        _isLoggedIn = false;
        _authToken = null;
      } else {
        _startTokenRefreshTimer();
      }
    } catch (e) {
      // Keep current state on error
    }
  }
}

class AuthWrapper extends StatelessWidget {
  final Widget child;

  const AuthWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: AuthService.isLoggedIn(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }

        if (!snapshot.hasData || !snapshot.data!) {
          return SignInScreen(
            returnTo: ModalRoute.of(context)?.settings.name,
          );
        }

        return child;
      },
    );
  }
}

class AuthState extends InheritedWidget {
  final bool isLoggedIn;
  final Function() refreshAuthState;

  const AuthState({
    required this.isLoggedIn,
    required this.refreshAuthState,
    required super.child,
    super.key,
  });

  static AuthState? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AuthState>();
  }

  @override
  bool updateShouldNotify(AuthState oldWidget) {
    return isLoggedIn != oldWidget.isLoggedIn;
  }
}

class CODPaymentService {
  static const String _baseUrl =
      'https://eclcommerce.ernestchemists.com.gh/api';
  static const String _codEndpoint = '/pay-on-delivery';

  /// Process COD payment with the provided parameters
  static Future<Map<String, dynamic>> processCODPayment({
    required String firstName,
    required String email,
    required String phone,
    required double amount,
    String? authToken,
  }) async {
    debugPrint('[DEBUG] Entered CODPaymentService.processCODPayment');
    try {
      final url = Uri.parse('$_baseUrl$_codEndpoint');

      // Prepare request headers
      final headers = {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      };

      // Add authorization header if token is provided
      if (authToken != null && authToken.isNotEmpty) {
        if (authToken.startsWith('guest_')) {
          headers['Authorization'] = 'Guest $authToken';
          headers['X-Guest-ID'] = authToken;
        } else {
          headers['Authorization'] = 'Bearer $authToken';
        }
      }

      // Prepare request body
      final requestBody = {
        'fname': firstName,
        'email': email,
        'phone': phone,
        'amount': amount.toStringAsFixed(2),
      };

      debugPrint('COD Payment Request: \\${json.encode(requestBody)}');
      debugPrint('[DEBUG] COD Payment API Request Headers: $headers');
      debugPrint(
          '[DEBUG] COD Payment API Request Body: ${json.encode(requestBody)}');
      // Make the API call
      final response = await http
          .post(
        url,
        headers: headers,
        body: json.encode(requestBody),
      )
          .timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Request timed out. Please try again.');
        },
      );

      // Print the raw HTTP response for debugging (always)
      debugPrint(
          '[DEBUG] COD Payment API HTTP Status: \\${response.statusCode}');
      debugPrint('[DEBUG] COD Payment API HTTP Body: \\${response.body}');

      // Handle different response status codes
      if (response.statusCode == 200 || response.statusCode == 201) {
        try {
          final responseData = json.decode(response.body);
          return {
            'success': true,
            'data': responseData,
            'message':
                responseData['message'] ?? 'COD payment processed successfully',
          };
        } catch (e) {
          // Handle case where response is not JSON
          return {
            'success': true,
            'data': {'raw_response': response.body},
            'message': 'COD payment processed successfully',
          };
        }
      } else if (response.statusCode == 401) {
        return {
          'success': false,
          'message': 'Authentication required. Please log in again.',
          'error_code': 'UNAUTHORIZED',
          'status_code': response.statusCode,
          'body': response.body,
        };
      } else if (response.statusCode == 422) {
        try {
          final errorData = json.decode(response.body);
          return {
            'success': false,
            'message': errorData['message'] ?? 'Invalid request parameters',
            'errors': errorData['errors'],
            'error_code': 'VALIDATION_ERROR',
            'status_code': response.statusCode,
            'body': response.body,
          };
        } catch (e) {
          return {
            'success': false,
            'message': 'Invalid request parameters',
            'error_code': 'VALIDATION_ERROR',
            'status_code': response.statusCode,
            'body': response.body,
          };
        }
      } else if (response.statusCode >= 500) {
        return {
          'success': false,
          'message': 'Server error. Please try again later.',
          'error_code': 'SERVER_ERROR',
          'status_code': response.statusCode,
          'body': response.body,
        };
      } else {
        return {
          'success': false,
          'message': 'Payment failed. Please try again.',
          'error_code': 'UNKNOWN_ERROR',
          'status_code': response.statusCode,
          'body': response.body,
        };
      }
    } catch (e) {
      debugPrint('COD Payment Error: \\${e.toString()}');
      return {
        'success': false,
        'message': 'Payment failed: \\${e.toString()}',
        'error_code': 'EXCEPTION',
      };
    }
  }

  /// Validate COD payment parameters
  static Map<String, dynamic> validateParameters({
    required String firstName,
    required String email,
    required String phone,
    required double amount,
  }) {
    final errors = <String, String>{};

    // Validate first name
    if (firstName.trim().isEmpty) {
      errors['fname'] = 'First name is required';
    }

    // Validate email
    if (email.trim().isEmpty) {
      errors['email'] = 'Email is required';
    } else if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      errors['email'] = 'Please enter a valid email address';
    }

    // Validate phone
    if (phone.trim().isEmpty) {
      errors['phone'] = 'Phone number is required';
    } else if (!RegExp(r'^\+?[\d\s\-\(\)]+$').hasMatch(phone)) {
      errors['phone'] = 'Please enter a valid phone number';
    }

    // Validate amount
    if (amount <= 0) {
      errors['amount'] = 'Amount must be greater than 0';
    }

    return {
      'isValid': errors.isEmpty,
      'errors': errors,
    };
  }
}
