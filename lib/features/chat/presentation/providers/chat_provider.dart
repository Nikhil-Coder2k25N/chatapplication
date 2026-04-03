import 'dart:async';
import 'package:chatapplication/features/chat/data/repositories/chat_repositories.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/errors/app_exceptions.dart';

final chatRepositoryProvider = Provider<ChatRepository>((ref) => ChatRepository());
final currentChatIdProvider = StateProvider<String?>((ref) => null);

final chatMessagesProvider = StreamProvider.family<QuerySnapshot<Map<String, dynamic>>, String>((ref, chatId) {
  final repository = ref.watch(chatRepositoryProvider);
  return repository.getMessages(chatId);
});

final userChatsProvider = StreamProvider.family<QuerySnapshot<Map<String, dynamic>>, String>((ref, userId) {
  final repository = ref.watch(chatRepositoryProvider);
  return repository.getUserChats(userId);
});

// IMPORTANT: This is a FutureProvider, NOT a StreamProvider
final searchUsersProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, searchQuery) async {
  final repository = ref.watch(chatRepositoryProvider);
  final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
  if (searchQuery.isEmpty) {
    return [];
  }
  final result = await repository.searchUsers(searchQuery, currentUserId).first;
  return result;
});

final chatStateNotifierProvider = StateNotifierProvider<ChatStateNotifier, ChatState>((ref) {
  final repository = ref.watch(chatRepositoryProvider);
  return ChatStateNotifier(repository: repository);
});

final selectedUserProvider = StateProvider<Map<String, dynamic>?>((ref) => null);

final sendMessageProvider = FutureProvider.family<void, SendMessageParams>((ref, params) async {
  final repository = ref.watch(chatRepositoryProvider);
  await repository.sendMessage(params.chatId, params.senderId, params.message);
});

final markMessageAsReadProvider = FutureProvider.family<void, MarkReadParams>((ref, params) async {
  final repository = ref.watch(chatRepositoryProvider);
  await repository.markMessageAsRead(params.chatId, params.messageId);
});

final userDetailsProvider = FutureProvider.family<Map<String, dynamic>?, String>((ref, userId) async {
  final repository = ref.watch(chatRepositoryProvider);
  return await repository.getUserDetails(userId);
});

class SendMessageParams {
  final String chatId;
  final String senderId;
  final String message;
  SendMessageParams({required this.chatId, required this.senderId, required this.message});
}

class MarkReadParams {
  final String chatId;
  final String messageId;
  MarkReadParams({required this.chatId, required this.messageId});
}

class ChatState {
  final bool isLoading;
  final bool isSending;
  final String? error;
  final List<ChatUser>? users;
  final Map<String, bool> typingStatus;
  ChatState({
    this.isLoading = false,
    this.isSending = false,
    this.error,
    this.users,
    this.typingStatus = const {},
  });
  ChatState copyWith({bool? isLoading, bool? isSending, String? error, List<ChatUser>? users, Map<String, bool>? typingStatus}) {
    return ChatState(
      isLoading: isLoading ?? this.isLoading,
      isSending: isSending ?? this.isSending,
      error: error ?? this.error,
      users: users ?? this.users,
      typingStatus: typingStatus ?? this.typingStatus,
    );
  }
}

class ChatUser {
  final String uid;
  final String displayName;
  final String? email;
  final String? photoURL;
  final bool isOnline;
  final DateTime? lastSeen;
  ChatUser({
    required this.uid,
    required this.displayName,
    this.email,
    this.photoURL,
    this.isOnline = false,
    this.lastSeen,
  });
  factory ChatUser.fromMap(Map<String, dynamic> map) {
    return ChatUser(
      uid: map['uid'] ?? '',
      displayName: map['displayName'] ?? 'Unknown User',
      email: map['email'],
      photoURL: map['photoURL'],
      isOnline: map['isOnline'] ?? false,
      lastSeen: map['lastSeen'] != null ? (map['lastSeen'] as Timestamp).toDate() : null,
    );
  }
}

class ChatStateNotifier extends StateNotifier<ChatState> {
  final ChatRepository _repository;
  ChatStateNotifier({required ChatRepository repository}) : _repository = repository, super(ChatState());

  Future<void> loadUsers(String searchQuery, String currentUserId) async {
    if (searchQuery.isEmpty) {
      state = state.copyWith(users: []);
      return;
    }
    state = state.copyWith(isLoading: true, error: null);
    try {
      final usersData = await _repository.searchUsers(searchQuery, currentUserId).first;
      final users = usersData.map((data) => ChatUser.fromMap(data)).toList();
      state = state.copyWith(users: users, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Failed to load users: ${e.toString()}');
    }
  }

  @override
  void dispose() {
    super.dispose();
  }
}

final typingIndicatorProvider = Provider<TypingIndicator>((ref) => TypingIndicator(ref: ref));

class TypingIndicator {
  final Ref _ref;
  Timer? _timer;
  bool _isTyping = false;
  TypingIndicator({required Ref ref}) : _ref = ref;
  void userIsTyping(String chatId, String userId) {
    if (_isTyping) return;
    _isTyping = true;
    final chatDocRef = FirebaseFirestore.instance.collection('chats').doc(chatId);
    chatDocRef.update({'typingUsers.$userId': true});
    _timer?.cancel();
    _timer = Timer(const Duration(seconds: 2), () => userStoppedTyping(chatId, userId));
  }
  void userStoppedTyping(String chatId, String userId) {
    _isTyping = false;
    final chatDocRef = FirebaseFirestore.instance.collection('chats').doc(chatId);
    chatDocRef.update({'typingUsers.$userId': FieldValue.delete()});
  }
  void dispose() => _timer?.cancel();
}

final chatActionsProvider = Provider<ChatActions>((ref) => ChatActions(ref: ref));

class ChatActions {
  final Ref _ref;
  ChatActions({required Ref ref}) : _ref = ref;
  Future<void> deleteMessage(String chatId, String messageId) async {
    try {
      await FirebaseFirestore.instance.collection('chats').doc(chatId).collection('messages').doc(messageId).delete();
    } catch (e) {
      throw ChatException(message: 'Failed to delete message: ${e.toString()}', code: 'DELETE_FAILED');
    }
  }
  Future<void> editMessage(String chatId, String messageId, String newText) async {
    try {
      await FirebaseFirestore.instance.collection('chats').doc(chatId).collection('messages').doc(messageId).update({
        'text': newText,
        'editedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw ChatException(message: 'Failed to edit message: ${e.toString()}', code: 'EDIT_FAILED');
    }
  }
}