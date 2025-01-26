import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/openAPI.dart';
import 'services/imageUpload.dart';
import 'models/chatHistory.dart';
import 'package:shared_preferences/shared_preferences.dart';


class ChatScreen extends StatefulWidget {
  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  String _selectedModel = 'gpt-3.5-turbo';
  File? _selectedImage;
  bool _isUploading = false;
  String? _conversationId;

  @override
  void initState() {
    super.initState();
    _initializeConversation();
  }

  Future<void> _initializeConversation() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? storedConversationId = prefs.getString('conversationId');

    if (storedConversationId == null) {
      storedConversationId = DateTime.now().millisecondsSinceEpoch.toString();
      await prefs.setString('conversationId', storedConversationId);
    }

    setState(() {
      _conversationId = storedConversationId;
    });

    await _fetchChatHistory();
  }

  Future<void> _fetchChatHistory() async {
    if (_conversationId == null) return;

    final chatRepository = Provider.of<ChatRepository>(context, listen: false);
    await chatRepository.connect();
    final messages = await chatRepository.getChatHistory(_conversationId!);
    setState(() {
      _messages.addAll(messages);
    });
    await chatRepository.close();
  }

  Future<void> _clearConversation() async{
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('conversationId');
    setState(() {
      _messages.clear();
      _conversationId = null;
    });
    await _initializeConversation();
  }

  void _selectImage() async {

    if(_selectedModel != 'gpt-4o-mini') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Image upload is only supported for GPT-4o, Please change the model from above dropdown menu')),
      );
      return;
    }
    final imageUploadService = Provider.of<ImageUploadService>(context, listen: false);
    final pickedImage = await imageUploadService.pickImage();

    if (pickedImage != null) {
      setState(() {
        _selectedImage = pickedImage;
      });
    }
  }

  void _sendMessage() async {

    if(_conversationId == null) return;

    final message = _messageController.text.trim();
    if (message.isEmpty && _selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Message cannot be empty')),
      );
      return;
    }

    setState(() {
      _isUploading = true;
    });

    final openAIService = Provider.of<OpenAIService>(context, listen: false);
    final imageUploadService = Provider.of<ImageUploadService>(context, listen: false);
    final chatRepository = Provider.of<ChatRepository>(context, listen: false);

    String? imageUrl;
    if (_selectedImage != null) {
      imageUrl = await imageUploadService.uploadImageFile(context, _selectedImage!);
      if (imageUrl == null) {
        setState(() {
          _isUploading = false;
        });
        return;
      }
    }

    final userMessage = ChatMessage(
      conversationId: _conversationId!,
      content: message,
      isUserMessage: true,
      timestamp: DateTime.now(),
      imageUrl: imageUrl,
      model: _selectedModel,
    );

    setState(() {
      _messages.add(userMessage);
      _messageController.clear();
      _selectedImage = null;
    });

    _scrollToBottom();

    try {
      final response = await openAIService.getChatResponse(
        message: message,
        model: _selectedModel,
        imageUrl: imageUrl,
      );

      final aiMessage = ChatMessage(
        conversationId: _conversationId!,
        content: response,
        isUserMessage: false,
        timestamp: DateTime.now(),
        model: _selectedModel,
      );

      setState(() {
        _messages.add(aiMessage);
      });

      _scrollToBottom();

      await chatRepository.connect();
      await chatRepository.saveMessage(userMessage);
      await chatRepository.saveMessage(aiMessage);
      await chatRepository.close();
    } catch (e) {
      print(e);
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Widget _buildMessageBubble(ChatMessage message) {
    final isUserMessage = message.isUserMessage;
    return Align(
      alignment: isUserMessage ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isUserMessage ? Colors.blueAccent : Colors.grey[200],
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: isUserMessage ? Radius.circular(16) : Radius.zero,
            bottomRight: isUserMessage ? Radius.zero : Radius.circular(16),
          ),
        ),
        child: Column(
          crossAxisAlignment:
          isUserMessage ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (message.imageUrl != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Image.network(message.imageUrl!, height: 150),
              ),
            Text(
              message.content,
              style: TextStyle(
                color: isUserMessage ? Colors.white : Colors.black,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('ChatGPT Clone', style: TextStyle(fontSize: 18)),
        backgroundColor: Colors.blueAccent,
        actions: [
          DropdownButton<String>(
            value: _selectedModel,
            dropdownColor: Colors.blueAccent,
            items: [
              DropdownMenuItem(child: Text('GPT-3.5'), value: 'gpt-3.5-turbo'),
              DropdownMenuItem(child: Text('GPT-4'), value: 'gpt-4'),
              DropdownMenuItem(child: Text('GPT-4o'), value: 'gpt-4o-mini'),
            ],
            onChanged: (value) {
              setState(() {
                _selectedModel = value!;
              });
            },
          ),
          IconButton(onPressed: _clearConversation, icon: Icon(Icons.delete)),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                return _buildMessageBubble(message);
              },
            ),
          ),
          if (_isUploading) LinearProgressIndicator(),
          if (_selectedImage != null)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(_selectedImage!, height: 150),
              ),
            ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.image, color: Colors.blueAccent),
                    onPressed: _selectImage,
                  ),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        filled: true,
                        fillColor: Colors.grey[200],
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: Colors.blueAccent,
                    child: IconButton(
                      icon: Icon(Icons.send, color: Colors.white),
                      onPressed: _sendMessage,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
