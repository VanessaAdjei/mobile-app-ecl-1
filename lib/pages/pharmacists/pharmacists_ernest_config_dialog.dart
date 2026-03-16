// Ernest AI configuration dialog (Gemini API key) for Pharmacists page.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/ernest_ai_service.dart';

class ErnestConfigurationDialog extends StatefulWidget {
  const ErnestConfigurationDialog({super.key});

  @override
  State<ErnestConfigurationDialog> createState() =>
      _ErnestConfigurationDialogState();
}

class _ErnestConfigurationDialogState extends State<ErnestConfigurationDialog> {
  final TextEditingController _apiKeyController = TextEditingController();
  bool _isConfiguring = false;
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 25,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.purple[400]!, Colors.purple[600]!],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.smart_toy,
                color: Colors.white,
                size: 48,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Configure Ask Ernest',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'To use Ernest, you need a Google Gemini API key. Get one for free at:\nhttps://makersuite.google.com/app/apikey',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _apiKeyController,
              decoration: InputDecoration(
                labelText: 'Google Gemini API Key',
                hintText: 'Enter your API key here',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: Icon(Icons.key, color: Colors.purple[600]),
              ),
              obscureText: true,
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.red[600],
                ),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => Navigator.pop(context),
                        child: Center(
                          child: Text(
                            'Cancel',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[700],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.purple[500]!, Colors.purple[600]!],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: _isConfiguring ? null : _configureService,
                        child: Center(
                          child: _isConfiguring
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white),
                                  ),
                                )
                              : Text(
                                  'Configure',
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _configureService() async {
    if (_apiKeyController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter your API key';
      });
      return;
    }

    setState(() {
      _isConfiguring = true;
      _errorMessage = null;
    });

    try {
      final success = await ErnestAIService.configure(_apiKeyController.text);
      if (!mounted) return;
      if (success) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Ernest AI configured successfully! 🎉'),
            backgroundColor: Colors.green[600],
          ),
        );
      } else {
        setState(() {
          _errorMessage = 'Invalid API key. Please check and try again.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Configuration failed: ${e.toString()}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isConfiguring = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }
}
