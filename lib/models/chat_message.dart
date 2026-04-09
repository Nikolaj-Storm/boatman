class ChatMessage {
  final String id;
  final String role; // 'user' or 'assistant'
  final String content;
  final DateTime timestamp;
  final List<String>? sourceChunks; // references used in RAG

  ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    DateTime? timestamp,
    this.sourceChunks,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'role': role,
      'content': content,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: map['id'] as String,
      role: map['role'] as String,
      content: map['content'] as String,
      timestamp: DateTime.parse(map['timestamp'] as String),
    );
  }

  bool get isUser => role == 'user';
  bool get isAssistant => role == 'assistant';
}

class ChatSession {
  final String id;
  final String boatProfileId;
  String title;
  final DateTime createdAt;
  DateTime lastMessageAt;
  List<ChatMessage> messages;

  ChatSession({
    required this.id,
    required this.boatProfileId,
    this.title = 'New Chat',
    DateTime? createdAt,
    DateTime? lastMessageAt,
    List<ChatMessage>? messages,
  })  : createdAt = createdAt ?? DateTime.now(),
        lastMessageAt = lastMessageAt ?? DateTime.now(),
        messages = messages ?? [];

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'boat_profile_id': boatProfileId,
      'title': title,
      'created_at': createdAt.toIso8601String(),
      'last_message_at': lastMessageAt.toIso8601String(),
    };
  }

  factory ChatSession.fromMap(Map<String, dynamic> map) {
    return ChatSession(
      id: map['id'] as String,
      boatProfileId: map['boat_profile_id'] as String,
      title: map['title'] as String? ?? 'New Chat',
      createdAt: DateTime.parse(map['created_at'] as String),
      lastMessageAt: DateTime.parse(map['last_message_at'] as String),
    );
  }
}
