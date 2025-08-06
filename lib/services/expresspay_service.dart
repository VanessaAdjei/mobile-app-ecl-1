// services/expresspay_service.dart
// services/expresspay_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class ExpressPayApi {
  String? _serverUrl;
  bool _debugMode = false;
  String? _token;

  Function(bool paymentCompleted, String message)? _paymentCompletionListener;
  Function(bool paymentSuccessful, dynamic jsonObject, String message)?
      _queryCompletionListener;

  ExpressPayApi(BuildContext context, String serverUrl) {
    _serverUrl = serverUrl;
  }

  void setPaymentCompletionListener(Function(bool, String) listener) {
    _paymentCompletionListener = listener;
  }

  void setQueryCompletionListener(Function(bool, dynamic, String) listener) {
    _queryCompletionListener = listener;
  }

  void setDebugMode(bool enabled) {
    _debugMode = enabled;
  }

  Future<void> pay(Map<String, String> params) async {
    try {
      params['request'] = 'submit';

      debugPrint('ExpressPay payment params: $params');

      if (_debugMode) {
        _token = 'DEBUG_${DateTime.now().millisecondsSinceEpoch}';
        debugPrint('Debug mode: Generated token $_token');

        await checkout();
        return;
      }

      final response = await http.post(
        Uri.parse(_serverUrl!),
        body: params,
      );

      debugPrint('ExpressPay API response: ${response.body}');

      final responseData = json.decode(response.body);
      if (responseData['status'] == '1') {
        _token = responseData['token'];
        debugPrint('Received token: $_token');
        await checkout();
      } else {
        final errorMsg = responseData['message'] ?? 'Payment failed';
        debugPrint('Payment failed: $errorMsg');
        if (_paymentCompletionListener != null) {
          _paymentCompletionListener!(false, errorMsg);
        }
      }
    } catch (e) {
      debugPrint('Payment exception: $e');
      if (_paymentCompletionListener != null) {
        _paymentCompletionListener!(false, 'Error: $e');
      }
    }
  }

  Future<void> checkout() async {
    String? url = getCheckoutUrl();
    debugPrint('Checkout URL: $url');

    if (url != null) {
      try {
        final Uri uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(
            uri,
            mode: LaunchMode.externalApplication,
            webOnlyWindowName: '_self',
          );
        } else {
          throw 'Could not launch $url';
        }
      } catch (e) {
        debugPrint('Checkout error: $e');
        if (_paymentCompletionListener != null) {
          _paymentCompletionListener!(
              false, 'Could not launch payment page: $e');
        }
      }
    } else {
      if (_paymentCompletionListener != null) {
        _paymentCompletionListener!(false, 'Missing payment token');
      }
    }
  }

  String? getCheckoutUrl() {
    return _token != null
        ? 'https://sandbox.expresspaygh.com/checkout?token=$_token'
        : null;
  }

  Future<void> query(String token) async {
    try {
      debugPrint('Querying payment with token: $token');
      final response = await http.post(
        Uri.parse('$_serverUrl?action=query'),
        body: {'token': token},
      );

      debugPrint('Query response: ${response.body}');
      final responseData = json.decode(response.body);
      final success = responseData['status'] == '1';
      debugPrint('Query success: $success');

      if (_queryCompletionListener != null) {
        _queryCompletionListener!(
            success, responseData, responseData['message'] ?? '');
      }
    } catch (e) {
      debugPrint('Query error: $e');
      if (_queryCompletionListener != null) {
        _queryCompletionListener!(false, null, 'Query error: $e');
      }
    }
  }

  String? getToken() => _token;
}

class MainActivity extends StatefulWidget {
  const MainActivity({super.key});

  @override
  MainActivityState createState() => MainActivityState();
}

class MainActivityState extends State<MainActivity> {
  late ExpressPayApi expressPayApi;

  @override
  void initState() {
    super.initState();

    expressPayApi = ExpressPayApi(
      context,
      "https://sandbox.expresspaygh.com/api/sdk/php/server.php",
    );

    expressPayApi.setDebugMode(true);
    expressPayApi.setPaymentCompletionListener(
        onExpressPayPaymentFinished as Function(bool p1, String p2));
  }

  void pay() {
    final params = {
      'request': 'submit',
      'order_id': '82373',
      'currency': 'GHS',
      'amount': '5.00',
      'order_desc': "Daily Plan",
      'user_name': 'testapi@expresspaygh.com',
      'first_name': 'Customer',
      'last_name': 'Name',
      'email': 'customer@example.com',
      'phone_number': '233244123123',
      'account_number': '233244123123',
    };
    expressPayApi.pay(params);
  }

  void displayMessageDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          content: Text(message),
          actions: <Widget>[
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void queryPayment(BuildContext context, String token) {
    expressPayApi
        .setQueryCompletionListener((paymentSuccessful, jsonObject, message) {
      if (paymentSuccessful) {
        displayMessageDialog(context, message);
      } else {
        debugPrint('expressPayDemo: $message');
        displayMessageDialog(context, message);
      }
    });
    expressPayApi.query(token);
  }

  void onExpressPayPaymentFinished(
      BuildContext context, bool paymentCompleted, String message) {
    if (paymentCompleted) {
      String? token = expressPayApi.getToken();
      if (token != null) {
        queryPayment(context, token);
      }
    } else {
      debugPrint('expressPayDemo: $message');
      displayMessageDialog(context, message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ExpressPay Demo')),
      body: Center(
        child: ElevatedButton(
          onPressed: pay,
          child: const Text('Pay Now'),
        ),
      ),
    );
  }
}
