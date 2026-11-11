/// Who wrote a message in a deal chat.
enum ChatAuthor {
  me,
  buyer,
  seller,
  agent,
  manager,
  system;

  static ChatAuthor fromName(String? n) =>
      ChatAuthor.values.firstWhere((a) => a.name == n, orElse: () => me);
}

/// One message in the deal chat / status log.
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.dealId,
    required this.author,
    required this.text,
    required this.createdAt,
  });

  final String id;
  final String dealId;
  final ChatAuthor author;
  final String text;
  final DateTime createdAt;

  bool get isSystem => author == ChatAuthor.system;
  bool get isMine => author == ChatAuthor.me;

  Map<String, dynamic> toJson() => {
    'id': id,
    'dealId': dealId,
    'author': author.name,
    'text': text,
    'createdAt': createdAt.toIso8601String(),
  };

  factory ChatMessage.fromJson(Map<dynamic, dynamic> j) => ChatMessage(
    id: j['id'] as String,
    dealId: j['dealId'] as String,
    author: ChatAuthor.fromName(j['author'] as String?),
    text: j['text'] as String? ?? '',
    createdAt:
        DateTime.tryParse(j['createdAt'] as String? ?? '') ?? DateTime.now(),
  );
}
