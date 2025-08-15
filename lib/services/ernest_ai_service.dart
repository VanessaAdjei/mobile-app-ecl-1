// services/ernest_ai_service.dart
import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

class ErnestAIService {

  static const String _apiKey =
      'AIzaSyCFmnQt32wCfsjoLVFEfFq7JrIDd2CqHZk'; // Your Gemini API key
  static const String _modelName = 'gemini-1.5-pro';

  // Health safety prompt template
  static const String _safetyPrompt = '''
You are Ernest, a helpful AI health assistant for Ernest Chemists Limited. 

IMPORTANT SAFETY RULES:
- Provide GENERAL health information and wellness advice only
- NEVER give specific medical diagnoses
- NEVER recommend specific medications or dosages
- NEVER suggest treatments for serious conditions
- ALWAYS encourage consulting healthcare professionals for medical advice
- Include appropriate disclaimers when discussing health topics

Your role is to:
- Offer general wellness tips
- Explain common health concepts
- Provide lifestyle recommendations
- Answer general health questions
- Guide users to seek professional help when needed

Be friendly, professional, and always prioritize user safety.
''';

  // Check if AI service is ready (always true with centralized setup)
  static Future<bool> isConfigured() async {
    return _apiKey.isNotEmpty;
  }

  // Configure the AI service (not needed with centralized setup)
  static Future<bool> configure(String apiKey) async {
    // This method is kept for backward compatibility but not used
    return true;
  }

  // Test API connection and get available models
  static Future<Map<String, dynamic>> testConnection() async {
    try {
      debugPrint('🔍 Testing Ernest AI connection...');
      debugPrint('🔑 API Key: ${_apiKey.substring(0, 10)}...');
      debugPrint('🤖 Model: $_modelName');
      debugPrint('🔍 API Key length: ${_apiKey.length} characters');

      // Test 1: Basic model creation
      debugPrint('🔍 Test 1: Creating GenerativeModel...');
      final model = GenerativeModel(
        model: _modelName,
        apiKey: _apiKey,
      );
      debugPrint('✅ Test 1 passed: GenerativeModel created');

      // Test 2: Simple content generation
      debugPrint('🔍 Test 2: Testing content generation...');
      final testPrompt = 'Hi';
      final content = [Content.text(testPrompt)];
      debugPrint('🔍 Test 2: Content created, calling generateContent...');

      final response = await model.generateContent(content);
      debugPrint('🔍 Test 2: generateContent completed');

      if (response.text != null) {
        debugPrint('✅ Ernest AI connection successful!');
        debugPrint(
            '📝 Response: ${response.text!.substring(0, response.text!.length > 50 ? 50 : response.text!.length)}...');
        return {
          'success': true,
          'message': 'Connection successful',
          'response': response.text,
        };
      } else {
        debugPrint('❌ Ernest AI connection failed - no response text');
        return {
          'success': false,
          'message': 'No response text received',
        };
      }
    } catch (e) {
      debugPrint('❌ Ernest AI connection error: $e');
      debugPrint('🔍 Error type: ${e.runtimeType}');
      debugPrint('🔍 Error details: ${e.toString()}');

      // Check for specific error types
      if (e.toString().contains('quota')) {
        debugPrint('🚨 QUOTA ERROR DETECTED');
        debugPrint('💡 This usually means:');
        debugPrint('   - Free tier limit reached (15 req/min)');
        debugPrint('   - Billing not set up');
        debugPrint('   - Account restrictions');
      }

      return {
        'success': false,
        'message': 'Connection failed: ${e.toString()}',
        'error': e.toString(),
      };
    }
  }

