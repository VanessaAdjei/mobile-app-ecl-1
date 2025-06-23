// pages/auth_service.dart
import 'dart:async';
import 'package:eclapp/pages/signinpage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'ProductModel.dart';
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
      print('Initializing AuthService...');

      // Start with a quick local check first
      _authToken = await _secureStorage.read(key: authTokenKey);
      if (_authToken != null) {
        // Set logged in state optimistically, validate in background
        _isLoggedIn = true;
        print('Token found, setting optimistic login state');

        // Validate token in background without blocking
        _validateTokenInBackground();
      } else {
        _isLoggedIn = false;
        print('No token found, user not logged in');
      }

      // Migrate data in background without blocking
      _migrateExistingData().catchError((e) {
        print('Background data migration error: $e');
      });

      print('AuthService initialization complete. Login status: $_isLoggedIn');
    } catch (e) {
      print('Error during AuthService initialization: $e');
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
      print('Error fetching products: $e');
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
      print('Error fetching product details: $e');
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
    print('SignUp request payload: ' + payload.toString());

    try {
      final response = await http
          .post(
            url,
            headers: {"Content-Type": "application/json"},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 30));

      print('SignUp response status: ' + response.statusCode.toString());
      print('SignUp response body: ' + response.body);

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
      print("Error during signup: $e");
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
        print("OTP Verified Successfully!");
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
      print("Error during OTP verification: $e");
      rethrow;
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
      if (_authToken == null) {
        _authToken = await _secureStorage.read(key: authTokenKey);
      }
      return _authToken != null ? 'Bearer $_authToken' : null;
    } catch (e) {
      print('Error getting bearer token: $e');
      return null;
    }
  }

  static Future<void> clearToken() async {
    try {
      print('Clearing token...');
      await _secureStorage.delete(key: authTokenKey);
      _authToken = null;
      _isLoggedIn = false;
      _cachedUserData = null;
      _lastTokenVerification = null;
      _tokenRefreshTimer?.cancel();
      print('Token cleared successfully');
    } catch (e) {
      print('Error clearing token: $e');
    }
  }

  static Future<void> saveToken(String token) async {
    try {
      print('Saving new token...');
      await _secureStorage.write(key: authTokenKey, value: token);
      _authToken = token;
      _isLoggedIn = true;
      _lastTokenVerification = DateTime.now();
      _startTokenRefreshTimer();
      print('Token saved successfully and user is now logged in');
    } catch (e) {
      print('Error saving token: $e');
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
      print('SignIn request payload: ' + payload.toString());

      final response = await http
          .post(
            Uri.parse('$baseUrl/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 30));

      print('SignIn response status: ' + response.statusCode.toString());
      print('SignIn response body: ' + response.body);

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
          print('Storing user data: $userData');
          await storeUserData(userData);

          // Also store individual fields for backward compatibility
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
      print('Error during sign in: $e');
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
        print('Token verification interval exceeded, checking validity...');
        final isValid = await _checkTokenValidity();
        if (!isValid) {
          print('Token validation failed, setting login state to false');
          _isLoggedIn = false;
          return false;
        }
      } else {
        print('Using cached token validation, user is logged in');
      }
      return true;
    }

    // If not in memory, check storage
    if (_authToken == null) {
      print('No token in memory, checking storage...');
      final token = await _secureStorage.read(key: authTokenKey);
      if (token == null) {
        print('No token found in storage');
        _isLoggedIn = false;
        return false;
      }
      _authToken = token;
    }

    // Verify token only if it's been long enough since last verification
    if (_lastTokenVerification == null ||
        DateTime.now().difference(_lastTokenVerification!) >
            _tokenVerificationInterval) {
      print('Verifying token from storage...');
      final isValid = await _checkTokenValidity();
      if (!isValid) {
        print('Token validation failed, setting login state to false');
        _isLoggedIn = false;
        return false;
      }
    } else {
      print('Using cached token validation from storage');
    }

    _isLoggedIn = true;
    print('User is logged in');
    return true;
  }

  // New method to check token validity without clearing it
  static Future<bool> _checkTokenValidity() async {
    if (_authToken == null) return false;

    try {
      print('Checking token validity...');
      final response = await http.get(
        Uri.parse('$baseUrl/verify-token'),
        headers: {
          'Authorization': 'Bearer $_authToken',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      _lastTokenVerification = DateTime.now();
      print('Token validity check response: ${response.statusCode}');

      if (response.statusCode == 200) {
        print('Token is valid');
        return true;
      } else if (response.statusCode == 401) {
        print('Token is invalid (401 Unauthorized)');
        return false;
      } else {
        print('Unexpected response status: ${response.statusCode}');
        // For other status codes, we'll assume the token is still valid
        // to avoid logging out users due to temporary server issues
        return true;
      }
    } on TimeoutException {
      print('Token validation timeout, assuming token is valid');
      _lastTokenVerification = DateTime.now();
      // Don't invalidate token on timeout, assume it's still valid
      return true;
    } on SocketException {
      print('Network error during token validation, assuming token is valid');
      _lastTokenVerification = DateTime.now();
      // Don't invalidate token on network errors, assume it's still valid
      return true;
    } catch (e) {
      print('Error checking token validity: $e');
      _lastTokenVerification = DateTime.now();
      // Don't clear token on other errors, assume it's still valid
      return true;
    }
  }

  // Keep the original _verifyToken method for backward compatibility
  static Future<bool> _verifyToken() async {
    return await _checkTokenValidity();
  }

  //  logout
  static Future<void> logout() async {
    try {
      print('Logging out user...');
      if (_authToken != null) {
        try {
          await http.post(
            Uri.parse('$baseUrl/logout'),
            headers: {'Authorization': 'Bearer $_authToken'},
          ).timeout(const Duration(seconds: 10));
          print('Logout request sent to server');
        } catch (e) {
          print('Error sending logout request to server: $e');
          // Continue with local logout even if server request fails
        }
      }
    } catch (e) {
      debugPrint('Logout error: $e');
    } finally {
      print('Clearing local authentication state...');
      _authToken = null;
      _isLoggedIn = false;
      _cachedUserData = null;
      _lastTokenVerification = null;
      _tokenRefreshTimer?.cancel();
      await _secureStorage.deleteAll();
      print('Logout completed successfully');
    }
  }

  static void _startTokenRefreshTimer() {
    _tokenRefreshTimer?.cancel();
    _tokenRefreshTimer = Timer.periodic(_tokenRefreshInterval, (_) async {
      try {
        if (await isLoggedIn()) {
          print('Token refresh timer: User is still logged in');
          // Only verify if enough time has passed since last verification
          if (_lastTokenVerification == null ||
              DateTime.now().difference(_lastTokenVerification!) >
                  _tokenVerificationInterval) {
            print('Token refresh timer: Checking token validity...');
            await _checkTokenValidity();
          } else {
            print('Token refresh timer: Using cached validation');
          }
        } else {
          print(
              'Token refresh timer: User is no longer logged in, stopping timer');
          _tokenRefreshTimer?.cancel();
        }
      } catch (e) {
        print('Error in token refresh timer: $e');
        // Don't stop the timer on errors, just log them
      }
    });
    print('Token refresh timer started');
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

    // Otherwise, get fresh token
    final token = await getBearerToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': token ?? '',
    };
  }

  static Future<void> storeUserData(Map<String, dynamic> user) async {
    try {
      print('Storing user data: $user');

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

      print('User data stored successfully');
    } catch (e) {
      print("Error saving user data: $e");
      rethrow;
    }
  }

  static Future<Map<String, dynamic>?> getCurrentUser() async {
    try {
      // First check the in-memory cache
      if (_cachedUserData != null) {
        print('Returning cached user data');
        return _cachedUserData;
      }

      print('Fetching user data from storage...');

      // Try to get the consolidated user data first
      final userData = await _secureStorage.read(key: userDataKey);
      if (userData != null) {
        print('Found consolidated user data');
        _cachedUserData = json.decode(userData);
        return _cachedUserData;
      }

      print('Consolidated data not found, checking individual fields...');

      // If consolidated data doesn't exist, try to get individual fields
      final name = await _secureStorage.read(key: userNameKey);
      final email = await _secureStorage.read(key: userEmailKey);
      final phone = await _secureStorage.read(key: userPhoneNumberKey);
      final id = await _secureStorage.read(key: userIdKey);
      final hashedLink = await _secureStorage.read(key: hashedLinkKey);

      if (email != null) {
        print('Found individual user fields, consolidating...');
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

      print('No user data found');
      return null;
    } catch (e) {
      print("Error retrieving user data: $e");
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
      print("Retrieved User Name: $userName");

      return userName?.isNotEmpty == true ? userName : "User";
    } catch (e) {
      print("Error retrieving user name: $e");
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
      print("Error decoding users data: $e");
      return false;
    }
  }

  static Future<String?> getUserEmail() async {
    try {
      return await _secureStorage.read(key: userEmailKey);
    } catch (e) {
      print("❌ Error retrieving user email: $e");
      return null;
    }
  }

  static Future<String?> getUserPhoneNumber() async {
    try {
      return await _secureStorage.read(key: userPhoneNumberKey);
    } catch (e) {
      print("❌ Error retrieving phone number: $e");
      return null;
    }
  }

  static Future<void> debugPrintUserData() async {
    try {
      String? usersData = await _secureStorage.read(key: usersKey);
      print("DEBUG: Users Data: $usersData");
    } catch (e) {
      print("Error retrieving user data for debugging: $e");
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

            print("Entered Hashed Password: $inputHash");
            print("Stored Hashed Password: $storedHash");

            return storedHash == inputHash;
          }
        }
      }
      print("User not found or no password stored.");
      return false;
    } catch (e) {
      print("Error validating password: $e");
      return false;
    }
  }

  static Future<bool> updatePassword(
      String oldPassword, String newPassword) async {
    try {
      if (!(await validateCurrentPassword(oldPassword))) {
        print("Old password does not match.");
        return false;
      }

      String? userEmail = await _secureStorage.read(key: loggedInUserKey);
      if (userEmail != null) {
        String? storedUserJson = await _secureStorage.read(key: usersKey);
        if (storedUserJson != null) {
          Map<String, dynamic> users = jsonDecode(storedUserJson);
          users[userEmail]['password'] = hashPassword(newPassword);

          await _secureStorage.write(key: usersKey, value: jsonEncode(users));
          print("Password updated successfully for $userEmail");
          return true;
        }
      }

      print("Password update failed.");
      return false;
    } catch (e) {
      print("Error updating password: $e");
      return false;
    }
  }

  static Future<void> saveUserName(String username) async {
    await _secureStorage.write(key: userNameKey, value: username);
    print("Username saved: $username");
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
      print('Token used for check-auth: $token');
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
      print('Raw check-auth HTTP response: ${response.body}');

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
    return await _secureStorage.read(key: authTokenKey);
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
    print('\n=== Add to Cart Check Auth ===');
    print('Request details:');
    print('- Product ID: $productID');
    print('- Quantity: $quantity');
    print('- Batch No: $batchNo');

    final token = await _secureStorage.read(key: authTokenKey);
    if (token == null) {
      print('Error: No auth token found');
      return {'status': 'error', 'message': 'Not authenticated'};
    }

    print('\nMaking API request to: $baseUrl/check-auth');
    print('Headers:');
    print('- Authorization: Bearer ${token.substring(0, 20)}...');
    print('- Accept: application/json');
    print('- Content-Type: application/json');

    final requestBody = {
      'productID': productID,
      'quantity': quantity,
      'batch_no': batchNo,
    };
    print('Request body: ${json.encode(requestBody)}');

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

      print('\nResponse details:');
      print('- Status code: ${response.statusCode}');
      print('- Headers:');
      response.headers.forEach((key, value) {
        print('  $key: $value');
      });
      print('- Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        print('\nParsed response data:');
        print(json.encode(data));
        return data;
      } else {
        print('\nError response:');
        print('- Status code: ${response.statusCode}');
        print('- Body: ${response.body}');
        print('\nFull request details:');
        print('- URL: ${response.request?.url}');
        print('- Method: ${response.request?.method}');
        print('- Headers: ${response.request?.headers}');
        print('- Request body: ${json.encode(requestBody)}');
        return {
          'status': 'error',
          'message': 'Failed to add to cart: ${response.statusCode}',
        };
      }
    } catch (e) {
      print('\nException during API call:');
      print(e);
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

      // Add local orders
      allOrders.addAll(localOrders);

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

      // If server fails, try to return local orders only
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
      final token = await getToken();
      if (token == null) {
        return {'status': 'error', 'message': 'Not authenticated'};
      }

      final userId = await getCurrentUserID();
      if (userId == null) {
        return {'status': 'error', 'message': 'User ID not found'};
      }

      // Create order description
      String orderDesc = items
          .map((item) => '${item['quantity']}x ${item['name']}')
          .join(', ');
      if (orderDesc.length > 100) {
        orderDesc = '${orderDesc.substring(0, 97)}...';
      }

      // Add promo code info to order description if applied
      if (promoCode != null) {
        orderDesc += ' (Promo: $promoCode)';
      }

      // Use the expresspayment endpoint with a special flag for cash on delivery
      final requestBody = {
        'request': 'submit',
        'order_id': orderId,
        'currency': 'GHS',
        'amount': totalAmount.toStringAsFixed(2),
        'order_desc': orderDesc,
        'payment_method': paymentMethod,
        'payment_type': 'cash_on_delivery',
        'user_id': userId,
        'account_number': userId,
        'redirect_url': 'http://eclcommerce.test/complete',
        'items': items
            .map((item) => {
                  'product_id': int.tryParse(item['productId'] ?? '0') ?? 0,
                  'product_name': item['name'] ?? 'Unknown Product',
                  'product_img': item['imageUrl'] ?? '',
                  'qty': item['quantity'] ?? 1,
                  'price': (item['price'] ?? 0.0).toDouble(),
                  'batch_no': item['batchNo'] ?? '',
                })
            .toList(),
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      // Add promo code if applied
      if (promoCode != null && promoCode.isNotEmpty) {
        requestBody['promo_code'] = promoCode;
      }

      print('\n=== CREATING CASH ON DELIVERY ORDER ===');
      print('Request URL: $baseUrl/expresspayment');
      print('Request Body: ${jsonEncode(requestBody)}');

      final response = await http
          .post(
            Uri.parse('$baseUrl/expresspayment'),
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(requestBody),
          )
          .timeout(const Duration(seconds: 30));

      print('Response Status: ${response.statusCode}');
      print('Response Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);

        // Check if the response contains errors
        if (data is Map<String, dynamic> && data.containsKey('errors')) {
          print('Backend returned errors, storing order locally');
          return await _storeCashOnDeliveryOrderLocally(
            items: items,
            totalAmount: totalAmount,
            orderId: orderId,
            paymentMethod: paymentMethod,
            promoCode: promoCode,
          );
        }

        return {
          'status': 'success',
          'message': 'Order created successfully',
          'data': data,
        };
      } else {
        // If backend doesn't support cash on delivery orders, store locally
        print(
            'Backend doesn\'t support cash on delivery orders, storing locally');
        return await _storeCashOnDeliveryOrderLocally(
          items: items,
          totalAmount: totalAmount,
          orderId: orderId,
          paymentMethod: paymentMethod,
          promoCode: promoCode,
        );
      }
    } catch (e) {
      print('Error creating cash on delivery order: $e');
      // Fallback to local storage
      return await _storeCashOnDeliveryOrderLocally(
        items: items,
        totalAmount: totalAmount,
        orderId: orderId,
        paymentMethod: paymentMethod,
        promoCode: promoCode,
      );
    }
  }

  /// Store cash on delivery order locally as fallback
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
        print('_storeCashOnDeliveryOrderLocally: User ID is null');
        return {'status': 'error', 'message': 'User ID not found'};
      }

      print('_storeCashOnDeliveryOrderLocally: Storing order for user $userId');
      print('_storeCashOnDeliveryOrderLocally: Order ID: $orderId');
      print('_storeCashOnDeliveryOrderLocally: Total Amount: $totalAmount');
      print('_storeCashOnDeliveryOrderLocally: Items count: ${items.length}');

      // Create order data
      final orderData = {
        'user_id': userId,
        'order_id': orderId,
        'transaction_id': orderId,
        'delivery_id': orderId,
        'payment_method': paymentMethod,
        'status': 'processing',
        'total_price': totalAmount,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
        'items': items
            .map((item) => {
                  'product_name': item['name'] ?? 'Unknown Product',
                  'product_img': item['imageUrl'] ?? '',
                  'qty': item['quantity'] ?? 1,
                  'price': (item['price'] ?? 0.0).toDouble(),
                  'batch_no': item['batchNo'] ?? '',
                })
            .toList(),
      };

      print('_storeCashOnDeliveryOrderLocally: Order data: $orderData');

      // Store in secure storage
      final orderKey = 'local_order_$orderId';
      await _secureStorage.write(
        key: orderKey,
        value: jsonEncode(orderData),
      );

      print('Cash on delivery order stored locally with key: $orderKey');

      return {
        'status': 'success',
        'message': 'Order stored locally successfully',
        'data': orderData,
      };
    } catch (e) {
      print('Error storing order locally: $e');
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
        print('getLocalCashOnDeliveryOrders: User ID is null');
        return [];
      }

      print('getLocalCashOnDeliveryOrders: Fetching orders for user $userId');
      final allKeys = await _secureStorage.readAll();
      print(
          'getLocalCashOnDeliveryOrders: All storage keys: ${allKeys.keys.toList()}');

      final localOrders = <Map<String, dynamic>>[];

      for (final entry in allKeys.entries) {
        if (entry.key.startsWith('local_order_')) {
          print(
              'getLocalCashOnDeliveryOrders: Found local order key: ${entry.key}');
          try {
            final orderData = jsonDecode(entry.value);
            print(
                'getLocalCashOnDeliveryOrders: Order data for ${entry.key}: $orderData');
            if (orderData['user_id'] == userId) {
              localOrders.add(orderData);
              print(
                  'getLocalCashOnDeliveryOrders: Added order for user $userId');
            } else {
              print(
                  'getLocalCashOnDeliveryOrders: Order user_id ${orderData['user_id']} does not match current user $userId');
            }
          } catch (e) {
            print('Error parsing local order: $e');
          }
        }
      }

      print(
          'getLocalCashOnDeliveryOrders: Returning ${localOrders.length} local orders');
      return localOrders;
    } catch (e) {
      print('Error getting local orders: $e');
      return [];
    }
  }

  static Future<void> printStoredToken() async {
    final token = await _secureStorage.read(key: authTokenKey);
    print('AuthService.printStoredToken: '
        '${token != null && token.length > 20 ? token.substring(0, 20) + '...' : token}');
  }

  static Future<void> _validateTokenInBackground() async {
    try {
      final isValid = await _checkTokenValidity();
      if (!isValid) {
        print('Token validation failed in background, updating login state');
        _isLoggedIn = false;
        _authToken = null;
      } else {
        _startTokenRefreshTimer();
      }
    } catch (e) {
      print('Background token validation error: $e');
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
