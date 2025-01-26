import 'package:mongo_dart/mongo_dart.dart';
import 'dart:async';

class ChatMessage {
  final String conversationId;
  final String content;
  final bool isUserMessage;
  final DateTime timestamp;
  final String? imageUrl;
  final String model;

  ChatMessage({
    required this.conversationId,
    required this.content,
    required this.isUserMessage,
    required this.timestamp,
    this.imageUrl,
    required this.model,
  });

  Map<String, dynamic> toMap() {
    return {
      'conversationId': conversationId,
      'content': content,
      'isUserMessage': isUserMessage,
      'timestamp': timestamp.toIso8601String(),
      'imageUrl': imageUrl,
      'model': model,
    };
  }

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      conversationId: map['conversationId'],
        content: map['content'],
        isUserMessage: map['isUserMessage'],
        timestamp: DateTime.parse(map['timestamp']),
        imageUrl: map['imageUrl'],
        model: map['model'],
    );
  }
}

class ChatRepository {
  late Db _db;
  late DbCollection _chatCollection;

  Future<void> connect() async {
    _db = await Db.create('mongodb+srv://shashi2002sah:saroj%402002@cluster0.h4s6t.mongodb.net/chatgpt_clone');
    await _db.open();
    _chatCollection = _db.collection('chat_history');
  }

  Future<void> saveMessage(ChatMessage message) async {
    await _chatCollection.insertOne(message.toMap());
  }

  Future<List<ChatMessage>> getChatHistory(String conversationId) async {
    final messages = await _chatCollection.find({'conversationId': conversationId}).toList();
    return messages.map((map) => ChatMessage.fromMap(map)).toList();
  }

  Future<void> close() async {
    await _db.close();
  }
}