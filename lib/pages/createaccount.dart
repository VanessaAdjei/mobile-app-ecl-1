// pages/createaccount.dart
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/auth_service.dart';
import '../utils/terms_gate.dart';
import 'otp.dart';
import 'privacypolicy.dart';
import 'signinpage.dart';
import 'terms_and_conditions_page.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  static const Color _fieldTextColor = Color(0xFF1F2937);
  static const Color _fieldHintColor = Color(0xFF6B7280);
  static const String _bannerAsset = 'assets/images/banner3.jpg';

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

  late final TapGestureRecognizer _termsTapRecognizer;
  late final TapGestureRecognizer _privacyTapRecognizer;

  @override
  void initState() {
    super.initState();
    _termsTapRecognizer = TapGestureRecognizer()..onTap = _openTerms;
    _privacyTapRecognizer = TapGestureRecognizer()..onTap = _openPrivacy;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requireAppTermsAccepted();
    });
  }

  Future<void> _requireAppTermsAccepted() async {
    final accepted = await TermsGate.ensureAccepted(context);
    if (!accepted && mounted) {
      Navigator.pop(context);
    }
  }

  void _openTerms() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const TermsAndConditionsPage()),
    );
  }

  void _openPrivacy() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const PrivacyPolicyScreen()),
    );
  }

  @override
  void dispose() {
    _termsTapRecognizer.dispose();
    _privacyTapRecognizer.dispose();
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
    } on UnverifiedAccountException catch (e) {
      debugPrint('🔍 SIGNUP: unverified account — sending to OTP: ${e.email}');
      if (!mounted) return;
      // Login probe already triggered OTP delivery for this account.
      Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => OtpVerificationScreen(
            email: e.email,
            phoneNumber: e.phone,
            password: e.password,
            name: e.name,
            resendOtpOnOpen: false,
          ),
        ),
        (route) => false,
      );
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

  Widget _entrance(
    Widget child, {
    int delayMs = 0,
    double slideY = 0.12,
    double slideX = 0,
  }) {
    return child
        .animate()
        .fadeIn(
          duration: 420.ms,
          delay: delayMs.ms,
          curve: Curves.easeOut,
        )
        .slideY(
          begin: slideY,
          end: 0,
          duration: 480.ms,
          delay: delayMs.ms,
          curve: Curves.easeOutCubic,
        )
        .slideX(
          begin: slideX,
          end: 0,
          duration: 480.ms,
          delay: delayMs.ms,
          curve: Curves.easeOutCubic,
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            _bannerAsset,
            fit: BoxFit.cover,
            alignment: Alignment.center,
          )
              .animate(onPlay: (controller) => controller.repeat(reverse: true))
              .fadeIn(duration: 700.ms)
              .scale(
                begin: const Offset(1.0, 1.0),
                end: const Offset(1.08, 1.08),
                duration: 12.seconds,
                curve: Curves.easeInOut,
              ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.42),
                  Colors.black.withValues(alpha: 0.55),
                  Colors.black.withValues(alpha: 0.82),
                ],
                stops: const [0.0, 0.45, 1.0],
              ),
            ),
          ).animate().fadeIn(duration: 900.ms),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 8),
                    _entrance(
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: Colors.white.withValues(alpha: 0.15),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.22),
                            ),
                          ),
                          child: IconButton(
                            icon: const Icon(
                              Icons.arrow_back_rounded,
                              color: Colors.white,
                            ),
                            onPressed: () {
                              if (Navigator.canPop(context)) {
                                Navigator.pop(context);
                              }
                            },
                          ),
                        ),
                      ),
                      delayMs: 60,
                      slideX: -0.08,
                      slideY: 0,
                    ),
                    const SizedBox(height: 20),
                    Center(
                      child: GestureDetector(
                        onTap: _handleLogoTap,
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.14),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.28),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.28),
                                blurRadius: 16,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Image.asset(
                            'assets/images/png.png',
                            height: 64,
                            width: 64,
                          ),
                        ),
                      )
                          .animate()
                          .fadeIn(duration: 500.ms, delay: 120.ms)
                          .scale(
                            begin: const Offset(0.85, 0.85),
                            end: const Offset(1, 1),
                            duration: 550.ms,
                            delay: 120.ms,
                            curve: Curves.easeOutBack,
                          )
                          .then(delay: 700.ms)
                          .shimmer(
                            duration: 1800.ms,
                            color: Colors.white.withValues(alpha: 0.35),
                          ),
                    )
                        .animate(onPlay: (c) => c.repeat(reverse: true))
                        .moveY(
                          begin: 0,
                          end: -5,
                          duration: 2.4.seconds,
                          curve: Curves.easeInOut,
                        ),
                    const SizedBox(height: 20),
                    _entrance(
                      Text(
                        'Join Ernest Chemists Ltd',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 30,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: -0.6,
                          height: 1.15,
                          shadows: [
                            Shadow(
                              color: Colors.black.withValues(alpha: 0.45),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                      ),
                      delayMs: 220,
                    ),
                    const SizedBox(height: 8),
                    _entrance(
                      Text(
                        'Create an account for prescriptions,\nrefills, and faster checkout',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          height: 1.45,
                          color: Colors.white.withValues(alpha: 0.88),
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      delayMs: 300,
                      slideY: 0.08,
                    ),
                    const SizedBox(height: 24),
                    _buildFormCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _entrance(
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
                            delayMs: 380,
                            slideX: -0.04,
                          ),
                          const SizedBox(height: 14),
                          _entrance(
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
                                if (!value.contains('@') ||
                                    !value.contains('.')) {
                                  return 'Please enter a valid email';
                                }
                                if (_emailExists) {
                                  return 'This email is already registered';
                                }
                                return null;
                              },
                              onChanged: (value) {
                                if (_emailExists) {
                                  setState(() => _emailExists = false);
                                }
                              },
                            ),
                            delayMs: 440,
                            slideX: 0.04,
                          ),
                          const SizedBox(height: 14),
                          _entrance(
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
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'[\d+]'),
                                ),
                                LengthLimitingTextInputFormatter(13),
                              ],
                              prefixText: '+233 ',
                            ),
                            delayMs: 500,
                            slideX: -0.04,
                          ),
                          const SizedBox(height: 14),
                          _entrance(
                            _buildPasswordField(
                              'Password',
                              Icons.lock_outline_rounded,
                              passwordController,
                              _passwordVisible,
                              () => setState(
                                () => _passwordVisible = !_passwordVisible,
                              ),
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
                            delayMs: 560,
                            slideX: 0.04,
                          ),
                          const SizedBox(height: 14),
                          _entrance(
                            _buildPasswordField(
                              'Confirm Password',
                              Icons.lock_outline_rounded,
                              confirmPasswordController,
                              _confirmPasswordVisible,
                              () => setState(
                                () => _confirmPasswordVisible =
                                    !_confirmPasswordVisible,
                              ),
                              (value) {
                                if (value != passwordController.text) {
                                  return 'Passwords do not match';
                                }
                                return null;
                              },
                            ),
                            delayMs: 620,
                            slideX: -0.04,
                          ),
                          const SizedBox(height: 16),
                          _entrance(
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: Checkbox(
                                    value: _termsAgreed,
                                    onChanged: (value) => setState(
                                      () => _termsAgreed = value ?? false,
                                    ),
                                    activeColor: Colors.green.shade700,
                                    side: BorderSide(
                                      color: Colors.grey.shade400,
                                    ),
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: RichText(
                                      text: TextSpan(
                                        style: GoogleFonts.poppins(
                                          fontSize: 12.5,
                                          color: Colors.grey.shade700,
                                          height: 1.45,
                                        ),
                                        children: [
                                          const TextSpan(
                                            text: 'I agree to the ',
                                          ),
                                          TextSpan(
                                            text: 'Terms & Conditions',
                                            recognizer: _termsTapRecognizer,
                                            style: GoogleFonts.poppins(
                                              color: Colors.green.shade700,
                                              fontWeight: FontWeight.w600,
                                              decoration:
                                                  TextDecoration.underline,
                                            ),
                                          ),
                                          const TextSpan(text: ' and '),
                                          TextSpan(
                                            text: 'Privacy Statement',
                                            recognizer: _privacyTapRecognizer,
                                            style: GoogleFonts.poppins(
                                              color: Colors.green.shade700,
                                              fontWeight: FontWeight.w600,
                                              decoration:
                                                  TextDecoration.underline,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            delayMs: 680,
                          ),
                        ],
                      ),
                    )
                        .animate()
                        .fadeIn(duration: 500.ms, delay: 340.ms)
                        .slideY(
                          begin: 0.1,
                          end: 0,
                          duration: 550.ms,
                          delay: 340.ms,
                          curve: Curves.easeOutCubic,
                        ),
                    const SizedBox(height: 20),
                    _buildPrimaryButton()
                        .animate()
                        .fadeIn(duration: 450.ms, delay: 740.ms)
                        .slideY(
                          begin: 0.15,
                          end: 0,
                          duration: 500.ms,
                          delay: 740.ms,
                          curve: Curves.easeOutBack,
                        )
                        .shimmer(
                          delay: 1200.ms,
                          duration: 1400.ms,
                          color: Colors.white.withValues(alpha: 0.28),
                        ),
                    const SizedBox(height: 18),
                    _entrance(
                      Center(
                        child: RichText(
                          text: TextSpan(
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: Colors.white.withValues(alpha: 0.88),
                            ),
                            children: [
                              const TextSpan(
                                text: 'Already have an account? ',
                              ),
                              WidgetSpan(
                                alignment: PlaceholderAlignment.baseline,
                                baseline: TextBaseline.alphabetic,
                                child: GestureDetector(
                                  onTap: () {
                                    Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const SignInScreen(),
                                      ),
                                    );
                                  },
                                  child: Text(
                                    'Sign In',
                                    style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      decoration: TextDecoration.underline,
                                      decorationColor: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      delayMs: 820,
                      slideY: 0.06,
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.97),
            Colors.green.shade50.withValues(alpha: 0.95),
            Colors.white.withValues(alpha: 0.98),
          ],
          stops: const [0.0, 0.45, 1.0],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.65)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildPrimaryButton() {
    final canSubmit = _termsAgreed && !_isLoading;

    return Opacity(
      opacity: canSubmit ? 1 : 0.45,
      child: Container(
      height: 54,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.green.shade500,
            Colors.green.shade700,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.green.shade900.withValues(alpha: 0.35),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: canSubmit ? _signUp : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(
                'Create Account',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  letterSpacing: 0.2,
                ),
              ),
      ),
    ),
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
      style: const TextStyle(color: _fieldTextColor, fontSize: 14),
      cursorColor: Colors.green.shade700,
      autofillHints: keyboardType == TextInputType.emailAddress
          ? const [AutofillHints.email]
          : null,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: Colors.grey.shade600,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        hintStyle: const TextStyle(color: _fieldHintColor, fontSize: 13),
        prefixIcon: Icon(icon, color: Colors.green.shade700, size: 20),
        prefixText: prefixText,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.green.shade600, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.red.shade400),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.red.shade400, width: 2),
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
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
      style: const TextStyle(color: _fieldTextColor, fontSize: 14),
      cursorColor: Colors.green.shade700,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: Colors.grey.shade600,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        prefixIcon: Icon(icon, color: Colors.green.shade700, size: 20),
        suffixIcon: IconButton(
          icon: Icon(
            isVisible ? Icons.visibility_off : Icons.visibility,
            color: Colors.grey.shade600,
            size: 20,
          ),
          onPressed: onToggle,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.green.shade600, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.red.shade400),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.red.shade400, width: 2),
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
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
                        builder: (context) => const SignInScreen(),
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
