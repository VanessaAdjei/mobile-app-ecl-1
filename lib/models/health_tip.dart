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

    // Create a summary from the title
    String summary = content;
    if (summary.length > 150) {
      summary = summary.substring(0, 150) + '...';
    }

    return HealthTip(
      title: content,
      url: url,
      content: content,
      category: category,
      imageUrl: imageUrl,
      summary: summary,
    );
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
          'Maintain a healthy lifestyle with regular exercise and balanced nutrition.',
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
