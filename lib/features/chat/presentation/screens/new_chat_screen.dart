import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import '../providers/chat_provider.dart';

class NewChatScreen extends ConsumerStatefulWidget {
  const NewChatScreen({super.key});

  @override
  ConsumerState<NewChatScreen> createState() => _NewChatScreenState();
}

class _NewChatScreenState extends ConsumerState<NewChatScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    if (currentUserId == null) {
      return const Scaffold(
        body: Center(child: Text('User not logged in')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('New Chat'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search users...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    setState(() {
                      _searchController.clear();
                      _searchQuery = '';
                    });
                  },
                )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                filled: true,
                fillColor: Colors.grey[900],
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
        ),
      ),
      body: _searchQuery.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search,
              size: 64,
              color: Colors.grey[600],
            ),
            const SizedBox(height: 16),
            Text(
              'Search for users to start chatting',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      )
          : Consumer(
        builder: (context, ref, child) {
          final searchResults = ref.watch(searchUsersProvider(_searchQuery));

          return searchResults.when(
            data: (users) {
              if (users.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.person_off, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('No users found'),
                    ],
                  ),
                );
              }

              return ListView.builder(
                itemCount: users.length,
                itemBuilder: (context, index) {
                  final user = users[index];
                  final userId = user['uid'];
                  final displayName = user['displayName'] ?? 'Unknown User';
                  final photoURL = user['photoURL'];
                  final isOnline = user['isOnline'] ?? false;
                  final chatRepository = ref.read(chatRepositoryProvider);

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage: photoURL != null ? NetworkImage(photoURL) : null,
                      child: photoURL == null ? const Icon(Icons.person) : null,
                    ),
                    title: Text(displayName),
                    subtitle: Text(isOnline ? 'Online' : 'Offline'),
                    trailing: const Icon(Icons.chat),
                    onTap: () {
                      final chatId = chatRepository.getChatId(currentUserId, userId);
                      // Use context.push with GoRouter instead of Navigator.pushNamed
                      context.push('/chat/$chatId');
                    },
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
                    onPressed: () => ref.invalidate(searchUsersProvider(_searchQuery)),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}