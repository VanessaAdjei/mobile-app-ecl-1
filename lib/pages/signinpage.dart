// pages/signinpage.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:eclapp/pages/forgot_password.dart';
import 'package:eclapp/pages/homepage.dart';
import 'package:eclapp/pages/createaccount.dart';
import 'package:eclapp/pages/auth_service.dart';
import 'package:eclapp/pages/authprovider.dart';
import 'package:eclapp/pages/cartprovider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SignInScreen extends StatefulWidget {
  final String? returnTo;
  final VoidCallback? onSuccess;

  const SignInScreen({super.key, this.onSuccess, this.returnTo});

  @override
  SignInScreenState createState() => SignInScreenState();
}

class SignInScreenState extends State<SignInScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _errorMessage = null;
  }

  @override
  void dispose() {
    _errorMessage = null;
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String _getUserFriendlyError(String error) {
    final lowerError = error.toLowerCase();

    if (lowerError.contains('socketexception') ||
        lowerError.contains('connection refused') ||
        lowerError.contains('network is unreachable')) {
      return 'Oops! We couldn\'t reach our servers. Please check your internet connection and try again.';
    }

    // timeout errors
    if (lowerError.contains('timeout') || lowerError.contains('timed out')) {
      return 'This is taking longer than usual. Please check your connection and try again.';
    }

    // wrong email/password errors
    if (lowerError.contains('invalid-credential') ||
        lowerError.contains('invalid email or password') ||
        lowerError.contains('login information invalid')) {
      return 'The email or password you entered doesn\'t match our records. Please double-check and try again.';
    }

    // user doesnt exist
    if (lowerError.contains('user-not-found') ||
        lowerError.contains('no user found')) {
      return 'We couldn\'t find an account with this email. Please check your email address or create a new account.';
    }

    // too many login attempts
    if (lowerError.contains('too-many-requests') ||
        lowerError.contains('rate limit')) {
      return 'You\'ve tried signing in too many times. Please wait a few minutes and try again.';
    }

    // server errors
    if (lowerError.contains('500') ||
        lowerError.contains('internal server error')) {
      return 'We\'re experiencing some technical issues on our end. Please try again in a few moments.';
    }

    // default error message
    return 'Something unexpected happened. Please try again, and if the problem persists, contact support.';
  }

  String _getErrorTitle(String message) {
    final lowerMessage = message.toLowerCase();

    if (lowerMessage.contains('email') ||
        lowerMessage.contains('password') ||
        lowerMessage.contains('credentials') ||
        lowerMessage.contains('invalid')) {
      return 'Couldn\'t Sign You In';
    }

    if (lowerMessage.contains('connection') ||
        lowerMessage.contains('network') ||
        lowerMessage.contains('internet')) {
      return 'Connection Issue';
    }

    if (lowerMessage.contains('server') ||
        lowerMessage.contains('unavailable')) {
      return 'Service Temporarily Unavailable';
    }

    if (lowerMessage.contains('too many') ||
        lowerMessage.contains('attempts')) {
      return 'Too Many Attempts';
    }

    return 'Oops! Something Went Wrong';
  }

  String _enhanceErrorMessage(String message) {
    final lowerMessage = message.toLowerCase();

    // make api error messages nicer and easier to understand
    if (lowerMessage.contains('login information invalid') ||
        lowerMessage.contains('invalid') && lowerMessage.contains('password')) {
      return 'The email or password you entered doesn\'t match our records. Please double-check your credentials and try again.';
    }

    if (lowerMessage.contains('email') && lowerMessage.contains('not found')) {
      return 'We couldn\'t find an account with this email address. Please verify your email or sign up for a new account.';
    }

    if (lowerMessage.contains('too many') ||
        lowerMessage.contains('attempts')) {
      return 'You\'ve made too many sign-in attempts. Please wait a few minutes before trying again to keep your account secure.';
    }

    if (lowerMessage.contains('server') ||
        lowerMessage.contains('unavailable')) {
      return 'Our servers are temporarily unavailable. Please try again in a few moments. We apologize for the inconvenience.';
    }

    if (lowerMessage.contains('connection') ||
        lowerMessage.contains('network')) {
      return 'We couldn\'t connect to our servers. Please check your internet connection and try again.';
    }

    // if its already a nice message, just return it
    if (message.length < 100 &&
        !lowerMessage.contains('exception') &&
        !lowerMessage.contains('error') &&
        !lowerMessage.contains('failed')) {
      return message;
    }

    // otherwise make it user-friendly
    return _getUserFriendlyError(message);
  }

  void _showError(String message) {
    debugPrint('SHOW ERROR CALLED: $message');
    if (!mounted) return;

    // clean up the message, remove "Exception: " if its there
    String cleanMessage = message.replaceAll('Exception: ', '').trim();

    // make all error messages nicer and easier to understand
    String displayMessage = _enhanceErrorMessage(cleanMessage);

    // set the error message so it shows in the ui
    setState(() {
      _errorMessage = displayMessage;
    });
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await AuthService.signIn(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );
      debugPrint('=== SIGN IN API RESPONSE ===');
      debugPrint('Sign in result: $result');
      debugPrint('Success: ${result['success']}');
      debugPrint('Message: ${result['message']}');
      debugPrint('Token: ${result['token']}');
      debugPrint('User: ${result['user']}');
      debugPrint('============================');

      // Check if login was successful
      if (result['success'] == true &&
          result['token'] != null &&
          result['user'] != null) {
        // Add a delay to ensure token is properly saved
        await Future.delayed(const Duration(milliseconds: 100));

        // Force update AuthService state
        await AuthService.forceUpdateAuthState();

        // Try to update AuthProvider first
        try {
          final authProvider =
              Provider.of<AuthProvider>(context, listen: false);
          await authProvider.refreshAuthState();
        } catch (e) {}

        // get the current auth state
        final authState = AuthState.of(context);
        if (authState != null) {
          await authState.refreshAuthState();
        } else {}

        // sync cart for the logged in user
        final userId = await AuthService.getCurrentUserID();
        if (userId != null) {
          await Provider.of<CartProvider>(context, listen: false)
              .handleUserLogin(userId);
        } else {}

        if (widget.onSuccess != null) {
          widget.onSuccess!();
        }
        // Final verification - check if user is actually logged in
        final isActuallyLoggedIn = await AuthService.isLoggedIn();
        debugPrint('Is actually logged in: $isActuallyLoggedIn');
        if (!isActuallyLoggedIn) {
          // If still not logged in, show error
          _showError('Login failed. Please try again.');
          return;
        }
        // clear error message after login works
        if (mounted) {
          setState(() {
            _errorMessage = null;
          });
        }
        if (mounted) {
          debugPrint('🔍 SignIn: Handling post-login navigation');
          debugPrint(
              '🔍 SignIn: onSuccess callback exists: ${widget.onSuccess != null}');
          debugPrint('🔍 SignIn: returnTo exists: ${widget.returnTo != null}');
          debugPrint(
              '🔍 SignIn: onSuccess callback type: ${widget.onSuccess.runtimeType}');
          debugPrint('🔍 SignIn: returnTo value: ${widget.returnTo}');

          // if theres an onSuccess callback, let it handle navigation
          if (widget.onSuccess != null) {
            debugPrint('🔍 SignIn: Calling onSuccess callback');
            try {
              widget.onSuccess!();
              debugPrint('🔍 SignIn: onSuccess callback executed successfully');
            } catch (e) {
              debugPrint('🔍 SignIn: Error executing onSuccess callback: $e');
            }
            // go back to the previous page after callback succeeds
            Navigator.pop(context);
            return;
          } else if (widget.returnTo != null) {
            debugPrint('🔍 SignIn: Navigating to returnTo: ${widget.returnTo}');
            Navigator.pushReplacementNamed(context, widget.returnTo!);
          } else {
            // check if theres prescription data waiting
            final prefs = await SharedPreferences.getInstance();
            final hasPendingPrescription =
                prefs.getBool('has_pending_prescription') ?? false;

            debugPrint(
                '🔍 SignIn: Checking for pending prescription: $hasPendingPrescription');

            if (hasPendingPrescription) {
              debugPrint(
                  '🔍 SignIn: Found pending prescription, navigating to upload page');
              // Don't clear the flag here - let main.dart handle it after retrieving data

              // Navigate to a special route that will handle the prescription upload
              Navigator.pushReplacementNamed(context, '/prescription-upload');
            } else {
              debugPrint(
                  '🔍 SignIn: No pending prescription, navigating to HomePage');
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const HomePage()),
              );
            }
          }
        }
      } else {
        // get the actual error message from the api response
        final errorMessage =
            result['message'] ?? 'Login failed. Please check your credentials.';
        debugPrint('🔍 SignIn: Error message from API: $errorMessage');
        _showError(errorMessage);
      }
    } catch (e) {
      // handle errors that might happen during login
      // _showError will make the message nicer automatically
      _showError(e.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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
                  Colors.black.withValues(alpha: 0.4),
                  Colors.black.withValues(alpha: 0.6),
                ],
              ),
            ),
          ),

          // Content
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                children: [
                  const SizedBox(height: 30),

                  // Back Button with improved styling
                  Align(
                    alignment: Alignment.topLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.white.withValues(alpha: 0.15),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2),
                        ),
                      ),
                      child: IconButton(
                        icon: const Icon(
                          Icons.arrow_back_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                  ),

                  // Logo Section with improved styling
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.15),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Image.asset(
                      'assets/images/png.png',
                      height: 70,
                      width: 70,
                    ),
                  ),

                  const SizedBox(height: 25),

                  // Welcome Text with improved styling
                  ShaderMask(
                    shaderCallback: (bounds) => LinearGradient(
                      colors: [
                        Colors.white,
                        Colors.white.withValues(alpha: 0.95)
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ).createShader(bounds),
                    child: Text(
                      "Let's Get You\nSigned In",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: -0.5,
                        shadows: [
                          Shadow(
                            offset: const Offset(2, 2),
                            blurRadius: 6,
                            color: Colors.black.withValues(alpha: 0.4),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 25),

                  // Error Message with improved styling
                  if (_errorMessage != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.red.shade50,
                            Colors.orange.shade50,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.red.shade200.withValues(alpha: 0.6),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.red.shade200.withValues(alpha: 0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 6),
                            spreadRadius: 0,
                          ),
                          BoxShadow(
                            color: Colors.red.shade50.withValues(alpha: 0.5),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                            spreadRadius: -2,
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _errorMessage = null;
                            });
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.red.shade400,
                                        Colors.red.shade600,
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.red.shade300
                                            .withValues(alpha: 0.4),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.error_outline_rounded,
                                    color: Colors.white,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _getErrorTitle(_errorMessage!),
                                        style: TextStyle(
                                          color: Colors.red.shade800,
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.2,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _errorMessage!,
                                        style: TextStyle(
                                          color: Colors.red.shade700,
                                          fontSize: 13.5,
                                          height: 1.5,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  Icons.close_rounded,
                                  color: Colors.red.shade400,
                                  size: 20,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    )
                        .animate()
                        .fadeIn(duration: 300.ms, curve: Curves.easeOut)
                        .slideY(
                          begin: -0.2,
                          end: 0,
                          duration: 400.ms,
                          curve: Curves.easeOutCubic,
                        )
                        .scale(
                          begin: const Offset(0.95, 0.95),
                          end: const Offset(1.0, 1.0),
                          duration: 300.ms,
                          curve: Curves.easeOut,
                        ),

                  // Form Card with simple, clean design
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.green.shade50.withValues(alpha: 0.95),
                          Colors.green.shade100.withValues(alpha: 0.9),
                          Colors.white.withValues(alpha: 0.98),
                        ],
                        stops: const [0.0, 0.5, 1.0],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Email Field
                          Text(
                            'Email Address',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade800,
                            ),
                          ),
                          const SizedBox(height: 3),
                          TextFormField(
                            controller: _emailController,
                            decoration: InputDecoration(
                              hintText: 'Enter your email address',
                              hintStyle: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 13,
                              ),
                              prefixIcon: Icon(
                                Icons.email_outlined,
                                color: Colors.green.shade700,
                                size: 18,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade300,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade300,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: Colors.green.shade600,
                                  width: 2,
                                ),
                              ),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 10,
                              ),
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
                          const SizedBox(height: 12),

                          // Password Field
                          Text(
                            'Password',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade800,
                            ),
                          ),
                          const SizedBox(height: 3),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            decoration: InputDecoration(
                              hintText: 'Enter your password',
                              hintStyle: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 13,
                              ),
                              prefixIcon: Icon(
                                Icons.lock_outline,
                                color: Colors.green.shade700,
                                size: 18,
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                  color: Colors.grey.shade600,
                                  size: 18,
                                ),
                                onPressed: () => setState(
                                    () => _obscurePassword = !_obscurePassword),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade300,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade300,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: Colors.green.shade600,
                                  width: 2,
                                ),
                              ),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 10,
                              ),
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
                          const SizedBox(height: 6),

                          // Forgot Password
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
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
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                              ),
                              child: Text(
                                'Forgot Password?',
                                style: TextStyle(
                                  color: Colors.blue.shade700,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Sign In Button
                          SizedBox(
                            width: double.infinity,
                            height: 44,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _signIn,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green.shade600,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                elevation: 2,
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text(
                                      'SIGN IN',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.0,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Sign Up Link with improved styling
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Don't have an account? ",
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 15,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
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
                            horizontal: 4,
                            vertical: 4,
                          ),
                        ),
                        child: Text(
                          'Sign Up',
                          style: TextStyle(
                            color: Colors.blue.shade300,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
