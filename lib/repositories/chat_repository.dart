import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/chat_message_model.dart';
import '../models/chat_thread_model.dart';
import '../services/firestore_service.dart';

class ChatRepository {
  final FirestoreService _firestoreService;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  ChatRepository(this._firestoreService);

  Stream<List<ChatMessageModel>> retrieveChatHistory(String uid1, String uid2) {
    return _firestoreService.streamChats(uid1, uid2);
  }

  Stream<List<ChatThreadModel>> watchFieldUserThreads(
    String companyId,
    String fieldUserId,
  ) {
    return _firestoreService.streamFieldUserChatThreads(companyId, fieldUserId);
  }

  Stream<List<ChatMessageModel>> watchThreadMessages(String chatId) {
    return _firestoreService.streamChatMessages(chatId);
  }

  Future<void> ensureThread(ChatThreadModel thread) async {
    await _firestoreService.ensureChatThread(thread);
  }

  Future<void> sendChatMessage(ChatMessageModel message) async {
    await _firestoreService.saveChatMessage(message);
  }

  Future<void> updateThreadAfterMessage({
    required String chatId,
    required String companyId,
    required String lastMessage,
    required String lastSenderId,
    required String fieldUserId,
    required String supplierId,
    String? fieldUserName,
  }) async {
    await _firestoreService.updateChatThreadAfterMessage(
      chatId: chatId,
      companyId: companyId,
      lastMessage: lastMessage,
      lastSenderId: lastSenderId,
      fieldUserId: fieldUserId,
      supplierId: supplierId,
      fieldUserName: fieldUserName,
    );
  }

  Future<void> markThreadReadForFieldUser(String chatId) async {
    await _firestoreService.markChatThreadReadForFieldUser(chatId);
  }

  Stream<List<ChatThreadModel>> watchSupplierThreads(String supplierId) {
    return _firestoreService.streamSupplierChatThreads(supplierId);
  }

  Future<void> markThreadReadForSupplier(String chatId) async {
    await _firestoreService.markChatThreadReadForSupplier(chatId);
  }

  Future<void> markMessagesRead(String chatId, String currentUserId) async {
    await _firestoreService.markChatMessagesRead(chatId, currentUserId);
  }

  /// Soft-delete message for current user
  Future<void> hideMessageForUser(String chatId, String messageId, String userId) async {
    await _db
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageId)
        .update({
      'hiddenBy': FieldValue.arrayUnion([userId]),
    });
  }

  /// Bulk soft-delete messages for current user
  Future<void> hideMessagesForUser(String chatId, List<String> messageIds, String userId) async {
    final batch = _db.batch();
    for (final id in messageIds) {
      batch.update(
        _db.collection('chats').doc(chatId).collection('messages').doc(id),
        {'hiddenBy': FieldValue.arrayUnion([userId])},
      );
    }
    await batch.commit();
  }

  /// Delete message for everyone (WhatsApp style)
  Future<void> deleteMessageForEveryone(String chatId, String messageId) async {
    await _db
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageId)
        .update({
      'isDeletedForEveryone': true,
      'text': 'This message was deleted',
      'attachmentUrl': null,
    });
  }

  /// Bulk delete messages for everyone
  Future<void> deleteMessagesForEveryone(String chatId, List<String> messageIds) async {
    final batch = _db.batch();
    for (final id in messageIds) {
      batch.update(
        _db.collection('chats').doc(chatId).collection('messages').doc(id),
        {
          'isDeletedForEveryone': true,
          'text': 'This message was deleted',
          'attachmentUrl': null,
        },
      );
    }
    await batch.commit();
  }

  /// Clear entire chat for current user (hides the thread from list)
  Future<void> hideThreadForUser(String chatId, String userId) async {
    await _db.collection('chats').doc(chatId).update({
      'hiddenBy': FieldValue.arrayUnion([userId]),
    });
  }
}
