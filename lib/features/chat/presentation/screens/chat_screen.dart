import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/chat_provider.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String chatId;
  const ChatScreen({super.key, required this.chatId});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  late final TextEditingController _messageController;
  late final ScrollController _scrollController;
  late final FocusNode _focusNode;
  String _currentUserId = '';

  @override
  void initState() {
    super.initState();
    _messageController = TextEditingController();
    _scrollController = ScrollController();
    _focusNode = FocusNode();
    _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(currentChatIdProvider.notifier).state = widget.chatId;
      }
    });

    _focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (!mounted) return;
    final typingIndicator = ref.read(typingIndicatorProvider);
    if (_focusNode.hasFocus) {
      typingIndicator.userIsTyping(widget.chatId, _currentUserId);
    } else {
      typingIndicator.userStoppedTyping(widget.chatId, _currentUserId);
    }
  }

  void _sendMessage() async {
    final text = _messageController.text;
    if (text.trim().isEmpty) return;

    final params = SendMessageParams(
      chatId: widget.chatId,
      senderId: _currentUserId,
      message: text,
    );

    _messageController.clear();

    try {
      await ref.read(sendMessageProvider(params).future);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scrollController.hasClients) {
          _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send message: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUserId.isEmpty) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final messagesAsync = ref.watch(chatMessagesProvider(widget.chatId));
    final typingStatus = ref.watch(chatStateNotifierProvider).typingStatus;

    return Scaffold(
      appBar: AppBar(
        title: _buildAppBarTitle(),
        centerTitle: false,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: Colors.grey[800]),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: messagesAsync.when(
              data: (snapshot) {
                final messages = snapshot.docs;
                if (messages.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_outlined, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('No messages yet', style: TextStyle(color: Colors.grey)),
                        Text('Send a message to start the conversation',
                            style: TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  reverse: true,
                  controller: _scrollController,
                  padding: const EdgeInsets.all(12),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final messageData = message.data();
                    final isMe = messageData['senderId'] == _currentUserId;
                    return MessageBubble(
                      messageId: message.id,
                      text: messageData['text'] ?? '',
                      isMe: isMe,
                      timestamp: messageData['timestamp'] as Timestamp?,
                      isRead: messageData['isRead'] ?? false,
                      chatId: widget.chatId,
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
                      onPressed: () => ref.invalidate(chatMessagesProvider(widget.chatId)),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (typingStatus.values.any((isTyping) => isTyping))
            _buildTypingIndicator(),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildAppBarTitle() {
    final otherUserId = widget.chatId.split('_').firstWhere(
          (id) => id != _currentUserId,
      orElse: () => widget.chatId.split('_').first,
    );

    final userDetails = ref.watch(userDetailsProvider(otherUserId));

    return userDetails.when(
      data: (user) {
        final displayName = user?['displayName'] ?? 'Chat';
        final isOnline = user?['isOnline'] ?? false;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(displayName),
            if (isOnline)
              const Text('Online', style: TextStyle(fontSize: 12, color: Colors.green)),
          ],
        );
      },
      loading: () => const Text('Loading...'),
      error: (_, __) => const Text('Chat'),
    );
  }

  Widget _buildTypingIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: const Row(
        children: [
          SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
          SizedBox(width: 8),
          Text('Someone is typing...', style: TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(top: BorderSide(color: Colors.grey[800]!)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              focusNode: _focusNode,
              decoration: InputDecoration(
                hintText: 'Type a message...',
                filled: true,
                fillColor: Colors.grey[900],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              maxLines: null,
              textInputAction: TextInputAction.send,
              onChanged: (text) {
                if (text.isNotEmpty && mounted) {
                  ref.read(typingIndicatorProvider)
                      .userIsTyping(widget.chatId, _currentUserId);
                }
              },
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            backgroundColor: const Color(0xFF6C63FF),
            child: IconButton(
              icon: const Icon(Icons.send, color: Colors.white),
              onPressed: _sendMessage,
              tooltip: 'Send message',
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}

class MessageBubble extends ConsumerWidget {
  final String messageId;
  final String text;
  final bool isMe;
  final Timestamp? timestamp;
  final bool isRead;
  final String chatId;

  const MessageBubble({
    super.key,
    required this.messageId,
    required this.text,
    required this.isMe,
    this.timestamp,
    required this.isRead,
    required this.chatId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onLongPress: () => _showMessageOptions(ref),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          decoration: BoxDecoration(
            color: isMe ? const Color(0xFF6C63FF) : Colors.grey[800],
            borderRadius: BorderRadius.circular(16).copyWith(
              bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(16),
              bottomLeft: !isMe ? const Radius.circular(4) : const Radius.circular(16),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(text, style: const TextStyle(color: Colors.white)),
              if (timestamp != null) ...[
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _formatTime(timestamp!.toDate()),
                      style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.7)),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 4),
                      Icon(
                        isRead ? Icons.done_all : Icons.done,
                        size: 12,
                        color: Colors.white.withOpacity(0.7),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showMessageOptions(WidgetRef ref) {
    final actions = ref.read(chatActionsProvider);
    showModalBottomSheet(
      context: ref.context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isMe) ...[
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Edit'),
                onTap: () {
                  Navigator.pop(context);
                  _editMessage(ref);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete),
                title: const Text('Delete'),
                onTap: () {
                  Navigator.pop(context);
                  actions.deleteMessage(chatId, messageId);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _editMessage(WidgetRef ref) {
    final controller = TextEditingController(text: text);
    showDialog(
      context: ref.context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Message'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Edit your message...'),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final newText = controller.text.trim();
              if (newText.isNotEmpty && newText != text) {
                ref.read(chatActionsProvider).editMessage(chatId, messageId, newText);
              }
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);
    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inHours < 1) return '${difference.inMinutes}m ago';
    if (difference.inDays < 1) return '${difference.inHours}h ago';
    return '${difference.inDays}d ago';
  }
}