  // Test with different model names
  static Future<Map<String, dynamic>> testAlternativeModels() async {
    final models = ['gemini-1.5-flash', 'gemini-1.5-pro', 'gemini-pro'];

    for (final modelName in models) {
      try {
        debugPrint('🔍 Testing model: $modelName');

        final model = GenerativeModel(
          model: modelName,
          apiKey: _apiKey,
        );

        final content = [Content.text('Hi')];
        final response = await model.generateContent(content);

        if (response.text != null) {
          debugPrint('✅ Model $modelName works!');
          return {
            'success': true,
            'working_model': modelName,
            'message': 'Found working model: $modelName',
          };
        }
      } catch (e) {
        debugPrint('❌ Model $modelName failed: $e');
      }
    }

    return {
      'success': false,
      'message': 'All models failed',
    };
  }

  // Ask Ernest a health question
  static Future<ErnestResponse> askQuestion(String question) async {
    try {
      // Check if API key is properly configured
      if (!await isConfigured()) {
        return ErnestResponse(
          success: false,
          message: 'AI service not configured. Please contact support.',
          requiresConfiguration: true,
        );
      }

      final model = GenerativeModel(
        model: _modelName,
        apiKey: _apiKey,
      );

      // Combine safety prompt with user question
      final fullPrompt = '''
$_safetyPrompt

User Question: $question

Please provide a helpful, safe response following all safety guidelines.
''';

      final content = [Content.text(fullPrompt)];
      final response = await model.generateContent(content);

      if (response.text != null) {
        return ErnestResponse(
          success: true,
          message: response.text!,
          requiresConfiguration: false,
        );
      } else {
        return ErnestResponse(
          success: false,
          message:
              'Sorry, I couldn\'t process your question. Please try again.',
          requiresConfiguration: false,
        );
      }
    } catch (e) {
      debugPrint('Error asking Ernest: $e');

      // Handle specific model errors
      if (e.toString().contains('model') ||
          e.toString().contains('not found')) {
        debugPrint('🔍 Model error detected. Trying to identify the issue...');
        debugPrint('🔑 API Key format: ${_apiKey.length} characters');
        debugPrint('🤖 Model name: $_modelName');

        return ErnestResponse(
          success: false,
          message:
              'Model not found. This might be a model name issue or API key permission problem.',
          requiresConfiguration: true,
        );
      }

      return ErnestResponse(
        success: false,
        message:
            'Sorry, I encountered an error. Please check your internet connection and try again.',
        requiresConfiguration: false,
      );
    }
  }

  // Get health tips from Ernest
  static Future<ErnestResponse> getHealthTips() async {
    return await askQuestion(
      'Give me 3 general health and wellness tips for today. Keep them simple and actionable.',
    );
  }

  // Get wellness advice
  static Future<ErnestResponse> getWellnessAdvice() async {
    return await askQuestion(
      'What are some general wellness practices I can incorporate into my daily routine?',
    );
  }

  // Clear API key (not needed with centralized setup)
  static Future<bool> clearConfiguration() async {
    // This method is kept for backward compatibility but not used
    return true;
  }
}

// Response model for Ernest AI
class ErnestResponse {
  final bool success;
  final String message;
  final bool requiresConfiguration;

  ErnestResponse({
    required this.success,
    required this.message,
    this.requiresConfiguration = false,
  });
}

// Health question categories for quick access
class HealthCategories {
  static const List<String> categories = [
    'General Wellness',
    'Nutrition',
    'Exercise',
    'Mental Health',
    'Sleep',
    'Stress Management',
    'Preventive Care',
    'Lifestyle Tips',
  ];

  static const Map<String, String> categoryQuestions = {
    'General Wellness':
        'What are some general wellness practices I can start today?',
    'Nutrition': 'What are some healthy eating habits I can adopt?',
    'Exercise': 'What are some simple exercises I can do at home?',
    'Mental Health': 'How can I improve my mental well-being?',
    'Sleep': 'What are some tips for better sleep?',
    'Stress Management': 'How can I manage daily stress effectively?',
    'Preventive Care':
        'What are some preventive health measures I should know?',
    'Lifestyle Tips': 'What lifestyle changes can improve my overall health?',
  };
}
