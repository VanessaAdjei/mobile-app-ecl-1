// pages/forgot_password.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'AppBackButton.dart';
import 'HomePage.dart';
import 'Cart.dart';
import 'package:provider/provider.dart';
import 'cart.dart';
import 'cartprovider.dart';
import '../widgets/cart_icon_button.dart';

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
      final response = await http.post(
        Uri.parse('https://eclcommerce.ernestchemists.com.gh/api/reset-pwd'),
        body: {'email': _emailController.text.trim()},
      );
      if (response.statusCode == 200) {
        setState(() {
          _feedback = 'Password reset instructions sent!';
          _feedbackColor = Colors.green;
        });
      } else {
        setState(() {
          _feedback = 'Failed to send reset instructions: ${response.body}';
          _feedbackColor = Colors.red;
        });
      }
    } catch (e) {
      setState(() {
        _feedback = 'Error: $e';
        _feedbackColor = Colors.red;
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(40.0),
        child: AppBar(
          backgroundColor:
              theme.appBarTheme.backgroundColor ?? Colors.green.shade700,
          elevation: theme.appBarTheme.elevation ?? 0,
          centerTitle: theme.appBarTheme.centerTitle ?? true,
          titleSpacing: 0,
          title: const Text(
            'Forgot Password',
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
          ),
          leading: AppBackButton(
            backgroundColor: theme.primaryColor,
            iconColor: Colors.white,
            onPressed: () {
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
              } else {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => HomePage()),
                );
              }
            },
          ),
          actions: [
            CartIconButton(
              iconColor: Colors.white,
              iconSize: 24,
              backgroundColor: Colors.transparent,
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
                  color: Colors.black.withOpacity(0.05),
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
                    'Enter your email or phone number and we\'ll send you instructions to reset your password.',
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
