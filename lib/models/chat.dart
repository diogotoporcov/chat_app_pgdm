import "package:cloud_firestore/cloud_firestore.dart";

class Chat {
  final String id; // ID do chat (ex: uid1_uid2)
  final List<String> participants; // UIDs dos usuários da conversa
  final String lastMessage;
  final DateTime updatedAt;

  Chat({
    required this.id,
    required this.participants,
    required this.lastMessage,
    required this.updatedAt,
  });

  factory Chat.fromMap(Map<String, dynamic> map, String id) {
    return Chat(
      id: id,
      participants: List<String>.from(map["participants"]),
      lastMessage: map["lastMessage"],
      updatedAt: (map["updatedAt"] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      "participants": participants,
      "lastMessage": lastMessage,
      "updatedAt": updatedAt,
    };
  }
}
