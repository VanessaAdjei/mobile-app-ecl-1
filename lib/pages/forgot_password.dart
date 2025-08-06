// pages/forgot_password.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'app_back_button.dart';

import 'signinpage.dart';
import '../widgets/cart_icon_button.dart';
import 'package:google_fonts/google_fonts.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final TextEditingController _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _feedback;
  Color? _feedbackColor;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _feedback = null;
    });

    try {
      final response = await http
          .post(
        Uri.parse('https://eclcommerce.ernestchemists.com.gh/api/reset-pwd'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'email': _emailController.text.trim()}),
      )
          .timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw TimeoutException(
              'Request timed out. Please check your internet connection and try again.');
        },
      );

      debugPrint('Reset password response: ${response.statusCode}');
      debugPrint('Response body: ${response.body}');

      if (response.statusCode == 200) {
        // Try to parse the response
        try {
          final responseData = jsonDecode(response.body);
          debugPrint('Response data: $responseData');
          debugPrint('Status: ${responseData['status']}');

          if (responseData['status'] == 'success' ||
              responseData['message']
                      ?.toString()
                      .toLowerCase()
                      .contains('sent') ==
                  true) {
            setState(() {
              _feedback = responseData['message'] ??
                  'Password reset instructions sent! Check your email for further instructions.';
              _feedbackColor = Colors.green;
            });
            // Navigate back to sign in page after a short delay
            debugPrint('Success! Navigating to sign in page in 2 seconds...');
            Future.delayed(const Duration(seconds: 2), () {
              debugPrint('Attempting navigation...');
              if (mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => SignInScreen()),
                );
                debugPrint('Navigation completed');
              } else {
                debugPrint('Widget not mounted, cannot navigate');
              }
            });
          } else {
            setState(() {
              _feedback = responseData['message'] ??
                  'Failed to send reset instructions. Please try again.';
              _feedbackColor = Colors.orange;
            });
          }
        } catch (parseError) {
          // If JSON parsing fails, use the raw response
          debugPrint(
              'JSON parsing failed, but status code is 200. Raw response: ${response.body}');
          setState(() {
            _feedback =
                'Password reset instructions sent! Check your email for further instructions.';
            _feedbackColor = Colors.green;
          });
          // Navigate back to sign in page after a short delay
          debugPrint(
              'Success (fallback)! Navigating to sign in page in 2 seconds...');
          Future.delayed(const Duration(seconds: 2), () {
            debugPrint('Attempting navigation (fallback)...');
            if (mounted) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => SignInScreen()),
              );
              debugPrint('Navigation completed (fallback)');
            } else {
              debugPrint('Widget not mounted, cannot navigate (fallback)');
            }
          });
        }
      } else if (response.statusCode == 404) {
        setState(() {
          _feedback =
              'Email address not found. Please check your email or contact support.';
          _feedbackColor = Colors.red;
        });
      } else if (response.statusCode == 422) {
        try {
          final responseData = jsonDecode(response.body);
          final errors = responseData['errors'];
          if (errors != null && errors['email'] != null) {
            setState(() {
              _feedback = errors['email'][0] ??
                  'Invalid email format. Please check your email address.';
              _feedbackColor = Colors.red;
            });
          } else {
            setState(() {
              _feedback = responseData['message'] ??
                  'Invalid email format. Please check your email address.';
              _feedbackColor = Colors.red;
            });
          }
        } catch (parseError) {
          setState(() {
            _feedback =
                'Invalid email format. Please check your email address.';
            _feedbackColor = Colors.red;
          });
        }
      } else if (response.statusCode == 429) {
        setState(() {
          _feedback =
              'Too many requests. Please wait a few minutes before trying again.';
          _feedbackColor = Colors.orange;
        });
      } else if (response.statusCode >= 500) {
        setState(() {
          _feedback =
              'Server error. Please try again later or contact support if the problem persists.';
          _feedbackColor = Colors.red;
        });
      } else {
        try {
          final responseData = jsonDecode(response.body);
          setState(() {
            _feedback = responseData['message'] ??
                'Failed to send reset instructions. Please try again.';
            _feedbackColor = Colors.red;
          });
        } catch (parseError) {
          setState(() {
            _feedback = 'Failed to send reset instructions. Please try again.';
            _feedbackColor = Colors.red;
          });
        }
      }
    } on TimeoutException catch (e) {
      setState(() {
        _feedback = e.message ??
            'Request timed out. Please check your internet connection and try again.';
        _feedbackColor = Colors.orange;
      });
    } on FormatException catch (e) {
      setState(() {
        _feedback = 'Invalid response from server. Please try again.';
        _feedbackColor = Colors.red;
      });
      debugPrint('Format exception: $e');
    } on SocketException catch (e) {
      setState(() {
        _feedback =
            'No internet connection. Please check your network and try again.';
        _feedbackColor = Colors.red;
      });
      debugPrint('Socket exception: $e');
    } on HttpException catch (e) {
      setState(() {
        _feedback =
            'Network error. Please check your connection and try again.';
        _feedbackColor = Colors.red;
      });
      debugPrint('HTTP exception: $e');
    } catch (e) {
      setState(() {
        _feedback = 'An unexpected error occurred. Please try again.';
        _feedbackColor = Colors.red;
      });
      debugPrint('Unexpected error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70.0),
        child: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          titleSpacing: 0,
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.green.shade700,
                  Colors.green.shade800,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
          ),
          title: Text(
            'Forgot Password',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
          leading: BackButtonUtils.simple(
            backgroundColor: Colors.white.withValues(alpha: 0.2),
            iconColor: Colors.white,
          ),
          actions: [
            Container(
              margin: EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: CartIconButton(
                iconColor: Colors.white,
                iconSize: 24,
                backgroundColor: Colors.transparent,
              ),
            ),
          ],
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.lock_reset, color: Colors.green, size: 48),
                  const SizedBox(height: 16),
                  const Text(
                    'Reset your password',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Enter your email and we\'ll send you instructions to reset your password.',
                    style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'Email or Phone',
                      prefixIcon:
                          const Icon(Icons.email_outlined, color: Colors.green),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter your email or phone';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.green.shade300,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text('Send Reset Link',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  if (_feedback != null) ...[
                    const SizedBox(height: 18),
                    Text(
                      _feedback!,
                      style: TextStyle(
                          color: _feedbackColor, fontWeight: FontWeight.w600),
                      textAlign: TextAlign.center,
                    ),
                    // Add manual navigation button for success case
                    if (_feedbackColor == Colors.green) ...[
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 40,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => SignInScreen()),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade600,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text('Back to Sign In'),
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
