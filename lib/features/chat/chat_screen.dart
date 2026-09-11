import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../models/chat_message.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _messages = <ChatMessage>[
    ChatMessage(username: 'B_music02', message: 'Genel sohbete hoş geldiniz.'),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() => _messages.add(ChatMessage(username: 'Sen', message: text)));
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('B_music02 Genel Sohbet', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)), Text('Topluluk odası', style: TextStyle(fontSize: 11, color: AppColors.textSecondary))])),
      body: Column(children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(18),
            itemCount: _messages.length,
            itemBuilder: (context, i) {
              final m = _messages[i];
              final mine = m.username == 'Sen';
              return Align(
                alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 290),
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(color: mine ? AppColors.burgundy : AppColors.surfaceAlt, borderRadius: BorderRadius.circular(18)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(m.username, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: AppColors.gold)),
                    const SizedBox(height: 4),
                    Text(m.message),
                  ]),
                ),
              );
            },
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Row(children: [
              Expanded(child: TextField(controller: _controller, textInputAction: TextInputAction.send, onSubmitted: (_) => _send(), decoration: const InputDecoration(hintText: 'Mesaj yaz...'))),
              const SizedBox(width: 8),
              IconButton.filled(onPressed: _send, icon: const Icon(Icons.send_rounded)),
            ]),
          ),
        ),
      ]),
    );
  }
}
