import 'package:dash_chat_2/dash_chat_2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gemini/flutter_gemini.dart';

class Ai extends StatefulWidget {
  const Ai({super.key});

  @override
  State<Ai> createState() => _AiState();
}

class _AiState extends State<Ai> {
  final gemini = Gemini.instance;
  List<ChatMessage> messages = [];
  final currentUser = ChatUser(id: "0", firstName: "User");
  final geminiUser = ChatUser(id: "1", firstName: "Softrix AI");

  String formatAIResponse(String response) {
    response = response.replaceAllMapped(
      RegExp(r'\*\*(.*?)\*\*'),
          (match) => '${match[1]}:',
    );

    response = response.replaceAllMapped(
      RegExp(r'\* (.*?)(?:\n|$)'),
          (match) => '- ${match[1]}\n',
    );

    return response.trim();
  }

  Widget textBuilder(ChatMessage message, ChatMessage? previousMessage, ChatMessage? nextMessage) {
    final lines = message.text.split('\n');
    final textWidgets = <Widget>[];

    for (var line in lines) {
      if (line.endsWith(':')) {
        textWidgets.add(
          Text(
            line,
            style: TextStyle(
              color: message.user == currentUser ? Colors.white : Colors.black,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        );
      } else {
        textWidgets.add(
          Text(
            line,
            style: TextStyle(
              color: message.user == currentUser ? Colors.white : Colors.black,
              fontSize: 14,
            ),
          ),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: textWidgets,
    );
  }

  BoxDecoration messageDecorationBuilder(ChatMessage message, ChatMessage? previousMessage, ChatMessage? nextMessage) {
    return BoxDecoration(
      color: message.user == currentUser ? const Color(0xFF007BFF) : Colors.grey[200],
      borderRadius: BorderRadius.circular(12),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          'Softrix AI',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        elevation: 0,
      ),
      backgroundColor: Colors.white,
      body: DashChat(
        currentUser: currentUser,
        onSend: _handleSendMessage,
        messages: messages,
        messageOptions: MessageOptions(
          showTime: true,
          timeTextColor: Colors.grey,
          messageTextBuilder: textBuilder,
          messageDecorationBuilder: messageDecorationBuilder,
        ),
        inputOptions: InputOptions(
          inputDecoration: InputDecoration(
            hintText: 'Type your message...',
            hintStyle: const TextStyle(color: Colors.grey),
            filled: true,
            fillColor: Colors.grey[50],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF007BFF)),
            ),
          ),
          inputTextStyle: const TextStyle(color: Colors.black),
          sendButtonBuilder: (onSend) => IconButton(
            onPressed: onSend,
            icon: const Icon(Icons.send, color: Color(0xFF007BFF)),
          ),
        ),
      ),
    );
  }

  void _handleSendMessage(ChatMessage message) async {
    setState(() {
      messages.insert(0, message);
    });

    try {
      final config = GenerationConfig(
        temperature: 0.9,
        topP: 0.95,
        topK: 40,
        maxOutputTokens: 2048,
      );

      final prompt =
          "You are Tradezy AI, a helpful assistant for trader. Provide detailed and conversational responses. User's message: ${message.text}";

      final response = await gemini.text(prompt, generationConfig: config);

      if (response?.output != null) {
        final formattedResponse = formatAIResponse(response!.output.toString());

        setState(() {
          messages.insert(
            0,
            ChatMessage(
              user: geminiUser,
              createdAt: DateTime.now(),
              text: formattedResponse,
            ),
          );
        });
      } else {
        setState(() {
          messages.insert(
            0,
            ChatMessage(
              user: geminiUser,
              createdAt: DateTime.now(),
              text: "Sorry, I couldn't generate a response. Please try again.",
            ),
          );
        });
      }
    } catch (e) {
      debugPrint('Error: $e');
      setState(() {
        messages.insert(
          0,
          ChatMessage(
            user: geminiUser,
            createdAt: DateTime.now(),
            text: "Sorry, I encountered an error. Please try again.",
          ),
        );
      });
    }
  }
}