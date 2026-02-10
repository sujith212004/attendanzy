import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'ai_chat_config.dart';
import '../config/api_config.dart';

/// Service class to handle AI API communication
class AIChatService {
  static final AIChatService _instance = AIChatService._internal();
  factory AIChatService() => _instance;
  AIChatService._internal();

  /// Check if the AI server is healthy and responsive
  Future<bool> checkServerHealth() async {
    // Get base URL without /api suffix
    final String configBaseUrl = ApiConfig.baseUrl.replaceAll('/api', '');

    // Try multiple URLs in case one doesn't work
    final List<String> possibleUrls = [
      '$configBaseUrl/health', // From config (production or dev)
      'http://10.0.2.2:5000/health', // Android emulator fallback
      'http://192.168.1.10:5000/health', // Real device on same network
      'http://localhost:5000/health', // Desktop/iOS simulator
      'http://127.0.0.1:5000/health', // Alternative localhost
    ];

    for (String url in possibleUrls) {
      try {
        print('Trying to connect to: $url');
        final response = await http
            .get(Uri.parse(url), headers: AIChatConfig.requestHeaders)
            .timeout(const Duration(seconds: 3));

        if (response.statusCode == 200) {
          print('Successfully connected to: $url');
          // Update the base URL in config if we found a working one
          _workingBaseUrl = url.replaceAll('/health', '');
          return true;
        }
      } catch (e) {
        print('Failed to connect to $url: $e');
        continue;
      }
    }

    print('No working server URL found');
    return false;
  }

  // Store the working URL
  String? _workingBaseUrl;

