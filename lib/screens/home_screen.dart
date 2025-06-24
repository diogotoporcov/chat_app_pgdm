import 'package:flutter/cupertino.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../main.dart';
import '../models/user.dart';
import '../services/chat_service.dart';
import '../services/auth_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
  FlutterLocalNotificationsPlugin();

  void _setupPushNotifications() async {
    await _firebaseMessaging.setAutoInitEnabled(true);
    await _firebaseMessaging.requestPermission();

    final token = await _firebaseMessaging.getToken();
    final currentUser = fb_auth.FirebaseAuth.instance.currentUser;
    if (currentUser != null && token != null) {
      await saveFcmToken(currentUser.uid, token);
    }

    const androidSettings = AndroidInitializationSettings("@mipmap/ic_launcher");
    const initSettings = InitializationSettings(android: androidSettings);
    await _localNotificationsPlugin.initialize(initSettings);

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _showLocalNotification(message);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      final chatId = message.data["chatId"];
      final senderId = message.data["senderId"];
      if (chatId != null) {
        navigatorKey.currentState?.pushNamed(
            "/chat",
            arguments: { "chatId": chatId, "otherUserId": senderId }
        );
      }
    });

    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) {
        final chatId = message.data["chatId"];
        final senderId = message.data["senderId"];
        if (chatId != null) {
          navigatorKey.currentState?.pushNamed(
              "/chat",
              arguments: { "chatId": chatId, "otherUserId": senderId }
          );
        }
      }
    });
  }

  void _showLocalNotification(RemoteMessage message) async {
    const androidDetails = AndroidNotificationDetails(
      "chat_channel",
      "Mensagens",
      importance: Importance.max,
      priority: Priority.high,
    );

    const notificationDetails = NotificationDetails(android: androidDetails);

    await _localNotificationsPlugin.show(
      0,
      message.notification?.title ?? "Nova mensagem",
      message.notification?.body ?? "",
      notificationDetails,
    );
  }

  @override
  void initState() {
    super.initState();
    _setupPushNotifications();
  }

  void _showNewChatPopup() {
    final TextEditingController usernameController = TextEditingController();
    showCupertinoDialog(
      context: context,
      builder: (ctx) {
        return CupertinoAlertDialog(
          title: const Text("Novo Chat"),
          content: Column(
            children: [
              const SizedBox(height: 8),
              CupertinoTextField(
                controller: usernameController,
                placeholder: "Nome de usuário",
                autofocus: true,
              ),
            ],
          ),
          actions: [
            CupertinoDialogAction(
              isDefaultAction: true,
              child: const Text("Cancelar"),
              onPressed: () {
                if (!ctx.mounted) return;
                Navigator.of(ctx).pop();
              },
            ),
            CupertinoDialogAction(
              child: const Text("Iniciar"),
              onPressed: () async {
                if (!ctx.mounted) return;
                final username = usernameController.text.trim();
                Navigator.of(ctx).pop();

                if (username.isEmpty) {
                  _showErrorDialog("Digite um nome de usuário.");
                  return;
                }

                final result = await _startChatWithUser(username);
                if (!mounted) return;
                if (result != null) {
                  Navigator.of(context).pushNamed("/chat", arguments: {"chatId": result});
                }
              },
            ),
          ],
        );
      },
    );
  }

  Future<String?> _startChatWithUser(String username) async {
    final currentUser = fb_auth.FirebaseAuth.instance.currentUser;
    if (currentUser == null) return null;

    try {
      final usersQuery = await FirebaseFirestore.instance
          .collection("users")
          .where("username", isEqualTo: username)
          .limit(1)
          .get();
      if (!mounted) return null;

      if (usersQuery.docs.isEmpty) {
        _showErrorDialog("Usuário '$username' não encontrado.");
        return null;
      }

      final otherUserId = usersQuery.docs.first["uid"];
      if (otherUserId == currentUser.uid) {
        _showErrorDialog("Você não pode iniciar um chat consigo mesmo.");
        return null;
      }

      final chatService = ChatService();
      final existingChatId = await chatService.getIndividualChatId(currentUser.uid, otherUserId);
      final chatId = existingChatId ?? await chatService.createChat([currentUser.uid, otherUserId]);

      return chatId;
    } catch (e) {
      if (!mounted) return null;
      _showErrorDialog("Erro ao iniciar o chat: ${e.toString()}");
      return null;
    }
  }

  void _showErrorDialog(String message) {
    if (!mounted) return;
    showCupertinoDialog(
      context: context,
      builder: (ctx) {
        return CupertinoAlertDialog(
          title: const Text("Erro"),
          content: Text(message),
          actions: [
            CupertinoDialogAction(
              child: const Text("OK"),
              onPressed: () {
                if (!ctx.mounted) return;
                Navigator.of(ctx).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<String> _getChatDisplayName(Map<String, dynamic> data, String currentUserId) async {
    if (data.containsKey("groupName") && data["groupName"] is String && data["groupName"].toString().isNotEmpty) {
      return data["groupName"];
    }

    final participants = List<String>.from(data["participants"] ?? []);
    if (participants.length == 2) {
      final otherUserId = participants.firstWhere((id) => id != currentUserId, orElse: () => "");
      final otherUser = await fetchUserFromFirestore(otherUserId);
      return (otherUser != null) ? otherUser.username : "Usuário Desconhecido";
    }

    List<String> usernames = [];

    for (final uid in participants) {
      if (uid == currentUserId) continue;
      final user = await fetchUserFromFirestore(uid);
      if (user != null) usernames.add(user.username);
    }

    if (usernames.isEmpty) return "Grupo sem nome";
    if (usernames.length > 3) {
      return "${usernames.take(3).join(', ')} & ${usernames.length - 3} outros";
    }
    return usernames.join(", ");
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = fb_auth.FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).pushReplacementNamed("/");
        }
      });
      return const CupertinoPageScaffold(
        child: Center(
          child: CupertinoActivityIndicator(),
        ),
      );
    }

    final chatsRef = FirebaseFirestore.instance
        .collection("chats")
        .where("participants", arrayContains: currentUser.uid)
        .orderBy("updatedAt", descending: true);
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text("Chats"),
        automaticallyImplyLeading: false,
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Icon(CupertinoIcons.person_circle),
          onPressed: () {
            final currentUser = fb_auth.FirebaseAuth.instance.currentUser;
            if (currentUser != null) {
              Navigator.of(context).pushNamed("/profile", arguments: {
                "uid": currentUser.uid,
              });
            }
          },
        ),
      ),
      child: Stack(
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: SafeArea(
                child: StreamBuilder<QuerySnapshot>(
                  stream: chatsRef.snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return const Center(
                        child: Text("Erro ao carregar os chats"),
                      );
                    }

                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CupertinoActivityIndicator());
                    }

                    final docs = snapshot.data?.docs;
                    if (docs == null || docs.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              "Nenhum chat encontrado",
                              style: TextStyle(fontSize: 18),
                            ),
                            const SizedBox(height: 20),
                            CupertinoButton.filled(
                              onPressed: _showNewChatPopup,
                              child: const Text("Iniciar novo chat"),
                            ),
                          ],
                        ),
                      );
                    }

                    return CustomScrollView(
                      slivers: [
                        SliverList(
                          delegate: SliverChildBuilderDelegate(
                                (context, index) {
                              final doc = docs[index];
                              final chatId = doc.id;
                              final data = doc.data()! as Map<String, dynamic>;

                              return FutureBuilder(
                                future: _getChatDisplayName(data, currentUser.uid),
                                builder: (context, nameSnapshot) {
                                  final displayName = nameSnapshot.data ?? "Carregando...";

                                  final participants = List<String>.from(data["participants"] ?? []);
                                  final otherUserId = participants.firstWhere((id) => id != currentUser.uid, orElse: () => "");

                                  return FutureBuilder<User?>(
                                    future: fetchUserFromFirestore(otherUserId),
                                    builder: (context, userSnapshot) {
                                      final userData = userSnapshot.data;
                                      final profileUrl = userData?.profilePictureUrl;

                                      return CupertinoButton(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                                        onPressed: () {
                                          Navigator.of(context).pushNamed("/chat", arguments: {
                                            "chatId": chatId,
                                            "otherUserId": otherUserId,
                                          });
                                        },
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            ClipOval(
                                              child: profileUrl != null && profileUrl.isNotEmpty
                                                  ? Image.network(
                                                profileUrl,
                                                width: 48,
                                                height: 48,
                                                fit: BoxFit.cover,
                                              )
                                                  : Container(
                                                width: 48,
                                                height: 48,
                                                color: CupertinoColors.systemGrey5,
                                                child: const Icon(
                                                  CupertinoIcons.person,
                                                  size: 28,
                                                  color: CupertinoColors.systemGrey,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    displayName,
                                                    style: const TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 17,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    data["lastMessage"] ?? "",
                                                    style: const TextStyle(color: CupertinoColors.systemGrey),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ],
                                              ),
                                            ),
                                            if (data["updatedAt"] != null)
                                              Text(
                                                "${(data["updatedAt"] as Timestamp).toDate().hour.toString().padLeft(2, '0')}:${(data["updatedAt"] as Timestamp).toDate().minute.toString().padLeft(2, '0')}",
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: CupertinoColors.systemGrey,
                                                ),
                                              ),
                                          ],
                                        ),
                                      );
                                    },
                                  );
                                },
                              );
                            },
                            childCount: docs.length,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
          StreamBuilder<QuerySnapshot>(
            stream: chatsRef.snapshots(),
            builder: (context, snapshot) {
              final docs = snapshot.data?.docs;
              final bool hasChats = docs != null && docs.isNotEmpty;

              return AnimatedOpacity(
                opacity: hasChats ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: Align(
                  alignment: Alignment.bottomRight,
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: CupertinoButton.filled(
                      onPressed: _showNewChatPopup,
                      padding: const EdgeInsets.all(16.0),
                      borderRadius: BorderRadius.circular(30.0),
                      child: const Icon(CupertinoIcons.add),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
