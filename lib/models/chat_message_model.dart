// Pure Dart Model
import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessageModel {
  final String id;
  final String? chatId;
  final String? companyId;
  final String senderId;
  final String senderName;
  final String receiverId;
  final String content;
  final DateTime timestamp;
  final String? attachmentUrl;
  final bool isRead;
  final List<String> hiddenBy;
  final bool isDeletedForEveryone;

  ChatMessageModel({
    required this.id,
    this.chatId,
    this.companyId,
    required this.senderId,
    required this.senderName,
    required this.receiverId,
    required this.content,
    required this.timestamp,
    this.attachmentUrl,
    this.isRead = false,
    this.hiddenBy = const [],
    this.isDeletedForEveryone = false,
  });

  ChatMessageModel copyWith({
    String? id,
    String? chatId,
    String? companyId,
    String? senderId,
    String? senderName,
    String? receiverId,
    String? content,
    DateTime? timestamp,
    String? attachmentUrl,
    bool? isRead,
    List<String>? hiddenBy,
    bool? isDeletedForEveryone,
  }) {
    return ChatMessageModel(
      id: id ?? this.id,
      chatId: chatId ?? this.chatId,
      companyId: companyId ?? this.companyId,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      receiverId: receiverId ?? this.receiverId,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      attachmentUrl: attachmentUrl ?? this.attachmentUrl,
      isRead: isRead ?? this.isRead,
      hiddenBy: hiddenBy ?? this.hiddenBy,
      isDeletedForEveryone: isDeletedForEveryone ?? this.isDeletedForEveryone,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'text': content,
      if (senderName.isNotEmpty) 'senderName': senderName,
      if (receiverId.isNotEmpty) 'receiverId': receiverId,
      if (companyId != null) 'companyId': companyId,
      'timestamp': FieldValue.serverTimestamp(),
      'isRead': isRead,
      if (attachmentUrl != null) 'attachmentUrl': attachmentUrl,
      'hiddenBy': hiddenBy,
      'isDeletedForEveryone': isDeletedForEveryone,
    };
  }

  factory ChatMessageModel.fromMap(Map<String, dynamic> map) {
    return ChatMessageModel(
      id: map['id'] as String? ?? '',
      chatId: map['chatId'] as String?,
      companyId: map['companyId'] as String?,
      senderId: map['senderId'] as String? ?? '',
      senderName: map['senderName'] as String? ?? '',
      receiverId: map['receiverId'] as String? ?? '',
      content: (map['text'] as String?) ?? (map['content'] as String?) ?? '',
      timestamp: _parseTimestamp(map['timestamp']),
      attachmentUrl: map['attachmentUrl'] as String?,
      isRead: map['isRead'] as bool? ?? false,
      hiddenBy: List<String>.from(map['hiddenBy'] ?? []),
      isDeletedForEveryone: map['isDeletedForEveryone'] as bool? ?? false,
    );
  }

  static DateTime _parseTimestamp(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.now();
    }
    return DateTime.now();
  }
}
