import 'package:eclapp/pages/signinpage.dart';
import 'package:flutter/material.dart';
import 'auth_service.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String email;

  const OtpVerificationScreen({super.key, required this.email});

  @override
  _OtpVerificationScreenState createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final TextEditingController otpController = TextEditingController();
  bool isLoading = false;

  Future<void> _verifyOtp() async {
    setState(() => isLoading = true);

    bool isVerified = await AuthService.verifyOTP(widget.email, otpController.text.trim());

    setState(() => isLoading = false);

    if (isVerified) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("OTP verified successfully!")),
      );

      // Navigate to Sign In page
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => SignInScreen()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Invalid OTP. Please try again.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Verify OTP")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text("Enter the OTP sent to ${widget.email}", style: TextStyle(fontSize: 16)),
            SizedBox(height: 20),
            TextField(
              controller: otpController,
              keyboardType: TextInputType.text,
              decoration: InputDecoration(labelText: "OTP"),
            ),
            SizedBox(height: 20),
            isLoading
                ? CircularProgressIndicator()
                : ElevatedButton(
              onPressed: _verifyOtp,
              child: Text("Verify OTP"),
            ),
          ],
        ),
      ),
    );
  }
}
