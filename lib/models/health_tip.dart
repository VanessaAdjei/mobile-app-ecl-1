// models/health_tip.dart
class HealthTip {
  final String title;
  final String url;
  final String content;
  final String category;
  final String? imageUrl;
  final String? summary;

  HealthTip({
    required this.title,
    required this.url,
    required this.content,
    required this.category,
    this.imageUrl,
    this.summary,
  });

  factory HealthTip.fromJson(Map<String, dynamic> json) {
    // Extract content from the title and create a summary
    String content = json['Title'] ?? 'Health Tip';
    String category = json['Categories'] ?? 'Health';
    String url = json['AccessibleVersion'] ?? '';
    String? imageUrl = json['ImageUrl'];

    // Create a shorter title and a more detailed summary
    String title = content;
    String summary = content;

    // If the content is long, create a shorter title and keep the full content as summary
    if (content.length > 50) {
      // Try to find a natural break point for the title
      int breakPoint = content.indexOf('.');
      if (breakPoint > 20 && breakPoint < 60) {
        title = content.substring(0, breakPoint).trim();
        summary = content;
      } else {
        // If no good break point, truncate title and keep full content as summary
        title = content.length > 40
            ? content.substring(0, 40).trim() + '...'
            : content;
        summary = content;
      }
    } else {
      // For short content, use it as title and create a more descriptive summary
      title = content;
      summary = _createDescriptiveSummary(content, category);
    }

    return HealthTip(
      title: title,
      url: url,
      content: content,
      category: category,
      imageUrl: imageUrl,
      summary: summary,
    );
  }

  // Helper method to create descriptive summaries
  static String _createDescriptiveSummary(String content, String category) {
    // Create more descriptive summaries based on the content and category
    String lowerContent = content.toLowerCase();
    String lowerCategory = category.toLowerCase();

    if (lowerContent.contains('exercise') ||
        lowerContent.contains('physical activity')) {
      return 'Regular physical activity strengthens your heart, improves mood, and helps maintain a healthy weight.';
    } else if (lowerContent.contains('sleep') ||
        lowerContent.contains('rest')) {
      return 'Quality sleep supports immune function, memory consolidation, and overall physical and mental recovery.';
    } else if (lowerContent.contains('diet') ||
        lowerContent.contains('nutrition') ||
        lowerContent.contains('eat')) {
      return 'A balanced diet rich in fruits, vegetables, and whole grains provides essential nutrients for optimal health.';
    } else if (lowerContent.contains('water') ||
        lowerContent.contains('hydrate')) {
      return 'Proper hydration helps maintain body temperature, lubricate joints, and transport nutrients throughout your body.';
    } else if (lowerContent.contains('wash') ||
        lowerContent.contains('hygiene')) {
      return 'Proper hand hygiene is one of the most effective ways to prevent the spread of germs and infections.';
    } else if (lowerContent.contains('stress') ||
        lowerContent.contains('mental')) {
      return 'Managing stress through relaxation techniques and self-care practices supports both mental and physical well-being.';
    } else if (lowerContent.contains('vaccine') ||
        lowerContent.contains('immunization')) {
      return 'Vaccinations help protect you and your community from preventable diseases and serious health complications.';
    } else if (lowerContent.contains('screen') ||
        lowerContent.contains('digital')) {
      return 'Regular breaks from digital devices help reduce eye strain, improve posture, and maintain mental well-being.';
    } else {
      // Generic descriptive summary
      return 'This health tip provides valuable guidance for maintaining and improving your overall well-being and quality of life.';
    }
  }

  // Create a fallback health tip
  factory HealthTip.fallback() {
    return HealthTip(
      title: 'Stay Healthy',
      url: '',
      content:
          'Maintain a healthy lifestyle with regular exercise and balanced nutrition.',
      category: 'Wellness',
      summary:
          'A healthy lifestyle includes regular physical activity, balanced nutrition, adequate sleep, and stress management for optimal well-being.',
    );
  }
}

class MyHealthfinderResponse {
  final List<HealthTip> tips;
  final int totalCount;

  MyHealthfinderResponse({
    required this.tips,
    required this.totalCount,
  });

  factory MyHealthfinderResponse.fromJson(Map<String, dynamic> json) {
    final result = json['Result'];
    if (result == null) {
      return MyHealthfinderResponse(tips: [], totalCount: 0);
    }

    final resources = result['Resources'];
    if (resources == null) {
      return MyHealthfinderResponse(tips: [], totalCount: 0);
    }

    final resourceList = resources['Resource'] as List? ?? [];
    final tips = resourceList
        .map<HealthTip>((item) => HealthTip.fromJson(item))
        .toList();

    return MyHealthfinderResponse(
      tips: tips,
      totalCount: result['Total'] ?? tips.length,
    );
  }
}
