import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import '../providers/chat_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import 'new_chat_screen.dart';

class ChatListScreen extends ConsumerWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = FirebaseAuth.instance.currentUser?.uid;

    if (userId == null) {
      return const Scaffold(
        body: Center(child: Text('User not logged in')),
      );
    }

    final chatsAsync = ref.watch(userChatsProvider(userId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chats'),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ref.read(authStateProvider.notifier).signOut();
              if (context.mounted) {
                context.go('/login');
              }
            },
            tooltip: 'Sign out',
          ),
        ],
      ),
      body: chatsAsync.when(
        data: (snapshot) {
          final chats = snapshot.docs;

          // Sort chats manually by lastMessageTime (newest first)
          final sortedChats = List.from(chats);
          sortedChats.sort((a, b) {
            final aTime = a.data()['lastMessageTime'] as Timestamp?;
            final bTime = b.data()['lastMessageTime'] as Timestamp?;

            if (aTime == null && bTime == null) return 0;
            if (aTime == null) return 1;
            if (bTime == null) return -1;

            return bTime.toDate().compareTo(aTime.toDate());
          });

          if (sortedChats.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.chat_outlined,
                    size: 64,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No chats yet',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap the + button to start a new chat',
                    style: TextStyle(
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: sortedChats.length,
            itemBuilder: (context, index) {
              final chat = sortedChats[index];
              final chatId = chat.id;
              final chatData = chat.data();
              final lastMessage = chatData['lastMessage'] ?? 'No messages';
              final lastMessageTime = chatData['lastMessageTime'] as Timestamp?;
              final participants = List<String>.from(chatData['participants'] ?? []);
              final otherParticipantId = participants.firstWhere(
                    (id) => id != userId,
                orElse: () => participants.first,
              );

              return _ChatListItem(
                chatId: chatId,
                otherParticipantId: otherParticipantId,
                lastMessage: lastMessage,
                lastMessageTime: lastMessageTime,
                currentUserId: userId,
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error: ${error.toString()}'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(userChatsProvider(userId)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const NewChatScreen(),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _ChatListItem extends ConsumerWidget {
  final String chatId;
  final String otherParticipantId;
  final String lastMessage;
  final Timestamp? lastMessageTime;
  final String currentUserId;

  const _ChatListItem({
    required this.chatId,
    required this.otherParticipantId,
    required this.lastMessage,
    required this.lastMessageTime,
    required this.currentUserId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userDetails = ref.watch(userDetailsProvider(otherParticipantId));

    return userDetails.when(
      data: (user) {
        final displayName = user?['displayName'] ?? 'Unknown User';
        final photoURL = user?['photoURL'];
        final isOnline = user?['isOnline'] ?? false;

        return ListTile(
          leading: Stack(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundImage: photoURL != null ? NetworkImage(photoURL) : null,
                child: photoURL == null ? const Icon(Icons.person, size: 28) : null,
              ),
              if (isOnline)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: const BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
          title: Text(
            displayName,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            lastMessage,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: lastMessageTime != null
              ? Text(
            _formatTime(lastMessageTime!.toDate()),
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          )
              : null,
          onTap: () => context.push('/chat/$chatId'),
        );
      },
      loading: () => const ListTile(
        leading: CircleAvatar(child: CircularProgressIndicator()),
        title: Text('Loading...'),
      ),
      error: (_, __) => ListTile(
        leading: const CircleAvatar(child: Icon(Icons.error)),
        title: const Text('Unknown User'),
        subtitle: Text(lastMessage),
        onTap: () => context.push('/chat/$chatId'),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}