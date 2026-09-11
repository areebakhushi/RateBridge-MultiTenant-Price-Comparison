// MVVM: ViewModel
import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/company_model.dart';
import '../models/user_model.dart';
import '../models/category_model.dart';
import '../models/payment_proof_model.dart';
import '../models/subscription_model.dart';
import '../models/transaction_model.dart';
import '../services/notification_service.dart';
import '../utils/invite_code_generator.dart';
import '../utils/app_exception.dart';
import '../constants/firestore_paths.dart';
import 'auth_viewmodel.dart';

// New Admin Models
class PlatformTransaction {
  final String id;
  final String type; // 'subscription' | 'order_payment' | 'commission'
  final String companyName;
  final String? supplierName;
  final double amount;
  final String status; // 'pending' | 'confirmed' | 'failed' | 'settled'
  final DateTime? date;
  final String payerRole;
  final String? screenshotUrl;
  final String? rejectionReason;

  PlatformTransaction({
    required this.id,
    required this.type,
    required this.companyName,
    this.supplierName,
    required this.amount,
    required this.status,
    this.date,
    this.payerRole = '',
    this.screenshotUrl,
    this.rejectionReason,
  });
}

class AdminViewModel extends ChangeNotifier {
  final FirebaseFirestore _db;
  final NotificationService? _notificationService;

  String? _uid;
  String? _adminName;
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  List<Map<String, dynamic>> _suppliersList = [];
  List<Map<String, dynamic>> get suppliersList => _suppliersList;

  List<Map<String, dynamic>> _ceosList = [];
  List<Map<String, dynamic>> get ceosList => _ceosList;

  List<CompanyModel> _companies = [];
  List<CompanyModel> get companiesList => _companies;

  List<PlatformTransaction> _transactions = [];
  List<PlatformTransaction> get transactions => _transactions;

  List<PaymentProofModel> _pendingPayments = [];
  List<PaymentProofModel> get pendingPayments => _pendingPayments;

  List<PaymentProofModel> _confirmedPayments = [];
  List<PaymentProofModel> get confirmedPayments => _confirmedPayments;

  StreamSubscription? _paymentQueueSub;

  AdminViewModel([this._notificationService, FirebaseFirestore? firestore])
      : _db = firestore ?? FirebaseFirestore.instance;

  @override
  void dispose() {
    _paymentQueueSub?.cancel();
    super.dispose();
  }

  void updateAuth(AuthViewModel auth) {
    if (auth.user != null && (auth.user!.role.toLowerCase() == 'admin' || auth.user!.role.toLowerCase() == 'administrator')) {
      if (_uid != auth.user!.uid) {
        _uid = auth.user!.uid;
        _adminName = auth.user!.name;
        loadDashboardData();
        loadPaymentQueue();
        loadCEOs();
        loadSuppliers();
      }
    }
  }

