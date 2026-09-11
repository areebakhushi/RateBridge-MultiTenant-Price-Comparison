import 'package:cloud_firestore/cloud_firestore.dart';

class OrderModel {
  final String orderId;
  final String companyId;
  final String fieldUserUid;
  final String supplierId;
  final String materialId;
  final String materialName;
  final String supplierName;
  final String fieldUserName;
  final String? fieldUserPhone;
  final double quantity; 
  final String unit; 
  final double unitPrice;
  final double totalAmount;
  final double commissionAmount;
  final double supplierEarning;
  final String deliveryAddress;
  final String? siteLocation; 
  final String? notes;
  final String status; // pending|accepted|delivered|confirmed|rejected|cancelled
  final String? rejectionReason;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? requiredDate; 
  final DateTime? deliveredAt;
  final DateTime? confirmedAt;
  final bool commissionDeducted;
  final String? chatMetaId;
  final String? paymentProofUrl;
  final String? paymentStatus;
  final List<String> deletedBy;

  const OrderModel({
    required this.orderId,
    required this.companyId,
    required this.fieldUserUid,
    required this.supplierId,
    required this.materialId,
    required this.materialName,
    required this.supplierName,
    required this.fieldUserName,
    this.fieldUserPhone,
    required this.quantity,
    required this.unit,
    required this.unitPrice,
    required this.totalAmount,
    this.commissionAmount = 0.0,
    this.supplierEarning = 0.0,
    required this.deliveryAddress,
    this.siteLocation,
    this.notes,
    required this.status,
    this.rejectionReason,
    required this.createdAt,
    required this.updatedAt,
    this.requiredDate,
    this.deliveredAt,
    this.confirmedAt,
    this.commissionDeducted = false,
    this.chatMetaId,
    this.paymentProofUrl,
    this.paymentStatus,
    this.deletedBy = const [],
  });

  String get id => orderId;
  List<String> get hiddenBy => deletedBy;

  factory OrderModel.fromMap(String id, Map<String, dynamic> map) => OrderModel(
    orderId: id,
    companyId: map['companyId'] ?? '',
    fieldUserUid: map['fieldUserUid'] ?? '',
    supplierId: map['supplierId'] ?? map['supplierUid'] ?? '',
    materialId: map['materialId'] ?? '',
    materialName: map['materialName'] ?? '',
    supplierName: map['supplierName'] ?? '',
    fieldUserName: map['fieldUserName'] ?? '',
    fieldUserPhone: map['fieldUserPhone'],
    quantity: (map['quantity'] as num?)?.toDouble() ?? 0.0,
    unit: map['unit'] ?? 'unit',
    unitPrice: (map['unitPrice'] as num?)?.toDouble() ?? 0.0,
    totalAmount: (map['totalAmount'] as num?)?.toDouble() ?? 0.0,
    commissionAmount: (map['commissionAmount'] as num?)?.toDouble() ?? 0.0,
    supplierEarning: (map['supplierEarning'] as num?)?.toDouble() ?? 0.0,
    deliveryAddress: map['deliveryAddress'] ?? '',
    siteLocation: map['siteLocation'],
    notes: map['notes'],
    status: map['status'] ?? 'pending',
    rejectionReason: map['rejectionReason'],
    createdAt: map['createdAt'] is Timestamp 
        ? (map['createdAt'] as Timestamp).toDate() 
        : DateTime.tryParse(map['createdAt']?.toString() ?? '') ?? DateTime.now(),
    updatedAt: map['updatedAt'] is Timestamp 
        ? (map['updatedAt'] as Timestamp).toDate() 
        : DateTime.tryParse(map['updatedAt']?.toString() ?? '') ?? DateTime.now(),
    requiredDate: map['requiredDate'] is Timestamp ? (map['requiredDate'] as Timestamp).toDate() : null,
    deliveredAt: map['deliveredAt'] is Timestamp ? (map['deliveredAt'] as Timestamp).toDate() : null,
    confirmedAt: map['confirmedAt'] is Timestamp ? (map['confirmedAt'] as Timestamp).toDate() : null,
    commissionDeducted: map['commissionDeducted'] ?? false,
    chatMetaId: map['chatMetaId'],
    paymentProofUrl: map['paymentProofUrl'],
    paymentStatus: map['paymentStatus'],
    deletedBy: List<String>.from(map['deletedBy'] ?? map['hiddenBy'] ?? []),
  );

