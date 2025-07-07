// pages/pharmacists.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'AppBackButton.dart';
import '../widgets/cart_icon_button.dart';
import 'homepage.dart';

class PharmacistsPage extends StatefulWidget {
  const PharmacistsPage({Key? key}) : super(key: key);

  @override
  State<PharmacistsPage> createState() => _PharmacistsPageState();
}

class _PharmacistsPageState extends State<PharmacistsPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _symptomsController = TextEditingController();
  final TextEditingController _chatController = TextEditingController();

  String _selectedConsultationType = 'WhatsApp';
  String _selectedGenderPreference = 'No Preference';
  DateTime _selectedDate = DateTime.now().add(Duration(days: 1));
  TimeOfDay _selectedTime = TimeOfDay.now();

  bool _isChatOpen = false;
  bool _isTyping = false;
  List<ChatMessage> _chatMessages = [];

  final List<String> _consultationTypes = [
    'WhatsApp',
    'Zoom',
    'Phone Call',
  ];
  final List<String> _genderPreferences = [
    'No Preference',
    'Male Pharmacist',
    'Female Pharmacist'
  ];

  @override
  void initState() {
    super.initState();
    // Add welcome message to chat
    _chatMessages.add(ChatMessage(
      text:
          "Hello! I'm your health assistant. I can help you with general health questions and guide you to the right pharmacist. How can I help you today?",
      isUser: false,
    ));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _symptomsController.dispose();
    _chatController.dispose();
    super.dispose();
  }

  void _showContactOptions(BuildContext context, String phoneNumber) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.call, color: Colors.green),
                title: Text('Call'),
                onTap: () {
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  }
                  _launchPhoneDialer(phoneNumber);
                },
              ),
              ListTile(
                leading:
                    FaIcon(FontAwesomeIcons.whatsapp, color: Color(0xFF25D366)),
                title: Text('WhatsApp'),
                onTap: () {
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  }
                  _launchWhatsApp(phoneNumber,
                      "Hello, I'd like to speak with a pharmacist.");
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _launchPhoneDialer(String phoneNumber) async {
    final Uri callUri = Uri.parse("tel:$phoneNumber");
    if (await canLaunchUrl(callUri)) {
      await launchUrl(callUri);
    }
  }

  void _launchWhatsApp(String phoneNumber, String message) async {
    if (!phoneNumber.startsWith('+')) {
      phoneNumber = '+233${phoneNumber.substring(1)}';
    }
    String whatsappUrl =
        'whatsapp://send?phone=$phoneNumber&text=${Uri.encodeComponent(message)}';
    if (await canLaunch(whatsappUrl)) {
      await launch(whatsappUrl);
    }
  }

  void _showBookingForm() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.9,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 25,
                offset: Offset(0, -8),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Column(
              children: [
                // Enhanced Handle bar with animation
                Container(
                  margin: EdgeInsets.only(top: 12),
                  width: 50,
                  height: 5,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.grey[400]!, Colors.grey[300]!],
                    ),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.3),

                // Enhanced Header with animations
                Container(
                  padding: EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.green[600]!,
                        Colors.green[700]!,
                        Colors.green[800]!
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      stops: [0.0, 0.5, 1.0],
                    ),
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(25)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.withOpacity(0.3),
                        blurRadius: 15,
                        offset: Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.calendar_today,
                          color: Colors.white,
                          size: 26,
                        ),
                      )
                          .animate()
                          .scale(duration: 600.ms, curve: Curves.elasticOut),
                      SizedBox(width: 18),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Book Virtual Consultation',
                              style: GoogleFonts.poppins(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            )
                                .animate()
                                .fadeIn(delay: 200.ms)
                                .slideX(begin: 0.3),
                            SizedBox(height: 4),
                            Text(
                              'Get expert advice from our pharmacists',
                              style: GoogleFonts.poppins(
                                fontSize: 15,
                                color: Colors.white.withOpacity(0.95),
                                height: 1.2,
                              ),
                            )
                                .animate()
                                .fadeIn(delay: 400.ms)
                                .slideX(begin: 0.3),
                          ],
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 6,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon:
                              Icon(Icons.close, color: Colors.white, size: 22),
                          tooltip: 'Close',
                        ),
                      )
                          .animate()
                          .scale(duration: 400.ms, curve: Curves.elasticOut),
                    ],
                  ),
                ).animate().fadeIn(delay: 100.ms).slideY(begin: -0.2),

                // Enhanced Form content with animations
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(24),
                    child: Column(
                      children: [
                        // Progress indicator
                        _buildProgressIndicator(),
                        SizedBox(height: 24),

                        // Form fields with staggered animations
                        _buildModernDropdownField(
                          'Consultation Type',
                          _selectedConsultationType,
                          _consultationTypes,
                          (value) => setState(
                              () => _selectedConsultationType = value!),
                          Icons.video_call,
                        ).animate().fadeIn(delay: 600.ms).slideX(begin: 0.2),
                        SizedBox(height: 20),

                        _buildModernDropdownField(
                          'Pharmacist Gender Preference',
                          _selectedGenderPreference,
                          _genderPreferences,
                          (value) => setState(
                              () => _selectedGenderPreference = value!),
                          Icons.person,
                        ).animate().fadeIn(delay: 700.ms).slideX(begin: 0.2),
                        SizedBox(height: 20),

                        _buildModernTextField(
                          'Full Name',
                          _nameController,
                          Icons.person_outline,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your full name';
                            }
                            return null;
                          },
                        ).animate().fadeIn(delay: 800.ms).slideX(begin: 0.2),
                        SizedBox(height: 20),

                        _buildModernTextField(
                          'Phone Number',
                          _phoneController,
                          Icons.phone,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your phone number';
                            }
                            if (!RegExp(r'^\+?[\d\s-]+$').hasMatch(value)) {
                              return 'Please enter a valid phone number';
                            }
                            return null;
                          },
                        ).animate().fadeIn(delay: 900.ms).slideX(begin: 0.2),
                        SizedBox(height: 20),

                        _buildModernTextField(
                          'Symptoms/Concerns',
                          _symptomsController,
                          Icons.medical_services,
                          maxLines: 3,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please describe your symptoms or concerns';
                            }
                            return null;
                          },
                        ).animate().fadeIn(delay: 1000.ms).slideX(begin: 0.2),
                        SizedBox(height: 20),

                        _buildModernDatePicker()
                            .animate()
                            .fadeIn(delay: 1100.ms)
                            .slideX(begin: 0.2),
                        SizedBox(height: 20),

                        _buildModernTimePicker()
                            .animate()
                            .fadeIn(delay: 1200.ms)
                            .slideX(begin: 0.2),
                        SizedBox(height: 30),

                        // Enhanced submit button with loading state
                        _buildEnhancedSubmitButton(),
                        SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green[50]!, Colors.blue[50]!],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green[200]!, width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.green[600],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.check, color: Colors.white, size: 16),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Booking Progress',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.green[800],
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Fill in your details to book your consultation',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.green[700],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedSubmitButton() {
    return Container(
      width: double.infinity,
      height: 52,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green[500]!, Colors.green[600]!, Colors.green[700]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: [0.0, 0.5, 1.0],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.3),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _submitBookingWithValidation,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.check_circle,
                  color: Colors.white,
                  size: 20,
                ),
                SizedBox(width: 12),
                Text(
                  'Book Consultation',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn(delay: 1300.ms).scale(begin: Offset(0.8, 0.8));
  }

  void _submitBookingWithValidation() {
    // Validate all fields
    String? nameError =
        _nameController.text.isEmpty ? 'Please enter your full name' : null;
    String? phoneError =
        _phoneController.text.isEmpty ? 'Please enter your phone number' : null;
    String? symptomsError = _symptomsController.text.isEmpty
        ? 'Please describe your symptoms'
        : null;

    if (nameError != null || phoneError != null || symptomsError != null) {
      // Show validation errors
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Container(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Please complete all required fields:',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                if (nameError != null)
                  Text('• $nameError',
                      style: GoogleFonts.poppins(fontSize: 12)),
                if (phoneError != null)
                  Text('• $phoneError',
                      style: GoogleFonts.poppins(fontSize: 12)),
                if (symptomsError != null)
                  Text('• $symptomsError',
                      style: GoogleFonts.poppins(fontSize: 12)),
              ],
            ),
          ),
          backgroundColor: Colors.red[600],
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }

    // Show loading state
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _buildLoadingDialog(),
    );

    // Simulate API call
    Future.delayed(Duration(seconds: 2), () {
      Navigator.pop(context); // Close loading dialog
      _showSuccessDialog();
    });
  }

  Widget _buildLoadingDialog() {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(16),
              ),
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.green[600]!),
                strokeWidth: 3,
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Booking Your Consultation...',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Please wait while we process your request',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.green[400]!, Colors.green[600]!],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.check_circle,
                  color: Colors.white,
                  size: 48,
                ),
              ),
              SizedBox(height: 16),
              Text(
                'Booking Successful!',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Your consultation has been booked successfully. We\'ll contact you soon to confirm the details.',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 20),
              Container(
                width: double.infinity,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.green[500]!, Colors.green[600]!],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      Navigator.pop(context); // Close success dialog
                      Navigator.pop(context); // Close booking form
                      // Clear form
                      _nameController.clear();
                      _phoneController.clear();
                      _symptomsController.clear();
                      setState(() {
                        _selectedDate = DateTime.now().add(Duration(days: 1));
                        _selectedTime = TimeOfDay.now();
                      });
                    },
                    child: Center(
                      child: Text(
                        'Done',
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernDropdownField(String label, String value,
      List<String> options, Function(String?) onChanged, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.green[700], size: 20),
            SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
          ],
        ),
        SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: DropdownButtonFormField<String>(
            value: value,
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              suffixIcon:
                  Icon(Icons.keyboard_arrow_down, color: Colors.green[700]),
            ),
            items: options.map((String option) {
              return DropdownMenuItem<String>(
                value: option,
                child: Text(
                  option,
                  style: GoogleFonts.poppins(fontSize: 14),
                ),
              );
            }).toList(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildModernTextField(
      String label, TextEditingController controller, IconData icon,
      {int maxLines = 1, String? Function(String?)? validator}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.green[700], size: 20),
            SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
          ],
        ),
        SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: TextField(
            controller: controller,
            maxLines: maxLines,
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildModernDatePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.calendar_today, color: Colors.green[700], size: 20),
            SizedBox(width: 8),
            Text(
              'Preferred Date',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
          ],
        ),
        SizedBox(height: 8),
        InkWell(
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: _selectedDate,
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(Duration(days: 30)),
              builder: (context, child) {
                return Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: ColorScheme.light(
                      primary: Colors.green[700]!,
                      onPrimary: Colors.white,
                    ),
                  ),
                  child: child!,
                );
              },
            );
            if (date != null) {
              setState(() => _selectedDate = date);
            }
          },
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                  style: GoogleFonts.poppins(fontSize: 14),
                ),
                Icon(Icons.calendar_today, color: Colors.green[700]),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildModernTimePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.access_time, color: Colors.green[700], size: 20),
            SizedBox(width: 8),
            Text(
              'Preferred Time',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
          ],
        ),
        SizedBox(height: 8),
        InkWell(
          onTap: () async {
            final time = await showTimePicker(
              context: context,
              initialTime: _selectedTime,
              initialEntryMode: TimePickerEntryMode.input,
              builder: (context, child) {
                return Theme(
                  data: Theme.of(context).copyWith(
                    timePickerTheme: TimePickerThemeData(
                      hourMinuteTextColor: Colors.green[700],
                      hourMinuteColor: Colors.green[50],
                      dialHandColor: Colors.green[700],
                      dialBackgroundColor: Colors.green[50],
                      dialTextColor: Colors.green[700],
                      entryModeIconColor: Colors.green[700],
                    ),
                  ),
                  child: child!,
                );
              },
            );
            if (time != null) {
              setState(() => _selectedTime = time);
            }
          },
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _selectedTime.format(context),
                  style: GoogleFonts.poppins(fontSize: 14),
                ),
                Icon(Icons.access_time, color: Colors.green[700]),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGradientButton(
      String text, IconData icon, VoidCallback onPressed) {
    return Container(
      width: double.infinity,
      height: 45,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green[600]!, Colors.green[700]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.25),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 16),
            SizedBox(width: 6),
            Text(
              text,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _submitBooking() {
    // Here you would typically send the booking to your backend
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
            Text('Consultation booked successfully! We\'ll contact you soon.'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
    Navigator.pop(context);
  }

  void _sendChatMessage() {
    if (_chatController.text.trim().isEmpty) return;

    String userMessage = _chatController.text.trim();
    _chatMessages.add(ChatMessage(text: userMessage, isUser: true));
    _chatController.clear();

    // Add typing indicator
    setState(() {
      _isTyping = true;
    });

    // Simulate typing delay for better UX
    Future.delayed(Duration(milliseconds: 800), () {
      String botResponse = _getBotResponse(userMessage);
      _chatMessages.add(ChatMessage(text: botResponse, isUser: false));

      setState(() {
        _isTyping = false;
      });
    });
  }

  String _getBotResponse(String message) {
    message = message.toLowerCase();

    // Enhanced keyword matching with synonyms and related terms
    if (_containsAny(message,
        ['headache', 'head pain', 'migraine', 'head ache', 'head hurting'])) {
      return _getHeadacheResponse(message);
    } else if (_containsAny(
        message, ['fever', 'temperature', 'hot', 'burning up', 'chills'])) {
      return _getFeverResponse(message);
    } else if (_containsAny(message,
        ['cough', 'cold', 'flu', 'sore throat', 'runny nose', 'congestion'])) {
      return _getColdResponse(message);
    } else if (_containsAny(message, [
      'stomach',
      'nausea',
      'vomiting',
      'diarrhea',
      'upset stomach',
      'indigestion',
      'heartburn'
    ])) {
      return _getStomachResponse(message);
    } else if (_containsAny(message,
        ['allergy', 'allergic', 'sneezing', 'itchy', 'rash', 'hives'])) {
      return _getAllergyResponse(message);
    } else if (_containsAny(
        message, ['pain', 'hurt', 'aching', 'sore', 'tender'])) {
      return _getPainResponse(message);
    } else if (_containsAny(message, [
      'sleep',
      'insomnia',
      'tired',
      'fatigue',
      'exhausted',
      'can\'t sleep'
    ])) {
      return _getSleepResponse(message);
    } else if (_containsAny(
        message, ['back pain', 'backache', 'lower back', 'upper back'])) {
      return _getBackPainResponse(message);
    } else if (_containsAny(
        message, ['joint pain', 'arthritis', 'stiffness', 'swelling'])) {
      return _getJointPainResponse(message);
    } else if (_containsAny(
        message, ['skin', 'acne', 'eczema', 'dry skin', 'itchy skin'])) {
      return _getSkinResponse(message);
    } else if (_containsAny(
        message, ['anxiety', 'stress', 'worried', 'nervous', 'panic'])) {
      return _getAnxietyResponse(message);
    } else if (_containsAny(
        message, ['blood pressure', 'hypertension', 'high bp', 'low bp'])) {
      return _getBloodPressureResponse(message);
    } else if (_containsAny(
        message, ['diabetes', 'blood sugar', 'glucose', 'diabetic'])) {
      return _getDiabetesResponse(message);
    } else if (_containsAny(
        message, ['weight', 'diet', 'nutrition', 'vitamins', 'supplements'])) {
      return _getNutritionResponse(message);
    } else if (_containsAny(
        message, ['exercise', 'workout', 'fitness', 'physical activity'])) {
      return _getExerciseResponse(message);
    } else if (_containsAny(
        message, ['medication', 'medicine', 'drug', 'pill', 'prescription'])) {
      return _getMedicationResponse(message);
    } else if (_containsAny(
        message, ['pregnancy', 'pregnant', 'baby', 'maternal'])) {
      return _getPregnancyResponse(message);
    } else if (_containsAny(
        message, ['elderly', 'aging', 'senior', 'old age'])) {
      return _getElderlyResponse(message);
    } else if (_containsAny(
        message, ['emergency', 'urgent', 'severe', 'critical', 'help'])) {
      return _getEmergencyResponse(message);
    } else {
      return _getGeneralResponse(message);
    }
  }

  bool _containsAny(String text, List<String> keywords) {
    return keywords.any((keyword) => text.contains(keyword));
  }

  // Enhanced response methods with severity assessment
  String _getHeadacheResponse(String message) {
    bool isSevere = _containsAny(message,
        ['severe', 'intense', 'migraine', 'throbbing', 'debilitating']);
    bool isSudden = _containsAny(message, ['sudden', 'acute', 'unexpected']);

    if (isSevere || isSudden) {
      return "🚨 **Severe/Sudden Headache Detected**\n\n⚠️ **Immediate Action Required:**\n• Seek medical attention immediately\n• This could indicate a serious condition\n• Do not delay treatment\n\n**While waiting for medical care:**\n• Rest in a quiet, dark room\n• Avoid bright lights and loud noises\n• Stay hydrated\n• Do not take additional medications without medical advice\n\n🔴 **Call emergency services if you experience:**\n• Vision changes\n• Confusion or difficulty speaking\n• Numbness or weakness\n• Severe nausea or vomiting";
    }

    return "**Headache Management**\n\n**Immediate Relief:**\n• Rest in a quiet, dark room\n• Stay well hydrated\n• Take acetaminophen or ibuprofen\n• Apply cold or warm compress\n• Practice relaxation techniques\n\n**Prevention:**\n• Maintain regular sleep schedule\n• Reduce screen time\n• Manage stress levels\n• Avoid known triggers\n\n⚠️ **Seek medical attention if:**\n• Headache persists > 24 hours\n• Pain becomes severe\n• Accompanied by other symptoms\n• New or unusual pattern";
  }

  String _getFeverResponse(String message) {
    bool isHighFever =
        _containsAny(message, ['high', '103', '39', '104', '40', 'very hot']);
    bool isProlonged =
        _containsAny(message, ['days', 'week', 'persistent', 'continuous']);

    if (isHighFever || isProlonged) {
      return "🚨 **High/Prolonged Fever Detected**\n\n⚠️ **Medical Attention Required:**\n• Fever above 103°F (39.4°C)\n• Fever lasting > 3 days\n• Seek immediate medical care\n\n**Emergency Symptoms:**\n• Difficulty breathing\n• Severe headache\n• Stiff neck\n• Confusion\n• Rash\n\n🔴 **Call emergency services immediately if:**\n• Fever > 105°F (40.6°C)\n• Seizures occur\n• Severe dehydration signs";
    }

    return "**Fever Management**\n\n**Home Care:**\n• Rest and stay hydrated\n• Take acetaminophen or ibuprofen\n• Monitor temperature regularly\n• Wear light clothing\n• Take lukewarm baths\n• Use cool compresses\n\n**Hydration:**\n• Water, clear fluids\n• Electrolyte solutions\n• Avoid caffeine/alcohol\n\n⚠️ **Seek medical care if:**\n• Temperature > 103°F\n• Fever lasts > 3 days\n• Accompanied by severe symptoms\n• Signs of dehydration";
  }

  String _getColdResponse(String message) {
    bool isSevere =
        _containsAny(message, ['severe', 'bad', 'terrible', 'worse']);
    bool hasFever = _containsAny(message, ['fever', 'temperature', 'hot']);

    String response =
        "**Cold & Flu Management**\n\n**Symptom Relief:**\n• Rest and stay hydrated\n• Use honey for cough relief\n• Saline nasal sprays\n• Over-the-counter decongestants\n• Humidifier for congestion\n• Throat lozenges\n\n**Prevention:**\n• Wash hands frequently\n• Avoid close contact with sick people\n• Boost immune system\n• Get adequate sleep\n\n**Medications:**\n• Acetaminophen for fever/pain\n• Decongestants for stuffy nose\n• Expectorants for productive cough\n• Antihistamines for runny nose";

    if (isSevere || hasFever) {
      response +=
          "\n\n⚠️ **Seek medical attention if:**\n• High fever (>103°F)\n• Difficulty breathing\n• Symptoms worsen after 10 days\n• Severe headache or body aches";
    }

    return response;
  }

  String _getStomachResponse(String message) {
    bool isSevere =
        _containsAny(message, ['severe', 'intense', 'terrible', 'worse']);
    bool hasBlood = _containsAny(message, ['blood', 'bleeding', 'red']);
    bool isVomiting =
        _containsAny(message, ['vomiting', 'throwing up', 'nausea']);

    if (isSevere || hasBlood) {
      return "🚨 **Severe Stomach Issues Detected**\n\n⚠️ **Immediate Medical Attention Required:**\n• Severe abdominal pain\n• Blood in stool or vomit\n• Signs of dehydration\n• Seek emergency care\n\n🔴 **Emergency Symptoms:**\n• Severe, sudden pain\n• Blood in stool/vomit\n• Inability to keep fluids down\n• Signs of dehydration\n• High fever with pain";
    }

    return "**Stomach Issue Management**\n\n**Diet (BRAT):**\n• Bananas\n• Rice (white)\n• Applesauce\n• Toast (dry)\n\n**Hydration:**\n• Clear fluids\n• Electrolyte solutions\n• Small, frequent sips\n• Avoid dairy, caffeine, alcohol\n\n**Rest:**\n• Avoid lying down after eating\n• Rest in comfortable position\n• Gentle movement\n\n**Medications:**\n• Antacids for heartburn\n• Anti-nausea medications\n• Probiotics for gut health\n\n⚠️ **Seek medical care if:**\n• Symptoms persist > 48 hours\n• Severe pain\n• Signs of dehydration\n• Blood in stool/vomit";
  }

  String _getAllergyResponse(String message) {
    bool isSevere = _containsAny(
        message, ['severe', 'bad', 'worse', 'difficulty breathing']);
    bool isAnaphylaxis = _containsAny(message,
        ['throat closing', 'can\'t breathe', 'swelling', 'anaphylaxis']);

    if (isSevere || isAnaphylaxis) {
      return "🚨 **Severe Allergic Reaction Detected**\n\n⚠️ **EMERGENCY - Call 911 Immediately:**\n• Difficulty breathing\n• Swelling of face/throat\n• Rapid heartbeat\n• Dizziness/fainting\n• Use epinephrine if prescribed\n\n🔴 **Anaphylaxis Symptoms:**\n• Throat tightness\n• Difficulty swallowing\n• Wheezing\n• Rapid pulse\n• Loss of consciousness";
    }

    return "**Allergy Management**\n\n**Medications:**\n• Antihistamines (Benadryl, Claritin)\n• Nasal sprays for congestion\n• Eye drops for itchy eyes\n• Prescription medications if needed\n\n**Avoidance:**\n• Identify and avoid triggers\n• Keep windows closed during high pollen\n• Use air purifiers\n• Wash hands frequently\n• Change clothes after outdoor activities\n\n**Prevention:**\n• Monitor pollen counts\n• Take medications before exposure\n• Carry emergency medications\n• Wear protective clothing\n\n⚠️ **Seek medical care if:**\n• Symptoms are severe\n• Difficulty breathing\n• Swelling of face/throat\n• No improvement with OTC medications";
  }

  String _getPainResponse(String message) {
    bool isSevere =
        _containsAny(message, ['severe', 'intense', 'terrible', 'unbearable']);
    bool isChest = _containsAny(message, ['chest', 'heart', 'breastbone']);

    if (isChest) {
      return "🚨 **Chest Pain Detected**\n\n⚠️ **EMERGENCY - Call 911 Immediately:**\n• Chest pain could indicate heart attack\n• Do not delay treatment\n• Call emergency services\n\n🔴 **Heart Attack Symptoms:**\n• Chest pressure/pain\n• Pain radiating to arm/jaw\n• Shortness of breath\n• Nausea/sweating\n• Dizziness";
    }

    if (isSevere) {
      return "**Severe Pain Management**\n\n⚠️ **Seek Medical Attention:**\n• Severe pain requires evaluation\n• Do not ignore persistent severe pain\n• Consult healthcare provider\n\n**Temporary Relief:**\n• Rest the affected area\n• Apply ice or heat\n• Over-the-counter pain relievers\n• Gentle stretching if appropriate\n• Avoid activities that worsen pain";
    }

    return "**Pain Management**\n\n**Home Care:**\n• Rest the affected area\n• Apply ice (acute injury) or heat (chronic pain)\n• Over-the-counter pain relievers\n• Gentle stretching if appropriate\n• Avoid activities that worsen pain\n\n**Prevention:**\n• Maintain good posture\n• Regular exercise\n• Proper ergonomics\n• Stress management\n\n⚠️ **Seek medical care if:**\n• Pain is severe or persistent\n• Accompanied by other symptoms\n• Affects daily activities\n• No improvement with home care";
  }

  String _getSleepResponse(String message) {
    bool isChronic =
        _containsAny(message, ['weeks', 'months', 'chronic', 'long time']);

    String response =
        "**Sleep Improvement Strategies**\n\n**Sleep Hygiene:**\n• Maintain regular sleep schedule\n• Create relaxing bedtime routine\n• Keep bedroom cool, dark, quiet\n• Avoid screens 1 hour before bed\n• Use comfortable bedding\n\n**Lifestyle Changes:**\n• Limit caffeine (after 2 PM)\n• Avoid alcohol before bed\n• Exercise regularly (not close to bedtime)\n• Manage stress levels\n• Avoid large meals before sleep\n\n**Environment:**\n• Optimal temperature (65-68°F)\n• White noise machine\n• Blackout curtains\n• Comfortable mattress/pillows";

    if (isChronic) {
      response +=
          "\n\n⚠️ **Chronic Insomnia:**\n• Consult sleep specialist\n• Consider cognitive behavioral therapy\n• Rule out underlying conditions\n• Avoid long-term sleep medications";
    }

    return response;
  }

  String _getBackPainResponse(String message) {
    bool isSevere = _containsAny(message, ['severe', 'intense', 'terrible']);
    bool hasNumbness =
        _containsAny(message, ['numbness', 'tingling', 'weakness']);

    if (isSevere || hasNumbness) {
      return "🚨 **Severe Back Pain with Neurological Symptoms**\n\n⚠️ **Medical Attention Required:**\n• Numbness or tingling\n• Weakness in legs\n• Loss of bladder/bowel control\n• Severe, unrelenting pain\n• Seek immediate medical care";
    }

    return "**Back Pain Management**\n\n**Immediate Relief:**\n• Rest (limited time)\n• Ice for first 48 hours\n• Heat after 48 hours\n• Over-the-counter pain relievers\n• Gentle stretching\n\n**Prevention:**\n• Maintain good posture\n• Regular exercise\n• Proper lifting techniques\n• Ergonomic workspace\n• Core strengthening\n\n**When to Seek Care:**\n• Pain persists > 2 weeks\n• Radiating pain to legs\n• Numbness or weakness\n• Loss of bladder control\n• Severe pain";
  }

  String _getJointPainResponse(String message) {
    bool isSevere = _containsAny(message, ['severe', 'intense', 'swelling']);
    bool isChronic = _containsAny(message, ['chronic', 'long time', 'months']);

    String response =
        "**Joint Pain Management**\n\n**Home Care:**\n• Rest the affected joint\n• Apply ice for acute pain\n• Heat for chronic pain\n• Over-the-counter pain relievers\n• Gentle range-of-motion exercises\n• Compression/braces if needed\n\n**Lifestyle:**\n• Maintain healthy weight\n• Low-impact exercise\n• Proper footwear\n• Joint protection techniques\n• Anti-inflammatory diet";

    if (isSevere || isChronic) {
      response +=
          "\n\n⚠️ **Severe/Chronic Joint Pain:**\n• Consult rheumatologist\n• Consider physical therapy\n• Rule out arthritis\n• Prescription medications may be needed";
    }

    return response;
  }

  String _getSkinResponse(String message) {
    bool isSevere =
        _containsAny(message, ['severe', 'infected', 'pus', 'fever']);
    bool isRash = _containsAny(message, ['rash', 'hives', 'allergic']);

    if (isSevere) {
      return "🚨 **Severe Skin Condition Detected**\n\n⚠️ **Medical Attention Required:**\n• Signs of infection (pus, fever)\n• Severe pain or swelling\n• Rapidly spreading rash\n• Seek medical care immediately";
    }

    if (isRash) {
      return "**Skin Rash Management**\n\n**General Care:**\n• Keep area clean and dry\n• Avoid scratching\n• Use gentle, fragrance-free products\n• Cool compresses for itching\n• Over-the-counter hydrocortisone\n\n**Allergic Reactions:**\n• Identify and avoid triggers\n• Antihistamines for itching\n• Seek medical care if severe\n\n⚠️ **Seek medical care if:**\n• Rash is widespread\n• Accompanied by fever\n• Signs of infection\n• No improvement in 1-2 weeks";
    }

    return "**Skin Care Management**\n\n**General Care:**\n• Gentle cleansing\n• Moisturize regularly\n• Protect from sun\n• Avoid harsh products\n• Stay hydrated\n\n**Common Conditions:**\n• Acne: Benzoyl peroxide, salicylic acid\n• Eczema: Moisturize, avoid triggers\n• Dry skin: Humidifier, gentle products\n• Sun protection: SPF 30+, reapply\n\n⚠️ **Seek medical care if:**\n• Persistent skin problems\n• Signs of infection\n• Unusual changes\n• No improvement with OTC treatments";
  }

  String _getAnxietyResponse(String message) {
    bool isSevere = _containsAny(
        message, ['severe', 'panic', 'can\'t function', 'overwhelming']);
    bool isPanic = _containsAny(
        message, ['panic attack', 'can\'t breathe', 'heart racing']);

    if (isSevere || isPanic) {
      return "🚨 **Severe Anxiety/Panic Attack Detected**\n\n⚠️ **Immediate Help Available:**\n• Call crisis hotline: 988\n• Seek mental health professional\n• Emergency room if needed\n• You're not alone\n\n**During Panic Attack:**\n• Focus on breathing\n• Ground yourself (5-4-3-2-1 technique)\n• Find safe, quiet space\n• Call trusted person\n\n🔴 **Emergency if:**\n• Thoughts of self-harm\n• Unable to function\n• Severe physical symptoms";
    }

    return "**Anxiety Management**\n\n**Immediate Techniques:**\n• Deep breathing exercises\n• Progressive muscle relaxation\n• Mindfulness meditation\n• Grounding techniques\n• Physical exercise\n\n**Lifestyle Changes:**\n• Regular sleep schedule\n• Limit caffeine/alcohol\n• Regular exercise\n• Stress management\n• Social support\n\n**Professional Help:**\n• Therapy (CBT, DBT)\n• Medication if prescribed\n• Support groups\n• Crisis hotlines\n\n⚠️ **Seek professional help if:**\n• Anxiety affects daily life\n• Persistent worry\n• Physical symptoms\n• Difficulty functioning";
  }

  String _getBloodPressureResponse(String message) {
    bool isHigh = _containsAny(message, ['high', 'hypertension', 'elevated']);
    bool isLow = _containsAny(message, ['low', 'hypotension', 'dizzy']);

    if (isHigh) {
      return "**High Blood Pressure Management**\n\n**Lifestyle Changes:**\n• Reduce salt intake\n• Regular exercise\n• Maintain healthy weight\n• Limit alcohol\n• Quit smoking\n• Stress management\n\n**Diet:**\n• DASH diet\n• Potassium-rich foods\n• Limit processed foods\n• Reduce caffeine\n\n**Monitoring:**\n• Regular BP checks\n• Home monitoring\n• Keep log of readings\n• Regular doctor visits\n\n⚠️ **Seek medical care if:**\n• BP > 180/120\n• Severe headache\n• Chest pain\n• Shortness of breath\n• Vision changes";
    }

    if (isLow) {
      return "**Low Blood Pressure Management**\n\n**Immediate Relief:**\n• Increase salt intake\n• Stay hydrated\n• Avoid alcohol\n• Stand up slowly\n• Compression stockings\n\n**Lifestyle:**\n• Regular meals\n• Adequate hydration\n• Avoid hot environments\n• Regular exercise\n\n⚠️ **Seek medical care if:**\n• Fainting episodes\n• Dizziness affecting daily life\n• Underlying medical conditions\n• Severe symptoms";
    }

    return "**Blood Pressure Information**\n\n**Normal Range:**\n• Systolic: < 120 mmHg\n• Diastolic: < 80 mmHg\n\n**Monitoring:**\n• Regular check-ups\n• Home monitoring\n• Lifestyle tracking\n• Medication compliance\n\n**Prevention:**\n• Healthy diet\n• Regular exercise\n• Stress management\n• Regular sleep\n• Limit alcohol/smoking";
  }

  String _getDiabetesResponse(String message) {
    bool isHigh = _containsAny(message, ['high', 'elevated', 'spike']);
    bool isLow = _containsAny(message, ['low', 'hypoglycemia', 'shaky']);

    if (isHigh) {
      return "**High Blood Sugar Management**\n\n**Immediate Actions:**\n• Check blood glucose\n• Take prescribed medications\n• Stay hydrated\n• Monitor for symptoms\n• Contact healthcare provider\n\n**Symptoms to Watch:**\n• Increased thirst\n• Frequent urination\n• Fatigue\n• Blurred vision\n• Slow-healing wounds\n\n⚠️ **Seek medical care if:**\n• Very high readings\n• Ketones in urine\n• Severe symptoms\n• Difficulty breathing";
    }

    if (isLow) {
      return "🚨 **Low Blood Sugar Management**\n\n**Immediate Treatment:**\n• Consume 15g fast-acting carbs\n• Recheck in 15 minutes\n• Repeat if still low\n• Follow with protein/carbs\n• Glucagon if unconscious\n\n**Fast-Acting Carbs:**\n• Glucose tablets\n• Fruit juice\n• Regular soda\n• Honey\n• Candy\n\n⚠️ **Emergency if:**\n• Unconscious\n• Unable to swallow\n• Severe confusion\n• Seizures";
    }

    return "**Diabetes Management**\n\n**Daily Care:**\n• Monitor blood glucose\n• Take medications as prescribed\n• Healthy diet\n• Regular exercise\n• Foot care\n\n**Lifestyle:**\n• Carbohydrate counting\n• Regular meals\n• Stress management\n• Adequate sleep\n• Regular check-ups\n\n**Prevention:**\n• Weight management\n• Healthy diet\n• Regular exercise\n• Blood pressure control\n• Cholesterol management";
  }

  String _getNutritionResponse(String message) {
    return "**Nutrition & Wellness Guidance**\n\n**General Nutrition:**\n• Balanced diet (fruits, vegetables, lean protein)\n• Adequate hydration (8 glasses water/day)\n• Limit processed foods\n• Portion control\n• Regular meal timing\n\n**Supplements:**\n• Consult healthcare provider\n• Vitamin D (if deficient)\n• Omega-3 fatty acids\n• Probiotics for gut health\n• Multivitamin if needed\n\n**Weight Management:**\n• Calorie deficit for weight loss\n• Regular exercise\n• Mindful eating\n• Adequate sleep\n• Stress management\n\n**Special Diets:**\n• Consult registered dietitian\n• Consider food allergies\n• Cultural preferences\n• Medical conditions\n\n⚠️ **Consult healthcare provider for:**\n• Significant weight changes\n• Dietary restrictions\n• Supplement recommendations\n• Medical conditions affecting nutrition";
  }

  String _getExerciseResponse(String message) {
    return "**Exercise & Fitness Guidance**\n\n**General Recommendations:**\n• 150 minutes moderate exercise/week\n• 75 minutes vigorous exercise/week\n• Strength training 2-3 times/week\n• Flexibility exercises\n• Balance training (older adults)\n\n**Getting Started:**\n• Start slowly and gradually increase\n• Choose activities you enjoy\n• Set realistic goals\n• Find exercise buddy\n• Track progress\n\n**Safety:**\n• Warm up and cool down\n• Stay hydrated\n• Listen to your body\n• Stop if pain occurs\n• Consult doctor if needed\n\n**Types of Exercise:**\n• Cardio: Walking, swimming, cycling\n• Strength: Weight training, resistance bands\n• Flexibility: Yoga, stretching\n• Balance: Tai chi, balance exercises\n\n⚠️ **Consult healthcare provider if:**\n• New to exercise\n• Medical conditions\n• Recent surgery/injury\n• Pregnancy\n• Elderly with health concerns";
  }

  String _getMedicationResponse(String message) {
    return "**Medication Safety & Information**\n\n**General Safety:**\n• Take as prescribed\n• Don't skip doses\n• Store properly\n• Check expiration dates\n• Keep medication list\n\n**Interactions:**\n• Inform all healthcare providers\n• Check for drug interactions\n• Avoid alcohol if advised\n• Be aware of food interactions\n• Read package inserts\n\n**Side Effects:**\n• Monitor for side effects\n• Report unusual symptoms\n• Don't stop without consulting doctor\n• Keep symptom diary\n\n**Storage:**\n• Cool, dry place\n• Away from children\n• Original containers\n• Proper disposal\n\n⚠️ **Important:**\n• Never share medications\n• Consult pharmacist for questions\n• Report adverse reactions\n• Keep emergency contacts\n• Regular medication reviews";
  }

  String _getPregnancyResponse(String message) {
    return "**Pregnancy Health Guidance**\n\n**Prenatal Care:**\n• Regular prenatal visits\n• Take prenatal vitamins\n• Folic acid supplementation\n• Avoid alcohol/smoking\n• Limit caffeine\n\n**Nutrition:**\n• Balanced diet\n• Adequate protein\n• Iron-rich foods\n• Calcium sources\n• Stay hydrated\n\n**Exercise:**\n• Low-impact activities\n• Prenatal yoga\n• Walking, swimming\n• Avoid contact sports\n• Listen to your body\n\n**Safety:**\n• Avoid raw fish/meat\n• No hot tubs/saunas\n• Limit exposure to chemicals\n• Proper seatbelt use\n• Regular rest\n\n⚠️ **Seek medical care for:**\n• Vaginal bleeding\n• Severe abdominal pain\n• Decreased fetal movement\n• High fever\n• Severe headaches\n• Vision changes\n\n**Consult healthcare provider for all pregnancy-related questions and concerns.**";
  }

  String _getElderlyResponse(String message) {
    return "**Senior Health & Wellness**\n\n**General Health:**\n• Regular check-ups\n• Medication reviews\n• Vision and hearing checks\n• Dental care\n• Vaccinations\n\n**Safety:**\n• Fall prevention\n• Home safety assessment\n• Emergency contacts\n• Medical alert systems\n• Proper lighting\n\n**Nutrition:**\n• Adequate protein\n• Calcium and vitamin D\n• Hydration\n• Smaller, frequent meals\n• Easy-to-chew foods\n\n**Exercise:**\n• Low-impact activities\n• Balance training\n• Strength training\n• Flexibility exercises\n• Walking programs\n\n**Mental Health:**\n• Social engagement\n• Cognitive activities\n• Stress management\n• Adequate sleep\n• Depression screening\n\n⚠️ **Regular monitoring for:**\n• Blood pressure\n• Blood sugar\n• Cholesterol\n• Bone density\n• Cognitive function\n\n**Consult healthcare provider for personalized recommendations.**";
  }

  String _getEmergencyResponse(String message) {
    return "🚨 **EMERGENCY MEDICAL SITUATION**\n\n⚠️ **IMMEDIATE ACTION REQUIRED:**\n\n🔴 **Call Emergency Services (911) for:**\n• Chest pain or pressure\n• Difficulty breathing\n• Severe bleeding\n• Unconsciousness\n• Severe head injury\n• Signs of stroke\n• Severe allergic reaction\n• Overdose\n• Severe burns\n• Broken bones with deformity\n\n**While Waiting for Help:**\n• Stay calm\n• Keep person comfortable\n• Don't move if injured\n• Apply pressure to bleeding\n• Clear airway if needed\n\n**Emergency Contacts:**\n• 911 (Emergency)\n• Poison Control: 1-800-222-1222\n• Crisis Hotline: 988\n\n**Do not delay seeking medical care for serious symptoms.**";
  }

  String _getGeneralResponse(String message) {
    return "**Health Information & Guidance**\n\nI'm here to help with general health questions. Here are some topics I can assist with:\n\n**Common Health Concerns:**\n• Headaches and pain\n• Fever and infections\n• Cold and flu symptoms\n• Stomach and digestive issues\n• Allergies and skin conditions\n• Sleep problems\n• Anxiety and stress\n• Chronic conditions\n\n**Preventive Care:**\n• Nutrition and diet\n• Exercise and fitness\n• Medication safety\n• Senior health\n• Pregnancy care\n\n**For specific medical advice, personalized recommendations, or complex health issues, please consult with one of our pharmacists using the 'Book Virtual Consultation' button above.\n\n**Remember:** This is for general information only and should not replace professional medical advice.";
  }

  // Color-coded message gradients based on severity
  List<Color> _getMessageGradient(String message) {
    message = message.toLowerCase();

    // Emergency/Urgent - Red gradient
    if (message.contains('🚨') ||
        message.contains('emergency') ||
        message.contains('call 911') ||
        message.contains('immediate')) {
      return [Colors.red[400]!, Colors.red[600]!];
    }

    // Warning - Orange gradient
    if (message.contains('⚠️') ||
        message.contains('seek medical') ||
        message.contains('medical attention') ||
        message.contains('severe')) {
      return [Colors.orange[400]!, Colors.orange[600]!];
    }

    // Information - Blue gradient
    if (message.contains('information') ||
        message.contains('guidance') ||
        message.contains('management') ||
        message.contains('care')) {
      return [Colors.blue[400]!, Colors.blue[600]!];
    }

    // Default - Green gradient
    return [Colors.green[400]!, Colors.green[500]!];
  }

  Widget _buildQuickActionButton(String label, String query) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.2),
            Colors.white.withOpacity(0.1)
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            _chatController.text = query;
            _sendChatMessage();
          },
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text(
              label,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  blurRadius: 4,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            child: _buildAnimatedDots(),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedDots() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: Duration(milliseconds: 600),
          builder: (context, value, child) {
            return Container(
              margin: EdgeInsets.only(right: index < 2 ? 4 : 0),
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: Colors.grey[600]!.withOpacity(0.3 + (value * 0.7)),
                shape: BoxShape.circle,
              ),
            );
          },
          onEnd: () {
            // Restart animation
            setState(() {});
          },
        );
      }),
    );
  }

  void _clearChat() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.warning, color: Colors.orange[600], size: 24),
              SizedBox(width: 8),
              Text(
                'Clear Chat',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Text(
            'Are you sure you want to clear all chat messages? This action cannot be undone.',
            style: GoogleFonts.poppins(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: GoogleFonts.poppins(
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.green[500]!, Colors.green[600]!],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: TextButton(
                onPressed: () {
                  setState(() {
                    _chatMessages.clear();
                    _chatController.clear();
                  });
                  Navigator.of(context).pop();
                },
                child: Text(
                  'Clear',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: Theme.of(context).appBarTheme.elevation,
        centerTitle: Theme.of(context).appBarTheme.centerTitle,
        leading: AppBackButton(
          backgroundColor: Colors.white.withOpacity(0.2),
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
        title: Text(
          'Meet the Pharmacists',
          style: Theme.of(context).appBarTheme.titleTextStyle,
        ),
        actions: [
          CartIconButton(
            iconColor: Colors.white,
            iconSize: 24,
          ),
        ],
      ),
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Column(
          children: [
            // Main Content
            Expanded(
              child: ListView(
                padding: EdgeInsets.all(20),
                children: [
                  // Hero Section
                  _buildHeroSection(),
                  SizedBox(height: 20),

                  // Virtual Consultation Section
                  _buildModernSectionHeader('Virtual Consultation',
                      Icons.video_call, 'Book your consultation'),
                  SizedBox(height: 12),
                  _buildModernVirtualConsultationCard(),
                  SizedBox(height: 20),

                  // Health Blogs Section
                  _buildModernSectionHeader('Health Insights', Icons.article,
                      'Latest health articles'),
                  SizedBox(height: 12),
                  _buildModernHealthBlogsSection(),
                  SizedBox(height: 100), // Space for chat button
                ],
              ),
            ),

            // Chat Button
            if (!_isChatOpen) _buildModernChatButton(),

            // Chat Interface
            if (_isChatOpen) _buildModernChatInterface(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroSection() {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.indigo[600]!,
            Colors.indigo[700]!,
            Colors.indigo[800]!
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: [0.0, 0.5, 1.0],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.indigo.withOpacity(0.3),
            blurRadius: 15,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white.withOpacity(0.3)),
                ),
                child: Icon(
                  Icons.medical_services,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Professional Healthcare',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Get expert advice from our experienced pharmacists with 24/7 support.',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.95),
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              _buildFeatureBadge(
                  Icons.check_circle, 'Expert Advice', Colors.green[400]!),
              _buildFeatureBadge(
                  Icons.access_time, '24/7 Support', Colors.orange[400]!),
              _buildFeatureBadge(
                  Icons.security, 'Secure & Private', Colors.blue[400]!),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureBadge(IconData icon, String text, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          SizedBox(width: 4),
          Text(
            text,
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernSectionHeader(
      String title, IconData icon, String subtitle) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.grey[50]!, Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.green[400]!, Colors.green[500]!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.green.withOpacity(0.2),
                  blurRadius: 4,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernVirtualConsultationCard() {
    return Container(
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.white, Colors.grey[50]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[200]!, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue[500]!, Colors.blue[600]!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.15),
                      blurRadius: 3,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
                child: Icon(Icons.video_call, color: Colors.white, size: 14),
              ),
              SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Virtual Consultation',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    SizedBox(height: 1),
                    Text(
                      'Choose platform',
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        color: Colors.grey[600],
                        height: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          _buildModernPlatformSelection(),
          SizedBox(height: 8),
          _buildGradientButton(
            'Book Now',
            Icons.calendar_today,
            _showBookingForm,
          ),
        ],
      ),
    );
  }

  Widget _buildModernPlatformSelection() {
    return Column(
      children: [
        _buildModernPlatformOption(
          'WhatsApp',
          FontAwesomeIcons.whatsapp,
          Colors.green,
          'Quick messaging',
          _selectedConsultationType == 'WhatsApp',
          () => setState(() => _selectedConsultationType = 'WhatsApp'),
        ),
        SizedBox(height: 8),
        _buildModernPlatformOption(
          'Zoom',
          Icons.video_call,
          Colors.blue,
          'Video consultation',
          _selectedConsultationType == 'Zoom',
          () => setState(() => _selectedConsultationType = 'Zoom'),
        ),
        SizedBox(height: 8),
        _buildModernPlatformOption(
          'Phone Call',
          Icons.call,
          const Color.fromARGB(255, 180, 97, 167),
          'Voice consultation',
          _selectedConsultationType == 'Phone Call',
          () => setState(() => _selectedConsultationType = 'Phone Call'),
        ),
        SizedBox(height: 8),
      ],
    );
  }

  Widget _buildModernPlatformOption(String title, IconData icon, Color color,
      String description, bool isSelected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: Duration(milliseconds: 300),
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isSelected ? null : Colors.grey[50],
          border: Border.all(
            color: isSelected ? color : Colors.grey[200]!,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.2),
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: isSelected
                    ? LinearGradient(
                        colors: [color, color.withOpacity(0.8)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: isSelected ? null : Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: color.withOpacity(0.3),
                          blurRadius: 4,
                          offset: Offset(0, 1),
                        ),
                      ]
                    : null,
              ),
              child: Icon(
                icon,
                color: isSelected ? Colors.white : Colors.grey[600],
                size: 14,
              ),
            ),
            SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? color : Colors.grey[800],
                    ),
                  ),
                  Text(
                    description,
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Container(
                padding: EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check,
                  color: Colors.white,
                  size: 12,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernHealthBlogsSection() {
    final blogs = [
      {
        'title': 'Managing Diabetes: A Complete Guide',
        'excerpt':
            'Learn about diabetes management, diet tips, and medication guidelines...',
        'image': 'assets/images/health.png',
        'date': '2 days ago',
        'category': 'Chronic Disease',
        'color': Colors.orange,
        'icon': Icons.monitor_heart,
      },
      {
        'title': 'Understanding Blood Pressure',
        'excerpt':
            'Everything you need to know about maintaining healthy blood pressure...',
        'image': 'assets/images/medicine.png',
        'date': '1 week ago',
        'category': 'Heart Health',
        'color': Colors.red,
        'icon': Icons.favorite,
      },
      {
        'title': 'Seasonal Allergies: Prevention & Treatment',
        'excerpt':
            'How to manage seasonal allergies and find relief from symptoms...',
        'image': 'assets/images/personal.png',
        'date': '2 weeks ago',
        'category': 'Allergies',
        'color': Colors.blue,
        'icon': Icons.air,
      },
      {
        'title': 'Mental Health & Wellness',
        'excerpt':
            'Tips for maintaining good mental health and emotional well-being...',
        'image': 'assets/images/health.png',
        'date': '3 days ago',
        'category': 'Mental Health',
        'color': Colors.purple,
        'icon': Icons.psychology,
      },
    ];

    return Column(
      children: blogs.map((blog) => _buildModernBlogCard(blog)).toList(),
    );
  }

  Widget _buildModernBlogCard(Map<String, dynamic> blog) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(12),
              bottomLeft: Radius.circular(12),
            ),
            child: Image.asset(
              blog['image'] as String,
              width: 80,
              height: 80,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: 80,
                  height: 80,
                  color: Colors.grey[200],
                  child: Icon(
                    blog['icon'] as IconData,
                    color: Colors.grey[400],
                    size: 24,
                  ),
                );
              },
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      blog['category'] as String,
                      style: GoogleFonts.poppins(
                        fontSize: 9,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    blog['title'] as String,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 3),
                  Text(
                    blog['excerpt'] as String,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: Colors.grey[600],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 6),
                  Text(
                    blog['date'] as String,
                    style: GoogleFonts.poppins(
                      fontSize: 9,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernChatButton() {
    return Container(
      padding: EdgeInsets.all(12),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.green[500]!,
              Colors.green[600]!,
              Colors.green[700]!
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            stops: [0.0, 0.5, 1.0],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.green.withOpacity(0.3),
              blurRadius: 15,
              offset: Offset(0, 6),
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 10,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: FloatingActionButton.extended(
          onPressed: () => setState(() => _isChatOpen = true),
          backgroundColor: Colors.transparent,
          elevation: 0,
          icon: Container(
            padding: EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.smart_toy, color: Colors.white, size: 16),
                SizedBox(width: 3),
                Icon(Icons.auto_awesome, color: Colors.yellow[300], size: 12),
              ],
            ),
          ),
          label: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'AI Health Assistant',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              Text(
                'Ask me anything',
                style: GoogleFonts.poppins(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 9,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernChatInterface() {
    return Container(
      height: 450,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.white, Colors.green[50]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.3),
            blurRadius: 25,
            offset: Offset(0, -8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Chat Header
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.green[600]!,
                  Colors.green[700]!,
                  Colors.green[800]!
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
              boxShadow: [
                BoxShadow(
                  color: Colors.green.withOpacity(0.4),
                  blurRadius: 15,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withOpacity(0.25),
                        Colors.white.withOpacity(0.15)
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withOpacity(0.2),
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(Icons.smart_toy, color: Colors.white, size: 20),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.auto_awesome,
                              color: Colors.yellow[300], size: 14),
                          SizedBox(width: 4),
                          Text(
                            'AI Health Assistant',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'Powered by Enerst Chemists • 24/7 Available',
                        style: GoogleFonts.poppins(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withOpacity(0.25),
                        Colors.white.withOpacity(0.15)
                      ],
                    ),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withOpacity(0.1),
                        blurRadius: 4,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                  child: IconButton(
                    onPressed: _clearChat,
                    icon: Icon(Icons.clear_all, color: Colors.white, size: 18),
                    tooltip: 'Clear Chat',
                    padding: EdgeInsets.all(8),
                    constraints: BoxConstraints(minWidth: 36, minHeight: 36),
                  ),
                ),
                SizedBox(width: 6),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withOpacity(0.25),
                        Colors.white.withOpacity(0.15)
                      ],
                    ),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withOpacity(0.1),
                        blurRadius: 4,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                  child: IconButton(
                    onPressed: () => setState(() => _isChatOpen = false),
                    icon: Icon(Icons.close, color: Colors.white, size: 18),
                    tooltip: 'Close Chat',
                    padding: EdgeInsets.all(8),
                    constraints: BoxConstraints(minWidth: 36, minHeight: 36),
                  ),
                ),
              ],
            ),
          ),

          // Chat Messages
          Expanded(
            child: Column(
              children: [
                // Quick Action Buttons (show only when chat is empty)
                if (_chatMessages.isEmpty) ...[
                  Container(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Quick Health Topics:',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _buildQuickActionButton('Headache', 'headache'),
                            _buildQuickActionButton('Fever', 'fever'),
                            _buildQuickActionButton('Cough', 'cough'),
                            _buildQuickActionButton('Stomach', 'stomach pain'),
                            _buildQuickActionButton('Allergy', 'allergy'),
                            _buildQuickActionButton('Sleep', 'sleep problems'),
                            _buildQuickActionButton('Pain', 'pain'),
                            _buildQuickActionButton('Anxiety', 'anxiety'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],

                // Chat Messages
                Expanded(
                  child: ListView.builder(
                    padding: EdgeInsets.all(16),
                    itemCount: _chatMessages.length + (_isTyping ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _chatMessages.length && _isTyping) {
                        return _buildTypingIndicator();
                      }
                      return _buildModernChatMessage(_chatMessages[index]);
                    },
                  ),
                ),
              ],
            ),
          ),

          // Chat Input
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.white, Colors.green[50]!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.white, Colors.grey[100]!],
                      ),
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(color: Colors.grey[200]!, width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _chatController,
                      decoration: InputDecoration(
                        hintText: 'Ask about your health...',
                        hintStyle: GoogleFonts.poppins(
                          color: Colors.grey[500],
                          fontSize: 14,
                        ),
                        border: InputBorder.none,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        prefixIcon: Icon(
                          Icons.medical_services,
                          color: Colors.green[600],
                          size: 20,
                        ),
                      ),
                      onSubmitted: (_) => _sendChatMessage(),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.green[500]!, Colors.green[600]!],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.withOpacity(0.4),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: IconButton(
                    onPressed: _sendChatMessage,
                    icon: Icon(Icons.send, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernChatMessage(ChatMessage message) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment:
            message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!message.isUser) ...[
            Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _getMessageGradient(message.text),
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.withOpacity(0.3),
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(Icons.smart_toy, size: 18, color: Colors.white),
            ),
            SizedBox(width: 10),
          ],
          Flexible(
            child: Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: message.isUser
                    ? LinearGradient(
                        colors: [Colors.green[500]!, Colors.green[600]!],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: message.isUser ? null : Colors.grey[50],
                borderRadius: BorderRadius.circular(18),
                border: message.isUser
                    ? null
                    : Border.all(color: Colors.grey[200]!, width: 1),
                boxShadow: message.isUser
                    ? [
                        BoxShadow(
                          color: Colors.green.withOpacity(0.2),
                          blurRadius: 8,
                          offset: Offset(0, 3),
                        ),
                      ]
                    : [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          blurRadius: 6,
                          offset: Offset(0, 2),
                        ),
                      ],
              ),
              child: Text(
                message.text,
                style: GoogleFonts.poppins(
                  color: message.isUser ? Colors.white : Colors.grey[800],
                  fontSize: 14,
                  fontWeight:
                      message.isUser ? FontWeight.w500 : FontWeight.w400,
                ),
              ),
            ),
          ),
          if (message.isUser) ...[
            SizedBox(width: 10),
            Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.green[600]!, Colors.green[700]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.withOpacity(0.3),
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(Icons.person, size: 18, color: Colors.white),
            ),
          ],
        ],
      ),
    );
  }
}

class ChatMessage {
  final String text;
  final bool isUser;

  ChatMessage({required this.text, required this.isUser});
}
