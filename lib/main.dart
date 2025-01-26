import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/openAPI.dart';
import 'services/imageUpload.dart';
import 'models/chatHistory.dart';
import 'chatScreen.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: ".env");

  // Initialize repositories and services
  final chatRepository = ChatRepository();
  await chatRepository.connect();

  runApp(
      MultiProvider(
        providers: [
          Provider<OpenAIService>(create: (_) => OpenAIService()),
          Provider<ImageUploadService>(create: (_) => ImageUploadService()),
          Provider<ChatRepository>.value(value: chatRepository),
        ],
        child: ChatGPTCloneApp(),
      )
  );
}

class ChatGPTCloneApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ChatGPT Clone',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: ChatScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}