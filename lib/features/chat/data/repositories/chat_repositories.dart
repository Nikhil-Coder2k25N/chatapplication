import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/errors/app_exceptions.dart';

class ChatRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _uuid = const Uuid();

  String getChatId(String uid1, String uid2) {
    final sorted = [uid1, uid2]..sort();
    return '${sorted[0]}_${sorted[1]}';
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getMessages(String chatId) {
    if (chatId.isEmpty) {
      throw const ChatException(message: 'Chat ID cannot be empty');
    }
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getUserChats(String userId) {
    return _firestore
        .collection('chats')
        .where('participants', arrayContains: userId)
        .snapshots();
  }

  Future<void> sendMessage(String chatId, String senderId, String text) async {
    if (chatId.isEmpty) {
      throw const ChatException(message: 'Chat ID cannot be empty');
    }
    if (senderId.isEmpty) {
      throw const ChatException(message: 'Sender ID cannot be empty');
    }

    final trimmedText = text.trim();
    if (trimmedText.isEmpty) {
      throw const ChatException(message: 'Message cannot be empty');
    }

    final chatDocRef = _firestore.collection('chats').doc(chatId);
    final msgCollectionRef = chatDocRef.collection('messages');
    final msgDocRef = msgCollectionRef.doc();

    try {
      await _firestore.runTransaction((transaction) async {
        final participants = chatId.split('_');
        final otherParticipant = participants.firstWhere(
              (id) => id != senderId,
          orElse: () => participants.first,
        );

        transaction.set(chatDocRef, {
          'participants': [senderId, otherParticipant],
          'lastMessage': trimmedText,
          'lastMessageTime': FieldValue.serverTimestamp(),
          'lastMessageSender': senderId,
          'type': 'direct',
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        transaction.set(msgDocRef, {
          'messageId': _uuid.v4(),
          'senderId': senderId,
          'text': trimmedText,
          'timestamp': FieldValue.serverTimestamp(),
          'isRead': false,
        });
      });
    } catch (e) {
      throw ChatException(
        message: 'Failed to send message: ${e.toString()}',
        code: 'SEND_MESSAGE_FAILED',
      );
    }
  }

  Future<void> markMessageAsRead(String chatId, String messageId) async {
    try {
      await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(messageId)
          .update({'isRead': true});
    } catch (e) {
      throw ChatException(
        message: 'Failed to mark message as read',
        code: 'MARK_READ_FAILED',
      );
    }
  }

  Future<Map<String, dynamic>?> getUserDetails(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        return doc.data();
      }
      return null;
    } catch (e) {
      throw ChatException(
        message: 'Failed to get user details',
        code: 'GET_USER_FAILED',
      );
    }
  }

  // Returns a Stream of List (not QuerySnapshot)
  Stream<List<Map<String, dynamic>>> searchUsers(String searchQuery, String currentUserId) async* {
    if (searchQuery.isEmpty) {
      yield [];
      return;
    }

    try {
      final snapshot = await _firestore
          .collection('users')
          .where('uid', isNotEqualTo: currentUserId)
          .limit(50)
          .get();

      final results = snapshot.docs
          .map((doc) => doc.data())
          .where((user) {
        final displayName = user['displayName'] ?? '';
        return displayName.toLowerCase().contains(searchQuery.toLowerCase());
      })
          .toList();

      yield results;
    } catch (e) {
      throw ChatException(
        message: 'Failed to search users: ${e.toString()}',
        code: 'SEARCH_FAILED',
      );
    }
  }
}