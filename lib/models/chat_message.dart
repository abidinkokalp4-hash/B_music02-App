class ChatMessage {
  ChatMessage({required this.username, required this.message, DateTime? sentAt})
      : sentAt = sentAt ?? DateTime.now();

  final String username;
  final String message;
  final DateTime sentAt;
}
