import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Offline AI service using Google Gemini AI
/// Works completely without any server - directly from Flutter app
class OfflineAIService {
  static final OfflineAIService _instance = OfflineAIService._internal();
  factory OfflineAIService() => _instance;
  OfflineAIService._internal();

  GenerativeModel? _model;
  bool _isInitialized = false;
  String? _apiKey;

  // Your Google AI API key - replace with your actual key
  static const String _defaultApiKey = 'YOUR_GOOGLE_AI_API_KEY';

  /// Initialize the AI service
  Future<bool> initialize() async {
    try {
      // Try to get API key from shared preferences first
      final prefs = await SharedPreferences.getInstance();
      _apiKey = prefs.getString('google_ai_api_key') ?? _defaultApiKey;

      if (_apiKey == null || _apiKey == 'YOUR_GOOGLE_AI_API_KEY') {
        print('⚠️ Google AI API key not configured');
        return false;
      }

      // Initialize Gemini model
      _model = GenerativeModel(
        model: 'gemini-1.5-flash', // Fast and free model
        apiKey: _apiKey!,
        generationConfig: GenerationConfig(
          temperature: 0.7,
          topK: 40,
          topP: 0.95,
          maxOutputTokens: 1024,
        ),
        safetySettings: [
          SafetySetting(HarmCategory.harassment, HarmBlockThreshold.medium),
          SafetySetting(HarmCategory.hateSpeech, HarmBlockThreshold.medium),
          SafetySetting(
            HarmCategory.sexuallyExplicit,
            HarmBlockThreshold.medium,
          ),
          SafetySetting(
            HarmCategory.dangerousContent,
            HarmBlockThreshold.medium,
          ),
        ],
      );

      _isInitialized = true;
      print('✅ Offline AI service initialized successfully');
      return true;
    } catch (e) {
      print('❌ Failed to initialize AI service: $e');
      _isInitialized = false;
      return false;
    }
  }

  /// Check if AI service is available
  bool get isAvailable => _isInitialized && _model != null;

  /// Send a text message to AI
  Future<AIResponse> sendMessage(String message) async {
    if (!isAvailable) {
      return AIResponse.error(
        'AI service not initialized. Please check your API key.',
      );
    }

    try {
      // Create content for the AI
      final content = [Content.text(message)];

      // Generate response
      final response = await _model!.generateContent(content);

      if (response.text != null && response.text!.isNotEmpty) {
        return AIResponse.success(response.text!);
      } else {
        return AIResponse.error('AI returned an empty response');
      }
    } catch (e) {
      print('Error generating AI response: $e');
      if (e.toString().contains('API_KEY')) {
        return AIResponse.error(
          'Invalid API key. Please check your Google AI API key.',
        );
      } else if (e.toString().contains('quota')) {
        return AIResponse.error('API quota exceeded. Please try again later.');
      } else {
        return AIResponse.error('Failed to get AI response: ${e.toString()}');
      }
    }
  }

  /// Send an image with optional text to AI
  Future<AIResponse> sendImageMessage(
    Uint8List imageBytes,
    String mimeType, [
    String? textMessage,
  ]) async {
    if (!isAvailable) {
      return AIResponse.error(
        'AI service not initialized. Please check your API key.',
      );
    }

    try {
      // Create content with image and optional text
      final List<Content> content = [];

      if (textMessage != null && textMessage.isNotEmpty) {
        content.add(Content.text(textMessage));
      } else {
        content.add(
          Content.text(
            'Please analyze this image and describe what you see in detail.',
          ),
        );
      }

      // Add image data
      content.add(Content.data(mimeType, imageBytes));

      // Generate response
      final response = await _model!.generateContent(content);

      if (response.text != null && response.text!.isNotEmpty) {
        return AIResponse.success(response.text!);
      } else {
        return AIResponse.error('AI returned an empty response for the image');
      }
    } catch (e) {
      print('Error analyzing image: $e');
      if (e.toString().contains('API_KEY')) {
        return AIResponse.error(
          'Invalid API key. Please check your Google AI API key.',
        );
      } else if (e.toString().contains('quota')) {
        return AIResponse.error('API quota exceeded. Please try again later.');
      } else if (e.toString().contains('image')) {
        return AIResponse.error(
          'Failed to process image. Please try a different image format.',
        );
      } else {
        return AIResponse.error('Failed to analyze image: ${e.toString()}');
      }
    }
  }

  /// Set API key and reinitialize
  Future<bool> setApiKey(String apiKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('google_ai_api_key', apiKey);
      _apiKey = apiKey;
      return await initialize();
    } catch (e) {
      print('Failed to set API key: $e');
      return false;
    }
  }

  /// Get stored API key (masked for security)
  Future<String> getMaskedApiKey() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = prefs.getString('google_ai_api_key') ?? '';
      if (key.length > 8) {
        return '${key.substring(0, 4)}****${key.substring(key.length - 4)}';
      }
      return key.isNotEmpty ? '****' : 'Not set';
    } catch (e) {
      return 'Error';
    }
  }

  /// Test AI connection with a simple message
  Future<bool> testConnection() async {
    try {
      final response = await sendMessage(
        'Hello! Please respond with just "AI is working" if you can understand this message.',
      );
      return response.isSuccess;
    } catch (e) {
      return false;
    }
  }

  /// Get fallback response for basic questions
  String getFallbackResponse(String message) {
    final normalizedMessage = message.toLowerCase().trim();

    // Math expression evaluation (existing functionality)
    try {
      // Simple math expressions
      if (RegExp(r'^[\d\+\-\*\/\(\)\s\.]+$').hasMatch(normalizedMessage)) {
        // You can add math expression evaluation here
        return "I can see this looks like a math expression. For calculations, please use a calculator app or describe the problem in words.";
      }
    } catch (e) {
      // Continue to other fallbacks
    }

    // Common question patterns
    final fallbackResponses = {
      'hello':
          'Hi there! I\'m your offline AI assistant. How can I help you with your studies today?',
      'hi': 'Hello! What would you like to learn about?',
      'help':
          'I\'m here to help with your questions! You can ask me about any subject, and I\'ll do my best to assist.',
      'what':
          'I can help explain concepts, solve problems, and answer questions on various topics.',
      'how':
          'I can provide step-by-step explanations for problems and processes.',
      'why':
          'I can help explain the reasons behind various concepts and phenomena.',
      'math':
          'I can help with math problems! Describe your question and I\'ll provide explanations.',
      'science':
          'I can assist with science questions across physics, chemistry, biology, and more.',
      'history':
          'I can help with historical questions and provide context about events.',
      'english':
          'I can help with grammar, writing, literature, and language questions.',
      'study':
          'I can provide study tips, explain concepts, and help with homework questions.',
    };

    // Check for matching patterns
    for (final entry in fallbackResponses.entries) {
      if (normalizedMessage.contains(entry.key)) {
        return entry.value;
      }
    }

    return 'I\'m here to help with your questions! Please ask me about any topic you\'d like to learn about - science, math, history, or any other subject.';
  }
}

/// Response class for AI interactions
class AIResponse {
  final String message;
  final bool isSuccess;
  final String? errorCode;

  AIResponse._(this.message, this.isSuccess, [this.errorCode]);

  factory AIResponse.success(String message) => AIResponse._(message, true);
  factory AIResponse.error(String error, [String? code]) =>
      AIResponse._(error, false, code);

  @override
  String toString() => isSuccess ? 'Success: $message' : 'Error: $message';
}
