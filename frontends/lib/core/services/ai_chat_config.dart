import 'package:flutter/foundation.dart';

/// Configuration class for AI Chat Integration
class AIChatConfig {
  // API Configuration - Updated to use your AI server
  // Note: Use 10.0.2.2 for Android emulator, 192.168.1.5 for real device
  static const String _baseUrl =
      kDebugMode
          ? 'http://10.0.2.2:5000' // Android emulator can access host via 10.0.2.2
          : 'http://192.168.1.10:5000'; // Real device on same network

  // Alternative URLs for different platforms:
  // For real Android device on same network: 'http://192.168.1.5:5000'
  // For iOS simulator: 'http://localhost:5000' or 'http://127.0.0.1:5000'
  // For Windows desktop: 'http://localhost:5000'

  static const String chatEndpoint = '$_baseUrl/chat';
  static const String healthEndpoint = '$_baseUrl/health';
  static const String resetEndpoint = '$_baseUrl/chat/reset';
  static const String testEndpoint = '$_baseUrl/test';

  // Timeout Configuration
  static const Duration apiTimeout = Duration(seconds: 30);
  static const Duration connectionTimeout = Duration(seconds: 10);

  // Chat Configuration
  static const String botName = 'Alice';
  static const String botDescription = 'Your AI Study Assistant';
  static const String defaultErrorMessage =
      'Sorry, I encountered an error. Please try again later.';
  static const String networkErrorMessage =
      'Sorry, I can\'t connect to the internet right now. Please check your connection.';
  static const String timeoutErrorMessage =
      'Sorry, the request is taking too long. Please try again.';

  // UI Configuration
  static const int maxMessageLength = 1000;
  static const bool enableTypingIndicator = true;
  static const Duration typingAnimationSpeed = Duration(milliseconds: 500);

  // Conversation Configuration
  static const bool enableConversationMemory = true;
  static const String conversationId = 'flutter_chat_session';

  // Fallback responses when AI is offline
  static const Map<String, String> fallbackResponses = {
    'hello':
        'Hi there! I\'m currently in offline mode, but I can still help with basic questions.',
    'hi': 'Hello! How can I assist you today?',
    'bye': 'Goodbye! Have a great day!',
    'goodbye': 'See you later! Take care!',
    'help':
        'I\'m here to help! Ask me anything and I\'ll do my best to assist you.',
    'thanks': 'You\'re welcome! Is there anything else I can help you with?',
    'thank you': 'My pleasure! Feel free to ask if you need more help.',
  };

  // Request headers
  static const Map<String, String> requestHeaders = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    'User-Agent': 'Attendanzy-Flutter-App/1.0',
  };
}
