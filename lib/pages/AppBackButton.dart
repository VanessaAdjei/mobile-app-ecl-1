// pages/AppBackButton.dart
import 'package:flutter/material.dart';
import 'homepage.dart';

class AppBackButton extends StatelessWidget {
  final Color backgroundColor;
  final Color iconColor;
  final VoidCallback? onPressed;

  const AppBackButton({
    Key? key,
    this.backgroundColor = const Color(0xFF43A047), // green[600]
    this.iconColor = Colors.white,
    this.onPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        borderRadius: BorderRadius.circular(100),
        onTap: onPressed ??
            () {
              if (Navigator.canPop(context) && !(ModalRoute.of(context)?.isFirst ?? false)) {
                Navigator.pop(context);
              } else {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const HomePage()),
                  (route) => false,
                );
              }
            },
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: backgroundColor,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.arrow_back_rounded,
            color: iconColor,
            size: 20,
          ),
        ),
      ),
    );
  }
}