  /// Send a message to the AI and get a response
  Future<AIChatResponse> sendMessage(String message) async {
    try {
      // Validate input
      if (message.trim().isEmpty) {
        return AIChatResponse.error('Message cannot be empty');
      }

      if (message.length > AIChatConfig.maxMessageLength) {
        return AIChatResponse.error(
          'Message is too long. Please keep it under ${AIChatConfig.maxMessageLength} characters.',
        );
      }

      // Prepare request body
      final requestBody = {
        'message': message.trim(),
        if (AIChatConfig.enableConversationMemory)
          'conversation_id': AIChatConfig.conversationId,
      };

      // Use working URL if available, otherwise use default
      String chatUrl =
          _workingBaseUrl != null
              ? '$_workingBaseUrl/chat'
              : AIChatConfig.chatEndpoint;

      print('Sending message to: $chatUrl');

      // Make API request
      final response = await http
          .post(
            Uri.parse(chatUrl),
            headers: AIChatConfig.requestHeaders,
            body: json.encode(requestBody),
          )
          .timeout(AIChatConfig.apiTimeout);

      // Handle response
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body) as Map<String, dynamic>;

        final aiResponse =
            responseData['response'] as String? ??
            responseData['message'] as String? ??
            responseData['answer'] as String? ??
            'Sorry, I received an empty response.';

        return AIChatResponse.success(aiResponse);
      } else {
        print('API Error: ${response.statusCode} - ${response.body}');
        return AIChatResponse.error(
          'Sorry, I\'m having trouble connecting to my AI brain. Please try again.',
        );
      }
    } on SocketException {
      return AIChatResponse.error(AIChatConfig.networkErrorMessage);
    } on TimeoutException {
      return AIChatResponse.error(AIChatConfig.timeoutErrorMessage);
    } on FormatException {
      return AIChatResponse.error(
        'Sorry, I received a malformed response. Please try again.',
      );
    } catch (e) {
      print('Unexpected error in sendMessage: $e');
      return AIChatResponse.error(AIChatConfig.defaultErrorMessage);
    }
  }

  /// Send an image with optional text message to the AI and get a response
  Future<AIChatResponse> sendImageMessage(
    String base64Image,
    String mimeType, [
    String? textMessage,
  ]) async {
    try {
      // Validate inputs
      if (base64Image.trim().isEmpty) {
        return AIChatResponse.error('Image data cannot be empty');
      }

      // Prepare request body
      final requestBody = {
        'image': base64Image,
        'mime_type': mimeType,
        if (textMessage != null && textMessage.trim().isNotEmpty)
          'message': textMessage.trim(),
        if (AIChatConfig.enableConversationMemory)
          'conversation_id': AIChatConfig.conversationId,
      };

      // Use working URL if available, otherwise use default
      String imageUrl =
          _workingBaseUrl != null
              ? '$_workingBaseUrl/image'
              : 'http://10.0.2.2:5000/image'; // Default for Android emulator

      print('Sending image to: $imageUrl');

      // Make API request with longer timeout for image processing
      final response = await http
          .post(
            Uri.parse(imageUrl),
            headers: AIChatConfig.requestHeaders,
            body: json.encode(requestBody),
          )
          .timeout(
            const Duration(seconds: 30),
          ); // Longer timeout for image processing

      // Handle response
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body) as Map<String, dynamic>;

        final aiResponse =
            responseData['response'] as String? ??
            responseData['message'] as String? ??
            responseData['answer'] as String? ??
            'I can see the image, but I\'m having trouble analyzing it right now.';

        return AIChatResponse.success(aiResponse);
      } else {
        print('Image API Error: ${response.statusCode} - ${response.body}');
        return AIChatResponse.error(
          'Sorry, I\'m having trouble analyzing images right now. Please try again.',
        );
      }
    } on SocketException {
      return AIChatResponse.error(
        'No internet connection. Please check your network and try again.',
      );
    } on TimeoutException {
      return AIChatResponse.error(
        'Image processing is taking too long. Please try with a smaller image.',
      );
    } on FormatException {
      return AIChatResponse.error(
        'Sorry, I received a malformed response while processing your image.',
      );
    } catch (e) {
      print('Unexpected error in sendImageMessage: $e');
      return AIChatResponse.error('Failed to process image. Please try again.');
    }
  }

  /// Reset the conversation context
  Future<bool> resetConversation() async {
    try {
      final requestBody = {
        if (AIChatConfig.enableConversationMemory)
          'conversation_id': AIChatConfig.conversationId,
      };

      // Use working URL if available, otherwise use default
      String resetUrl =
          _workingBaseUrl != null
              ? '$_workingBaseUrl/chat/reset'
              : AIChatConfig.resetEndpoint;

      final response = await http
          .post(
            Uri.parse(resetUrl),
            headers: AIChatConfig.requestHeaders,
            body: json.encode(requestBody),
          )
          .timeout(AIChatConfig.connectionTimeout);

      return response.statusCode == 200;
    } catch (e) {
      print('Failed to reset conversation: $e');
      return false;
    }
  }

  /// Get a fallback response when AI is not available
  String getFallbackResponse(String userMessage) {
    final normalizedMessage = userMessage.toLowerCase().trim();

    // Check for exact matches first
    for (final entry in AIChatConfig.fallbackResponses.entries) {
      if (normalizedMessage.contains(entry.key)) {
        return entry.value;
      }
    }

    // Default fallback
    return 'I\'m sorry, I\'m currently offline. Could you please try again later?';
  }
}

/// Class to represent AI chat responses
class AIChatResponse {
  final String message;
  final bool isSuccess;
  final DateTime timestamp;

  AIChatResponse._({
    required this.message,
    required this.isSuccess,
    required this.timestamp,
  });

  factory AIChatResponse.success(String message) {
    return AIChatResponse._(
      message: message,
      isSuccess: true,
      timestamp: DateTime.now(),
    );
  }

  factory AIChatResponse.error(String errorMessage) {
    return AIChatResponse._(
      message: errorMessage,
      isSuccess: false,
      timestamp: DateTime.now(),
    );
  }

  @override
  String toString() {
    return 'AIChatResponse(message: $message, isSuccess: $isSuccess, timestamp: $timestamp)';
  }
}
