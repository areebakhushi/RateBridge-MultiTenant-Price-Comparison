// MVVM: ViewModel — business logic only
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../models/subscription_model.dart';
import '../models/order_model.dart';
import '../models/partnership_request_model.dart';
import '../models/company_model.dart';
import '../models/supplier_model.dart';
import '../repositories/order_repository.dart';
import '../repositories/partnership_request_repository.dart';
import '../repositories/user_repository.dart';
import '../repositories/company_repository.dart';
import '../repositories/invitation_repository.dart';
import '../services/cloud_function_service.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';
import '../constants/app_constants.dart';
import '../constants/firestore_paths.dart';
import '../utils/app_exception.dart';
import '../utils/invite_code_generator.dart';

class CeoViewModel extends ChangeNotifier {
  final String? _uid;
  final String _name;

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final PartnershipRequestRepository _partnershipRepo;
  final UserRepository _userRepo;
  final CompanyRepository _companyRepo;
  final InvitationRepository _invitationRepo;
  final OrderRepository _orderRepo;
  final NotificationService _notificationService;
  final StorageService _storageService = StorageService();

  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;
  CompanyModel? _company;
  List<SupplierModel> _marketplaceSuppliers = [];

  String? _partnershipWatchCompanyId;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      _partnershipRequestsSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      _linkedSuppliersSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      _marketplaceSuppliersSub;
  final Map<String, PartnershipRequestModel> _latestPartnershipBySupplierId = {};
  final Set<String> _activePartnerSupplierIds = {};
  List<PartnershipRequestModel> _receivedPartnershipRequests = [];
  List<PartnershipRequestModel> _sentPartnershipRequests = [];
  bool _partnershipRequestsReady = false;

  bool _appealSubmitted = false;
  bool get appealSubmitted => _appealSubmitted;

  CeoViewModel(
      this._uid,
      this._name,
      this._orderRepo,
      this._partnershipRepo,
      this._userRepo,
      this._companyRepo,
      this._invitationRepo,
      this._notificationService, [
        CloudFunctionService? cloudFunctionService
      ]) {
    if (_uid != null) {
      _loadCompanyData();
    }
  }

  String? get uid => _uid;
  String get name => _name;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;
  CompanyModel? get company => _company;
  List<SupplierModel> get marketplaceSuppliers => _marketplaceSuppliers;
  bool get partnershipRequestsReady => _partnershipRequestsReady;
  List<PartnershipRequestModel> get receivedPartnershipRequests =>
      List<PartnershipRequestModel>.unmodifiable(_receivedPartnershipRequests);
  List<PartnershipRequestModel> get sentPartnershipRequests =>
      List<PartnershipRequestModel>.unmodifiable(_sentPartnershipRequests);
  List<PartnershipRequestModel> get pendingReceivedPartnershipRequests =>
      _receivedPartnershipRequests
          .where((r) => r.status == 'pending')
          .toList(growable: false);

  /// CEO Sent partnership requests that are currently waiting for supplier approval.
  List<PartnershipRequestModel> get pendingSentPartnershipRequests =>
      _sentPartnershipRequests
          .where((r) => r.status == 'pending')
          .toList(growable: false);

