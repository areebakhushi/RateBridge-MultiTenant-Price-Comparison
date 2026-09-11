// MVVM: Repository — Firestore access only
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/order_model.dart';
import '../models/rating_model.dart';
import '../models/supplier_model.dart';
import '../services/firestore_service.dart';
import '../utils/app_exception.dart';

class OrderRepository {
  final FirestoreService _firestoreService;
  final FirebaseFirestore _db;

  OrderRepository(this._firestoreService, {FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  Future<void> createOrder(OrderModel order) async {
    try {
      await _db
          .collection('orders')
          .doc(order.orderId)
          .set(order.toMap());
    } on FirebaseException catch (e) {
      throw AppException('Failed to create order: ${e.message}');
    }
  }

  Future<void> submitOrder(OrderModel order) => createOrder(order);

  Future<OrderModel?> getOrderById(String orderId) async {
    try {
      final doc = await _db.collection('orders').doc(orderId).get();
      if (!doc.exists || doc.data() == null) return null;
      return OrderModel.fromMap(doc.id, doc.data() as Map<String, dynamic>);
    } on FirebaseException catch (e) {
      throw AppException('Failed to load order: ${e.message}');
    }
  }

  Future<SupplierModel?> getSupplierById(String supplierUid) async {
    return _firestoreService.getSupplierById(supplierUid);
  }

  Future<void> submitWeightReport(
    String orderId,
    double actualWeight, {
    String? remarks,
  }) async {
    try {
      await _db.collection('orders').doc(orderId).update({
        'actualWeight': actualWeight,
        if (remarks != null && remarks.isNotEmpty) 'weightReportRemarks': remarks,
        'status': 'delivered',
        'deliveredAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      throw AppException('Failed to submit weight report: ${e.message}');
    }
  }

  Future<void> updateOrder(String orderId, Map<String, dynamic> updates) async {
    try {
      await _db.collection('orders').doc(orderId).update(updates);
    } on FirebaseException catch (e) {
      throw AppException('Failed to update order: ${e.message}');
    }
  }

  Stream<List<OrderModel>> watchCompanyOrders(
    String companyId,
    String? statusFilter, {
    DocumentSnapshot? startAfter,
    String? userId,
  }) {
    Query query = _db
        .collection('orders')
        .where('companyId', isEqualTo: companyId)
        .orderBy('createdAt', descending: true);

    if (statusFilter != null && statusFilter != 'all' && statusFilter != 'All') {
      query = query.where('status', isEqualTo: statusFilter.toLowerCase());
    }
    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    return query.snapshots().map((snapshot) {
      var orders = snapshot.docs
          .map((doc) => OrderModel.fromMap(doc.id, doc.data() as Map<String, dynamic>))
          .toList();
      if (userId != null) {
        orders = orders.where((o) => !o.hiddenBy.contains(userId)).toList();
      }
      return orders;
    });
  }

  /// Fetches all orders for a supplier using efficient Firestore indexing.
  Stream<List<OrderModel>> getOrdersForSupplier(String supplierUid, {String? userId}) {
    return _db
        .collection('orders')
        .where('supplierId', isEqualTo: supplierUid)
        .snapshots()
        .map((snapshot) {
      var orders = snapshot.docs
          .map((doc) => OrderModel.fromMap(doc.id, doc.data()))
          .toList();
      if (userId != null) {
        orders = orders.where((o) => !o.hiddenBy.contains(userId)).toList();
      }
      orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return orders;
    });
  }

  /// Watches supplier orders for a specific company with optional status filtering.
  Stream<List<OrderModel>> watchSupplierOrders(
    String supplierUid,
    String companyId,
    String? statusFilter, {
    String? userId,
  }) {
    Query query = _db
        .collection('orders')
        .where('supplierId', isEqualTo: supplierUid)
        .where('companyId', isEqualTo: companyId)
        .orderBy('createdAt', descending: true);

    if (statusFilter != null && statusFilter != 'all' && statusFilter != 'All') {
      query = query.where('status', isEqualTo: statusFilter.toLowerCase());
    }

    return query.snapshots().map((snapshot) {
      var orders = snapshot.docs
          .map((doc) => OrderModel.fromMap(doc.id, doc.data() as Map<String, dynamic>))
          .toList();
      if (userId != null) {
        orders = orders.where((o) => !o.hiddenBy.contains(userId)).toList();
      }
      return orders;
    });
  }

  Stream<List<OrderModel>> watchFieldUserOrders(
    String fieldUserUid,
    String companyId,
    String? statusFilter, {
    String? userId,
  }) {
    try {
      Query query = _db
          .collection('orders')
          .where('fieldUserUid', isEqualTo: fieldUserUid)
          .where('companyId', isEqualTo: companyId);

      if (statusFilter != null &&
          statusFilter != 'all' &&
          statusFilter != 'All') {
        query = query.where('status', isEqualTo: statusFilter.toLowerCase());
      }

      return query.snapshots().map((snapshot) {
        var orders = snapshot.docs
            .map((doc) =>
                OrderModel.fromMap(doc.id, doc.data() as Map<String, dynamic>))
            .toList();
        if (userId != null) {
          orders = orders.where((o) => !o.hiddenBy.contains(userId)).toList();
        }
        orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return orders;
      });
    } on FirebaseException catch (e) {
      return Stream.error(AppException('Failed to load orders: ${e.message}'));
    }
  }

  Future<List<OrderModel>> getRecentFieldOrders(int limit) async {
    final snap = await _db
        .collection('orders')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    return snap.docs.map((doc) => OrderModel.fromMap(doc.id, doc.data())).toList();
  }

  Future<String?> resolveCeoUid(String companyId) async {
    try {
      final doc = await _db.collection('companies').doc(companyId).get();
      if (!doc.exists || doc.data() == null) return null;
      final ceoUid = doc.data()!['ceoUid'] as String?;
      if (ceoUid != null && ceoUid.isNotEmpty) return ceoUid;
      return null;
    } on FirebaseException catch (e) {
      throw AppException('Failed to resolve company CEO: ${e.message}');
    }
  }

  Future<void> updateStatus(
    String orderId,
    String companyId,
    String status, {
    String? reason,
    DateTime? deliveredAt,
    DateTime? confirmedAt,
  }) async {
    try {
      final Map<String, dynamic> updates = {
        'status': status.toLowerCase(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (reason != null) updates['rejectionReason'] = reason;
      if (deliveredAt != null) updates['deliveredAt'] = Timestamp.fromDate(deliveredAt);
      if (confirmedAt != null) updates['confirmedAt'] = Timestamp.fromDate(confirmedAt);

      await _db
          .collection('orders')
          .doc(orderId)
          .update(updates);
    } on FirebaseException catch (e) {
      throw AppException('Failed to update order status: ${e.message}');
    }
  }

  Future<void> updateOrderStatus(String orderId, String status) async {
     await _db
          .collection('orders')
          .doc(orderId)
          .update({
            'status': status.toLowerCase(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
  }

  Future<void> cancelOrder(String orderId, String companyId) async {
    try {
      final doc = await _db
          .collection('orders')
          .doc(orderId)
          .get();
      if (!doc.exists) throw AppException('Order not found');
      
      final data = doc.data() as Map<String, dynamic>;
      final status = data['status'] as String;
      
      if (status != 'pending' && status != 'accepted' && status != 'pending_approval') {
        throw AppException('Cannot cancel order in $status status');
      }
      await updateStatus(orderId, companyId, 'cancelled');
    } on FirebaseException catch (e) {
      throw AppException('Failed to cancel order: ${e.message}');
    }
  }

  Future<bool> hasRatingForOrder(String orderId, String companyId) async {
    final snapshot = await _db
        .collection('ratings')
        .where('orderId', isEqualTo: orderId)
        .limit(1)
        .get();
    return snapshot.docs.isNotEmpty;
  }

  Future<bool> hasRatingForOrderByUser(String orderId, String userId) async {
    try {
      final snapshot = await _db
          .collection('ratings')
          .where('orderId', isEqualTo: orderId)
          .get();
      return snapshot.docs.any((doc) {
        final data = doc.data();
        final ratedBy = data['userId'] ?? data['fieldUserId'];
        return ratedBy == userId;
      });
    } on FirebaseException catch (e) {
      throw AppException('Failed to check existing rating: ${e.message}');
    }
  }

  Future<void> submitRating(String orderId, String companyId, RatingModel rating) async {
    try {
      final ref = _db.collection('ratings').doc();
      await ref.set({
        ...rating.toMap(),
        'companyId': companyId,
        'fieldUserId': rating.userId,
      });
    } on FirebaseException catch (e) {
      throw AppException('Failed to submit rating: ${e.message}');
    }
  }

  Future<void> updateSupplierAvgRating(String supplierUid) async {
    try {
      final snapshot = await _db
          .collection('ratings')
          .where('supplierUid', isEqualTo: supplierUid)
          .get();
      if (snapshot.docs.isEmpty) return;

      final scores = snapshot.docs
          .map((doc) => (doc.data()['rating'] as num?)?.toDouble() ?? 0.0)
          .where((score) => score > 0)
          .toList();
      if (scores.isEmpty) return;

      final average =
          scores.fold<double>(0, (total, score) => total + score) / scores.length;

      await _db.collection('suppliers').doc(supplierUid).set(
        {'rating': double.parse(average.toStringAsFixed(2))},
        SetOptions(merge: true),
      );
    } on FirebaseException catch (e) {
      throw AppException('Failed to update supplier rating: ${e.message}');
    }
  }

  Stream<List<RatingModel>> watchSupplierRatings(String supplierUid) {
    return _db
        .collection('ratings')
        .where('supplierUid', isEqualTo: supplierUid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => RatingModel.fromMap(doc.id, doc.data()))
            .toList());
  }

  /// Soft-delete: Hide order for a specific user.
  Future<void> hideOrderForUser(String orderId, String userId) async {
    try {
      await _db.collection('orders').doc(orderId).update({
        'hiddenBy': FieldValue.arrayUnion([userId]),
      });
    } on FirebaseException catch (e) {
      throw AppException('Failed to hide order: ${e.message}');
    }
  }

  /// Bulk soft-delete orders.
  Future<void> hideOrdersForUser(List<String> orderIds, String userId) async {
    try {
      final batch = _db.batch();
      for (final id in orderIds) {
        batch.update(_db.collection('orders').doc(id), {
          'hiddenBy': FieldValue.arrayUnion([userId]),
        });
      }
      await batch.commit();
    } on FirebaseException catch (e) {
      throw AppException('Failed to hide orders: ${e.message}');
    }
  }
}
