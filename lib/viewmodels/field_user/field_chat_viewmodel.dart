import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/chat_message_model.dart';
import '../../models/chat_thread_model.dart';
import '../../repositories/chat_repository.dart';
import '../../services/notification_service.dart';
import '../../utils/chat_id_utils.dart';
import '../../utils/chat_image_utils.dart';

/// Chat list and thread messaging for field users.
class FieldChatViewModel extends ChangeNotifier {
  final ChatRepository _chatRepo;
  final NotificationService _notificationService;

  bool _isLoadingThreads = false;
  bool _isLoadingMessages = false;
  bool _isSending = false;
  String? _errorMessage;
  List<ChatThreadModel> _threads = [];
  List<ChatMessageModel> _messages = [];
  String? _activeChatId;

  StreamSubscription<List<ChatThreadModel>>? _threadsSubscription;
  StreamSubscription<List<ChatMessageModel>>? _messagesSubscription;

  FieldChatViewModel(this._chatRepo, this._notificationService);

  bool get isLoadingThreads => _isLoadingThreads;
  bool get isLoadingMessages => _isLoadingMessages;
  bool get isSending => _isSending;
  String? get errorMessage => _errorMessage;
  List<ChatThreadModel> get threads => _threads;
  List<ChatMessageModel> get messages => _messages;
  int get unreadMessageCount =>
      _threads.fold(0, (total, thread) => total + thread.unreadFieldUser);

  static String chatIdFor({
    required String companyId,
    required String fieldUserId,
    required String supplierId,
  }) =>
      ChatIdUtils.buildChatId(
        companyId: companyId,
        fieldUserId: fieldUserId,
        supplierId: supplierId,
      );

  void watchConversations(String companyId, String fieldUserId) {
    _threadsSubscription?.cancel();
    _isLoadingThreads = true;
    _errorMessage = null;
    notifyListeners();

    _threadsSubscription =
        _chatRepo.watchFieldUserThreads(companyId, fieldUserId).listen(
      (data) {
        _threads = data.where((t) => !t.hiddenBy.contains(fieldUserId)).toList();
        _isLoadingThreads = false;
        notifyListeners();
      },
      onError: (e) {
        _errorMessage = e.toString();
        _isLoadingThreads = false;
        notifyListeners();
      },
    );
  }

  Future<void> startListening(
    String chatId, {
    required String currentUserId,
  }) async {
    if (_activeChatId == chatId && _messagesSubscription != null) return;

    _messagesSubscription?.cancel();
    _activeChatId = chatId;
    _isLoadingMessages = true;
    _messages = [];
    _errorMessage = null;
    notifyListeners();

    await _chatRepo.markMessagesRead(chatId, currentUserId);
    await _chatRepo.markThreadReadForFieldUser(chatId);

    _messagesSubscription = _chatRepo.watchThreadMessages(chatId).listen(
      (data) {
        _messages = data.where((m) => !m.hiddenBy.contains(currentUserId)).toList();
        _isLoadingMessages = false;
        notifyListeners();
      },
      onError: (e) {
        _errorMessage = e.toString();
        _isLoadingMessages = false;
        notifyListeners();
      },
    );
  }

  Future<void> openThread({
    required String companyId,
    required String fieldUserId,
    required String fieldUserName,
    required String supplierId,
    required String supplierName,
  }) async {
    final chatId = chatIdFor(
      companyId: companyId,
      fieldUserId: fieldUserId,
      supplierId: supplierId,
    );

    await _chatRepo.ensureThread(
      ChatThreadModel(
        chatId: chatId,
        companyId: companyId,
        fieldUserId: fieldUserId,
        supplierId: supplierId,
        supplierName: supplierName,
        fieldUserName: fieldUserName,
        lastMessage: '',
        lastMessageAt: DateTime.now(),
      ),
    );

    await startListening(chatId, currentUserId: fieldUserId);
  }

  Future<bool> sendMessage({
    required String companyId,
    required String fieldUserId,
    required String fieldUserName,
    required String supplierId,
    required String supplierName,
    String content = '',
    String? attachmentUrl,
  }) async {
    final trimmed = content.trim();
    final hasImage = attachmentUrl != null && attachmentUrl.isNotEmpty;
    if (trimmed.isEmpty && !hasImage) return false;

    final chatId = chatIdFor(
      companyId: companyId,
      fieldUserId: fieldUserId,
      supplierId: supplierId,
    );
    final preview = ChatImageUtils.threadPreview(
      text: trimmed,
      hasImage: hasImage,
    );

    _isSending = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _chatRepo.ensureThread(
        ChatThreadModel(
          chatId: chatId,
          companyId: companyId,
          fieldUserId: fieldUserId,
          supplierId: supplierId,
          supplierName: supplierName,
          fieldUserName: fieldUserName,
          lastMessage: preview,
          lastMessageAt: DateTime.now(),
          lastSenderId: fieldUserId,
        ),
      );

      final message = ChatMessageModel(
        id: '',
        chatId: chatId,
        companyId: companyId,
        senderId: fieldUserId,
        senderName: fieldUserName,
        receiverId: supplierId,
        content: trimmed,
        timestamp: DateTime.now(),
        attachmentUrl: attachmentUrl,
        isRead: false,
      );

      await _chatRepo.sendChatMessage(message);
      await _chatRepo.updateThreadAfterMessage(
        chatId: chatId,
        companyId: companyId,
        lastMessage: preview,
        lastSenderId: fieldUserId,
        fieldUserId: fieldUserId,
        supplierId: supplierId,
        fieldUserName: fieldUserName,
      );

      await _notificationService.notifyChatMessage(
        recipientUserId: supplierId,
        senderName: fieldUserName,
        preview: preview,
        chatId: chatId,
        companyId: companyId,
        fieldUserId: fieldUserId,
        fieldUserName: fieldUserName,
        supplierId: supplierId,
        supplierName: supplierName,
      );

      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isSending = false;
      notifyListeners();
    }
  }

  /// "Delete for Me" - hides a single message from the current user's view.
  Future<void> deleteMessageForMe(String chatId, String messageId, String userId) async {
    try {
      await _chatRepo.hideMessageForUser(chatId, messageId, userId);
      _messages.removeWhere((m) => m.id == messageId);
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// WhatsApp-style: Delete for everyone.
  Future<void> deleteMessageForEveryone(String chatId, String messageId) async {
    try {
      await _chatRepo.deleteMessageForEveryone(chatId, messageId);
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// "Delete for Me" - hides multiple messages.
  Future<void> deleteMessagesForMe(String chatId, List<String> messageIds, String userId) async {
    try {
      await _chatRepo.hideMessagesForUser(chatId, messageIds, userId);
      _messages.removeWhere((m) => messageIds.contains(m.id));
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Bulk WhatsApp-style: Delete for everyone.
  Future<void> deleteMessagesForEveryone(String chatId, List<String> messageIds) async {
    try {
      await _chatRepo.deleteMessagesForEveryone(chatId, messageIds);
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// "Delete for Me" - hides the entire conversation thread from the list.
  Future<void> hideConversation(String chatId, String userId) async {
    try {
      await _chatRepo.hideThreadForUser(chatId, userId);
      _threads.removeWhere((t) => t.chatId == chatId);
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  void closeThread() {
    _messagesSubscription?.cancel();
    _messagesSubscription = null;
    _activeChatId = null;
    _messages = [];
  }

  @override
  void dispose() {
    _threadsSubscription?.cancel();
    _messagesSubscription?.cancel();
    super.dispose();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
