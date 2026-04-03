import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.chat_bubble_rounded,
                size: 80,
                color: Color(0xFF6C63FF),
              ),
              const SizedBox(height: 24),
              const Text(
                'Secure Chat',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Sign in with Google to start chatting securely.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 40),
              authState.when(
                loading: () => const CircularProgressIndicator(),
                error: (error, _) => Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        error.toString(),
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _googleSignInButton(ref),
                  ],
                ),
                data: (_) => _googleSignInButton(ref),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _googleSignInButton(WidgetRef ref) {
    return ElevatedButton.icon(
      onPressed: () => ref.read(authStateProvider.notifier).signInWithGoogle(),
      icon: const Icon(Icons.login),
      label: const Text(
        'Continue with Google',
        style: TextStyle(fontSize: 16),
      ),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        minimumSize: const Size(200, 48),
      ),
    );
  }
}