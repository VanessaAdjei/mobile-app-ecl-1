// pages/createaccount.dart
import 'package:flutter/material.dart';
import 'auth_service.dart';
import 'otp.dart';
import 'signinpage.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';
import 'package:eclapp/widgets/error_display.dart';

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
      _showError("An error occurred. Please try again.");
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
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.green.shade50,
              Colors.white,
              Colors.green.shade100.withOpacity(0.3),
            ],
            stops: const [0.0, 0.6, 1.0],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Back Button with Glassmorphic Effect
                  Animate(
                    effects: [
                      FadeEffect(duration: 400.ms),
                      SlideEffect(
                        duration: 400.ms,
                        begin: const Offset(-0.3, 0),
                        end: Offset.zero,
                      ),
                    ],
                    child: Container(
                      margin: const EdgeInsets.only(top: 8, bottom: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.8),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.3),
                              ),
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
                        ),
                      ),
                    ),
                  ),

                  // Header Section
                  Animate(
                    effects: [
                      FadeEffect(duration: 500.ms, delay: 100.ms),
                      SlideEffect(
                        duration: 500.ms,
                        begin: const Offset(0, 0.2),
                        end: Offset.zero,
                        delay: 100.ms,
                      ),
                    ],
                    child: Center(
                      child: Column(
                        children: [
                          Image.asset(
                            'assets/images/png.png',
                            height: 70,
                            width: 70,
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
                  ),

                  const SizedBox(height: 32),

                  // Form Fields
                  Animate(
                    effects: [
                      FadeEffect(duration: 600.ms, delay: 200.ms),
                      SlideEffect(
                        duration: 600.ms,
                        begin: const Offset(0, 0.3),
                        end: Offset.zero,
                        delay: 200.ms,
                      ),
                    ],
                    child: _buildGlassmorphicCard(
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
                            Icons.email_outlined,
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
                              return null;
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
                              FilteringTextInputFormatter.allow(
                                  RegExp(r'[\d+]')),
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
                            validator: (value) {
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
                            () => setState(() => _confirmPasswordVisible =
                                !_confirmPasswordVisible),
                            validator: (value) {
                              if (value != passwordController.text) {
                                return 'Passwords do not match';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Terms and Conditions
                  Animate(
                    effects: [
                      FadeEffect(duration: 700.ms, delay: 300.ms),
                      SlideEffect(
                        duration: 700.ms,
                        begin: const Offset(0, 0.2),
                        end: Offset.zero,
                        delay: 300.ms,
                      ),
                    ],
                    child: _buildGlassmorphicCard(
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
                                      text: 'Privacy Policy',
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
                  ),

                  const SizedBox(height: 32),

                  // Sign Up Button
                  Animate(
                    effects: [
                      FadeEffect(duration: 800.ms, delay: 400.ms),
                      SlideEffect(
                        duration: 800.ms,
                        begin: const Offset(0, 0.3),
                        end: Offset.zero,
                        delay: 400.ms,
                      ),
                    ],
                    child: Container(
                      width: double.infinity,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.green.shade600,
                            Colors.green.shade800,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.green.shade200.withOpacity(0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
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
                          elevation: 0,
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
                                  letterSpacing: 0.3,
                                ),
                              ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Already have account
                  Animate(
                    effects: [
                      FadeEffect(duration: 900.ms, delay: 500.ms),
                      SlideEffect(
                        duration: 900.ms,
                        begin: const Offset(0, 0.2),
                        end: Offset.zero,
                        delay: 500.ms,
                      ),
                    ],
                    child: Center(
                      child: TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const SignInScreen()),
                          );
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                        child: RichText(
                          text: TextSpan(
                            text: 'Already have an account? ',
                            style: GoogleFonts.poppins(
                              color: Colors.grey.shade600,
                              fontSize: 15,
                            ),
                            children: [
                              TextSpan(
                                text: 'Sign In',
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
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGlassmorphicCard({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.85),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
              ),
            ),
            padding: const EdgeInsets.all(20),
            child: child,
          ),
        ),
      ),
    );
  }

  void _showError(String message) {
    SnackBarUtils.showError(context, message);
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
      style: GoogleFonts.poppins(
        fontSize: 15,
        color: Colors.grey.shade800,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.poppins(
          color: Colors.grey.shade600,
          fontSize: 14,
        ),
        prefixIcon: Container(
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: Colors.green.shade600,
            size: 20,
          ),
        ),
        prefixText: prefixText,
        prefixStyle: GoogleFonts.poppins(
          color: Colors.grey.shade700,
          fontWeight: FontWeight.w500,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.green.shade600, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.red.shade400, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.red.shade400, width: 2),
        ),
        filled: true,
        fillColor: Colors.white.withOpacity(0.7),
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
    VoidCallback onPressed, {
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: !isVisible,
      validator: validator,
      style: GoogleFonts.poppins(
        fontSize: 15,
        color: Colors.grey.shade800,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.poppins(
          color: Colors.grey.shade600,
          fontSize: 14,
        ),
        prefixIcon: Container(
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: Colors.green.shade600,
            size: 20,
          ),
        ),
        suffixIcon: Container(
          margin: const EdgeInsets.only(left: 8),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: IconButton(
            icon: Icon(
              isVisible
                  ? Icons.visibility_rounded
                  : Icons.visibility_off_rounded,
              color: Colors.green.shade600,
              size: 20,
            ),
            onPressed: onPressed,
          ),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.green.shade600, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.red.shade400, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.red.shade400, width: 2),
        ),
        filled: true,
        fillColor: Colors.white.withOpacity(0.7),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
    );
  }
}
