import 'package:cloud_firestore/cloud_firestore.dart';

class PartnershipRequestModel {
  final String requestId;
  final String companyId;
  final String companyName;
  final String supplierId;
  final String supplierName;
  final String initiatedBy; // 'ceo' | 'supplier'
  final String status; // pending | accepted | rejected | removed
  final String? message;
  final String? rejectionReason;
  final DateTime createdAt;
  final DateTime? respondedAt;
  final String? supplierEmail;
  final String? supplierCity;
  final List<String> supplierCategories;
  final double supplierRating;
  final List<String> deletedBy;

  PartnershipRequestModel({
    required this.requestId,
    required this.companyId,
    required this.companyName,
    required this.supplierId,
    required this.supplierName,
    required this.initiatedBy,
    required this.status,
    this.message,
    this.rejectionReason,
    required this.createdAt,
    this.respondedAt,
    this.supplierEmail,
    this.supplierCity,
    this.supplierCategories = const [],
    this.supplierRating = 0,
    this.deletedBy = const [],
  });

  factory PartnershipRequestModel.fromMap(
    String id,
    Map<String, dynamic> map,
  ) {
    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      if (value is Timestamp) return value.toDate();
      return DateTime.tryParse(value.toString());
    }

    return PartnershipRequestModel(
      requestId: id,
      companyId: (map['companyId'] ?? '') as String,
      companyName: (map['companyName'] ?? '') as String,
      supplierId: (map['supplierId'] ?? map['supplierUid'] ?? '') as String,
      supplierName: (map['supplierName'] ?? map['businessName'] ?? '') as String,
      initiatedBy: _normalizeInitiatedBy(map['initiatedBy'] as String?),
      status: (map['status'] ?? 'pending').toString().toLowerCase(),
      message: map['message'] as String?,
      rejectionReason: map['rejectionReason'] as String?,
      createdAt: parseDate(map['createdAt']) ?? DateTime.now(),
      respondedAt: parseDate(map['respondedAt']),
      supplierEmail: map['supplierEmail'] as String? ?? map['email'] as String?,
      supplierCity: map['supplierCity'] as String? ?? map['city'] as String?,
      supplierCategories: map['supplierCategories'] is List
          ? List<String>.from(map['supplierCategories'])
          : map['categories'] is List
              ? List<String>.from(map['categories'])
              : const [],
      supplierRating: (map['supplierRating'] as num?)?.toDouble() ??
          (map['rating'] as num?)?.toDouble() ??
          0,
      deletedBy: List<String>.from(map['deletedBy'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'requestId': requestId,
      'companyId': companyId,
      'companyName': companyName,
      'supplierId': supplierId,
      'supplierName': supplierName,
      'initiatedBy': initiatedBy,
      'status': status,
      'message': message,
      'rejectionReason': rejectionReason,
      'createdAt': Timestamp.fromDate(createdAt),
      if (respondedAt != null) 'respondedAt': Timestamp.fromDate(respondedAt!),
      'supplierEmail': supplierEmail,
      'supplierCity': supplierCity,
      'supplierCategories': supplierCategories,
      'supplierRating': supplierRating,
      'deletedBy': deletedBy,
    };
  }

  static String _normalizeInitiatedBy(String? value) {
    if (value == null) return 'supplier';
    final v = value.toLowerCase();
    if (v == 'company' || v == 'ceo') return 'ceo';
    return 'supplier';
  }

  bool get isCeoInitiated => initiatedBy == 'ceo';
  bool get isSupplierInitiated => initiatedBy == 'supplier';
}
