import 'package:eclapp/pages/signinpage.dart';
import 'package:flutter/cupertino.dart';

import 'auth_service.dart';

class ProtectedRoute extends StatelessWidget {
  final Widget child;

  const ProtectedRoute({required this.child, super.key});

  @override
  Widget build(BuildContext context) {
    final authState = AuthState.of(context);

    if (authState == null || !authState.isLoggedIn) {
      return SignInScreen(
        returnTo: ModalRoute.of(context)?.settings.name,
      );
    }

    return child;
  }
}