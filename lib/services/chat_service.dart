import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/chat.dart';
import '../models/message.dart';
import '../models/user.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> sendMessage({
    required String senderId,
    required String text,
    required String chatId,
    List<String> participantsForChatCreation = const [],
    String? replyToMessageId,
    String? imageUrl, // Added imageUrl parameter
  }) async {
    final message = Message(
      id: '',
      senderId: senderId,
      text: text,
      sentAt: DateTime.now(),
      readBy: [senderId],
      replyToMessageId: replyToMessageId,
      imageUrl: imageUrl, // Pass imageUrl to the Message constructor
    );

    await _firestore
        .collection("messages")
        .doc(chatId)
        .collection("messages")
        .add(message.toMap());

    // Update last message and updatedAt in chat
    await _firestore.collection("chats").doc(chatId).set(
      {
        "lastMessage": text,
        "updatedAt": DateTime.now(),
        if (participantsForChatCreation.isNotEmpty)
          "participants": participantsForChatCreation,
      },
      SetOptions(merge: true),
    );
  }

  Future<String?> getIndividualChatId(
      String userId1, String userId2) async {
    final chatQuery = await _firestore
        .collection("chats")
        .where("isGroup", isEqualTo: false)
        .where("participants", arrayContains: userId1)
        .get();

    for (var doc in chatQuery.docs) {
      final participants = List<String>.from(doc["participants"]);
      if (participants.contains(userId2)) {
        return doc.id;
      }
    }
    return null;
  }

  Future<String> createChat(List<String> participants) async {
    final chatData = {
      "participants": participants,
      "lastMessage": "Chat criado",
      "updatedAt": DateTime.now(),
      "isGroup": false,
    };

    final docRef = await _firestore.collection("chats").add(chatData);
    return docRef.id;
  }

  Future<String> createGroupChat(
      String groupName, List<String> participants) async {
    final chatData = {
      "participants": participants,
      "lastMessage": "Grupo criado",
      "updatedAt": DateTime.now(),
      "groupName": groupName,
      "isGroup": true,
    };

    final docRef = await _firestore.collection("chats").add(chatData);
    return docRef.id;
  }

  Stream<List<Chat>> getUserChats(String userId) {
    return _firestore
        .collection('chats')
        .where('participants', arrayContains: userId)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => Chat.fromMap(doc.data(), doc.id))
        .toList());
  }

  Stream<List<Message>> getMessages(String chatId) {
    return _firestore
        .collection("messages")
        .doc(chatId)
        .collection("messages")
        .orderBy("sentAt", descending: false)
        .snapshots()
        .map((snapshot) =>
        snapshot.docs.map((doc) => Message.fromMap(doc.data(), doc.id)).toList());
  }

  Future<void> markMessagesAsRead({
    required String chatId,
    required String userId,
    required List<Message> messages,
  }) async {
    final batch = _firestore.batch();

    for (final msg in messages) {
      if (!msg.readBy.contains(userId)) {
        final msgRef = _firestore
            .collection("messages")
            .doc(chatId)
            .collection("messages")
            .doc(msg.id);
        batch.update(msgRef, {
          "readBy": FieldValue.arrayUnion([userId]) // Corrected: Removed 'fb_auth.' prefix
        });
      }
    }

    await batch.commit();
  }

  Future<User?> fetchUserFromFirestore(String uid) async {
    final doc = await _firestore.collection("users").doc(uid).get();
    if (doc.exists) {
      return User.fromMap(doc.data()!);
    }
    return null;
  }

  Future<void> updateProfilePicture(String uid, String? imageUrl) async {
    await _firestore.collection("users").doc(uid).update({
      "profilePictureUrl": imageUrl,
    });
  }

  Future<void> updateStatusMessage(String uid, String statusMessage) async {
    await _firestore.collection("users").doc(uid).update({
      "statusMessage": statusMessage,
    });
  }

  Future<void> updateUsername(String uid, String newUsername) async {
    final usernameExists = await _firestore
        .collection("users")
        .where("username", isEqualTo: newUsername)
        .limit(1)
        .get();

    if (usernameExists.docs.isNotEmpty && usernameExists.docs.first.id != uid) {
      throw Exception("Nome de usuário já está em uso.");
    }

    await _firestore.collection("users").doc(uid).update({
      "username": newUsername,
    });
  }

  Future<void> deleteMessage(String chatId, String messageId) async {
    await _firestore
        .collection("messages")
        .doc(chatId)
        .collection("messages")
        .doc(messageId)
        .delete();
  }
}