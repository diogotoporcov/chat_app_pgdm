import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:intl/intl.dart';

import '../models/message.dart';
import '../services/chat_service.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final String? otherUserId; // novo campo

  const ChatScreen({super.key, required this.chatId, this.otherUserId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ChatService _chatService = ChatService();
  final TextEditingController _messageController = TextEditingController();
  final fb.User? currentUser = fb.FirebaseAuth.instance.currentUser;
  final ScrollController _scrollController = ScrollController();
  final FocusNode _messageFocusNode = FocusNode();

  Message? _replyingToMessage;
  final Map<String, GlobalKey> _messageKeys = {};

  void _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || currentUser == null) return;

    await _chatService.sendMessage(
      senderId: currentUser!.uid,
      text: text,
      chatId: widget.chatId,
      participantsForChatCreation: [],
      replyToMessageId: _replyingToMessage?.id,
    );

    setState(() {
      _messageController.clear();
      _replyingToMessage = null;
    });

    _messageFocusNode.requestFocus();

    Future.delayed(Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _scrollToMessage(String messageId) {
    final key = _messageKeys[messageId];
    if (key != null && key.currentContext != null) {
      Scrollable.ensureVisible(
        key.currentContext!,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
        alignment: 0.3,
      );
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _messageFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text("Conversa"),
        trailing: widget.otherUserId != null
            ? CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () {
            Navigator.of(context).pushNamed('/profile', arguments: {'uid': widget.otherUserId});
          },
          child: const Icon(CupertinoIcons.person),
        )
            : null,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: StreamBuilder<List<Message>>(
                    stream: _chatService.getMessages(widget.chatId),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return const Center(child: Text("Erro ao carregar mensagens"));
                      }
                      if (!snapshot.hasData) {
                        return const Center(child: CupertinoActivityIndicator());
                      }

                      final messages = snapshot.data!;

                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (_scrollController.hasClients) {
                          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
                        }
                      });

                      return ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(12),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final msg = messages[index];
                          final isMine = msg.senderId == currentUser?.uid;
                          final replyTo = msg.replyToMessageId != null
                              ? messages.firstWhere(
                                (m) => m.id == msg.replyToMessageId,
                            orElse: () => Message(
                              id: '',
                              senderId: '',
                              text: '[Mensagem não encontrada]',
                              sentAt: DateTime.now(),
                              readBy: [],
                            ),
                          )
                              : null;

                          final msgKey = _messageKeys.putIfAbsent(msg.id, () => GlobalKey());

                          double dragOffset = 0.0;

                          return StatefulBuilder(
                            key: msgKey,
                            builder: (context, setDragState) {
                              return GestureDetector(
                                onLongPress: isMine
                                    ? () {
                                  showCupertinoDialog(
                                    context: context,
                                    builder: (context) => CupertinoAlertDialog(
                                      title: const Text("Mensagem"),
                                      content: const Text("Deseja apagar esta mensagem?"),
                                      actions: [
                                        CupertinoDialogAction(
                                          onPressed: () => Navigator.of(context).pop(),
                                          child: const Text("Cancelar"),
                                        ),
                                        CupertinoDialogAction(
                                          isDestructiveAction: true,
                                          onPressed: () async {
                                            Navigator.of(context).pop();
                                            await FirebaseFirestore.instance
                                                .collection("messages")
                                                .doc(widget.chatId)
                                                .collection("messages")
                                                .doc(msg.id)
                                                .delete();
                                          },
                                          child: const Text("Apagar"),
                                        ),
                                      ],
                                    ),
                                  );
                                }
                                    : null,
                                onHorizontalDragUpdate: (details) {
                                  if (details.delta.dx > 0) {
                                    setDragState(() {
                                      dragOffset += details.delta.dx;
                                      dragOffset = dragOffset.clamp(0, 80);
                                    });
                                  }
                                },
                                onHorizontalDragEnd: (_) {
                                  if (dragOffset > 50) {
                                    setState(() {
                                      _replyingToMessage = msg;
                                    });
                                  }
                                  setDragState(() {
                                    dragOffset = 0.0;
                                  });
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 100),
                                  transform: Matrix4.translationValues(dragOffset, 0, 0),
                                  child: Align(
                                    alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
                                    child: ConstrainedBox(
                                      constraints: BoxConstraints(
                                        maxWidth: MediaQuery.of(context).size.width * 0.6,
                                      ),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        margin: const EdgeInsets.symmetric(vertical: 4),
                                        decoration: BoxDecoration(
                                          color: isMine
                                              ? CupertinoColors.systemBlue
                                              : CupertinoColors.systemGrey5,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            if (replyTo != null && replyTo.id.isNotEmpty)
                                              MouseRegion(
                                                cursor: SystemMouseCursors.click,
                                                child: GestureDetector(
                                                  behavior: HitTestBehavior.opaque,  // <- Importante para pegar clique em áreas vazias também
                                                  onTap: () => _scrollToMessage(replyTo.id),
                                                  child: Container(
                                                    padding: const EdgeInsets.symmetric(vertical: 4),
                                                    margin: const EdgeInsets.only(bottom: 4),
                                                    decoration: BoxDecoration(
                                                      border: Border(
                                                        left: BorderSide(
                                                          color: isMine
                                                              ? CupertinoColors.white
                                                              : CupertinoColors.systemGrey,
                                                          width: 3,
                                                        ),
                                                      ),
                                                    ),
                                                    child: Padding(
                                                      padding: const EdgeInsets.only(left: 8),
                                                      child: Text(
                                                        replyTo.text,
                                                        maxLines: 2,
                                                        overflow: TextOverflow.ellipsis,
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          fontStyle: FontStyle.italic,
                                                          color: isMine
                                                              ? CupertinoColors.white.withValues(alpha: 0.8)
                                                              : CupertinoColors.black.withValues(alpha: 0.6),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            Text(
                                              msg.text,
                                              style: TextStyle(
                                                color: isMine
                                                    ? CupertinoColors.white
                                                    : CupertinoColors.black,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              DateFormat("HH:mm").format(msg.sentAt),
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: isMine
                                                    ? CupertinoColors.white.withAlpha(180)
                                                    : CupertinoColors.systemGrey,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
                const Divider(height: 1),
                if (_replyingToMessage != null)
                  Container(
                    color: CupertinoColors.systemGrey6,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _scrollToMessage(_replyingToMessage!.id),
                            child: Text(
                              'Respondendo: ${_replyingToMessage!.text}',
                              style: const TextStyle(
                                fontStyle: FontStyle.italic,
                                color: CupertinoColors.systemGrey,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 2,
                            ),
                          ),
                        ),
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          onPressed: () {
                            setState(() {
                              _replyingToMessage = null;
                            });
                          },
                          child: const Icon(CupertinoIcons.clear_thick_circled, size: 20),
                        ),
                      ],
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: CupertinoTextField(
                          controller: _messageController,
                          placeholder: "Digite sua mensagem",
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          onSubmitted: (_) => _sendMessage(),
                          focusNode: _messageFocusNode,
                        ),
                      ),
                      const SizedBox(width: 8),
                      CupertinoButton(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        onPressed: _sendMessage,
                        child: const Icon(CupertinoIcons.arrow_up_circle_fill),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
