// pages/createaccount.dart
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'otp.dart';
import 'signinpage.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  bool _termsAgreed = false;
  bool _passwordVisible = false;
  bool _confirmPasswordVisible = false;
  bool _isLoading = false;
  bool _emailExists = false;
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();
  final TextEditingController phoneNumberController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    phoneNumberController.dispose();
    super.dispose();
  }

  void _signUp() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_termsAgreed) {
      _showError("Please agree to terms and conditions");
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final email = emailController.text.trim();
    final password = passwordController.text.trim();
    final name = nameController.text.trim();
    final phoneNumber = phoneNumberController.text.trim();

    try {
      final signUpSuccess = await AuthService.signUp(
        name,
        email,
        password,
        phoneNumber,
      );

      if (signUpSuccess) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => OtpVerificationScreen(
              email: email,
              phoneNumber: phoneNumber,
              password: password,
              name: name,
            ),
          ),
        );
      } else {
        _showError("Signup failed. Please try again.");
      }
    } catch (e) {
      // print the actual error message
      debugPrint('🔍 SIGNUP ERROR: ${e.toString()}');
      debugPrint('🔍 ERROR TYPE: ${e.runtimeType}');
      debugPrint('🔍 ERROR MESSAGE: ${e.toString()}');

      // handle specific error messages from the api
      String errorMessage = "An error occurred. Please try again.";

      // get error message, try to extract it if its an Exception
      String errorString = e.toString().toLowerCase();
      if (e is Exception) {
        // for Exception objects, the message might be in toString()
        errorString = e.toString().toLowerCase();
      }
      debugPrint('🔍 PROCESSED ERROR STRING: $errorString');

      // check error type first to detect it better
      final errorTypeString = e.runtimeType.toString().toLowerCase();
      debugPrint('🔍 ERROR TYPE STRING: $errorTypeString');

      if (errorString.contains('email is already registered')) {
        errorMessage =
            "This email is already registered. Would you like to sign in instead?";
        // set email exists flag and highlight the email field
        setState(() {
          _emailExists = true;
        });
        _highlightEmailField();
        _showError(errorMessage, showSignInAction: true);
        return;
      } else if (errorString.contains('phone number is already registered')) {
        errorMessage =
            "This phone number is already registered. Please use a different number.";
        // highlight the phone field
        _highlightPhoneField();
      } else if (errorString.contains('server is currently unavailable')) {
        errorMessage =
            "Server is currently unavailable. Please try again later.";
      } else if ((errorString.contains('unable to connect to the server') &&
              (errorString.contains('network') ||
                  errorString.contains('blocking') ||
                  errorString.contains('due to network'))) ||
          errorString.contains('unable to complete the request') ||
          (errorString.contains('try again later') &&
              errorString.contains('network'))) {
        errorMessage =
            "Unable to connect to the server due to network issues. Please try again later or check your internet connection.";
        debugPrint('🔍 Network/connection error detected: $errorString');
      } else if (errorString.contains('unable to connect to the server')) {
        errorMessage =
            "Unable to connect to the server. Please check your internet connection.";
      } else if (errorString.contains('request took too long to complete')) {
        errorMessage =
            "The request took too long to complete. Please try again.";
      } else if (errorString.contains('handshake') ||
          errorString.contains('certificate') ||
          errorString.contains('certificate_verify_failed') ||
          errorString.contains('ssl') ||
          errorString.contains('tls') ||
          errorString.contains('connection security') ||
          errorTypeString.contains('handshake')) {
        errorMessage =
            "SSL certificate error. Please check your connection and try again. If the problem persists, contact support.";
        debugPrint(
            '🔍 Certificate error detected, showing error message: $errorMessage');
        debugPrint('🔍 Widget mounted: $mounted');
        if (mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _showError(errorMessage);
            }
          });
        }
        return;
      } else if (errorString.contains('already registered')) {
        // generic "already registered" error
        errorMessage =
            "This account is already registered. Would you like to sign in instead?";
        _showError(errorMessage, showSignInAction: true);
        return;
      } else if (errorString.contains('email') &&
          errorString.contains('registered')) {
        // Fallback for email already registered
        errorMessage =
            "This email is already registered. Would you like to sign in instead?";
        setState(() {
          _emailExists = true;
        });
        _highlightEmailField();
        _showError(errorMessage, showSignInAction: true);
        return;
      }

      // show the error message (either specific or generic)
      debugPrint('🔍 Showing error message: $errorMessage');
      debugPrint('🔍 Original error: ${e.toString()}');
      debugPrint('🔍 Widget mounted: $mounted');

      // Always try to show the error
      if (mounted) {
        try {
          // Try to show immediately first
          _showError(errorMessage);
        } catch (e) {
          // If that fails, try in next frame
          debugPrint('⚠️ Error showing immediately, trying in next frame: $e');
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              try {
                _showError(errorMessage);
              } catch (e2) {
                debugPrint('⚠️ Error showing in postFrameCallback: $e2');
              }
            }
          });
        }
      } else {
        debugPrint('⚠️ Widget not mounted, cannot show error');
      }
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
      resizeToAvoidBottomInset: true,
      backgroundColor: Colors.green.shade50,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // back button
                Container(
                  margin: const EdgeInsets.only(top: 8, bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: Icon(
                      Icons.arrow_back_rounded,
                      color: Colors.green.shade800,
                      size: 24,
                    ),
                    onPressed: () {
                      if (Navigator.canPop(context)) {
                        Navigator.pop(context);
                      }
                    },
                  ),
                ),

                // header section
                Center(
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: () {
                          _handleLogoTap();
                        },
                        child: Image.asset(
                          'assets/images/png.png',
                          height: 70,
                          width: 70,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Create Account',
                        style: GoogleFonts.poppins(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Join Ernest Chemist for seamless shopping',
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w400,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // form input fields
                _buildCard(
                  child: Column(
                    children: [
                      _buildTextField(
                        'Full Name',
                        Icons.person_outline_rounded,
                        nameController,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        'Email Address',
                        _emailExists
                            ? Icons.error_outline
                            : Icons.email_outlined,
                        emailController,
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your email';
                          }
                          if (!value.contains('@') || !value.contains('.')) {
                            return 'Please enter a valid email';
                          }
                          if (_emailExists) {
                            return 'This email is already registered';
                          }
                          return null;
                        },
                        onChanged: (value) {
                          // Clear email exists error when user starts typing
                          if (_emailExists) {
                            setState(() {
                              _emailExists = false;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        'Phone Number',
                        Icons.phone_rounded,
                        phoneNumberController,
                        keyboardType: TextInputType.phone,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your phone number';
                          }
                          if (!RegExp(r'^\d{10}$').hasMatch(value)) {
                            return 'Enter a valid 10-digit Ghanaian number';
                          }
                          return null;
                        },
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[\d+]')),
                          LengthLimitingTextInputFormatter(13),
                        ],
                        prefixText: '+233 ',
                        onChanged: (value) {},
                      ),
                      const SizedBox(height: 16),
                      _buildPasswordField(
                        'Password',
                        Icons.lock_outline_rounded,
                        passwordController,
                        _passwordVisible,
                        () => setState(
                            () => _passwordVisible = !_passwordVisible),
                        (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a password';
                          }
                          if (value.length < 6) {
                            return 'Password must be at least 6 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      _buildPasswordField(
                        'Confirm Password',
                        Icons.lock_outline_rounded,
                        confirmPasswordController,
                        _confirmPasswordVisible,
                        () => setState(() =>
                            _confirmPasswordVisible = !_confirmPasswordVisible),
                        (value) {
                          if (value != passwordController.text) {
                            return 'Passwords do not match';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // terms and conditions checkbox
                _buildCard(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Transform.scale(
                        scale: 0.9,
                        child: Checkbox(
                          value: _termsAgreed,
                          onChanged: (value) =>
                              setState(() => _termsAgreed = value ?? false),
                          activeColor: Colors.green.shade600,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: RichText(
                            text: TextSpan(
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: Colors.grey.shade700,
                                height: 1.4,
                              ),
                              children: [
                                const TextSpan(text: 'I agree to the '),
                                TextSpan(
                                  text: 'Terms & Conditions',
                                  style: GoogleFonts.poppins(
                                    color: Colors.green.shade600,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const TextSpan(text: ' and '),
                                TextSpan(
                                  text: 'Privacy Statement',
                                  style: GoogleFonts.poppins(
                                    color: Colors.green.shade600,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // sign up button
                Container(
                  width: double.infinity,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.green.shade600,
                        Colors.green.shade700,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.shade200.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _signUp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _isLoading
                        ? SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : Text(
                            'Create Account',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 24),

                // Sign In Link
                Center(
                  child: RichText(
                    text: TextSpan(
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                      children: [
                        const TextSpan(text: 'Already have an account? '),
                        WidgetSpan(
                          child: GestureDetector(
                            onTap: () {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => SignInScreen(),
                                ),
                              );
                            },
                            child: Text(
                              'Sign In',
                              style: GoogleFonts.poppins(
                                color: Colors.green.shade600,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildTextField(
    String label,
    IconData icon,
    TextEditingController controller, {
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    List<TextInputFormatter>? inputFormatters,
    String? prefixText,
    void Function(String)? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      inputFormatters: inputFormatters,
      onChanged: onChanged,
      autofillHints: keyboardType == TextInputType.emailAddress
          ? const [AutofillHints.email]
          : null,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.green.shade600),
        prefixText: prefixText,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.green.shade600, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.red.shade400),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.red.shade400, width: 2),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
    );
  }

  Widget _buildPasswordField(
    String label,
    IconData icon,
    TextEditingController controller,
    bool isVisible,
    VoidCallback onToggle,
    String? Function(String?)? validator,
  ) {
    return TextFormField(
      controller: controller,
      obscureText: !isVisible,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.green.shade600),
        suffixIcon: IconButton(
          icon: Icon(
            isVisible ? Icons.visibility_off : Icons.visibility,
            color: Colors.grey.shade600,
          ),
          onPressed: onToggle,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.green.shade600, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.red.shade400),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.red.shade400, width: 2),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
    );
  }

  void _showError(String message, {bool showSignInAction = false}) {
    if (!mounted) {
      debugPrint('⚠️ Cannot show error - widget not mounted: $message');
      return;
    }

    debugPrint('🔍 Showing SnackBar with message: $message');

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Expanded(child: Text(message)),
                ],
              ),
              if (showSignInAction) ...[
                const SizedBox(height: 4),
                Text(
                  'Or try using a different email address',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
          backgroundColor: Colors.red.shade600,
          duration: const Duration(seconds: 5),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.only(top: 16.0, left: 16.0, right: 16.0),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          action: showSignInAction
              ? SnackBarAction(
                  label: 'Sign In',
                  textColor: Colors.white,
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SignInScreen(),
                      ),
                    );
                  },
                )
              : null,
        ),
      );
      debugPrint('✅ SnackBar shown successfully');
    } catch (e) {
      debugPrint('❌ Error showing SnackBar: $e');
      // fallback: try to show a simple dialog or print to console
      debugPrint('ERROR MESSAGE: $message');
    }
  }

  void _highlightEmailField() {
    // Focus on email field and trigger validation
    FocusScope.of(context).requestFocus(FocusNode());
    Future.delayed(Duration(milliseconds: 100), () {
      if (mounted) {
        _formKey.currentState?.validate();
      }
    });
  }

  void _highlightPhoneField() {
    // focus on phone field and trigger validation
    FocusScope.of(context).requestFocus(FocusNode());
    Future.delayed(Duration(milliseconds: 100), () {
      if (mounted) {
        _formKey.currentState?.validate();
      }
    });
  }

  int _logoInteractionCount = 0;
  DateTime? _lastInteractionTime;

  void _handleLogoTap() {
    debugPrint('🔍 LOGO TAPPED! Count: $_logoInteractionCount');
    final now = DateTime.now();

    if (_lastInteractionTime != null &&
        now.difference(_lastInteractionTime!).inSeconds > 2) {
      _logoInteractionCount = 0;
      debugPrint('🔍 RESET COUNT - too much time passed');
    }

    _logoInteractionCount++;
    _lastInteractionTime = now;

    debugPrint('🔍 TAP COUNT: $_logoInteractionCount');

    if (_logoInteractionCount == 3) {
      debugPrint('🔍 SHOWING SPECIAL FEEDBACK!');
      _logoInteractionCount = 0; // Reset for next time
      _showSpecialFeedback();
    }
  }

  void _showSpecialFeedback() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.favorite, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(
              'v❤️',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.pink.shade400,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
