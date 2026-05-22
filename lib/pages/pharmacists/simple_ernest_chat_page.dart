// Rule-based Ernest chat (no AI API).
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'pharmacists_models.dart';

// Simple Ernest Chat Page (No AI Integration)
class SimpleErnestChatPage extends StatefulWidget {
  const SimpleErnestChatPage({super.key});

  @override
  State<SimpleErnestChatPage> createState() => _SimpleErnestChatPageState();
}

class _SimpleErnestChatPageState extends State<SimpleErnestChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final List<SimpleChatMessage> _messages = [];
  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    // Add comprehensive welcome message for first-time users
    _messages.add(SimpleChatMessage(
      text:
          "Hi! I'm Ernest, your virtual health assistant. 👋\n\nI'm here to provide general health information and guidance. I can help with:\n• Common health questions\n• Wellness tips\n• General medical advice\n• Health education ",
      isUser: false,
      timestamp: DateTime.now(),
      showYesNoButtons: false,
    ));

    // Add follow-up message explaining what Ernest can't do
    Future.delayed(Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          _messages.add(SimpleChatMessage(
            text:
                "💡 Tip: If I can't help with your specific concern, I'll guide you to book an appointment with our qualified pharmacists for personalized care.",
            isUser: false,
            timestamp: DateTime.now(),
            showYesNoButtons: false,
          ));
        });
      }
    });
  }

  void _sendMessage() {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    setState(() {
      _messages.add(SimpleChatMessage(
        text: message,
        isUser: true,
        timestamp: DateTime.now(),
        showYesNoButtons: false,
      ));
      _isTyping = true;
    });
    _messageController.clear();

    // Simulate Ernest typing and responding
    Future.delayed(Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _isTyping = false;
          String response = _getErnestResponse(message);
          _messages.add(SimpleChatMessage(
            text: response,
            isUser: false,
            timestamp: DateTime.now(),
            showYesNoButtons: false,
          ));

          Future.delayed(Duration(seconds: 1), () {
            if (mounted) {
              setState(() {
                _messages.add(SimpleChatMessage(
                  text:
                      "💊 How are you feeling now? Did that help with your concern?",
                  isUser: false,
                  timestamp: DateTime.now(),
                  showYesNoButtons: true,
                ));
              });
            }
          });
        });
      }
    });
  }

  // Removed _shouldSuggestAppointment method

  void _navigateToAppointment() {
    // Close the chat page and return a signal to open the booking form
    Navigator.pop(context, 'open_form');
  }

  void _handleYesResponse() {
    setState(() {
      _messages.add(SimpleChatMessage(
        text:
            "Great! I'm glad I could help! 😊\n\nIf you need anything else in the future, feel free to chat with me again or book an appointment with our pharmacists.",
        isUser: false,
        timestamp: DateTime.now(),
        showYesNoButtons: false,
      ));
    });

    // Close chat after 3 seconds
    Future.delayed(Duration(seconds: 3), () {
      if (mounted) {
        Navigator.pop(context);
      }
    });
  }

  void _handleNoResponse() {
    setState(() {
      _messages.add(SimpleChatMessage(
        text:
            "I understand your problem hasn't been solved yet. 😔\n\nLet me help you further. What else would you like to know, or would you prefer to book an appointment with our pharmacists for personalized care?",
        isUser: false,
        timestamp: DateTime.now(),
        showYesNoButtons: false,
      ));
    });
  }

  // Show cashback notification
  void _showCashbackNotification(double amount) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Container(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.monetization_on,
                  color: Colors.green[700],
                  size: 20,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '🎉 Cashback Received!',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'You\'ve earned ₵${amount.toStringAsFixed(2)} cashback!',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                },
                icon: Icon(Icons.close, color: Colors.white, size: 18),
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ),
        ),
        backgroundColor: Colors.green[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: Duration(seconds: 5),
        margin: EdgeInsets.all(16),
        elevation: 8,
      ),
    );
  }

  String _getErnestResponse(String userMessage) {
    final message = userMessage.toLowerCase();

    if (message.contains('hello') || message.contains('hi')) {
      return "Hello! How are you feeling today?";
    } else if (message.contains('headache') || message.contains('head pain')) {
      return "I'm sorry to hear about your headache. Common causes include stress, dehydration, or eye strain. Try resting in a quiet, dark room and staying hydrated. If it persists, consider consulting a healthcare provider.";
    } else if (message.contains('fever') || message.contains('temperature')) {
      return "Fever can be a sign of infection. Monitor your temperature and stay hydrated. If it's above 103°F (39.4°C) or persists for more than 3 days, seek medical attention.";
    } else if (message.contains('cough') || message.contains('cold')) {
      return "For coughs and colds, rest, stay hydrated, and consider over-the-counter remedies. If symptoms are severe or persist, consult a healthcare provider.";
    } else if (message.contains('sleep') || message.contains('insomnia')) {
      return "Good sleep is crucial for health. Try maintaining a regular sleep schedule, avoiding screens before bed, and creating a relaxing bedtime routine.";
    } else if (message.contains('diet') || message.contains('nutrition')) {
      return "A balanced diet with fruits, vegetables, lean proteins, and whole grains supports overall health. Consider consulting a nutritionist for personalized advice.";
    } else if (message.contains('exercise') || message.contains('workout')) {
      return "Regular exercise is great for health! Aim for at least 150 minutes of moderate activity weekly. Start slowly and gradually increase intensity.";
    } else if (message.contains('stress') || message.contains('anxiety')) {
      return "Stress and anxiety are common. Try deep breathing, meditation, or talking to someone you trust. If it's overwhelming, consider professional help.";
    } else if (message.contains('thank')) {
      return "You're welcome! I'm here to help. Is there anything else you'd like to know?";
    } else if (message.contains('appointment') ||
        message.contains('book') ||
        message.contains('consult') ||
        message.contains('help') ||
        message.contains('need help') ||
        message.contains('how to book') ||
        message.contains('booking') ||
        message.contains('schedule')) {
      return "I'd be happy to help you book an appointment! 📅\n\n**Quick Steps:**\n1️⃣ Tap 'Book Appointment' below\n2️⃣ Choose consultation type (Video Call/Audio Call/Chat)\n3️⃣ Select preferred platform (Zoom/Google Meet/WhatsApp/Phone)\n4️⃣ Pick date & time\n5️⃣ Fill details & submit\n\nOur pharmacists are available 24/7!";
    } else if (message.contains('pain') ||
        message.contains('severe') ||
        message.contains('emergency')) {
      return "I'm concerned about your symptoms. For pain, severe symptoms, or emergency situations, please:\n\n🚨 Seek immediate medical attention if symptoms are severe\n🏥 Contact emergency services if needed\n💊 Book an appointment with our pharmacists for non-emergency concerns\n\nYour health and safety come first!";
    } else if (message.contains('medication') ||
        message.contains('prescription') ||
        message.contains('drug')) {
      return "I can provide general information about medications, but for specific prescription advice, drug interactions, or dosage questions, please consult with our pharmacists. They have the expertise to give you personalized medication guidance.";
    } else if (message.contains('diagnosis') ||
        message.contains('condition') ||
        message.contains('disease')) {
      return "I cannot diagnose medical conditions or diseases. For proper diagnosis and treatment, please book an appointment with our pharmacists or consult a healthcare provider. They can perform proper assessments and provide accurate medical guidance.";
    } else if (message.contains('help') || message.contains('support')) {
      return "I'm here to help! 🤝\n\n**I can assist with:**\n• Health information & tips\n• Symptom understanding\n• **Booking appointments**\n• Health education\n\n💡 For personalized advice, book with our pharmacists for:\n• Individual assessment\n• Tailored guidance\n• Specific medical questions\n\nNeed help with any of these?";
    } else {
      return "That's an interesting question! While I can provide general health information, your specific concern might require personalized medical advice.\n\n💡 Book with our pharmacists for:\n• Individual assessment\n• Personalized guidance\n• Specific medical questions\n• Treatment recommendations\n\n📅 Ready to book? Tap 'Book Appointment' below!\n\nNeed help with anything else?";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Text(
          'Chat with Ernest',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 18,
            color: Colors.white,
          ),
        ),
        backgroundColor: Color(0xFF2E7D32),
        elevation: 2,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            onPressed: () {
              setState(() {
                _messages.clear();
                _messages.add(SimpleChatMessage(
                  text:
                      "Hi! I'm Ernest, your virtual health assistant. 👋\n\nI'm here to provide general health information and guidance. I can help with:\n• Common health questions\n• Wellness tips\n• General medical advice\n• Health education ",
                  isUser: false,
                  timestamp: DateTime.now(),
                  showYesNoButtons: false,
                ));
              });
            },
            icon: Icon(Icons.refresh_rounded, color: Colors.white),
            tooltip: 'New chat',
          ),
        ],
      ),
      backgroundColor: Color(0xFFF4F7F6),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            margin: EdgeInsets.fromLTRB(16, 12, 16, 8),
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Color(0xFFC8E6C9)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded,
                    color: Color(0xFF2E7D32), size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'For urgent symptoms, contact emergency care immediately.',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: Color(0xFF1B5E20),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
              itemCount: _messages.length + (_isTyping ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length && _isTyping) {
                  return _buildTypingIndicator();
                }
                return _buildMessage(_messages[index]);
              },
            ),
          ),
          Container(
            margin: EdgeInsets.fromLTRB(10, 4, 10, 10),
            padding: EdgeInsets.fromLTRB(10, 10, 10, 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 16,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _navigateToAppointment,
                        icon: Icon(Icons.calendar_month_rounded,
                            size: 16, color: Color(0xFF2E7D32)),
                        label: Text(
                          'Book',
                          style: GoogleFonts.poppins(
                            color: Color(0xFF2E7D32),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Color(0xFFC8E6C9)),
                          backgroundColor: Color(0xFFE8F5E9),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: EdgeInsets.symmetric(vertical: 9),
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          setState(() {
                            _messages.add(SimpleChatMessage(
                              text:
                                  "💡 Quick Health Tips:\n\n• Stay hydrated (8 glasses of water daily)\n• Get 7-9 hours of sleep\n• Exercise for 30 minutes daily\n• Eat a balanced diet\n• Practice stress management\n\nNeed specific advice? Book an appointment with our pharmacists!",
                              isUser: false,
                              timestamp: DateTime.now(),
                            ));
                          });
                        },
                        icon: Icon(Icons.lightbulb_outline_rounded,
                            size: 16, color: Color(0xFFB45309)),
                        label: Text(
                          'Tips',
                          style: GoogleFonts.poppins(
                            color: Color(0xFFB45309),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Color(0xFFFED7AA)),
                          backgroundColor: Color(0xFFFFF7ED),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: EdgeInsets.symmetric(vertical: 9),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Color(0xFFE2E8F0)),
                        ),
                        child: TextField(
                          controller: _messageController,
                          decoration: InputDecoration(
                            hintText: 'Type your message...',
                            hintStyle: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Color(0xFF94A3B8),
                            ),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 11,
                            ),
                          ),
                          minLines: 1,
                          maxLines: 4,
                          textInputAction: TextInputAction.newline,
                          style: GoogleFonts.poppins(fontSize: 13),
                          onSubmitted: (_) => _sendMessage(),
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    Material(
                      color: Color(0xFF2E7D32),
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: _sendMessage,
                        child: Padding(
                          padding: EdgeInsets.all(11),
                          child: Icon(Icons.send_rounded,
                              color: Colors.white, size: 19),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessage(SimpleChatMessage message) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: message.isUser
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            children: [
              if (!message.isUser) ...[
                Container(
                  padding: EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child:
                      Icon(Icons.smart_toy, size: 18, color: Colors.green[700]),
                ),
                SizedBox(width: 8),
              ],
              Flexible(
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  decoration: BoxDecoration(
                    color: message.isUser ? Color(0xFF2E7D32) : Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                      bottomLeft: Radius.circular(message.isUser ? 16 : 4),
                      bottomRight: Radius.circular(message.isUser ? 4 : 16),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 8,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Text(
                    message.text,
                    style: GoogleFonts.poppins(
                      color: message.isUser ? Colors.white : Colors.black87,
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                ),
              ),
              if (message.isUser) ...[
                SizedBox(width: 8),
                Container(
                  padding: EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(Icons.person, size: 18, color: Colors.grey[600]),
                ),
              ],
            ],
          ),
          // Show Yes/No buttons if needed
          if (message.showYesNoButtons && !message.isUser) ...[
            SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Container(
                  margin: EdgeInsets.only(left: 40),
                  child: Row(
                    children: [
                      ElevatedButton(
                        onPressed: _handleYesResponse,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[600],
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding:
                              EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        ),
                        child: Text(
                          'Much Better! 😊',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                      SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: _handleNoResponse,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange[500],
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding:
                              EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        ),
                        child: Text(
                          'Still Need Help',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.smart_toy, size: 18, color: Colors.green[700]),
          ),
          SizedBox(width: 8),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 8,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTypingDot(0),
                SizedBox(width: 4),
                _buildTypingDot(1),
                SizedBox(width: 4),
                _buildTypingDot(2),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingDot(int index) {
    return AnimatedContainer(
      duration: Duration(milliseconds: 600),
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: Colors.green[400],
        borderRadius: BorderRadius.circular(4),
      ),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: Duration(milliseconds: 600),
        builder: (context, value, child) {
          return Transform.scale(
            scale: 0.5 + (0.5 * value),
            child: Opacity(
              opacity: value,
              child: child,
            ),
          );
        },
        child: Container(),
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }
}
