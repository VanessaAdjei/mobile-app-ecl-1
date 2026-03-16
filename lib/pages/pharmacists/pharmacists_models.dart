// Simple models used by the Pharmacists / Ernest AI feature.

class ChatMessage {
  final String text;
  final bool isUser;

  ChatMessage({required this.text, required this.isUser});
}

class SimpleChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final bool showYesNoButtons;

  SimpleChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.showYesNoButtons = false,
  });
}
