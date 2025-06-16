// pages/signinpage.dart
import 'package:flutter/material.dart';
import 'package:eclapp/pages/auth_service.dart';
import 'createaccount.dart';
import 'package:provider/provider.dart';
import 'package:eclapp/pages/cartprovider.dart';
import 'forgot_password.dart';
import 'profile.dart';
import 'settings.dart';
import 'purchases.dart';
import 'notifications.dart';
import 'prescription_history.dart';
import 'bulk_purchase_page.dart';

class SignInScreen extends StatefulWidget {
  final String? returnTo;
  final VoidCallback? onSuccess;

  const SignInScreen({super.key, this.onSuccess, this.returnTo});

  @override
  _SignInScreenState createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen>
    with SingleTickerProviderStateMixin {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _isResettingPassword = false;
  String? _errorMessage;
  late final AnimationController _errorAnimationController;
  late final Animation<double> _errorAnimation;

  @override
  void initState() {
    super.initState();
    _errorAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _errorAnimation = CurvedAnimation(
      parent: _errorAnimationController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _errorAnimationController.dispose();
    super.dispose();
  }

  String _getUserFriendlyError(String error) {
    // Network related errors
    if (error.toLowerCase().contains('socketexception') ||
        error.toLowerCase().contains('connection refused') ||
        error.toLowerCase().contains('network is unreachable')) {
      return 'Unable to connect to the server. Please check your internet connection and try again.';
    }

    // Timeout errors
    if (error.toLowerCase().contains('timeout') ||
        error.toLowerCase().contains('timed out')) {
      return 'The request took too long to complete. Please try again.';
    }

    // Authentication errors
    if (error.toLowerCase().contains('invalid-credential') ||
        error.toLowerCase().contains('invalid email or password')) {
      return 'The email or password you entered is incorrect. Please try again.';
    }

    // User not found
    if (error.toLowerCase().contains('user-not-found') ||
        error.toLowerCase().contains('no user found')) {
      return 'No account found with this email. Please check your email or sign up.';
    }

    // Rate limiting
    if (error.toLowerCase().contains('too-many-requests') ||
        error.toLowerCase().contains('rate limit')) {
      return 'Too many attempts. Please wait a few minutes before trying again.';
    }

    // Server errors
    if (error.toLowerCase().contains('500') ||
        error.toLowerCase().contains('internal server error')) {
      return 'We\'re experiencing technical difficulties. Please try again later.';
    }

    // Default error message
    return 'Something went wrong. Please try again.';
  }

  void _showError(String message) {
    if (!mounted) return;

    setState(() {
      _errorMessage = _getUserFriendlyError(message);
    });

    _errorAnimationController.forward(from: 0.0);

    // Auto-hide error after 5 seconds
    Future.delayed(const Duration(seconds: 5), () {
      if (!mounted) return;

      _errorAnimationController.reverse().then((_) {
        if (!mounted) return;
        setState(() {
          _errorMessage = null;
        });
      });
    });
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      print('Starting sign in process...');
      final result = await AuthService.signIn(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );
      print('SignIn result: $result');

      if (result['token'] != null && result['user'] != null) {
        print('Sign in successful, updating auth state...');

        // Get the current AuthState using the of() pattern
        final authState = AuthState.of(context);
        if (authState != null) {
          print('Refreshing auth state...');
          await authState.refreshAuthState();
        } else {
          print('Warning: AuthState not found in context');
        }

        // Sync cart for logged-in user
        final userId = await AuthService.getCurrentUserID();
        if (userId != null) {
          print('Syncing cart for user: $userId');
          await Provider.of<CartProvider>(context, listen: false)
              .handleUserLogin(userId);
        } else {
          print('Warning: Could not get current user ID');
        }

        widget.onSuccess?.call();

        if (widget.returnTo != null && widget.returnTo!.isNotEmpty) {
          print('Navigating to: ${widget.returnTo}');
          // If we have a return path, navigate to it
          final screen = _getScreenForRoute(widget.returnTo!);
          if (mounted) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => screen),
              (route) => false,
            );
          }
        } else {
          print('No return path, going back to previous screen');
          if (mounted) {
            Navigator.of(context).pop(true);
          }
        }
      } else {
        print('Sign in failed: ${result['message']}');
        _showError(result['message'] ??
            'Unable to sign in. Please check your credentials and try again.');
      }
    } catch (e, stackTrace) {
      print('Error during sign in: $e');
      print('Stack trace: $stackTrace');
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Add this helper method to handle route navigation
  Widget _getScreenForRoute(String route) {
    switch (route) {
      case '/profile':
        return const Profile();
      case '/settings':
        return const SettingsScreen();
      case '/purchases':
        return const PurchaseScreen();
      case '/notifications':
        return const NotificationsScreen();
      case '/prescription_history':
        return const PrescriptionHistoryScreen();
      case '/bulk_purchase':
        return const BulkPurchasePage();
      default:
        return const Profile(); // Default to profile if route not found
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background Image with gradient overlay
          Container(
            decoration: BoxDecoration(
              image: const DecorationImage(
                image: AssetImage("assets/images/background.png"),
                fit: BoxFit.cover,
              ),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.3),
                  Colors.black.withOpacity(0.5),
                ],
              ),
            ),
          ),

          // Content
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(height: MediaQuery.of(context).size.height * 0.15),

                  // Title with enhanced styling
                  ShaderMask(
                    shaderCallback: (bounds) => LinearGradient(
                      colors: [Colors.white, Colors.white.withOpacity(0.9)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ).createShader(bounds),
                    child: Text(
                      "Let's Get You\nSigned In",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            offset: const Offset(2, 2),
                            blurRadius: 4,
                            color: Colors.black.withOpacity(0.3),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Error Message with animation
                  if (_errorMessage != null)
                    AnimatedBuilder(
                      animation: _errorAnimation,
                      builder: (context, child) {
                        return SizeTransition(
                          sizeFactor: _errorAnimation,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 20),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.red.shade200),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.red.shade100.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(Icons.info_outline,
                                      color: Colors.red.shade700),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: TextStyle(
                                      color: Colors.red.shade700,
                                      fontSize: 14,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),

                  // Login Form Card with enhanced styling
                  Card(
                    elevation: 8,
                    shadowColor: Colors.black26,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.green.shade400.withOpacity(0.95),
                            Colors.white.withOpacity(0.98),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.all(24),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            // Email Field with enhanced styling
                            TextFormField(
                              controller: _emailController,
                              decoration: InputDecoration(
                                labelText: 'Email',
                                labelStyle:
                                    TextStyle(color: Colors.green.shade700),
                                prefixIcon: Icon(Icons.email,
                                    color: Colors.green.shade700),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide:
                                      BorderSide(color: Colors.green.shade300),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide:
                                      BorderSide(color: Colors.green.shade300),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                      color: Colors.green.shade700, width: 2),
                                ),
                                filled: true,
                                fillColor: Colors.white.withOpacity(0.9),
                                errorStyle:
                                    TextStyle(color: Colors.red.shade700),
                              ),
                              keyboardType: TextInputType.emailAddress,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your email';
                                }
                                if (!value.contains('@') ||
                                    !value.contains('.')) {
                                  return 'Please enter a valid email address';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 20),

                            // Password Field with enhanced styling
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              decoration: InputDecoration(
                                labelText: 'Password',
                                labelStyle:
                                    TextStyle(color: Colors.green.shade700),
                                prefixIcon: Icon(Icons.lock,
                                    color: Colors.green.shade700),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                    color: Colors.green.shade700,
                                  ),
                                  onPressed: () => setState(() =>
                                      _obscurePassword = !_obscurePassword),
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide:
                                      BorderSide(color: Colors.green.shade300),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide:
                                      BorderSide(color: Colors.green.shade300),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                      color: Colors.green.shade700, width: 2),
                                ),
                                filled: true,
                                fillColor: Colors.white.withOpacity(0.9),
                                errorStyle:
                                    TextStyle(color: Colors.red.shade700),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your password';
                                }
                                if (value.length < 6) {
                                  return 'Password must be at least 6 characters';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 24),

                            // Sign In Button with enhanced styling
                            SizedBox(
                              width: double.infinity,
                              height: 54,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _signIn,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green.shade700,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 5,
                                  disabledBackgroundColor:
                                      Colors.green.shade300,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text(
                                        'SIGN IN',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1.2,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Forgot Password with enhanced styling
                            TextButton(
                              onPressed: _isLoading
                                  ? null
                                  : () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              const ForgotPasswordPage(),
                                        ),
                                      );
                                    },
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                              ),
                              child: Text(
                                'Forgot Password?',
                                style: TextStyle(
                                  color: Colors.blue.shade800,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Create Account with enhanced styling
                  TextButton(
                    onPressed: _isLoading
                        ? null
                        : () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => SignUpScreen()),
                            );
                          },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                    ),
                    child: RichText(
                      text: TextSpan(
                        text: "Don't have an account? ",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          height: 1.5,
                        ),
                        children: [
                          TextSpan(
                            text: 'Sign Up',
                            style: TextStyle(
                              color: Colors.blue.shade300,
                              fontWeight: FontWeight.bold,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