  Future<void> _logAction({
    required String actionType,
    required String targetType,
    required String targetId,
    required String description,
    String? reason,
  }) async {
    final actorId = _uid ?? FirebaseAuth.instance.currentUser?.uid;
    if (actorId == null || actorId.isEmpty) {
      developer.log('Skipping audit log for $actionType: no admin actor id');
      return;
    }
    final actorName = (_adminName != null && _adminName!.trim().isNotEmpty)
        ? _adminName!.trim()
        : (FirebaseAuth.instance.currentUser?.displayName?.trim().isNotEmpty == true
            ? FirebaseAuth.instance.currentUser!.displayName!.trim()
            : 'Admin');
    try {
      await _db.collection('audit_logs').add({
        'actorId': actorId,
        'actorName': _clip(actorName, 200),
        'actionType': _clip(actionType, 80),
        'targetType': _clip(targetType, 40),
        'targetId': _clip(targetId, 200),
        'description': _clip(description, 1000),
        if (reason != null && reason.trim().isNotEmpty)
          'reason': _clip(reason.trim(), 4000),
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      developer.log("Error saving audit log: $e");
    }
  }

  String _clip(String value, int max) {
    final trimmed = value.trim();
    if (trimmed.length <= max) return trimmed;
    return '${trimmed.substring(0, max - 3)}...';
  }

  Future<String> _userName(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      final name = (doc.data()?['name'] ?? '').toString().trim();
      if (name.isNotEmpty) return name;
    } catch (e) {
      developer.log('Failed to load user name for $uid: $e');
    }
    return uid;
  }

  Future<String> _companyName(String? companyId) async {
    if (companyId == null || companyId.isEmpty) return 'unknown company';
    try {
      final doc = await _db.collection('companies').doc(companyId).get();
      final name = (doc.data()?['name'] ?? doc.data()?['companyName'] ?? '').toString().trim();
      if (name.isNotEmpty) return name;
    } catch (e) {
      developer.log('Failed to load company name for $companyId: $e');
    }
    return companyId;
  }

  Future<String> _supplierName(String uid) async {
    try {
      final supplierDoc = await _db.collection('suppliers').doc(uid).get();
      final business = (supplierDoc.data()?['businessName'] ?? supplierDoc.data()?['name'] ?? '').toString().trim();
      if (business.isNotEmpty) return business;
    } catch (e) {
      developer.log('Failed to load supplier profile for $uid: $e');
    }
    return _userName(uid);
  }

  Future<String> _resolvedCompanyId(String ceoUid, String? companyId) async {
    if (companyId != null && companyId.isNotEmpty) return companyId;
    try {
      final user = await _db.collection('users').doc(ceoUid).get();
      return (user.data()?['companyId'] ?? '').toString();
    } catch (_) {
      return '';
    }
  }

  Future<void> loadDashboardData() async {
    _isLoading = true;
    notifyListeners();
    try {
      final companySnap = await _db.collection('companies').get();
      _companies = companySnap.docs.map((doc) => CompanyModel.fromMap(doc.data())).toList();

      final txSnap = await _db.collection('transactions').limit(50).get();
      _transactions = txSnap.docs.map((d) {
        final data = d.data();
        return PlatformTransaction(
          id: d.id,
          type: data['type'] as String? ?? 'order_payment',
          companyName: data['companyName'] as String? ?? '',
          supplierName: data['supplierName'] as String?,
          amount: (data['amount'] as num? ?? 0).toDouble(),
          status: data['status'] as String? ?? 'pending',
          date: (data['date'] as Timestamp?)?.toDate(),
          payerRole: data['payerRole'] as String? ?? '',
          screenshotUrl: data['screenshotUrl'] as String?,
          rejectionReason: data['rejectionReason'] as String?,
        );
      }).toList();
    } catch (e) {
      developer.log("AdminViewModel Error: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadPaymentQueue() async {
    _paymentQueueSub?.cancel();
    _isLoading = true;
    notifyListeners();

    _paymentQueueSub = _db.collection('payment_proofs')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snap) {
      final all = snap.docs.map((doc) => PaymentProofModel.fromMap(doc.id, doc.data())).toList();
      _pendingPayments = all.where((p) => p.status == 'pending').toList();
      _confirmedPayments = all.where((p) => p.status != 'pending' && p.status != 'rejected').toList();
      _isLoading = false;
      notifyListeners();
    }, onError: (e) {
      developer.log("Error watching payment queue: $e");
      _isLoading = false;
      notifyListeners();
    });
  }

  Future<void> confirmPayment(PaymentProofModel payment) async {
    if (payment.status == 'confirmed' || payment.status == 'settled') return;
    _isLoading = true;
    notifyListeners();
    try {
      final now = DateTime.now();
      final batch = _db.batch();
      final paymentRef = _db.collection('payment_proofs').doc(payment.id);
      
      final targetStatus = payment.type == 'commission' ? 'settled' : 'confirmed';
      
      batch.update(paymentRef, {
        'status': targetStatus,
        'confirmedAt': FieldValue.serverTimestamp(),
        'confirmedBy': _uid ?? 'admin',
      });

      if (payment.type == 'subscription' && payment.planId != null) {
        final plan = kPlans.firstWhere((p) => p.planKey == payment.planId, orElse: () => kPlans.first);
        final expiry = plan.durationDays > 0 ? now.add(Duration(days: plan.durationDays)) : null;
        final subRef = _db.collection('subscriptions').doc(payment.companyId);
        batch.set(subRef, {
          'plan': plan.planKey,
          'status': 'active',
          'startedAt': FieldValue.serverTimestamp(),
          'expiresAt': expiry != null ? Timestamp.fromDate(expiry) : null,
          'adminGranted': false,
        }, SetOptions(merge: true));
        final historyEntry = SubscriptionHistoryEntry(
          plan: plan.planKey,
          action: 'purchased',
          date: now,
          amountPaid: payment.amount.toInt(),
          note: 'Confirmed by Admin',
        );
        batch.update(subRef, {
          'history': FieldValue.arrayUnion([historyEntry.toMap()]),
        });
        final companyRef = _db.collection('companies').doc(payment.companyId);
        batch.update(companyRef, {
          'plan': plan.planKey,
          'planExpiry': expiry != null ? Timestamp.fromDate(expiry) : null,
          'aiEnabled': plan.aiUnlocked,
          'status': 'active',
        });
      } 
      else if (payment.type == 'commission') {
        if (payment.relatedTransactions != null) {
          for (var txId in payment.relatedTransactions!) {
            batch.update(_db.collection(FirestorePaths.transactionsCol).doc(txId), {
              'status': 'settled',
              'settledAt': FieldValue.serverTimestamp(),
              'settledBy': _uid ?? 'admin',
              'paymentProofId': payment.id,
            });
          }
        }
      }
      
      await batch.commit();

      // Send notifications AFTER successful batch commit to prevent path errors from blocking the DB update
      if (_notificationService != null) {
        if (payment.type == 'subscription') {
          final plan = kPlans.firstWhere((p) => p.planKey == payment.planId, orElse: () => kPlans.first);
          await _notificationService!.notifySubscriptionDecision(
            ceoUid: payment.payerId,
            companyId: payment.companyId,
            title: 'Subscription Activated! ✅',
            message: 'Your ${plan.name} subscription has been activated successfully.',
            data: {'planId': plan.planKey, 'status': 'active'},
          );
        } else if (payment.type == 'commission') {
          await _notificationService!.notifyPaymentStatus(
            userId: payment.payerId,
            companyId: payment.companyId,
            title: 'Commission Payment Confirmed ✅',
            message: 'Your commission payment of Rs ${payment.amount} has been settled.',
            data: {'status': 'settled'},
          );
        }
      }
      
      await _logAction(actionType: 'confirm_payment', targetType: 'payment_proof', targetId: payment.id, description: 'Confirmed ${payment.type} payment of Rs ${payment.amount} from ${payment.payerName}');
    } catch (e) {
      developer.log("Error confirming payment: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> rejectPayment(PaymentProofModel payment, String reason) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _db.collection('payment_proofs').doc(payment.id).update({
        'status': 'rejected',
        'adminNotes': reason,
      });
      if (_notificationService != null) {
        await _notificationService!.notifyPaymentStatus(
          userId: payment.payerId,
          companyId: payment.companyId,
          title: 'Payment Rejected ❌',
          message: 'Your payment proof for ${payment.type} was rejected. Reason: $reason',
          data: {'status': 'rejected', 'reason': reason},
        );
      }
      await _logAction(actionType: 'reject_payment', targetType: 'payment_proof', targetId: payment.id, description: 'Rejected ${payment.type} payment from ${payment.payerName}', reason: reason);
    } catch (e) {
      developer.log("Error rejecting payment: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadCEOs() async {
    _isLoading = true;
    notifyListeners();
    try {
      final userSnap = await _db.collection('users').where('role', isEqualTo: 'CEO').get();
      List<Map<String, dynamic>> temp = [];
      for (var doc in userSnap.docs) {
        final ceo = UserModel.fromMap(doc.data());
        final companySnap = await _db.collection('companies').doc(ceo.companyId).get();
        temp.add({
          'ceo': ceo,
          'company': companySnap.exists ? CompanyModel.fromMap(companySnap.data()!) : null,
        });
      }
      _ceosList = temp;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> acceptCEO(String? companyId, String ceoUid) async {
    _isLoading = true;
    notifyListeners();
    try {
      final batch = _db.batch();
      if (companyId != null && companyId.isNotEmpty) {
        String inviteCode = InviteCodeGenerator.generate();
        batch.update(_db.collection('companies').doc(companyId), {
          'status': 'active',
          'inviteCode': inviteCode,
          'inviteCodeGeneratedAt': FieldValue.serverTimestamp(),
        });
      }
      batch.update(_db.collection('users').doc(ceoUid), {'status': 'active', 'approved': true});
      await batch.commit();
      final ceoName = await _userName(ceoUid);
      final resolvedId = await _resolvedCompanyId(ceoUid, companyId);
      final companyName = await _companyName(resolvedId);
      await _logAction(actionType: 'approve_ceo', targetType: 'ceo', targetId: ceoUid, description: 'Approved CEO $ceoName for company $companyName');
      loadCEOs();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  Future<void> approveCEO(String? companyId, String ceoUid) => acceptCEO(companyId, ceoUid);

  Future<void> suspendCEO(String? companyId, String ceoUid) async {
    final resolvedId = await _resolvedCompanyId(ceoUid, companyId);
    final ceoName = await _userName(ceoUid);
    final companyName = await _companyName(resolvedId);
    await _db.collection('users').doc(ceoUid).update({'status': 'suspended'});
    if (resolvedId.isNotEmpty) await _db.collection('companies').doc(resolvedId).update({'status': 'suspended'});
    await _logAction(actionType: 'ban_company', targetType: 'company', targetId: resolvedId.isNotEmpty ? resolvedId : ceoUid, description: 'Banned company $companyName (CEO: $ceoName)');
    loadCEOs();
  }

  Future<void> activateCEO(String? companyId, String ceoUid) async {
    final resolvedId = await _resolvedCompanyId(ceoUid, companyId);
    final ceoName = await _userName(ceoUid);
    final companyName = await _companyName(resolvedId);
    await _db.collection('users').doc(ceoUid).update({'status': 'active'});
    if (resolvedId.isNotEmpty) await _db.collection('companies').doc(resolvedId).update({'status': 'active'});
    await _logAction(actionType: 'reactivate_company', targetType: 'company', targetId: resolvedId.isNotEmpty ? resolvedId : ceoUid, description: 'Reactivated company $companyName (CEO: $ceoName)');
    loadCEOs();
  }

  Future<void> rejectCEO(String? companyId, String ceoUid, String reason) async {
    final resolvedId = await _resolvedCompanyId(ceoUid, companyId);
    final ceoName = await _userName(ceoUid);
    final companyName = await _companyName(resolvedId);
    await _db.collection('users').doc(ceoUid).update({'status': 'rejected', 'rejectionReason': reason});
    if (resolvedId.isNotEmpty) await _db.collection('companies').doc(resolvedId).update({'status': 'rejected', 'rejectionReason': reason});
    await _logAction(actionType: 'reject_ceo', targetType: 'ceo', targetId: ceoUid, description: 'Rejected CEO application for $ceoName ($companyName)', reason: reason);
    loadCEOs();
  }

  Future<void> loadSuppliers() async {
    final snap = await _db.collection('users').where('role', isEqualTo: 'Supplier').get();
    _suppliersList = snap.docs.map((d) => {'user': UserModel.fromMap(d.data())}).toList();
    notifyListeners();
  }

  Future<void> approveSupplier(String uid) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _db.collection('users').doc(uid).update({'status': 'active', 'approved': true});
      await _db.collection('suppliers').doc(uid).update({'status': 'Active', 'isVerified': true});
      final supplierName = await _supplierName(uid);
      await _logAction(actionType: 'approve_supplier', targetType: 'supplier', targetId: uid, description: 'Approved supplier $supplierName');
      loadSuppliers();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> suspendSupplier(String uid) async {
    final supplierName = await _supplierName(uid);
    await _db.collection('users').doc(uid).update({'status': 'suspended'});
    await _db.collection('suppliers').doc(uid).update({'status': 'Suspended'});
    await _logAction(actionType: 'ban_supplier', targetType: 'supplier', targetId: uid, description: 'Banned supplier $supplierName');
    loadSuppliers();
  }

  Future<void> reactivateSupplier(String uid) async {
    final supplierName = await _supplierName(uid);
    await _db.collection('users').doc(uid).update({'status': 'active', 'approved': true});
    await _db.collection('suppliers').doc(uid).update({'status': 'Active', 'isVerified': true});
    await _logAction(actionType: 'reactivate_supplier', targetType: 'supplier', targetId: uid, description: 'Reactivated supplier $supplierName');
    loadSuppliers();
  }

  Future<void> rejectSupplier(String uid, String reason) async {
    final supplierName = await _supplierName(uid);
    await _db.collection('users').doc(uid).update({'status': 'rejected', 'rejectionReason': reason});
    await _db.collection('suppliers').doc(uid).update({'status': 'Rejected'});
    await _logAction(actionType: 'reject_supplier', targetType: 'supplier', targetId: uid, description: 'Rejected supplier application for $supplierName', reason: reason);
    loadSuppliers();
  }

  Future<void> deleteSupplierPermanently(String uid) async {
    await _db.collection('users').doc(uid).delete();
    await _db.collection('suppliers').doc(uid).delete();
    await _logAction(actionType: 'delete_supplier', targetType: 'supplier', targetId: uid, description: 'Permanently deleted supplier account and data');
    loadSuppliers();
  }

  Future<void> acceptAppeal(Map<String, dynamic> appeal, String appealId) async {
    _isLoading = true;
    notifyListeners();
    try {
      final uid = appeal['uid'] as String;
      final role = (appeal['role'] as String).toLowerCase();
      final batch = _db.batch();

      batch.update(_db.collection('appeals').doc(appealId), {
        'status': 'accepted',
        'respondedAt': FieldValue.serverTimestamp(),
        'respondedBy': _uid ?? 'admin',
      });

      if (role == 'supplier') {
        batch.update(_db.collection('users').doc(uid), {'status': 'active', 'approved': true});
        batch.update(_db.collection('suppliers').doc(uid), {'status': 'Active', 'isVerified': true});
      } else if (role == 'ceo') {
        final companyId = appeal['companyId'] as String;
        String inviteCode = InviteCodeGenerator.generate();
        batch.update(_db.collection('users').doc(uid), {'status': 'active', 'approved': true});
        if (companyId.isNotEmpty) {
          batch.update(_db.collection('companies').doc(companyId), {
            'status': 'active',
            'inviteCode': inviteCode,
            'inviteCodeGeneratedAt': FieldValue.serverTimestamp(),
          });
        }
      }

      await batch.commit();
      await _logAction(actionType: 'accept_appeal', targetType: 'appeal', targetId: appealId, description: 'Accepted $role appeal for ${appeal['name']}');
      
      if (_notificationService != null) {
        await _notificationService!.notifyPaymentStatus(
          userId: uid,
          companyId: appeal['companyId'] ?? '',
          title: 'Appeal Accepted ✅',
          message: 'Your account appeal has been accepted. You now have full access.',
          data: {'status': 'active'},
        );
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> rejectAppeal(Map<String, dynamic> appeal, String appealId, String reason) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _db.collection('appeals').doc(appealId).update({
        'status': 'rejected',
        'adminResponse': reason,
        'respondedAt': FieldValue.serverTimestamp(),
        'respondedBy': _uid ?? 'admin',
      });

      final uid = appeal['uid'] as String;
      await _logAction(actionType: 'reject_appeal', targetType: 'appeal', targetId: appealId, description: 'Rejected appeal for ${appeal['name']}', reason: reason);
      
      if (_notificationService != null) {
        await _notificationService!.notifyPaymentStatus(
          userId: uid,
          companyId: appeal['companyId'] ?? '',
          title: 'Appeal Rejected ❌',
          message: 'Your account appeal was rejected. Reason: $reason',
          data: {'status': 'rejected', 'reason': reason},
        );
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addCategory(String name, String unit, List<String> brands, List<String> grades, {String iconKey = 'construction_outlined'}) async {
    final docRef = await _db.collection('categories').add({
      'name': name, 'unit': unit, 'brands': brands, 'grades': grades, 'icon': iconKey, 'active': true, 'activeMaterialsCount': 0, 'createdAt': FieldValue.serverTimestamp(),
    });
    await _logAction(actionType: 'add_category', targetType: 'category', targetId: docRef.id, description: 'Added new material category: $name');
  }

  Future<void> editCategory(String id, String name, String unit, List<String> brands, List<String> grades, {bool? isActive}) async {
    final updates = <String, dynamic>{'name': name, 'unit': unit, 'brands': brands, 'grades': grades};
    if (isActive != null) updates['active'] = isActive;
    await _db.collection('categories').doc(id).update(updates);
    await _logAction(actionType: 'edit_category', targetType: 'category', targetId: id, description: 'Updated category details for $name');
  }

  Future<void> setCategoryActive(String id, bool active) async {
    await _db.collection('categories').doc(id).update({'active': active});
    await _logAction(actionType: active ? 'activate_category' : 'deactivate_category', targetType: 'category', targetId: id, description: '${active ? "Activated" : "Deactivated"} category');
  }

  Future<void> deleteCategory(String id) async {
    final cat = await _db.collection('categories').doc(id).get();
    final name = (cat.data()?['name'] as String?)?.trim() ?? '';
    if (name.isNotEmpty) {
      final used = await _db
          .collection('materials')
          .where('category', isEqualTo: name)
          .limit(1)
          .get();
      if (used.docs.isNotEmpty) {
        throw AppException(
          'Cannot delete "$name" while materials still use it. Deactivate the category instead.',
        );
      }
    }
    await _db.collection('categories').doc(id).delete();
    await _logAction(actionType: 'delete_category', targetType: 'category', targetId: id, description: 'Deleted category');
  }

  Future<void> settleSupplierCommissions({required String supplierUid, required String supplierName, required double unsettledAmount, required int orderCount}) async {
    final snap = await _db.collection('transactions').where('supplierUid', isEqualTo: supplierUid).where('status', isEqualTo: 'unsettled').get();
    if (snap.docs.isEmpty) return;
    final batch = _db.batch();
    for (final doc in snap.docs) { batch.update(doc.reference, {'status': 'settled', 'settledAt': FieldValue.serverTimestamp()}); }
    await batch.commit();
    await _logAction(actionType: 'settle_commission', targetType: 'supplier', targetId: supplierUid, description: 'Marked $orderCount commission transaction(s) as settled for $supplierName (Rs ${unsettledAmount.toStringAsFixed(0)})');
  }

  Stream<int> watchActiveUsersCount() => _db.collection('users').where('status', isEqualTo: 'active').snapshots().map((s) => s.docs.length);
  Stream<int> watchSuspendedUsersCount() => _db.collection('users').where('status', isEqualTo: 'suspended').snapshots().map((s) => s.docs.length);
  Stream<int> watchPendingUsersCount() => _db.collection('users').where('status', isEqualTo: 'pending').snapshots().map((s) => s.docs.length);
  Stream<List<CategoryModel>> watchCategories() => _db.collection('categories').snapshots().map((s) => s.docs.map((d) => CategoryModel.fromDoc(d.id, d.data())).where((c) => c.name.isNotEmpty).toList()..sort((a, b) => a.name.compareTo(b.name)));
}
