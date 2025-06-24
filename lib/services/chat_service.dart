import "package:cloud_firestore/cloud_firestore.dart";
import "../models/chat.dart";
import "../models/message.dart";

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Verifica se já existe um chat individual entre dois usuários.
  /// Retorna o chatId se existir, ou null se não existir.
  Future<String?> getIndividualChatId(String uid1, String uid2) async {
    final participants = [uid1, uid2]..sort();
    final chatsQuery = await _firestore
        .collection("chats")
        .where("participants", isEqualTo: participants)
        .get();

    if (chatsQuery.docs.isNotEmpty) {
      return chatsQuery.docs.first.id;
    }
    return null;
  }

  /// Cria um chat (individual ou grupo) e retorna o chatId.
  /// participants deve ter ao menos 2 UIDs.
  Future<String> createChat(List<String> participants) async {
    if (participants.length < 2) {
      throw Exception("Chat precisa ter ao menos 2 participantes");
    }
    participants.sort();

    final chatData = Chat(
      id: "",
      participants: participants,
      lastMessage: "",
      updatedAt: DateTime.now(),
    ).toMap();

    final docRef = await _firestore.collection("chats").add(chatData);
    return docRef.id;
  }

  /// Envia mensagem para chatId.
  /// Se chatId for null, cria chat individual automático entre sender e recipient.
  /// Retorna o ID da mensagem criada.
  Future<String> sendMessage({
    required String senderId,
    required String text,
    required String? chatId,
    required List<String> participantsForChatCreation, // necessário se chatId for null
    String? replyToMessageId,
  }) async {
    String finalChatId = chatId ?? "";

    if (finalChatId.isEmpty) {
      // cria chat individual se ainda não existir
      if (participantsForChatCreation.length != 2) {
        throw Exception("Para criar chat individual precisa exatamente 2 participantes");
      }
      // verifica se já existe chat
      final existingChatId = await getIndividualChatId(
        participantsForChatCreation[0],
        participantsForChatCreation[1],
      );
      if (existingChatId != null) {
        finalChatId = existingChatId;
      } else {
        finalChatId = await createChat(participantsForChatCreation);
      }
    }

    // cria a mensagem
    final messageData = Message(
      id: "",
      senderId: senderId,
      text: text,
      sentAt: DateTime.now(),
      readBy: [senderId], // quem enviou já leu
      replyToMessageId: replyToMessageId,
    ).toMap();

    final messageRef = await _firestore.collection("messages").doc(finalChatId).collection("messages").add(messageData);

    // atualiza o chat com lastMessage e updatedAt
    await _firestore.collection("chats").doc(finalChatId).update({
      "lastMessage": text,
      "updatedAt": DateTime.now(),
    });

    return messageRef.id;
  }

  Future<String> createGroupChat({
    required List<String> participants,
    String? groupName,
  }) async {
    if (participants.length < 2) {
      throw Exception("Grupo precisa ter ao menos 2 participantes");
    }

    participants.sort();

    final chatData = {
      "participants": participants,
      "lastMessage": "",
      "updatedAt": DateTime.now(),
      if (groupName != null) "groupName": groupName,
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
          "readBy": FieldValue.arrayUnion([userId]),
        });
      }
    }

    await batch.commit();
  }
}
