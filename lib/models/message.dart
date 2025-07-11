import "package:cloud_firestore/cloud_firestore.dart";

class Message {
  final String id;
  final String senderId;
  final String text;
  final DateTime sentAt;
  final List<String> readBy;
  final String? replyToMessageId;
  final String? imageUrl; // Add this new field

  Message({
    required this.id,
    required this.senderId,
    required this.text,
    required this.sentAt,
    required this.readBy,
    this.replyToMessageId,
    this.imageUrl, // Initialize the new field
  });

  factory Message.fromMap(Map<String, dynamic> map, String id) {
    return Message(
      id: id,
      senderId: map["senderId"],
      text: map["text"],
      sentAt: (map["sentAt"] as Timestamp).toDate(),
      readBy: List<String>.from(map["readBy"] ?? []),
      replyToMessageId: map["replyToMessageId"],
      imageUrl: map["imageUrl"], // Map the new field
    );
  }

  Map<String, dynamic> toMap() {
    return {
      "senderId": senderId,
      "text": text,
      "sentAt": sentAt,
      "readBy": readBy,
      if (replyToMessageId != null) "replyToMessageId": replyToMessageId,
      if (imageUrl != null) "imageUrl": imageUrl,
    };
  }
}