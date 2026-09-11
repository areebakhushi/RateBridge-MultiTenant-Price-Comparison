import 'package:cloud_firestore/cloud_firestore.dart';

/// Conversation summary stored at `chats/{chatId}` with `isThread: true`.
class ChatThreadModel {
  final String chatId;
  final String companyId;
  final String fieldUserId;
  final String supplierId;
  final String supplierName;
  final String fieldUserName;
  final String lastMessage;
  final DateTime lastMessageAt;
  final String? lastSenderId;
  final int unreadFieldUser;
  final int unreadSupplier;
  final List<String> hiddenBy;

  ChatThreadModel({
    required this.chatId,
    required this.companyId,
    required this.fieldUserId,
    required this.supplierId,
    required this.supplierName,
    this.fieldUserName = '',
    required this.lastMessage,
    required this.lastMessageAt,
    this.lastSenderId,
    this.unreadFieldUser = 0,
    this.unreadSupplier = 0,
    this.hiddenBy = const [],
  });

  bool get hasUnreadForFieldUser => unreadFieldUser > 0;

  factory ChatThreadModel.fromMap(String id, Map<String, dynamic> map) {
    return ChatThreadModel(
      chatId: id,
      companyId: map['companyId'] ?? '',
      fieldUserId: map['fieldUserId'] ?? '',
      supplierId: map['supplierId'] ?? '',
      supplierName: map['supplierName'] ?? '',
      fieldUserName: map['fieldUserName'] ?? '',
      lastMessage: map['lastMessage'] ?? '',
      lastMessageAt: _parseDate(map['lastMessageAt']),
      lastSenderId: map['lastSenderId'] as String?,
      unreadFieldUser: (map['unreadFieldUser'] as num?)?.toInt() ?? 0,
      unreadSupplier: (map['unreadSupplier'] as num?)?.toInt() ?? 0,
      hiddenBy: List<String>.from(map['hiddenBy'] ?? []),
    );
  }

  Map<String, dynamic> toMap() => {
        'isThread': true,
        'chatId': chatId,
        'companyId': companyId,
        'fieldUserId': fieldUserId,
        'supplierId': supplierId,
        'supplierName': supplierName,
        if (fieldUserName.isNotEmpty) 'fieldUserName': fieldUserName,
        'lastMessage': lastMessage,
        'lastMessageAt': lastMessageAt, // Using DateTime directly or FieldValue.serverTimestamp() in updates
        'lastSenderId': lastSenderId,
        'unreadFieldUser': unreadFieldUser,
        'unreadSupplier': unreadSupplier,
        'hiddenBy': hiddenBy,
      };

  static DateTime _parseDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    return DateTime.tryParse(value?.toString() ?? '') ?? DateTime.now();
  }
}
