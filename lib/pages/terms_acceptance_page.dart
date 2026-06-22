import 'package:eclapp/config/app_colors.dart';
import 'package:eclapp/services/home_preload_service.dart';
import 'package:eclapp/utils/app_error_utils.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'privacypolicy.dart';
import 'terms_and_conditions_page.dart';

class TermsAcceptancePage extends StatefulWidget {
  final VoidCallback? onAccepted;

  const TermsAcceptancePage({super.key, this.onAccepted});

  @override
  State<TermsAcceptancePage> createState() => _TermsAcceptancePageState();
}

class _TermsAcceptancePageState extends State<TermsAcceptancePage> {
  bool _termsAccepted = false;
  bool _isLoading = false;

  late final TapGestureRecognizer _termsTapRecognizer;
  late final TapGestureRecognizer _privacyTapRecognizer;
  late final TapGestureRecognizer _dataProtectionTapRecognizer;

  @override
  void initState() {
    super.initState();
    HomePreloadService.startOnboardingPreload();
    _termsTapRecognizer = TapGestureRecognizer()..onTap = _showTermsDialog;
    _privacyTapRecognizer = TapGestureRecognizer()..onTap = _showPrivacyPolicy;
    _dataProtectionTapRecognizer = TapGestureRecognizer()
      ..onTap = _launchDataProtectionUrl;
  }

  @override
  void dispose() {
    _termsTapRecognizer.dispose();
    _privacyTapRecognizer.dispose();
    _dataProtectionTapRecognizer.dispose();
    super.dispose();
  }