  void clearAppealState() {
    _appealSubmitted = false;
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> submitAppeal(String message, File? file, String? phone) async {
    _errorMessage = null;
    _isLoading = true;
    notifyListeners();
    try {
      final existing = await _db.collection('appeals')
          .where('uid', isEqualTo: _uid)
          .where('status', isEqualTo: 'pending')
          .get();
      if (existing.docs.isNotEmpty) {
        _errorMessage = 'Your appeal is already under review.';
        return;
      }

      String? imageUrl;
      if (file != null) {
        imageUrl = await _storageService.uploadFile(file: file, path: 'appeals/$_uid');
      }

      final userDoc = _uid != null ? await _userRepo.getUserDoc(_uid!) : null;

      await _db.collection('appeals').add({
        'uid': _uid,
        'role': 'CEO',
        'name': userDoc?.name ?? 'CEO',
        'companyId': _company?.id ?? userDoc?.companyId ?? '',
        'message': message,
        'phone': phone,
        'imageUrl': imageUrl,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'pending',
        'rejectionReason': userDoc?.rejectionReason ?? '',
      });
      _appealSubmitted = true;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadCompanyData() async {
    final uid = _uid;
    if (uid == null) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final user = await _userRepo.getUserDoc(uid);
      String currentCompanyId = user.companyId;
      CompanyModel? companyDoc;

      if (currentCompanyId.isNotEmpty) {
        companyDoc = await _companyRepo.getCompanyById(currentCompanyId);
      }

      if (companyDoc == null) {
        final query = await _db.collection('companies')
            .where('ceoUid', isEqualTo: uid)
            .limit(1)
            .get();

        if (query.docs.isNotEmpty) {
          final doc = query.docs.first;
          final Map<String, dynamic> data = Map<String, dynamic>.from(doc.data());
          data['id'] = doc.id;
          companyDoc = CompanyModel.fromMap(data);

          if (currentCompanyId != doc.id) {
            await _userRepo.updateUserDoc(uid, {'companyId': doc.id});
          }
        }
      }

      if (companyDoc != null) {
        _company = companyDoc;
        ensurePartnershipStatusWatch(companyDoc.id);
        final companyActive =
            _company!.status.toLowerCase() == 'active';
        if (companyActive &&
            (_company!.inviteCode == null ||
                _company!.inviteCode!.isEmpty ||
                _company!.inviteCode == 'RB-XXXXXX')) {
          await regenerateInviteCode();
        }
      } else {
        _errorMessage = currentCompanyId.isEmpty
            ? "Account not associated with a company."
            : "Company profile not found.";
      }
    } catch (e) {
      _errorMessage = "Failed to load company details: ${e.toString()}";
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadDashboard() async => await _loadCompanyData();

  Future<void> regenerateInviteCode() async {
    final uid = _uid;
    if (_company == null || uid == null) return;
    _isLoading = true;
    notifyListeners();

    try {
      final oldKey = _company!.inviteCode;
      if (oldKey != null && oldKey.startsWith('RB-') && oldKey != 'RB-XXXXXX') {
        try { await _invitationRepo.updateStatus(oldKey, 'expired'); } catch (_) {}
      }

      final newKey = await _generateUniqueInviteCode();
      await _db.collection('companies').doc(_company!.id).update({
        'inviteCode': newKey,
        'inviteCodeGeneratedAt': FieldValue.serverTimestamp(),
      });

      _company = _company?.copyWith(
        inviteCode: newKey,
        inviteCodeGeneratedAt: DateTime.now(),
      );
      _successMessage = "New invite code generated.";
    } catch (e) {
      _errorMessage = "Failed to generate key.";
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<String> _generateUniqueInviteCode() async {
    for (var attempt = 0; attempt < 5; attempt++) {
      final candidate = InviteCodeGenerator.generate();
      final existing = await _db.collection('companies').where('inviteCode', isEqualTo: candidate).limit(1).get();
      if (existing.docs.isEmpty) return candidate;
    }
    return InviteCodeGenerator.generate(length: 8);
  }

  void clearMessages() {
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _marketplaceSuppliersSub?.cancel();
    _stopPartnershipStatusWatch();
    super.dispose();
  }

  void ensurePartnershipStatusWatch(String companyId) {
    if (companyId.isEmpty) return;
    if (_partnershipWatchCompanyId == companyId &&
        _partnershipRequestsSub != null) {
      return;
    }

    _stopPartnershipStatusWatch();
    _partnershipWatchCompanyId = companyId;

    _partnershipRequestsSub = _db
        .collection(FirestorePaths.partnershipRequestsCol)
        .where('companyId', isEqualTo: companyId)
        .snapshots()
        .listen(
      (snap) {
        final all = snap.docs
            .map((doc) => PartnershipRequestModel.fromMap(doc.id, doc.data()))
            .toList();

        _latestPartnershipBySupplierId.clear();
        final grouped = <String, List<PartnershipRequestModel>>{};
        for (final req in all) {
          grouped.putIfAbsent(req.supplierId, () => []).add(req);
        }
        for (final entry in grouped.entries) {
          entry.value.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          _latestPartnershipBySupplierId[entry.key] = entry.value.first;
        }

        _receivedPartnershipRequests = _sortPartnershipRequestsNewest(
          all.where((r) => r.initiatedBy == 'supplier'),
        );
        _sentPartnershipRequests = _sortPartnershipRequestsNewest(
          all.where((r) => r.initiatedBy == 'ceo'),
        );
        _partnershipRequestsReady = true;
        notifyListeners();
      },
      onError: (_) {
        _partnershipRequestsReady = true;
        _errorMessage = 'Failed to load partnership requests.';
        notifyListeners();
      },
    );

    _linkedSuppliersSub = _db
        .collection(FirestorePaths.companiesCol)
        .doc(companyId)
        .collection('suppliers')
        .snapshots()
        .listen(
      (snap) {
        _activePartnerSupplierIds
          ..clear()
          ..addAll(
            snap.docs.where((doc) {
              final status =
                  (doc.data()['status'] as String?)?.toLowerCase() ?? 'active';
              return status == 'active' || status == 'approved';
            }).map((doc) => doc.id),
          );
        notifyListeners();
      },
      onError: (_) {
        notifyListeners();
      },
    );
  }

  void _stopPartnershipStatusWatch() {
    _partnershipRequestsSub?.cancel();
    _linkedSuppliersSub?.cancel();
    _partnershipRequestsSub = null;
    _linkedSuppliersSub = null;
    _partnershipWatchCompanyId = null;
    _latestPartnershipBySupplierId.clear();
    _activePartnerSupplierIds.clear();
    _receivedPartnershipRequests = [];
    _sentPartnershipRequests = [];
    _partnershipRequestsReady = false;
  }

  List<PartnershipRequestModel> _sortPartnershipRequestsNewest(
    Iterable<PartnershipRequestModel> requests,
  ) {
    return List<PartnershipRequestModel>.from(requests)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  String? linkRejectionReasonFor(String supplierId) {
    if (supplierId.isEmpty) return null;
    final request = _latestPartnershipBySupplierId[supplierId];
    if (request?.status == 'rejected') {
      return request!.rejectionReason;
    }
    return null;
  }

  String linkStatusFor(String supplierId) {
    if (supplierId.isEmpty) return 'Not Invited';
    if (_activePartnerSupplierIds.contains(supplierId)) {
      return 'Already Partners';
    }

    final request = _latestPartnershipBySupplierId[supplierId];
    if (request == null) return 'Not Invited';

    switch (request.status) {
      case 'pending':
        return 'Request Pending';
      case 'accepted':
        return 'Already Partners';
      case 'rejected':
        return 'Request Rejected';
      case 'removed':
        return 'Not Invited';
      default:
        return 'Not Invited';
    }
  }

  // --- Real-time Streams ---

  Stream<UserModel?> watchCeoStatus() {
    final uid = _uid;
    if (uid == null) return Stream.value(null);
    return _db.collection('users').doc(uid).snapshots().map((doc) =>
    doc.exists ? UserModel.fromMap(doc.data() as Map<String, dynamic>) : null);
  }

  Stream<Map<String, dynamic>> watchDashboardStats(String companyId) {
    if (companyId.isEmpty) return Stream.value({});

    return _db.collection('companies').doc(companyId).snapshots().asyncMap((doc) async {
      if (!doc.exists) return {};

      final suppliers = await _db.collection('companies').doc(companyId).collection('suppliers').where('status', isEqualTo: 'active').get();
      final team = await _db.collection('users').where('companyId', isEqualTo: companyId).where('role', isEqualTo: 'field_user').get();
      final partnershipPending = await _db
          .collection('partnershipRequests')
          .where('companyId', isEqualTo: companyId)
          .where('status', isEqualTo: 'pending')
          .where('initiatedBy', isEqualTo: 'supplier')
          .get();

      final pendingApprovals = await _db.collection('orders')
          .where('companyId', isEqualTo: companyId)
          .where('status', isEqualTo: 'pending_approval')
          .get();

      final sub = await _db.collection('subscriptions').doc(companyId).get();
      final plan = sub.exists ? (sub.data()?['plan'] ?? 'Free') : 'Free';
      final expiresAt = sub.exists ? (sub.data()?['expiresAt'] as Timestamp?)?.toDate() : null;

      final companyData = doc.data();

      return {
        'companyName': companyData?['name'] ?? 'Workspace',
        'inviteCode': companyData?['inviteCode'] ?? 'RB-XXXXXX',
        'plan': plan,
        'activeSupplierCount': suppliers.docs.length,
        'fieldUserCount': team.docs.length,
        'pendingJoinCount': partnershipPending.docs.length,
        'pendingOrderApprovals': pendingApprovals.docs.length,
        'expiresAt': expiresAt,
      };
    });
  }

  Stream<List<OrderModel>> watchCompanyOrders(String companyId, String status) {
    if (companyId.isEmpty) {
      return Stream.value(const []);
    }

    final uid = _uid;

    Query<Map<String, dynamic>> buildQuery({required bool withOrderBy}) {
      Query<Map<String, dynamic>> query =
          _db.collection('orders').where('companyId', isEqualTo: companyId);
      if (status != 'All') {
        final statuses = _orderStatusesForTab(status);
        if (statuses.length == 1) {
          query = query.where('status', isEqualTo: statuses.first);
        } else if (statuses.isNotEmpty) {
          query = query.where('status', whereIn: statuses);
        }
      }
      if (withOrderBy) {
        query = query.orderBy('createdAt', descending: true);
      }
      return query;
    }

    return buildQuery(withOrderBy: true).snapshots().transform(
      StreamTransformer.fromHandlers(
        handleData: (snap, sink) {
          var orders = snap.docs
              .map((doc) => OrderModel.fromMap(doc.id, doc.data()))
              .toList();
          if (uid != null) {
            orders = orders.where((o) => !o.hiddenBy.contains(uid)).toList();
          }
          orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          sink.add(orders);
        },
        handleError: (error, stackTrace, sink) async {
          if (error is FirebaseException &&
              error.code == 'failed-precondition') {
            try {
              final snap = await buildQuery(withOrderBy: false).get();
              var orders = snap.docs
                  .map((doc) => OrderModel.fromMap(doc.id, doc.data()))
                  .toList();
              if (uid != null) {
                orders = orders.where((o) => !o.hiddenBy.contains(uid)).toList();
              }
              orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
              sink.add(orders);
              return;
            } catch (_) {}
          }
          sink.addError(error, stackTrace);
        },
      ),
    );
  }

  List<String> _orderStatusesForTab(String tabLabel) {
    switch (tabLabel) {
      case 'Pending':
        return [
          AppConstants.statusPendingApproval,
          AppConstants.statusPending,
          AppConstants.statusAccepted,
          AppConstants.statusInProgress,
          AppConstants.statusDelivered,
        ];
      case 'Confirmed':
        return [AppConstants.statusConfirmed];
      case 'Cancelled':
        return [
          AppConstants.statusCancelled,
          AppConstants.statusRejected,
        ];
      default:
        // Attempt to match by name if not one of the custom grouped labels
        return [tabLabel.toLowerCase().replaceAll(' ', '_')];
    }
  }

  Future<void> approveOrder(OrderModel order) async {
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
    try {
      if (order.status != AppConstants.statusPendingApproval) {
        throw Exception('Only orders awaiting approval can be approved.');
      }
      await _orderRepo.updateStatus(
        order.orderId,
        order.companyId,
        AppConstants.statusPending,
      );
      await _notificationService.notifyNewOrder(
        supplierId: order.supplierId,
        orderId: order.orderId,
        companyId: order.companyId,
        materialName: order.materialName,
        fieldUserName: order.fieldUserName,
      );
      _successMessage = 'Order approved and sent to supplier.';
    } catch (e) {
      _errorMessage = 'Failed to approve order: $e';
    }
    notifyListeners();
  }

  Future<void> rejectOrder(OrderModel order, {String reason = ''}) async {
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
    try {
      if (order.status != AppConstants.statusPendingApproval) {
        throw Exception('Only orders awaiting approval can be rejected.');
      }
      await _orderRepo.updateStatus(
        order.orderId,
        order.companyId,
        AppConstants.statusRejected,
        reason: reason.trim().isEmpty ? 'Rejected by CEO' : reason.trim(),
      );
      await _notificationService.notifyOrderRejected(
        fieldUserUid: order.fieldUserUid,
        orderId: order.orderId,
        companyId: order.companyId,
        materialName: order.materialName,
        supplierName: order.supplierName,
        reason: reason.trim().isEmpty ? 'Rejected by company approval' : reason.trim(),
      );
      _successMessage = 'Order rejected.';
    } catch (e) {
      _errorMessage = 'Failed to reject order: $e';
    }
    notifyListeners();
  }

  // --- Marketplace Implementation ---

  final List<String> _marketplaceStatuses = ['Active', 'active'];

  bool _isActiveMarketplaceSupplier(String status) {
    final normalized = status.trim().toLowerCase();
    return normalized == 'active';
  }

  List<SupplierModel> _suppliersFromDocs(Iterable<QueryDocumentSnapshot> docs) {
    final suppliers = <SupplierModel>[];
    for (final doc in docs) {
      try {
        final raw = doc.data();
        if (raw is! Map) continue;
        final data = Map<String, dynamic>.from(raw);
        data['id'] = doc.id;
        final supplier = SupplierModel.fromMap(data);
        if (_isActiveMarketplaceSupplier(supplier.status) &&
            !supplier.commissionRestricted) {
          suppliers.add(supplier);
        }
      } catch (_) {}
    }
    return suppliers;
  }

  Future<List<SupplierModel>> _fetchMarketplaceSuppliers() async {
    try {
      final snap = await _db
          .collection('suppliers')
          .where('status', whereIn: _marketplaceStatuses)
          .get();
      return _suppliersFromDocs(snap.docs);
    } catch (_) {
      final snap = await _db.collection('suppliers').get();
      return _suppliersFromDocs(snap.docs);
    }
  }

  Future<void> loadMarketplace() async {
    final companyId = _company?.id;
    if (companyId != null && companyId.isNotEmpty) {
      ensurePartnershipStatusWatch(companyId);
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    _marketplaceSuppliersSub?.cancel();
    try {
      _marketplaceSuppliersSub = _db
          .collection('suppliers')
          .where('status', whereIn: _marketplaceStatuses)
          .snapshots()
          .listen(
        (snap) {
          _marketplaceSuppliers = _suppliersFromDocs(snap.docs);
          _isLoading = false;
          notifyListeners();
        },
        onError: (_) {
          _fetchMarketplaceSuppliers().then((suppliers) {
            _marketplaceSuppliers = suppliers;
            _isLoading = false;
            notifyListeners();
          });
        },
      );
    } catch (e) {
      _errorMessage = 'Failed to load marketplace. Please try again.';
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> searchSuppliers(String queryText) async {
    if (queryText.isEmpty) {
      return loadMarketplace();
    }
    _isLoading = true;
    notifyListeners();
    try {
      final lowercaseQuery = queryText.toLowerCase().trim();
      
      Query query = _db.collection('suppliers').where('status', whereIn: _marketplaceStatuses);

      // Support search by email directly if it looks like one
      if (lowercaseQuery.contains('@')) {
        query = query.where('email', isEqualTo: lowercaseQuery);
      } else {
        // Range filter on business name
        query = query.where('businessName', isGreaterThanOrEqualTo: queryText)
                     .where('businessName', isLessThanOrEqualTo: '$queryText\uf8ff');
      }

      final snap = await query.get();
      _marketplaceSuppliers = _suppliersFromDocs(snap.docs);
    } catch (_) {
      try {
        _marketplaceSuppliers = await _fetchMarketplaceSuppliers();
      } catch (_) {
        _errorMessage = 'Search failed. Note: Searching by name is case-sensitive.';
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> applyFilters({String? city, String? category, bool? verifiedOnly}) async {
    _isLoading = true;
    notifyListeners();
    try {
      Query query = _db.collection('suppliers').where('status', whereIn: _marketplaceStatuses);

      if (city != null && city != 'All') {
        query = query.where('city', isEqualTo: city);
      }
      if (category != null && category != 'All') {
        query = query.where('materialType', isEqualTo: category);
      }
      if (verifiedOnly == true) {
        query = query.where('isVerified', isEqualTo: true);
      }

      final snap = await query.get();
      _marketplaceSuppliers = _suppliersFromDocs(snap.docs);
    } catch (_) {
      try {
        final all = await _fetchMarketplaceSuppliers();
        _marketplaceSuppliers = all.where((supplier) {
          if (city != null && city != 'All' && supplier.city != city) {
            return false;
          }
          if (category != null &&
              category != 'All' &&
              supplier.materialType != category) {
            return false;
          }
          if (verifiedOnly == true && !supplier.isVerified) return false;
          return true;
        }).toList();
      } catch (_) {
        _errorMessage = 'Failed to apply filters. Please try again.';
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> sortSuppliers(String criteria) async {
    if (criteria == 'Rating') {
      _marketplaceSuppliers.sort((a, b) => b.rating.compareTo(a.rating));
    } else if (criteria == 'Name') {
      _marketplaceSuppliers.sort((a, b) => a.name.compareTo(b.name));
    }
    notifyListeners();
  }

  Future<void> sendPartnershipRequest(
    String supplierId, {
    String? message,
  }) async {
    final company = _company;
    if (company == null || supplierId.isEmpty) return;

    final plan = kPlans.firstWhere((p) => p.planKey == company.plan,
        orElse: () => kPlans.first);
    if (plan.maxSuppliers != -1 &&
        _activePartnerSupplierIds.length >= plan.maxSuppliers) {
      _errorMessage =
          'Supplier limit reached for your ${plan.name} plan (${plan.maxSuppliers}). Please upgrade for more connections.';
      notifyListeners();
      return;
    }

    try {
      final supplierDoc =
          await _db.collection('suppliers').doc(supplierId).get();
      if (!supplierDoc.exists) return;
      final supplierData = supplierDoc.data()!;

      final requestId = await _partnershipRepo.createRequest(
        companyId: company.id,
        companyName: company.name,
        supplierId: supplierId,
        supplierName:
            supplierData['name'] ?? supplierData['businessName'] ?? 'Supplier',
        initiatedBy: 'ceo',
        message: message,
        supplierEmail: supplierData['email'] as String?,
        supplierCity: supplierData['city'] as String?,
        supplierCategories: supplierData['categories'] is List
            ? List<String>.from(supplierData['categories'])
            : const [],
        supplierRating: (supplierData['rating'] as num? ?? 0).toDouble(),
      );

      await _notificationService.notifyPartnershipInvitation(
        recipientUserId: supplierId,
        companyName: company.name,
        requestId: requestId,
        companyId: company.id,
      );

      _successMessage = 'Partnership request sent successfully.';
    } on AppException catch (e) {
      _errorMessage = e.message;
    } catch (e) {
      _errorMessage = 'Failed to send partnership request. Please try again.';
    }
    notifyListeners();
  }

  @Deprecated('Use sendPartnershipRequest')
  Future<void> sendInvitation(String supplierId) =>
      sendPartnershipRequest(supplierId);

  @Deprecated('Use receivedPartnershipRequests / sentPartnershipRequests')
  Stream<List<PartnershipRequestModel>> watchPartnershipRequests(
    String companyId,
    String type,
  ) {
    if (companyId.isEmpty) return Stream.value(const []);
    ensurePartnershipStatusWatch(companyId);
    final list = type == 'Sent'
        ? _sentPartnershipRequests
        : _receivedPartnershipRequests;
    return Stream.value(List<PartnershipRequestModel>.from(list));
  }

  @Deprecated('Use receivedPartnershipRequests / sentPartnershipRequests')
  Stream<List<PartnershipRequestModel>> watchJoinRequests(
    String companyId,
    String type,
  ) =>
      watchPartnershipRequests(companyId, type);

  Future<void> acceptPartnershipRequest(String reqId) async {
    final company = _company;
    if (company != null) {
      final plan = kPlans.firstWhere((p) => p.planKey == company.plan,
          orElse: () => kPlans.first);
      if (plan.maxSuppliers != -1 &&
          _activePartnerSupplierIds.length >= plan.maxSuppliers) {
        _errorMessage =
            'Supplier limit reached for your ${plan.name} plan (${plan.maxSuppliers}). Please upgrade to accept more partnerships.';
        notifyListeners();
        return;
      }
    }

    try {
      final reqSnap = await _db
          .collection(FirestorePaths.partnershipRequestsCol)
          .doc(reqId)
          .get();
      final reqData = reqSnap.data();
      await _partnershipRepo.acceptRequest(reqId);
      if (reqData != null &&
          PartnershipRequestModel.fromMap(reqId, reqData).isSupplierInitiated) {
        await _notificationService.notifyPartnershipAccepted(
          recipientUserId: reqData['supplierId'] as String,
          senderName: _company?.name ?? reqData['companyName'] as String? ?? '',
          companyId: reqData['companyId'] as String,
        );
      }
      _successMessage = 'Partnership accepted.';
    } on AppException catch (e) {
      _errorMessage = e.message;
    } catch (_) {
      _errorMessage = 'Failed to accept partnership. Please try again.';
    }
    notifyListeners();
  }

  Future<void> acceptJoinRequest(String reqId, String supplierUid) async {
    await acceptPartnershipRequest(reqId);
  }

  Future<void> rejectPartnershipRequest(String reqId, String reason) async {
    try {
      final reqSnap = await _db
          .collection(FirestorePaths.partnershipRequestsCol)
          .doc(reqId)
          .get();
      final reqData = reqSnap.data();
      await _partnershipRepo.rejectRequest(reqId, reason);
      if (reqData != null &&
          PartnershipRequestModel.fromMap(reqId, reqData).isSupplierInitiated) {
        await _notificationService.notifyPartnershipDeclined(
          recipientUserId: reqData['supplierId'] as String,
          senderName: _company?.name ?? reqData['companyName'] as String? ?? '',
          companyId: reqData['companyId'] as String,
        );
      }
      _successMessage = 'Partnership request rejected.';
    } on AppException catch (e) {
      _errorMessage = e.message;
    } catch (_) {
      _errorMessage = 'Failed to reject partnership. Please try again.';
    }
    notifyListeners();
  }

  Future<void> rejectJoinRequest(String reqId, String reason) async {
    await rejectPartnershipRequest(reqId, reason);
  }

  Future<void> withdrawPartnershipRequest(String requestId) async {
    try {
      await _partnershipRepo.withdrawRequest(requestId);
      _successMessage = 'Partnership request withdrawn.';
    } on AppException catch (e) {
      _errorMessage = e.message;
    } catch (e) {
      _errorMessage = 'Failed to withdraw partnership request: $e';
    }
    notifyListeners();
  }

  Stream<List<Map<String, dynamic>>> watchMySuppliers(String companyId) {
    return _db.collection('companies').doc(companyId).collection('suppliers')
        .snapshots().map((snap) => snap.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList());
  }

  Future<void> removeSupplier(String supplierId) async {
    final company = _company;
    if (company == null) return;
    try {
      await _partnershipRepo.removePartnership(
        companyId: company.id,
        supplierId: supplierId,
      );
      await _notificationService.notifyPartnershipRemoved(
        recipientUserId: supplierId,
        companyName: company.name,
        companyId: company.id,
      );
      _successMessage = 'Partnership removed.';
    } catch (e) {
      _errorMessage = 'Failed to remove partnership: $e';
    }
    notifyListeners();
  }

  Future<void> reactivateFieldUser(String uid) async {
    await _db.collection('users').doc(uid).update({'status': 'active'});
  }

  Future<void> loadCompanyProfile() async {
    await _loadCompanyData();
  }

  Future<void> updateCompanyProfile(Map<String, dynamic> data) async {
    final company = _company;
    if (company == null) return;
    await _db.collection('companies').doc(company.id).update(data);
    await _loadCompanyData();
  }

  Stream<List<UserModel>> watchFieldUsers(String companyId, String filter) {
    Query query = _db.collection('users')
        .where('companyId', isEqualTo: companyId)
        .where('role', isEqualTo: 'field_user');

    if (filter != 'All') {
      query = query.where('status', isEqualTo: filter.toLowerCase());
    }

    return query.snapshots().map((snap) => snap.docs.map((doc) =>
        UserModel.fromMap(doc.data() as Map<String, dynamic>)).toList());
  }

  Future<void> approveFieldUser(String uid) async =>
      await _db.collection('users').doc(uid).update({'status': 'active', 'approved': true, 'approvedAt': FieldValue.serverTimestamp()});

  Future<void> rejectFieldUser(String uid, String reason) async =>
      await _db.collection('users').doc(uid).update({'status': 'rejected', 'rejectionReason': reason});

  Future<void> deactivateFieldUser(String uid) async =>
      await _db.collection('users').doc(uid).update({'status': 'deactivated'});

  /// Activates or deactivates a linked supplier for this company.
  Future<void> toggleSupplierStatus(
      String supplierId, String companyId, bool activate) async {
    try {
      final newStatus = activate ? 'active' : 'deactivated';
      await _db
          .collection('companies')
          .doc(companyId)
          .collection('suppliers')
          .doc(supplierId)
          .update({'status': newStatus});
      _successMessage =
      activate ? 'Supplier activated.' : 'Supplier deactivated.';
    } catch (e) {
      _errorMessage = 'Failed to update supplier status: $e';
    }
    notifyListeners();
  }

  /// Cancels a pending or accepted order.
  Future<void> cancelOrder(String orderId, String companyId) async {
    try {
      await _db
          .collection('companies')
          .doc(companyId)
          .collection('orders')
          .doc(orderId)
          .update({'status': 'cancelled'});

      // Mirror on root orders collection if you use one
      await _db
          .collection('orders')
          .doc(orderId)
          .update({'status': 'cancelled'}).catchError((_) {});

      _successMessage = 'Order cancelled.';
    } catch (e) {
      _errorMessage = 'Failed to cancel order: $e';
    }
    notifyListeners();
  }

  /// Soft-deletes a single order from history.
  Future<void> hideOrder(String orderId) async {
    final uid = _uid;
    if (uid == null) return;
    try {
      await _orderRepo.hideOrderForUser(orderId, uid);
      _successMessage = 'Order removed from history.';
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  /// Bulk soft-deletes orders.
  Future<void> hideOrders(List<String> orderIds) async {
    final uid = _uid;
    if (uid == null) return;
    try {
      await _orderRepo.hideOrdersForUser(orderIds, uid);
      _successMessage = 'Orders removed from history.';
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }
}
