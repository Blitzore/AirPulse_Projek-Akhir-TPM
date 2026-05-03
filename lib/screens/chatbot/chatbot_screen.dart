import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

/// Layar chatbot AI (AirBot) untuk konsultasi kualitas udara dan kesehatan.
class ChatbotScreen extends StatefulWidget {
  final String apiKey;
  const ChatbotScreen({super.key, required this.apiKey});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  late final ChatSession _chat;
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final List<Map<String, String>> _messages = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final model = GenerativeModel(
      model: 'gemini-flash-latest',
      apiKey: widget.apiKey,
      systemInstruction: Content.system(
        'Kamu adalah AirBot, asisten AI untuk aplikasi AirPulse. '
        'Secara default, jawablah menggunakan Bahasa Indonesia kecuali pengguna memakai bahasa lain. '
        'Fokus utamamu adalah HANYA membantu menjawab pertanyaan seputar kualitas udara, suhu, kelembaban, dan kesehatan pernapasan. '
        'Jika pengguna menanyakan hal lain (seperti coding, matematika, terjemahan, lelucon, atau topik umum lainnya), tolak dengan sopan dan katakan bahwa kamu hanya diprogram untuk membahas kualitas udara dan kesehatan.',
      ),
    );
    _chat = model.startChat();
    _messages.add({
      'sender': 'bot',
      'text': 'Halo! Saya AirBot. Ada yang bisa saya bantu terkait kualitas udara dan kesehatan Anda?',
    });
  }

  void _sendMessage() async {
    final text = _textController.text;
    if (text.isEmpty) return;

    setState(() {
      _messages.add({'sender': 'user', 'text': text});
      _isLoading = true;
    });
    _textController.clear();
    _scrollToBottom();

    try {
      final response = await _chat.sendMessage(Content.text(text));
      setState(() {
        _messages.add({'sender': 'bot', 'text': response.text ?? 'Maaf, saya tidak mengerti.'});
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _messages.add({'sender': 'bot', 'text': 'Terjadi kesalahan: $e'});
        _isLoading = false;
      });
    }
    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AirBot (Konsultasi AI)')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final msg = _messages[index];
                  final isUser = msg['sender'] == 'user';
                  return Align(
                    alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isUser ? Colors.teal : Colors.grey[300],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        msg['text']!,
                        style: TextStyle(color: isUser ? Colors.white : Colors.black),
                      ),
                    ),
                  );
                },
              ),
            ),
            if (_isLoading) const Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator()),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      decoration: const InputDecoration(
                        hintText: 'Tanya tentang udara/kesehatan...',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: _sendMessage,
                    color: Colors.teal,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
