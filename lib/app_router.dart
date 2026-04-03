import 'package:chatapplication/features/auth/presentation/screens/login_screen.dart';
import 'package:chatapplication/features/chat/presentation/screens/chat_screen.dart';
import 'package:chatapplication/features/chat/presentation/screens/main_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/login',
    refreshListenable: GoRouterRefreshStream(
      FirebaseAuth.instance.authStateChanges(),
    ),
    redirect: (context, state) {
      final user = FirebaseAuth.instance.currentUser;
      final isLoggedIn = user != null;
      final isLoggingIn = state.matchedLocation == '/login';

      if (!isLoggedIn && !isLoggingIn) return '/login';
      if (isLoggedIn && isLoggingIn) return '/main';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: '/main',
        name: 'main',
        builder: (_, __) => const MainScreen(),
      ),
      GoRoute(
        path: '/chat/:chatId',
        name: 'chat',
        builder: (_, state) {
          final chatId = state.pathParameters['chatId'];
          if (chatId == null || chatId.isEmpty) {
            return const Scaffold(
              body: Center(child: Text('Invalid chat ID')),
            );
          }
          return ChatScreen(chatId: chatId);
        },
      ),
    ],
  );
}

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    stream.listen((_) => notifyListeners());
  }
}