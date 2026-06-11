// pages/otp.dart
import 'package:eclapp/pages/signinpage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:eclapp/services/auth_service.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/cart_provider.dart';
import '../main.dart' as main_app;
import 'package:eclapp/widgets/error_display.dart';
import 'package:sms_autofill/sms_autofill.dart';
import 'package:eclapp/pages/main_tab_shell.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String email;
  final String phoneNumber;
  final String? password;
  final String? name;
  final bool resendOtpOnOpen;

  const OtpVerificationScreen({
    super.key,
    required this.email,
    required this.phoneNumber,
    this.password,
    this.name,
    this.resendOtpOnOpen = false,
  });

  @override
  OtpVerificationScreenState createState() => OtpVerificationScreenState();
}

class OtpVerificationScreenState extends State<OtpVerificationScreen>
    with CodeAutoFill {
  static const int _otpLength = 5;
  /// Matches ECL 5-character alphanumeric OTPs in SMS body text.
  static const String _otpSmsRegex = r'[0-9A-Za-z]{5}';

  final List<TextEditingController> otpControllers = List.generate(
    _otpLength,
    (_) => TextEditingController(),
  );
  final List<FocusNode> focusNodes = List.generate(
    _otpLength,
    (_) => FocusNode(),
  );
  final TextEditingController _iosAutofillBridgeController =
      TextEditingController();

  bool isLoading = false;
  bool isResending = false;
  String otp = '';
  String? _detectedSmsCode;

  @override
  void initState() {
    super.initState();
    _logAndroidSmsSetupHint();
    listenForCode(smsCodeRegexPattern: _otpSmsRegex);
    if (widget.resendOtpOnOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _requestNewOtp());
    }
  }

  Future<void> _requestNewOtp({bool showSuccess = true}) async {
    if (isResending) return;
    setState(() => isResending = true);
    try {
      final result = await AuthService.requestVerificationOtp(
        email: widget.email,
      );
      if (!mounted) return;
      if (result['success'] == true) {
        if (showSuccess) {
          _showSuccess(
            result['message']?.toString() ??
                'A new verification code has been sent.',
          );
        }
      } else {
        _showError(
          result['message']?.toString() ??
              'Could not send a new code. Please try again.',
        );
      }
    } catch (e) {
      if (mounted) {
        _showError('Could not send a new code. Please try again.');
      }
    } finally {
      if (mounted) {
        setState(() => isResending = false);
      }
    }
  }

  Future<void> _logAndroidSmsSetupHint() async {
    try {
      final signature = await SmsAutoFill().getAppSignature;
      if (signature.isNotEmpty) {
        debugPrint(
          'OTP SMS (Android): add this hash to the SMS template if auto-read fails: $signature',
        );
      }
    } catch (e) {
      debugPrint('OTP SMS setup hint unavailable: $e');
    }
  }

  @override
  void codeUpdated() {
    final incoming = code;
    if (incoming == null || incoming.isEmpty) return;
    final normalized = _extractOtp(incoming);
    if (normalized == null) return;
    _onSmsCodeDetected(normalized);
  }

  String? _extractOtp(String raw) {
    final trimmed = raw.trim();
    if (trimmed.length == _otpLength &&
        RegExp(r'^[0-9A-Za-z]+$').hasMatch(trimmed)) {
      return trimmed.toUpperCase();
    }
    final match = RegExp(_otpSmsRegex).firstMatch(trimmed);
    return match?.group(0)?.toUpperCase();
  }

  void _onSmsCodeDetected(String normalized) {
    if (!mounted) return;
    final alreadyApplied = otp == normalized &&
        otpControllers.every((c) => c.text.isNotEmpty);
    if (alreadyApplied) return;

    setState(() => _detectedSmsCode = normalized);
    _applyOtpToFields(normalized);
    HapticFeedback.lightImpact();

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
          content: Row(
            children: [
              Icon(Icons.sms_outlined, color: Colors.green.shade100, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Code from your message: $normalized',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          action: SnackBarAction(
            label: 'Use',
            textColor: Colors.white,
            onPressed: () => _applyOtpToFields(normalized),
          ),
        ),
      );
  }

  void _applyOtpToFields(String normalized) {
    if (normalized.length != _otpLength) return;
    for (var i = 0; i < _otpLength; i++) {
      otpControllers[i].text = normalized[i];
    }
    setState(() {
      otp = normalized;
      _detectedSmsCode = normalized;
    });
    focusNodes.last.unfocus();
  }

  @override
  void dispose() {
    cancel();
    unregisterListener();
    for (final controller in otpControllers) {
      controller.dispose();
    }
    for (final node in focusNodes) {
      node.dispose();
    }
    _iosAutofillBridgeController.dispose();
    super.dispose();
  }

  void _onOtpChanged(String value, int index) {
    setState(() {
      otp = otpControllers.map((controller) => controller.text).join();
      if (_detectedSmsCode != null && otp != _detectedSmsCode) {
        _detectedSmsCode = null;
      }
    });

    if (value.length == 1 && index < _otpLength - 1) {
      focusNodes[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      focusNodes[index - 1].requestFocus();
    }

    if (otp.length == _otpLength) {
      _verifyOtp();
    }
  }

  void _onIosAutofillBridgeChanged(String value) {
    final normalized = _extractOtp(value);
    if (normalized != null) {
      _onSmsCodeDetected(normalized);
    }
  }

  Future<void> _verifyOtp() async {
    if (otp.length != _otpLength) {
      _showError("Please enter the complete $_otpLength-character OTP");
      return;
    }

    setState(() => isLoading = true);

    try {
      bool isVerified = await AuthService.verifyOTP(widget.email, otp);

      if (isVerified) {
        _showSuccess("OTP verified successfully!");

        if (widget.password != null && widget.name != null) {
          try {
            debugPrint('🔄 Starting auto-login process for: ${widget.email}');

            final result =
                await AuthService.signIn(widget.email, widget.password!);

            if (result['success'] == true && result['token'] != null) {
              debugPrint('✅ Auto-login successful, token received');

              await Future.delayed(const Duration(milliseconds: 200));
              await AuthService.forceUpdateAuthState();

              try {
                if (!context.mounted) return;
                final authProvider =
                    Provider.of<AuthProvider>(context, listen: false);
                await authProvider.login();
                debugPrint('✅ AuthProvider updated successfully');
              } catch (e) {
                debugPrint('⚠️ AuthProvider update failed: $e');
              }

              try {
                if (!context.mounted) return;
                final authState = main_app.AuthState.of(context);
                authState?.refreshAuthState();
              } catch (e) {
                debugPrint('⚠️ AuthState refresh failed: $e');
              }

              try {
                final userId = await AuthService.getCurrentUserID();
                if (userId != null) {
                  if (!context.mounted) return;
                  await Provider.of<CartProvider>(context, listen: false)
                      .handleUserLogin(userId);
                }
              } catch (e) {
                debugPrint('⚠️ Cart sync failed: $e');
              }

              await Future.delayed(const Duration(milliseconds: 100));
              final isActuallyLoggedIn = await AuthService.isLoggedIn();

              if (mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const MainTabShell(),
                  ),
                  (route) => false,
                );
              }

              if (!isActuallyLoggedIn) {
                debugPrint(
                    '⚠️ User not logged in after auto-login, but continuing to home');
              }
            } else {
              debugPrint('❌ Auto-login failed: ${result['message']}');
              _showError(
                  "Auto-login failed: ${result['message'] ?? 'Unknown error'}. Please try signing in manually.");

              await Future.delayed(const Duration(seconds: 2));
              if (mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const SignInScreen()),
                );
              }
            }
          } catch (e) {
            debugPrint('❌ Exception during auto-login: $e');
            _showError("Auto-login failed. Please try signing in manually.");

            await Future.delayed(const Duration(seconds: 2));
            if (mounted) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const SignInScreen()),
              );
            }
          }
        } else {
          if (!context.mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const SignInScreen()),
          );
        }
      } else {
        _showError("Invalid OTP. Please try again.");
        for (final controller in otpControllers) {
          controller.clear();
        }
        setState(() {
          otp = '';
          _detectedSmsCode = null;
        });
        focusNodes[0].requestFocus();
      }
    } catch (e) {
      debugPrint('❌ Error during OTP verification: $e');
      _showError("An error occurred. Please try again.");
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
                const SizedBox(height: 32),
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
                          'Enter $_otpLength-character code',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _buildSmsAutofillHint(),
                        if (_detectedSmsCode != null) ...[
                          const SizedBox(height: 10),
                          _buildDetectedCodeBanner(),
                        ],
                        const SizedBox(height: 16),
                        // iOS / autofill: one-time code from Messages keyboard bar
                        SizedBox(
                          width: 1,
                          height: 1,
                          child: TextField(
                            controller: _iosAutofillBridgeController,
                            autofillHints: const [AutofillHints.oneTimeCode],
                            keyboardType: TextInputType.text,
                            textCapitalization: TextCapitalization.characters,
                            enableSuggestions: false,
                            autocorrect: false,
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              counterText: '',
                            ),
                            style: const TextStyle(
                              fontSize: 1,
                              color: Colors.transparent,
                            ),
                            onChanged: _onIosAutofillBridgeChanged,
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: List.generate(
                            _otpLength,
                            _buildOtpField,
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
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
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
                const SizedBox(height: 12),
                TextButton(
                  onPressed: isResending ? null : () => _requestNewOtp(),
                  child: isResending
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.green.shade700,
                          ),
                        )
                      : Text(
                          'Resend code',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.green.shade700,
                          ),
                        ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSmsAutofillHint() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.green.shade100),
      ),
      child: Row(
        children: [
          Icon(Icons.sms_outlined, size: 18, color: Colors.green.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'When the SMS arrives, tap the code above your keyboard or allow the prompt to fill it in.',
              style: GoogleFonts.poppins(
                fontSize: 11,
                height: 1.35,
                color: Colors.green.shade800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetectedCodeBanner() {
    final code = _detectedSmsCode!;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _applyOtpToFields(code),
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.green.shade600,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.green.shade200.withValues(alpha: 0.5),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(Icons.touch_app_rounded,
                  color: Colors.white, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Code from your text message',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                    Text(
                      code,
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 4,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                'Use',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white, size: 20),
            ],
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
        autofillHints:
            index == 0 ? const [AutofillHints.oneTimeCode] : const <String>[],
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
