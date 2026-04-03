import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../data/repositories/auth_repository.dart';
import '../../../../core/errors/app_exceptions.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) => AuthRepository());

final authStateProvider = AsyncNotifierProvider<AuthStateNotifier, User?>(() => AuthStateNotifier());

class AuthStateNotifier extends AsyncNotifier<User?> {
  StreamSubscription<User?>? _authSubscription;

  @override
  Future<User?> build() async {
    final user = ref.read(authRepositoryProvider).currentUser;
    _listenToAuthChanges();
    return user;
  }

  void _listenToAuthChanges() {
    _authSubscription = ref.read(authRepositoryProvider).authStateChanges.listen((user) {
      state = AsyncData(user);
    });
  }

  Future<void> signInWithGoogle() async {
    state = const AsyncLoading();
    try {
      final result = await ref.read(authRepositoryProvider).signInWithGoogle();
      state = AsyncData(result.user);
    } on AppException catch (e) {
      state = AsyncError(e, StackTrace.current);
    } catch (e) {
      state = AsyncError(AuthException(message: e.toString()), StackTrace.current);
    }
  }

  Future<void> signOut() async {
    try {
      await ref.read(authRepositoryProvider).signOut();
      state = const AsyncData(null);
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
  }
}