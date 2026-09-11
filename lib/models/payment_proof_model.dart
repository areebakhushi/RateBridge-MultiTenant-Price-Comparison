import 'package:cloud_firestore/cloud_firestore.dart';

enum PaymentType { subscription, commission }

class PaymentProofModel {
  final String id;
  final String payerId; // ceoId or supplierUid
  final String companyId; // Relevant for CEOs
  final String payerName;
  final String payerRole;
  final double amount;
  final String method;
  final String screenshotUrl;
  final String status; // pending | pending_review | approved | rejected
  final String type; // subscription | commission
  final String? planId;
  final String? planName;
  final String? adminNotes;
  final String? confirmedBy;
  final DateTime createdAt; // submittedAt
  final DateTime? confirmedAt;
  
  // AI/Extended fields
  final double? amountDetected;
  final String? transactionIdDetected;
  final List<String>? relatedTransactions;
  final List<String> hiddenBy;

  PaymentProofModel({
    required this.id,
    required this.payerId,
    required this.companyId,
    required this.payerName,
    required this.payerRole,
    required this.amount,
    required this.method,
    required this.screenshotUrl,
    required this.status,
    required this.type,
    this.planId,
    this.planName,
    this.adminNotes,
    this.confirmedBy,
    required this.createdAt,
    this.confirmedAt,
    this.amountDetected,
    this.transactionIdDetected,
    this.relatedTransactions,
    this.hiddenBy = const [],
  });

  // Getters to support view legacy/naming preferences
  double get amountExpected => amount;
  String? get planKey => planId;

  factory PaymentProofModel.fromMap(String id, Map<String, dynamic> map) {
    return PaymentProofModel(
      id: id,
      payerId: map['payerId'] ?? map['ceoId'] ?? '',
      companyId: map['companyId'] ?? '',
      payerName: map['payerName'] ?? '',
      payerRole: map['payerRole'] ?? '',
      amount: (map['amount'] ?? map['amountExpected'] as num?)?.toDouble() ?? 0.0,
      method: map['method'] ?? map['paymentMethod'] ?? '',
      screenshotUrl: map['screenshotUrl'] ?? '',
      status: map['status'] ?? 'pending',
      type: map['type'] ?? '',
      planId: map['planId'] ?? map['planKey'],
      planName: map['planName'],
      adminNotes: map['adminNotes'],
      confirmedBy: map['confirmedBy'],
      createdAt: (map['createdAt'] ?? map['submittedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      confirmedAt: (map['confirmedAt'] ?? map['approvedAt'] as Timestamp?)?.toDate(),
      amountDetected: (map['amountDetected'] as num?)?.toDouble(),
      transactionIdDetected: map['transactionIdDetected'],
      relatedTransactions: map['relatedTransactions'] != null 
          ? List<String>.from(map['relatedTransactions']) 
          : null,
      hiddenBy: List<String>.from(map['hiddenBy'] ?? []),
    );
  }

  Map<String, dynamic> toMap() => {
    'payerId': payerId,
    'companyId': companyId,
    'payerName': payerName,
    'payerRole': payerRole,
    'amount': amount,
    'method': method,
    'screenshotUrl': screenshotUrl,
    'status': status,
    'type': type,
    'planId': planId,
    'planName': planName,
    'adminNotes': adminNotes,
    'confirmedBy': confirmedBy,
    'createdAt': Timestamp.fromDate(createdAt),
    if (confirmedAt != null) 'confirmedAt': Timestamp.fromDate(confirmedAt!),
    'amountDetected': amountDetected,
    'transactionIdDetected': transactionIdDetected,
    'relatedTransactions': relatedTransactions,
    'hiddenBy': hiddenBy,
  };

  PaymentProofModel copyWith({
    String? id,
    String? payerId,
    String? companyId,
    String? payerName,
    String? payerRole,
    double? amount,
    String? method,
    String? screenshotUrl,
    String? status,
    String? type,
    String? planId,
    String? planName,
    String? adminNotes,
    String? confirmedBy,
    DateTime? createdAt,
    DateTime? confirmedAt,
    double? amountDetected,
    String? transactionIdDetected,
    List<String>? relatedTransactions,
    List<String>? hiddenBy,
  }) {
    return PaymentProofModel(
      id: id ?? this.id,
      payerId: payerId ?? this.payerId,
      companyId: companyId ?? this.companyId,
      payerName: payerName ?? this.payerName,
      payerRole: payerRole ?? this.payerRole,
      amount: amount ?? this.amount,
      method: method ?? this.method,
      screenshotUrl: screenshotUrl ?? this.screenshotUrl,
      status: status ?? this.status,
      type: type ?? this.type,
      planId: planId ?? this.planId,
      planName: planName ?? this.planName,
      adminNotes: adminNotes ?? this.adminNotes,
      confirmedBy: confirmedBy ?? this.confirmedBy,
      createdAt: createdAt ?? this.createdAt,
      confirmedAt: confirmedAt ?? this.confirmedAt,
      amountDetected: amountDetected ?? this.amountDetected,
      transactionIdDetected: transactionIdDetected ?? this.transactionIdDetected,
      relatedTransactions: relatedTransactions ?? this.relatedTransactions,
      hiddenBy: hiddenBy ?? this.hiddenBy,
    );
  }
}
