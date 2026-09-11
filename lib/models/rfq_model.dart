import 'package:cloud_firestore/cloud_firestore.dart';

class RfqModel {
  final String id;
  final String companyId;
  final String companyName;
  final String category;
  final String materialDescription;
  final double quantity;
  final String unit;
  final String city;
  final DateTime requiredByDate;
  final String status; // 'open' | 'closed' | 'awarded'
  final DateTime createdAt;
  final String? awardedBidId;
  final String? awardedSupplierId;
  final String? createdByUid;
  final String? createdByName;
  final List<String> deletedBy;

  RfqModel({
    required this.id,
    required this.companyId,
    required this.companyName,
    required this.category,
    required this.materialDescription,
    required this.quantity,
    required this.unit,
    required this.city,
    required this.requiredByDate,
    required this.status,
    required this.createdAt,
    this.awardedBidId,
    this.awardedSupplierId,
    this.createdByUid,
    this.createdByName,
    this.deletedBy = const [],
  });

  List<String> get hiddenBy => deletedBy;

  factory RfqModel.fromMap(String id, Map<String, dynamic> map) {
    return RfqModel(
      id: id,
      companyId: map['companyId'] ?? '',
      companyName: map['companyName'] ?? '',
      category: map['category'] ?? '',
      materialDescription: map['materialDescription'] ?? '',
      quantity: (map['quantity'] as num?)?.toDouble() ?? 0.0,
      unit: map['unit'] ?? '',
      city: map['city'] ?? '',
      requiredByDate: (map['requiredByDate'] as Timestamp).toDate(),
      status: map['status'] ?? 'open',
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      awardedBidId: map['awardedBidId'],
      awardedSupplierId: map['awardedSupplierId'],
      createdByUid: map['createdByUid'],
      createdByName: map['createdByName'],
      deletedBy: List<String>.from(map['deletedBy'] ?? map['hiddenBy'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'companyId': companyId,
      'companyName': companyName,
      'category': category,
      'materialDescription': materialDescription,
      'quantity': quantity,
      'unit': unit,
      'city': city,
      'requiredByDate': Timestamp.fromDate(requiredByDate),
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'awardedBidId': awardedBidId,
      'awardedSupplierId': awardedSupplierId,
      'createdByUid': createdByUid,
      'createdByName': createdByName,
      'deletedBy': deletedBy,
    };
  }

  RfqModel copyWith({
    String? id,
    String? companyId,
    String? companyName,
    String? category,
    String? materialDescription,
    double? quantity,
    String? unit,
    String? city,
    DateTime? requiredByDate,
    String? status,
    DateTime? createdAt,
    String? awardedBidId,
    String? awardedSupplierId,
    String? createdByUid,
    String? createdByName,
    List<String>? deletedBy,
  }) {
    return RfqModel(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      companyName: companyName ?? this.companyName,
      category: category ?? this.category,
      materialDescription: materialDescription ?? this.materialDescription,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      city: city ?? this.city,
      requiredByDate: requiredByDate ?? this.requiredByDate,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      awardedBidId: awardedBidId ?? this.awardedBidId,
      awardedSupplierId: awardedSupplierId ?? this.awardedSupplierId,
      createdByUid: createdByUid ?? this.createdByUid,
      createdByName: createdByName ?? this.createdByName,
      deletedBy: deletedBy ?? this.deletedBy,
    );
  }
}