  Map<String, dynamic> toMap() => {
    'companyId': companyId,
    'fieldUserUid': fieldUserUid,
    'supplierId': supplierId,
    'materialId': materialId,
    'materialName': materialName,
    'supplierName': supplierName,
    'fieldUserName': fieldUserName,
    'fieldUserPhone': fieldUserPhone,
    'quantity': quantity,
    'unit': unit,
    'unitPrice': unitPrice,
    'totalAmount': totalAmount,
    'commissionAmount': commissionAmount,
    'supplierEarning': supplierEarning,
    'deliveryAddress': deliveryAddress,
    'siteLocation': siteLocation,
    'notes': notes,
    'status': status,
    'rejectionReason': rejectionReason,
    'createdAt': Timestamp.fromDate(createdAt),
    'updatedAt': Timestamp.fromDate(updatedAt),
    'requiredDate': requiredDate != null ? Timestamp.fromDate(requiredDate!) : null,
    'deliveredAt': deliveredAt != null ? Timestamp.fromDate(deliveredAt!) : null,
    'confirmedAt': confirmedAt != null ? Timestamp.fromDate(confirmedAt!) : null,
    'commissionDeducted': commissionDeducted,
    'chatMetaId': chatMetaId,
    if (paymentProofUrl != null) 'paymentProofUrl': paymentProofUrl,
    if (paymentStatus != null) 'paymentStatus': paymentStatus,
    'deletedBy': deletedBy,
  };

  OrderModel copyWith({
    String? orderId,
    String? companyId,
    String? fieldUserUid,
    String? supplierId,
    String? materialId,
    String? materialName,
    String? supplierName,
    String? fieldUserName,
    String? fieldUserPhone,
    double? quantity,
    String? unit,
    double? unitPrice,
    double? totalAmount,
    double? commissionAmount,
    double? supplierEarning,
    String? deliveryAddress,
    String? siteLocation,
    String? notes,
    String? status,
    String? rejectionReason,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? requiredDate,
    DateTime? deliveredAt,
    DateTime? confirmedAt,
    bool? commissionDeducted,
    String? chatMetaId,
    String? paymentProofUrl,
    String? paymentStatus,
    List<String>? deletedBy,
  }) {
    return OrderModel(
      orderId: orderId ?? this.orderId,
      companyId: companyId ?? this.companyId,
      fieldUserUid: fieldUserUid ?? this.fieldUserUid,
      supplierId: supplierId ?? this.supplierId,
      materialId: materialId ?? this.materialId,
      materialName: materialName ?? this.materialName,
      supplierName: supplierName ?? this.supplierName,
      fieldUserName: fieldUserName ?? this.fieldUserName,
      fieldUserPhone: fieldUserPhone ?? this.fieldUserPhone,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      unitPrice: unitPrice ?? this.unitPrice,
      totalAmount: totalAmount ?? this.totalAmount,
      commissionAmount: commissionAmount ?? this.commissionAmount,
      supplierEarning: supplierEarning ?? this.supplierEarning,
      deliveryAddress: deliveryAddress ?? this.deliveryAddress,
      siteLocation: siteLocation ?? this.siteLocation,
      notes: notes ?? this.notes,
      status: status ?? this.status,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      requiredDate: requiredDate ?? this.requiredDate,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      confirmedAt: confirmedAt ?? this.confirmedAt,
      commissionDeducted: commissionDeducted ?? this.commissionDeducted,
      chatMetaId: chatMetaId ?? this.chatMetaId,
      paymentProofUrl: paymentProofUrl ?? this.paymentProofUrl,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      deletedBy: deletedBy ?? this.deletedBy,
    );
  }
}
