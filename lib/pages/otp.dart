// pages/otp.dart
import 'package:eclapp/pages/signinpage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:eclapp/pages/auth_service.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';
import 'dart:async';
import 'package:provider/provider.dart';
import 'authprovider.dart';
import 'cartprovider.dart';
import '../main.dart' as main_app;
import 'package:eclapp/widgets/error_display.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String email;
  final String phoneNumber;
  final String? password; // Optional for auto-login
  final String? name; // Optional for auto-login

  const OtpVerificationScreen({
    super.key,
    required this.email,
    required this.phoneNumber,
    this.password,
    this.name,
  });

  @override
  OtpVerificationScreenState createState() => OtpVerificationScreenState();
}

class OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final List<TextEditingController> otpControllers = List.generate(
    5,
    (index) => TextEditingController(),
  );
  final List<FocusNode> focusNodes = List.generate(
    5,
    (index) => FocusNode(),
  );

  bool isLoading = false;
  String otp = '';
  bool canResend = false;
  int resendCountdown = 60;
  Timer? resendTimer;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
  }

  @override
  void dispose() {
    for (var controller in otpControllers) {
      controller.dispose();
    }
    for (var node in focusNodes) {
      node.dispose();
    }
    resendTimer?.cancel();
    super.dispose();
  }

  void _startResendTimer() {
    setState(() {
      canResend = false;
      resendCountdown = 60;
    });

    resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        resendCountdown--;
        if (resendCountdown <= 0) {
          canResend = true;
          timer.cancel();
        }
      });
    });
  }

  void _onOtpChanged(String value, int index) {
    setState(() {
      otp = otpControllers.map((controller) => controller.text).join();
    });

    if (value.length == 1 && index < 4) {
      focusNodes[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      focusNodes[index - 1].requestFocus();
    }

    // Auto-verify when all 5 characters are entered
    if (otp.length == 5) {
      _verifyOtp();
    }
  }

  Future<void> _verifyOtp() async {
    if (otp.length != 5) {
      _showError("Please enter the complete 5-character OTP");
      return;
    }

    setState(() => isLoading = true);

    try {
      bool isVerified = await AuthService.verifyOTP(widget.email, otp);

      if (isVerified) {
        _showSuccess("OTP verified successfully!");

        // Auto-login if credentials are provided
        if (widget.password != null) {
          try {
            final result =
                await AuthService.signIn(widget.email, widget.password!);

            if (result['success'] == true && result['token'] != null) {
              // Add a longer delay to ensure token is properly saved and all states are updated
              await Future.delayed(const Duration(milliseconds: 50));

              // Force update AuthService state multiple times to ensure consistency
              await AuthService.forceUpdateAuthState();
              await Future.delayed(const Duration(milliseconds: 100));
              await AuthService.forceUpdateAuthState();

              // Update AuthProvider state
              try {
                final authProvider =
                    Provider.of<AuthProvider>(context, listen: false);
                await authProvider
                    .login(); // This will check the current login state
              } catch (e) {
                // AuthProvider not available, continue
              }

              // Get the current AuthState using the of() pattern
              final authState = main_app.AuthState.of(context);
              if (authState != null) {
                authState.refreshAuthState();
              }

              // Sync cart for logged-in user
              final userId = await AuthService.getCurrentUserID();
              if (userId != null) {
                await Provider.of<CartProvider>(context, listen: false)
                    .handleUserLogin(userId);
              }

              // Final verification - check if user is actually logged in
              final isActuallyLoggedIn = await AuthService.isLoggedIn();
              if (!isActuallyLoggedIn) {
                // If still not logged in, redirect to sign in page
                if (mounted) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const SignInScreen()),
                  );
                }
                return;
              }

              // Successfully logged in, navigate to home
              if (mounted) {
                // Navigate to home and clear all previous routes
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/home',
                  (route) => false,
                );
              }
            } else {
              // Auto-login failed, redirect to sign in page
              if (mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const SignInScreen()),
                );
              }
            }
          } catch (e) {
         
            if (mounted) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const SignInScreen()),
              );
            }
          }
        } else {

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const SignInScreen()),
          );
        }
      } else {
        _showError("Invalid OTP. Please try again.");
        // Clear the OTP fields
        for (var controller in otpControllers) {
          controller.clear();
        }
        setState(() {
          otp = '';
        });
        focusNodes[0].requestFocus();
      }
    } catch (e) {
      _showError("An error occurred. Please try again.");
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _resendOtp() async {
    if (!canResend || isLoading) return;

    setState(() => isLoading = true);

    try {
      // Call the resend OTP API
      final result = await AuthService.resendOTP(widget.email);

      if (result['success'] == true) {
        _showSuccess("OTP resent successfully!");
        _startResendTimer(); // Restart the countdown
      } else {
        _showError(result['message'] ?? "Failed to resend OTP");
      }
    } catch (e) {
      _showError("An error occurred while resending OTP");
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
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
              Colors.green.shade100.withValues(alpha: 0.3),
            ],
            stops: const [0.0, 0.6, 1.0],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
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
                          color: Colors.black.withValues(alpha: 0.05),
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
                            color: Colors.white.withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.3),
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
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.green.shade50,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.green.shade200
                                    .withValues(alpha: 0.3),
                                blurRadius: 15,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.verified_user_rounded,
                            size: 40,
                            color: Colors.green.shade600,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Verify Your Account',
                          style: GoogleFonts.poppins(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade800,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'We\'ve sent a verification code to',
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w400,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.phoneNumber,
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 40),

                // OTP Input Section
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
                        Text(
                          'Enter 5-character code',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: List.generate(
                            5,
                            (index) => _buildOtpField(index),
                          ),
                        ),
                        const SizedBox(height: 24),
                        if (isLoading)
                          SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.green.shade600,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Manual Verify Button
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
                          color: Colors.green.shade200.withValues(alpha: 0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: isLoading ? null : _verifyOtp,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: isLoading
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
                              'Verify OTP',
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

                const SizedBox(height: 24),

                // Resend OTP Button
                Animate(
                  effects: [
                    FadeEffect(duration: 900.ms, delay: 500.ms),
                    SlideEffect(
                      duration: 900.ms,
                      begin: const Offset(0, 0.3),
                      end: Offset.zero,
                      delay: 500.ms,
                    ),
                  ],
                  child: Center(
                    child: Column(
                      children: [
                        Text(
                          'Didn\'t receive the code?',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 40,
                          child: TextButton(
                            onPressed:
                                canResend && !isLoading ? _resendOtp : null,
                            style: TextButton.styleFrom(
                              foregroundColor: canResend
                                  ? Colors.green.shade700
                                  : Colors.grey,
                              backgroundColor: canResend
                                  ? Colors.green.shade50
                                  : Colors.grey.shade200,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.refresh_rounded,
                                  size: 16,
                                  color: canResend
                                      ? Colors.green.shade700
                                      : Colors.grey,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  canResend
                                      ? 'Resend OTP'
                                      : 'Resend in ${resendCountdown}s',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: canResend
                                        ? Colors.green.shade700
                                        : Colors.grey,
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

                const SizedBox(height: 20),
              ],
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
            color: Colors.black.withValues(alpha: 0.05),
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
              color: Colors.white.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.3),
              ),
            ),
            padding: const EdgeInsets.all(20),
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _buildOtpField(int index) {
    return Container(
      width: 50,
      height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: focusNodes[index].hasFocus
              ? Colors.green.shade600
              : Colors.grey.shade500,
          width: focusNodes[index].hasFocus ? 3 : 2,
        ),
        color: Colors.white,
      ),
      child: TextField(
        controller: otpControllers[index],
        focusNode: focusNodes[index],
        keyboardType: TextInputType.text,
        textAlign: TextAlign.center,
        style: GoogleFonts.poppins(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: Colors.grey.shade800,
        ),
        decoration: const InputDecoration(
          border: InputBorder.none,
          counterText: '',
        ),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[0-9A-Za-z]')),
          LengthLimitingTextInputFormatter(1),
        ],
        onChanged: (value) => _onOtpChanged(value, index),
      ),
    );
  }

  void _showSuccess(String message) {
    SnackBarUtils.showSuccess(context, message);
  }

  void _showError(String message) {
    SnackBarUtils.showError(context, message);
  }
}
