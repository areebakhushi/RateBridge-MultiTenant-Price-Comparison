// MVVM: Model — pure Dart
import 'package:cloud_firestore/cloud_firestore.dart';

class TransactionModel {
  final String txId;
  final String orderId;
  final String companyId;
  final String supplierUid;
  final double totalAmount;
  final double commissionRate; // always 0.02
  final double commissionAmount;
  final double supplierEarning;
  final String status; // unsettled | settled | pending | failed
  final DateTime createdAt;
  final DateTime? settledAt;
  final List<String> hiddenBy;

  const TransactionModel({
    required this.txId,
    required this.orderId,
    required this.companyId,
    required this.supplierUid,
    required this.totalAmount,
    required this.commissionRate,
    required this.commissionAmount,
    required this.supplierEarning,
    required this.status,
    required this.createdAt,
    this.settledAt,
    this.hiddenBy = const [],
  });

  bool get isUnsettled => status.toLowerCase() == 'unsettled' || status.toLowerCase() == 'pending';
  bool get isSettled => status.toLowerCase() == 'settled' || status.toLowerCase() == 'confirmed';

  factory TransactionModel.fromMap(String id, Map<String, dynamic> map) => TransactionModel(
    txId: id,
    orderId: map['orderId'] ?? '',
    companyId: map['companyId'] ?? '',
    supplierUid: map['supplierUid'] ?? map['supplierId'] ?? '',
    totalAmount: (map['totalAmount'] as num?)?.toDouble() ?? 0.0,
    commissionRate: (map['commissionRate'] as num?)?.toDouble() ?? 0.02,
    commissionAmount: (map['commissionAmount'] as num?)?.toDouble() ?? 0.0,
    supplierEarning: (map['supplierEarning'] as num?)?.toDouble() ?? 0.0,
    status: map['status'] ?? 'unsettled',
    createdAt: map['createdAt'] is Timestamp 
        ? (map['createdAt'] as Timestamp).toDate() 
        : DateTime.tryParse(map['createdAt']?.toString() ?? '') ?? DateTime.now(),
    settledAt: map['settledAt'] is Timestamp
        ? (map['settledAt'] as Timestamp).toDate()
        : DateTime.tryParse(map['settledAt']?.toString() ?? ''),
    hiddenBy: List<String>.from(map['hiddenBy'] ?? []),
  );

  Map<String, dynamic> toMap() => {
    'orderId': orderId,
    'companyId': companyId,
    'supplierUid': supplierUid,
    'totalAmount': totalAmount,
    'commissionRate': commissionRate,
    'commissionAmount': commissionAmount,
    'supplierEarning': supplierEarning,
    'status': status,
    'createdAt': FieldValue.serverTimestamp(),
    if (settledAt != null) 'settledAt': Timestamp.fromDate(settledAt!),
    'hiddenBy': hiddenBy,
  };
}

/// Per-supplier unsettled commission rollup for the admin ledger.
class SupplierUnsettledSummary {
  final String supplierUid;
  final String supplierName;
  final double unsettledAmount;
  final int orderCount;
  final List<String> transactionIds;

  const SupplierUnsettledSummary({
    required this.supplierUid,
    required this.supplierName,
    required this.unsettledAmount,
    required this.orderCount,
    required this.transactionIds,
  });
}

/// Admin commission ledger totals and supplier rows.
class CommissionLedgerSnapshot {
  final double outstandingThisMonth;
  final double collectedThisMonth;
  final double grandTotalCollected;
  final List<SupplierUnsettledSummary> suppliers;

  const CommissionLedgerSnapshot({
    required this.outstandingThisMonth,
    required this.collectedThisMonth,
    required this.grandTotalCollected,
    required this.suppliers,
  });

  static const empty = CommissionLedgerSnapshot(
    outstandingThisMonth: 0,
    collectedThisMonth: 0,
    grandTotalCollected: 0,
    suppliers: [],
  );
}

class MonthlyEarning {
  final String month; // YYYY-MM
  final double gross;
  final double commission;
  final double net;
  final int orderCount;

  const MonthlyEarning({
    required this.month,
    required this.gross,
    required this.commission,
    required this.net,
    required this.orderCount,
  });

  factory MonthlyEarning.fromMap(String month, Map<String, dynamic> map) => MonthlyEarning(
    month: month,
    gross: (map['gross'] as num?)?.toDouble() ?? 0.0,
    commission: (map['commission'] as num?)?.toDouble() ?? 0.0,
    net: (map['net'] as num?)?.toDouble() ?? 0.0,
    orderCount: (map['orderCount'] as num?)?.toInt() ?? 0,
  );
}