  Future<void> _launchDataProtectionUrl() async {
    final url = Uri.parse('https://dataprotection.org.gh/');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      AppErrorUtils.showSnack(context, 'Could not open the website');
    }
  }

  Future<void> _acceptAndContinue() async {
    if (!_termsAccepted) {
      AppErrorUtils.showSnack(
        context,
        'Please accept the Terms & Conditions to continue',
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('terms_accepted', true);
      await prefs.setString(
        'terms_accepted_date',
        DateTime.now().toIso8601String(),
      );

      if (!mounted) return;
      debugPrint('✅ Terms accepted');
      widget.onAccepted?.call();
    } catch (e) {
      if (!mounted) return;
      AppErrorUtils.showSnack(context, 'Error: $e');
      setState(() => _isLoading = false);
    }
  }

  void _showTermsDialog() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const TermsAndConditionsPage()),
    );
  }

  void _showPrivacyPolicy() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const PrivacyPolicyScreen()),
    );
  }

  void _toggleAccepted() {
    setState(() => _termsAccepted = !_termsAccepted);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: Colors.white,
      body: MediaQuery.removePadding(
        context: context,
        removeTop: true,
        child: Column(
          children: [
            const _TermsWaveHeader(),
            Expanded(
              child: Transform.translate(
                offset: const Offset(0, -22),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 20,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Column(
                          children: [
                            Text(
                              'Welcome to Ernest Chemists Ltd',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF111827),
                                height: 1.3,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Center(
                              child: Container(
                                width: 28,
                                height: 2.5,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(2),
                                  gradient: LinearGradient(
                                    colors: [
                                      AppColors.primary.withValues(alpha: 0.4),
                                      AppColors.primary,
                                      AppColors.primary.withValues(alpha: 0.4),
                                    ],
                                  ),
                                ),
                              )
                                  .animate()
                                  .scaleX(
                                    begin: 0,
                                    end: 1,
                                    duration: 500.ms,
                                    curve: Curves.easeOutCubic,
                                    delay: 400.ms,
                                    alignment: Alignment.center,
                                  ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Review and accept our terms to continue using the app.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w400,
                                height: 1.5,
                                color: const Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        )
                            .animate()
                            .fadeIn(
                              duration: 450.ms,
                              curve: Curves.easeOut,
                              delay: 250.ms,
                            )
                            .slideY(
                              begin: 0.15,
                              end: 0,
                              duration: 500.ms,
                              curve: Curves.easeOutCubic,
                              delay: 250.ms,
                            ),
                        const SizedBox(height: 20),
                        _ConsentSection(
                          accepted: _termsAccepted,
                          onToggle: _toggleAccepted,
                          termsRecognizer: _termsTapRecognizer,
                          privacyRecognizer: _privacyTapRecognizer,
                        )
                            .animate()
                            .fadeIn(
                              duration: 450.ms,
                              curve: Curves.easeOut,
                              delay: 380.ms,
                            )
                            .slideY(
                              begin: 0.12,
                              end: 0,
                              duration: 480.ms,
                              curve: Curves.easeOutCubic,
                              delay: 380.ms,
                            ),
                        const SizedBox(height: 18),
                        Text(
                          'READ FULL DOCUMENTS',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1,
                            color: const Color(0xFF9CA3AF),
                          ),
                        )
                            .animate()
                            .fadeIn(duration: 400.ms, delay: 500.ms),
                        const SizedBox(height: 10),
                        _DocumentRow(
                          icon: Icons.description_outlined,
                          title: 'Terms & Conditions',
                          onTap: _showTermsDialog,
                        )
                            .animate()
                            .fadeIn(
                              duration: 420.ms,
                              curve: Curves.easeOut,
                              delay: 560.ms,
                            )
                            .slideX(
                              begin: -0.06,
                              end: 0,
                              duration: 450.ms,
                              curve: Curves.easeOutCubic,
                              delay: 560.ms,
                            ),
                        const SizedBox(height: 6),
                        _DocumentRow(
                          icon: Icons.privacy_tip_outlined,
                          title: 'Privacy Statement',
                          onTap: _showPrivacyPolicy,
                        )
                            .animate()
                            .fadeIn(
                              duration: 420.ms,
                              curve: Curves.easeOut,
                              delay: 640.ms,
                            )
                            .slideX(
                              begin: -0.06,
                              end: 0,
                              duration: 450.ms,
                              curve: Curves.easeOutCubic,
                              delay: 640.ms,
                            ),
                        const SizedBox(height: 14),
                        _DataProtectionNote(
                          recognizer: _dataProtectionTapRecognizer,
                        )
                            .animate()
                            .fadeIn(
                              duration: 400.ms,
                              curve: Curves.easeOut,
                              delay: 720.ms,
                            )
                            .slideY(
                              begin: 0.08,
                              end: 0,
                              duration: 420.ms,
                              curve: Curves.easeOutCubic,
                              delay: 720.ms,
                            ),
                      ],
                    ),
                  ),
                )
                    .animate()
                    .fadeIn(
                      duration: 500.ms,
                      curve: Curves.easeOut,
                      delay: 120.ms,
                    )
                    .slideY(
                      begin: 0.08,
                      end: 0,
                      duration: 550.ms,
                      curve: Curves.easeOutCubic,
                      delay: 120.ms,
                    ),
              ),
            ),
            Transform.translate(
              offset: const Offset(0, -8),
              child: Align(
                alignment: Alignment.center,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(20, 0, 20, 12 + bottomInset),
                  child: AnimatedScale(
                    scale: _termsAccepted ? 1 : 0.98,
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    child: SizedBox(
                      width: double.infinity,
                      height: 42,
                      child: ElevatedButton(
                        onPressed: (_isLoading || !_termsAccepted)
                            ? null
                            : _acceptAndContinue,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: const Color(0xFFE5E7EB),
                          disabledForegroundColor: const Color(0xFF9CA3AF),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                'Accept & Continue',
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                  ),
                )
                    .animate()
                    .fadeIn(
                      duration: 450.ms,
                      curve: Curves.easeOut,
                      delay: 800.ms,
                    )
                    .slideY(
                      begin: 0.2,
                      end: 0,
                      duration: 480.ms,
                      curve: Curves.easeOutCubic,
                      delay: 800.ms,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TermsWaveHeader extends StatelessWidget {
  const _TermsWaveHeader();

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final topInset = MediaQuery.paddingOf(context).top;
    final headerHeight = (size.height * 0.32).clamp(250.0, 310.0) + topInset;

    return ClipPath(
      clipper: _TermsWaveClipper(),
      child: SizedBox(
        height: headerHeight,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF062A12),
                    Color(0xFF0D3D18),
                    AppColors.accent,
                    Color(0xFF2E7D32),
                  ],
                  stops: [0.0, 0.28, 0.62, 1.0],
                ),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0.85, -0.35),
                  radius: 1.1,
                  colors: [
                    AppColors.primaryLight.withValues(alpha: 0.28),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
            Positioned(
              right: -30,
              top: topInset + 10,
              child: CircleAvatar(
                radius: 52,
                backgroundColor: Colors.white.withValues(alpha: 0.06),
              ),
            ),
            Positioned(
              left: -22,
              bottom: 28,
              child: CircleAvatar(
                radius: 34,
                backgroundColor: Colors.white.withValues(alpha: 0.05),
              ),
            ),
            Positioned(
              right: 40,
              bottom: 40,
              child: CircleAvatar(
                radius: 14,
                backgroundColor: AppColors.primaryLight.withValues(alpha: 0.14),
              ),
            ),
            Center(
              child: Padding(
                padding: EdgeInsets.only(top: topInset * 0.3),
                child: const _TermsHeaderLogo(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TermsHeaderLogo extends StatefulWidget {
  const _TermsHeaderLogo();

  @override
  State<_TermsHeaderLogo> createState() => _TermsHeaderLogoState();
}

class _TermsHeaderLogoState extends State<_TermsHeaderLogo>
    with TickerProviderStateMixin {
  late final AnimationController _enterController;
  late final AnimationController _pulseController;
  late final Animation<double> _enterScale;
  late final Animation<double> _enterOpacity;
  late final Animation<double> _pulseScale;

  @override
  void initState() {
    super.initState();
    _enterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
    _enterScale = Tween<double>(begin: 0.82, end: 1).animate(
      CurvedAnimation(parent: _enterController, curve: Curves.easeOutBack),
    );
    _enterOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _enterController, curve: Curves.easeOut),
    );
    _pulseScale = Tween<double>(begin: 1, end: 1.04).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _enterController.forward();
    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _enterController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_enterController, _pulseController]),
      builder: (context, child) {
        return Opacity(
          opacity: _enterOpacity.value,
          child: Transform.scale(
            scale: _enterScale.value * _pulseScale.value,
            child: child,
          ),
        );
      },
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.14),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: CircleAvatar(
          radius: 62,
          backgroundColor: Colors.white.withValues(alpha: 0.14),
          child: CircleAvatar(
            radius: 56,
            backgroundColor: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(11),
              child: Image.asset(
                'assets/images/png.png',
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ConsentSection extends StatefulWidget {
  const _ConsentSection({
    required this.accepted,
    required this.onToggle,
    required this.termsRecognizer,
    required this.privacyRecognizer,
  });

  final bool accepted;
  final VoidCallback onToggle;
  final TapGestureRecognizer termsRecognizer;
  final TapGestureRecognizer privacyRecognizer;

  @override
  State<_ConsentSection> createState() => _ConsentSectionState();
}

class _ConsentSectionState extends State<_ConsentSection>
    with SingleTickerProviderStateMixin {
  late final AnimationController _checkController;
  late final Animation<double> _checkScale;

  @override
  void initState() {
    super.initState();
    _checkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _checkScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.08), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.08, end: 1.0), weight: 60),
    ]).animate(CurvedAnimation(
      parent: _checkController,
      curve: Curves.easeOutCubic,
    ));
  }

  @override
  void didUpdateWidget(covariant _ConsentSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.accepted && !oldWidget.accepted) {
      _checkController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _checkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onToggle,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            color: widget.accepted
                ? AppColors.primary.withValues(alpha: 0.06)
                : const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color:
                  widget.accepted ? AppColors.primary : const Color(0xFFE5E7EB),
              width: widget.accepted ? 1.5 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ScaleTransition(
                scale: _checkScale,
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: Checkbox(
                    value: widget.accepted,
                    onChanged: (_) => widget.onToggle(),
                    activeColor: AppColors.primary,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: GoogleFonts.poppins(
                      fontSize: 11.5,
                      color: const Color(0xFF374151),
                      height: 1.5,
                    ),
                    children: [
                      const TextSpan(text: 'I accept the '),
                      TextSpan(
                        text: 'Terms & Conditions',
                        style: const TextStyle(
                          color: AppColors.primaryDark,
                          fontWeight: FontWeight.w600,
                        ),
                        recognizer: widget.termsRecognizer,
                      ),
                      const TextSpan(text: ' and '),
                      TextSpan(
                        text: 'Privacy Statement',
                        style: const TextStyle(
                          color: AppColors.primaryDark,
                          fontWeight: FontWeight.w600,
                        ),
                        recognizer: widget.privacyRecognizer,
                      ),
                      const TextSpan(text: '.'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DocumentRow extends StatefulWidget {
  const _DocumentRow({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  State<_DocumentRow> createState() => _DocumentRowState();
}

class _DocumentRowState extends State<_DocumentRow> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF9FAFB),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: widget.onTap,
        onHighlightChanged: (v) => setState(() => _pressed = v),
        borderRadius: BorderRadius.circular(10),
        child: AnimatedScale(
          scale: _pressed ? 0.98 : 1,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOutCubic,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(widget.icon, size: 16, color: AppColors.primaryDark),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1F2937),
                        ),
                      ),
                      Text(
                        'Tap to read',
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          color: const Color(0xFF9CA3AF),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: AppColors.primary.withValues(alpha: 0.7),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DataProtectionNote extends StatelessWidget {
  const _DataProtectionNote({required this.recognizer});

  final TapGestureRecognizer recognizer;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.15),
        ),
      ),
      child: RichText(
        textAlign: TextAlign.center,
        text: TextSpan(
          style: GoogleFonts.poppins(
            fontSize: 10,
            height: 1.45,
            color: const Color(0xFF6B7280),
          ),
          children: [
            const TextSpan(text: 'Your data rights · '),
            TextSpan(
              text: 'Ghana Data Protection Commission',
              style: const TextStyle(
                color: AppColors.primaryDark,
                fontWeight: FontWeight.w600,
              ),
              recognizer: recognizer,
            ),
          ],
        ),
      ),
    );
  }
}

class _TermsWaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height - 22);
    path.quadraticBezierTo(
      size.width * 0.5,
      size.height + 8,
      size.width,
      size.height - 22,
    );
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
