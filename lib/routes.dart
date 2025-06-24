import 'package:chat_app_pgdm/screens/chat_screen.dart';
import 'package:chat_app_pgdm/screens/profile_screen.dart';
import 'package:flutter/cupertino.dart';

import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/home_screen.dart';

final Map<String, WidgetBuilder> appRoutes = {
  "/login": (context) => const LoginScreen(),
  "/register": (context) => const RegisterScreen(),
  "/home": (context) => const HomeScreen(),
  "/chat": (context) {
    final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    final chatId = args["chatId"] as String;
    final otherUserId = args["otherUserId"] as String?;
    return ChatScreen(chatId: chatId, otherUserId: otherUserId);
  },
  "/profile": (context) {
    final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    final uid = args["uid"] as String;
    return ProfileScreen(uid: uid);
  },
};
