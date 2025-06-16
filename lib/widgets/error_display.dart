// widgets/error_display.dart
import 'package:flutter/material.dart';

class ErrorDisplay extends StatelessWidget {
  final String errorMessage;
  final VoidCallback? onRetry;
  final IconData? icon;
  final String? title;
  final Color? iconColor;
  final Color? textColor;
  final double? iconSize;
  final double? fontSize;

  const ErrorDisplay({
    Key? key,
    required this.errorMessage,
    this.onRetry,
    this.icon = Icons.error_outline,
    this.title = 'Oops! Something went wrong',
    this.iconColor = Colors.red,
    this.textColor = Colors.grey,
    this.iconSize = 48,
    this.fontSize = 16,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: iconColor?.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: iconSize,
                color: iconColor,
              ),
            ),
            SizedBox(height: 24),
            Text(
              title!,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            SizedBox(height: 8),
            Text(
              errorMessage,
              style: TextStyle(
                fontSize: fontSize,
                color: textColor,
              ),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: Icon(Icons.refresh),
                label: Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade700,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
