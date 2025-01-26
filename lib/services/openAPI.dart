import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class OpenAIService {
  final String _baseUrl = 'https://api.openai.com/v1/chat/completions';

  Future<String> getChatResponse({
    required String message,
    String model = 'gpt-3.5-turbo',
    String? imageUrl,
  }) async {
    final apiKey = dotenv.env['OPENAI_API_KEY'];
    if (apiKey == null) {
      throw Exception('OpenAI API key not found');
    }

    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $apiKey'
    };

    List<Map<String, dynamic>> messages = [
      {'role': 'user', 'content': message}
    ];

    // Add image context if provided
    if (imageUrl != null) {
      final bytes = await http.readBytes(Uri.parse(imageUrl));
      final base64Image = 'data:image/jpeg;base64,' + base64Encode(bytes);
      messages.add({
        'role': 'user',
        'content': [
          {'type': 'text', 'text': message},
          {'type': 'image_url', 'image_url': {'url': base64Image}}
        ]
      });
    }

    final body = jsonEncode({
      'model': model,
      'messages': messages,
      'max_tokens': 300
    });

    try {
      final response = await http.post(
          Uri.parse(_baseUrl),
          headers: headers,
          body: body
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['choices'][0]['message']['content'].trim();
      } else {
        throw Exception('Failed to get response: ${response.body}');
      }
    } catch (e) {
      return 'Sorry, an error occurred: $e';
    }
  }
}