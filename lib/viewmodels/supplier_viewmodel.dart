// MVVM: ViewModel — business logic only
import 'dart:async';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import '../models/rfq_model.dart';
import '../models/rfq_bid_model.dart';
import '../models/material_model.dart';
import '../models/order_model.dart';
import '../models/rating_model.dart';
import '../models/transaction_model.dart';
import '../models/payment_proof_model.dart';
import '../constants/app_constants.dart';
import '../constants/firestore_paths.dart';
import '../models/company_model.dart';
import '../models/user_model.dart';
import '../models/invitation_model.dart';
import '../repositories/material_repository.dart';
import '../repositories/order_repository.dart';
import '../repositories/transaction_repository.dart';
import '../repositories/price_history_repository.dart';
import '../repositories/user_repository.dart';
import '../repositories/company_repository.dart';
import '../models/partner_company_stats.dart';
import '../models/partnership_request_model.dart';
import '../repositories/partnership_request_repository.dart';
import '../services/cloudinary_service.dart';
import '../utils/app_exception.dart';
import '../services/storage_service.dart';
import '../services/cloud_function_service.dart';
import '../services/notification_service.dart';
import 'auth_viewmodel.dart';

enum SupplierStatus { unknown, pending, rejected, active }

class SupplierViewModel extends ChangeNotifier {
  final MaterialRepository _materialRepo;
  final OrderRepository _orderRepo;
  final TransactionRepository _transactionRepo;
  final StorageService _storageService;
  final UserRepository _userRepo;
  final CompanyRepository _companyRepo;
  final PartnershipRequestRepository _partnershipRepo;
  final NotificationService _notificationService;
  final CloudFunctionService _cloudFunctions;
  final FirebaseFirestore _db;
  final Future<String?> Function({
    required List<int> bytes,
    required String folder,
    String filename,
  }) _uploadImageBytes;

  SupplierViewModel(
    this._materialRepo,
    this._orderRepo,
    this._transactionRepo,
    this._storageService,
    PriceHistoryRepository _,
    this._cloudFunctions,
    this._userRepo,
    this._companyRepo,
    this._partnershipRepo,
    this._notificationService, {
    FirebaseFirestore? firestore,
    Future<String?> Function({
      required List<int> bytes,
      required String folder,
      String filename,
    })? uploadImageBytes,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _uploadImageBytes = uploadImageBytes ?? CloudinaryService.uploadImageBytes;

  static String monthKey([DateTime? date]) =>
      DateFormat('yyyy-MM').format(date ?? DateTime.now());

  String? _supplierUid;
  String? _selectedCompanyId;
  String? _rejectionReason;
  String? _error;
  String? _successMessage;
  bool _isLoading = false;
  bool _appealSubmitted = false;

  List<MaterialModel> _materials = [];
  List<OrderModel> _orders = [];
  List<RatingModel> _ratings = [];
  List<TransactionModel> _transactions = [];
  List<TransactionModel> _allCommissions = [];
  List<PaymentProofModel> _confirmedCommissionPayments = [];
  List<PaymentProofModel> _pendingCommissionPayments = [];
  
  List<CompanyModel> _companies = [];
  List<CompanyModel> _companyDirectory = [];
  List<CompanyModel> _allCompanyDirectory = [];
  String _directorySearchQuery = '';
  String? _directoryCityFilter;
  List<OrderModel> _allSupplierOrders = [];
  List<TransactionModel> _allSupplierTransactions = [];
  List<RatingModel> _allSupplierRatings = [];
  bool _partnershipHubDataLoaded = false;
  bool _commissionRestricted = false;
  String? _commissionRestrictionReason;
  List<InvitationModel> _invitations = [];
  List<MonthlyEarning> _monthlyEarnings = [];
  UserModel? _profile;
  String _status = 'pending';

  StreamSubscription? _statusSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _partnershipRequestsSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _linkedCompaniesSub;
  List<PartnershipRequestModel> _allPartnershipRequests = [];
  final Map<String, PartnershipRequestModel> _latestPartnershipByCompanyId = {};
  final Set<String> _activePartnerCompanyIds = {};
  List<PartnershipRequestModel> _incomingPartnershipRequests = [];
  List<PartnershipRequestModel> _outgoingPartnershipRequests = [];
  bool _partnershipListsReady = false;
  StreamSubscription? _companiesSubscription;
  StreamSubscription? _materialsSubscription;
  StreamSubscription? _ordersSubscription;
  StreamSubscription? _commissionsSub;
  StreamSubscription? _paymentsSub;
  StreamSubscription? _invitationsSubscription;
  StreamSubscription? _ratingsSubscription;
  StreamSubscription? _supplierRestrictionSub;

  bool _isDashboardLoading = false;
  bool _companiesLoaded = false;
  bool _companiesLoadFailed = false;
  bool _materialsInitialized = false;
  bool _ordersInitialized = false;
  bool _earningsInitialized = false;
  bool _ratingsInitialized = false;

  // --- Getters ---
  String? get supplierUid => _supplierUid;
  String? get selectedCompanyId => _selectedCompanyId;
  String? get rejectionReason => _rejectionReason;
  String? get error => _error;
  String? get successMessage => _successMessage;
  bool get isLoading => _isLoading;
  bool get partnershipListsReady => _partnershipListsReady;
  
  // Public exposure for View files
  List<MaterialModel> get materials => _materials;
  List<OrderModel> get orders => _orders;
  List<RatingModel> get ratings => _ratings;
  List<TransactionModel> get transactions => _transactions;
  List<CompanyModel> get companies => _companies;
  List<CompanyModel> get companyDirectory => _companyDirectory;
  bool get isDashboardLoading => _isDashboardLoading;
  bool get companiesLoaded => _companiesLoaded;
  bool get companiesLoadFailed => _companiesLoadFailed;
  bool get appealSubmitted => _appealSubmitted;
  UserModel? get profile => _profile;
  String get status => _status;

  List<PartnershipRequestModel> get incomingPartnershipRequests => List<PartnershipRequestModel>.unmodifiable(_incomingPartnershipRequests);
  List<PartnershipRequestModel> get outgoingPartnershipRequests => List<PartnershipRequestModel>.unmodifiable(_outgoingPartnershipRequests);
  List<PartnershipRequestModel> get allPartnershipRequests => List<PartnershipRequestModel>.unmodifiable(_allPartnershipRequests);
  List<PartnershipRequestModel> get pendingCeoInvitations => _allPartnershipRequests.where((r) => r.isCeoInitiated && r.status == 'pending').toList();
  List<PartnershipRequestModel> get pendingSupplierSentRequests => _allPartnershipRequests.where((r) => r.isSupplierInitiated && r.status == 'pending').toList();
  List<PartnershipRequestModel> get pastPartnershipRequests => _allPartnershipRequests.where((r) => r.status == 'rejected' || r.status == 'removed').take(10).toList();
  int get pendingPartnershipRequestsCount => _allPartnershipRequests.where((r) => r.status == 'pending').length;
  List<CompanyModel> get activePartnerCompanies => List<CompanyModel>.unmodifiable(_companies);
  bool get partnershipHubDataLoaded => _partnershipHubDataLoaded;
  bool get isCommissionRestricted => _commissionRestricted;
  String? get commissionRestrictionReason => _commissionRestrictionReason;
  List<PaymentProofModel> get paymentHistory => [..._confirmedCommissionPayments, ..._pendingCommissionPayments]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  List<InvitationModel> get invitations => _invitations;
  List<MonthlyEarning> get monthlyEarnings => _monthlyEarnings;

  // --- Commission Ledger Getters ---
  double get totalCommissionGenerated => _allCommissions.fold(0.0, (sum, tx) => sum + tx.commissionAmount);
  double get totalCommissionPaid => _confirmedCommissionPayments.fold(0.0, (sum, p) => sum + p.amount);
  double get commissionOwed {
    final owed = totalCommissionGenerated - totalCommissionPaid;
    return owed < 0.01 ? 0 : owed;
  }
  double get pendingCommissionApproval => _pendingCommissionPayments.fold(0.0, (sum, p) => sum + p.amount);

  // --- Stats and Aggregates ---
  double get totalEarnings => _orders.where((o) => o.status == 'confirmed').fold(0.0, (sum, o) => sum + o.totalAmount);
  double get netEarnings => totalEarnings * (1 - AppConstants.commissionRate);
  
  double grossSalesForMonth(String month) {
    final start = DateTime.parse('$month-01');
    final end = DateTime(start.month == 12 ? start.year + 1 : start.year, start.month == 12 ? 1 : start.month + 1, 1);
    return _orders.where((o) {
      final s = o.status.toLowerCase().trim();
      if (s != 'confirmed') return false;
      final date = o.confirmedAt ?? o.createdAt;
      return !date.isBefore(start) && date.isBefore(end);
    }).fold(0.0, (sum, o) => sum + o.totalAmount);
  }

  double netEarningsForMonth(String month) {
    return grossSalesForMonth(month) * (1 - AppConstants.commissionRate);
  }

  int get totalMaterialsCount => _materials.length;
  int get pendingOrdersCount => _orders.where((o) {
    final s = o.status.toLowerCase().trim();
    return s == 'pending' || s == 'pending_approval';
  }).length;
  int get activeOrdersCount => _orders.where((o) {
    final s = o.status.toLowerCase().trim();
    return s == 'accepted' || s == 'inprogress';
  }).length;
  int get ratingsCount => _ratings.length;
  double get averageRating {
    if (_ratings.isEmpty) return 0.0;
    return _ratings.fold<double>(0, (acc, r) => acc + r.rating) / _ratings.length;
  }
  
  List<OrderModel> get recentOrders {
    final sorted = List<OrderModel>.from(_orders)..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sorted.take(5).toList();
  }
  List<MaterialModel> get recentMaterials {
    final sorted = List<MaterialModel>.from(_materials)..sort((a, b) {
      final aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });
    return sorted.take(3).toList();
  }

  MaterialModel? materialById(String id) {
    if (id.isEmpty) return null;
    for (final material in _materials) {
      if (material.id == id) return material;
    }
    return null;
  }

  Future<MaterialModel?> fetchMaterialById(String id) {
    if (id.isEmpty) return Future.value(null);
    return _materialRepo.getMaterialById(id);
  }

  double get monthlyEarningsTotal => netEarningsForMonth(monthKey());
  int get completedThisMonth => _orders.where((o) => o.status == 'confirmed' && o.createdAt.month == DateTime.now().month).length;

  void updateAuth(AuthViewModel auth) {
    final newUid = auth.user?.uid;
    if (_supplierUid == newUid) {
      if (newUid != null && auth.user != null) {
        _profile = auth.user;
        _status = auth.user!.status ?? 'pending';
        _rejectionReason = auth.user!.rejectionReason;
      }
      return;
    }

    _cancelSubscriptions();
    _supplierUid = newUid;
    _error = null;
    _companiesLoaded = false;
    _companiesLoadFailed = false;
    _selectedCompanyId = null;
    _companies = [];

    if (_supplierUid != null) {
      _profile = auth.user;
      _status = auth.user?.status ?? 'pending';
      _rejectionReason = auth.user?.rejectionReason;
      _ensureAuthAndLoad();
    }
    notifyListeners();
  }

  Future<void> _ensureAuthAndLoad() async {
    final uid = _supplierUid;
    if (uid == null) return;
    ensurePartnershipStatusWatch();
    loadLinkedCompanies();
    loadInvitations();
    loadNotificationPreferences();
    _ensureSupplierRestrictionWatch();
    _startEarningsStreams();
    watchStatus();
  }

  void _startEarningsStreams() {
    final uid = _supplierUid;
    if (uid == null) return;

    _commissionsSub?.cancel();
    _commissionsSub = _db.collection(FirestorePaths.transactionsCol)
        .where('supplierUid', isEqualTo: uid)
        .snapshots().listen((snap) {
          _allCommissions = snap.docs
              .map((d) => TransactionModel.fromMap(d.id, d.data()))
              .where((tx) => !tx.hiddenBy.contains(uid))
              .toList();
          _earningsInitialized = true;
          _checkDashboardReady();
          notifyListeners();
        }, onError: (e) => _onDashboardStreamError('earnings', e));

    _paymentsSub?.cancel();
    _paymentsSub = _db.collection('payment_proofs')
        .where('payerId', isEqualTo: uid)
        .where('type', isEqualTo: 'commission')
        .snapshots().listen((snap) {
          final all = snap.docs
              .map((d) => PaymentProofModel.fromMap(d.id, d.data()))
              .where((p) => !p.hiddenBy.contains(uid))
              .toList();
          _confirmedCommissionPayments = all.where((p) => p.status == 'confirmed' || p.status == 'approved' || p.status == 'settled').toList();
          _pendingCommissionPayments = all.where((p) => p.status == 'pending').toList();
          notifyListeners();
        });

    _db.collection('commission_ensure_jobs').doc(uid).set({
      'uid': uid,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true)).catchError((e) {
      debugPrint('Commission ensure job skipped: $e');
    });
    _backfillMissingCommissionTransactions(uid);
  }

  Future<void> _backfillMissingCommissionTransactions(String uid) async {
    try {
      final snap = await _db
          .collection('orders')
          .where('supplierId', isEqualTo: uid)
          .get();
      for (final doc in snap.docs) {
        final data = doc.data();
        final status = (data['status'] ?? '').toString().toLowerCase().trim();
        if (status != 'confirmed') continue;
        final totalAmount = (data['totalAmount'] as num?)?.toDouble() ?? 0;
        if (totalAmount <= 0) continue;
        final commissionAmount = totalAmount * AppConstants.commissionRate;
        await _transactionRepo.createUnsettledCommissionTransaction(
          orderId: doc.id,
          companyId: (data['companyId'] ?? '').toString(),
          supplierUid: uid,
          totalAmount: totalAmount,
          commissionAmount: commissionAmount,
          supplierEarning: totalAmount - commissionAmount,
        );
      }
    } catch (e) {
      debugPrint('Commission transaction backfill skipped: $e');
    }
  }

  Future<void> retryInitialLoad() async {
    if (_supplierUid == null) return;
    _error = null;
    _companiesLoaded = false;
    _companiesLoadFailed = false;
    notifyListeners();
    await _ensureAuthAndLoad();
  }

  void _ensureSupplierRestrictionWatch() {
    final uid = _supplierUid;
    if (uid == null) return;
    _supplierRestrictionSub?.cancel();
    _supplierRestrictionSub = _db.collection('suppliers').doc(uid).snapshots().listen((snap) {
        final data = snap.data();
        _commissionRestricted = data?['commissionRestricted'] == true;
        _commissionRestrictionReason = data?['commissionRestrictionReason'] as String?;
        notifyListeners();
      }, onError: (_) {});
  }

  static const Map<String, bool> defaultNotificationPrefs = {
    'pushEnabled': true, 'newOrders': true, 'orderUpdates': true,
    'chatMessages': true, 'ratings': true, 'earnings': true,
  };
  Map<String, bool> _notificationPrefs = Map<String, bool>.from(defaultNotificationPrefs);
  bool _notificationPrefsLoaded = false;
  bool _notificationPrefsSaving = false;
  bool get notificationPrefsLoaded => _notificationPrefsLoaded;
  bool get notificationPrefsSaving => _notificationPrefsSaving;
  Map<String, bool> get notificationPrefs => Map<String, bool>.unmodifiable(_notificationPrefs);

  Future<void> loadNotificationPreferences() async {
    if (_supplierUid == null) return;
    try {
      final snap = await _db.collection('users').doc(_supplierUid!).get();
      final raw = snap.data()?['notificationPreferences'];
      if (raw is Map) {
        _notificationPrefs = { for (final e in defaultNotificationPrefs.entries) e.key: raw[e.key] == true };
      }
      _notificationPrefsLoaded = true;
    } catch (e) {
      _error ??= e.toString();
      _notificationPrefsLoaded = true;
    }
    notifyListeners();
  }

  Future<String?> saveNotificationPreferences(Map<String, bool> prefs) async {
    if (_supplierUid == null) return 'Not signed in';
    _notificationPrefsSaving = true;
    notifyListeners();
    try {
      await _userRepo.updateUserDoc(_supplierUid!, {'notificationPreferences': prefs});
      _notificationPrefs = Map<String, bool>.from(prefs);
      return null;
    } catch (e) { return e.toString(); } finally {
      _notificationPrefsSaving = false;
      notifyListeners();
    }
  }

  void ensurePartnershipStatusWatch() {
    final supplierId = _supplierUid;
    if (supplierId == null || supplierId.isEmpty) return;
    if (_partnershipRequestsSub != null) return;

    _partnershipRequestsSub = _db.collection(FirestorePaths.partnershipRequestsCol)
        .where('supplierId', isEqualTo: supplierId).snapshots().listen((snap) {
            final all = snap.docs.map((doc) => PartnershipRequestModel.fromMap(doc.id, doc.data())).toList();
            _latestPartnershipByCompanyId.clear();
            final grouped = <String, List<PartnershipRequestModel>>{};
            for (final req in all) { grouped.putIfAbsent(req.companyId, () => []).add(req); }
            for (final entry in grouped.entries) {
              entry.value.sort((a, b) => b.createdAt.compareTo(a.createdAt));
              _latestPartnershipByCompanyId[entry.key] = entry.value.first;
            }
            _allPartnershipRequests = _sortPartnershipRequestsNewest(all);
            _incomingPartnershipRequests = _sortPartnershipRequestsNewest(all.where((r) => r.initiatedBy == 'ceo'));
            _outgoingPartnershipRequests = _sortPartnershipRequestsNewest(all.where((r) => r.initiatedBy == 'supplier'));
            _partnershipListsReady = true;
            notifyListeners();
          }, onError: (_) {
            _partnershipListsReady = true;
            _error = 'Failed to load partnership requests.';
            notifyListeners();
          });

    _linkedCompaniesSub = _db.collection(FirestorePaths.suppliersCol).doc(supplierId).collection('companies').snapshots().listen((snap) {
            _activePartnerCompanyIds..clear()..addAll(snap.docs.where((doc) {
                      final status = (doc.data()['status'] as String?)?.toLowerCase() ?? 'active';
                      return status == 'active' || status == 'approved';
                    }).map((doc) => doc.id));
            notifyListeners();
          }, onError: (_) => notifyListeners());
  }

  List<PartnershipRequestModel> _sortPartnershipRequestsNewest(Iterable<PartnershipRequestModel> requests) {
    return List<PartnershipRequestModel>.from(requests)..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  String? partnershipRejectionReasonFor(String companyId) => _latestPartnershipByCompanyId[companyId]?.status == 'rejected' ? _latestPartnershipByCompanyId[companyId]!.rejectionReason : null;
  String partnershipStatusFor(String companyId) {
    if (companyId.isEmpty) return 'Not Requested';
    if (_activePartnerCompanyIds.contains(companyId)) return 'Already Partners';
    final request = _latestPartnershipByCompanyId[companyId];
    if (request == null) return 'Not Requested';
    switch (request.status) {
      case 'pending': return 'Request Pending';
      case 'accepted': return 'Already Partners';
      case 'rejected': return 'Request Rejected';
      case 'removed': return 'Not Requested';
      default: return 'Not Requested';
    }
  }

  String directoryActionFor(String companyId) {
    if (_activePartnerCompanyIds.contains(companyId)) return 'Partners ✓';
    final request = _latestPartnershipByCompanyId[companyId];
    if (request?.status == 'pending') return request!.isCeoInitiated ? 'Respond' : 'Pending';
    if ((request?.status == 'rejected' || request?.status == 'removed') && canReapplyToCompany(companyId)) return 'Request Again';
    return 'Send Request';
  }

  bool canReapplyToCompany(String companyId) {
    final request = _latestPartnershipByCompanyId[companyId];
    if (request == null) return true;
    if (request.status != 'rejected' && request.status != 'removed') return false;
    final closedAt = request.respondedAt ?? request.createdAt;
    return DateTime.now().difference(closedAt).inDays >= 7;
  }

  String pastRequestStatusLabel(PartnershipRequestModel request) {
    if (request.status == 'removed') return 'Removed';
    if (request.status == 'rejected') return request.isSupplierInitiated ? 'Declined by Them' : 'You Declined';
    return request.status;
  }

  PartnerCompanyStats partnerStatsFor(String companyId) {
    final orders = _allSupplierOrders.where((o) => o.companyId == companyId).toList();
    final txs = _allSupplierTransactions.where((t) => t.companyId == companyId).toList();
    final orderIds = orders.map((o) => o.orderId).toSet();
    final companyRatings = _allSupplierRatings.where((r) => orderIds.contains(r.orderId)).toList();
    final earnings = txs.fold<double>(0, (sum, tx) => sum + tx.supplierEarning);
    final avgRating = companyRatings.isEmpty ? 0.0 : companyRatings.fold<double>(0, (sum, r) => sum + r.rating) / companyRatings.length;
    return PartnerCompanyStats(totalOrders: orders.length, avgRating: avgRating, totalEarnings: earnings);
  }

  Future<void> loadPartnershipHubData() async {
    ensurePartnershipStatusWatch();
    _partnershipHubDataLoaded = false;
    notifyListeners();
    try {
      await Future.wait([loadLinkedCompanies(), loadCompanyDirectory(), _loadAllSupplierOrders(), _loadAllSupplierTransactions(), _loadAllSupplierRatings()]);
    } finally {
      _partnershipHubDataLoaded = true;
      notifyListeners();
    }
  }

  Future<void> _loadAllSupplierOrders() async {
    if (_supplierUid == null) return;
    final snap = await _db.collection('orders').where('supplierId', isEqualTo: _supplierUid).get();
    _allSupplierOrders = snap.docs.map((doc) => OrderModel.fromMap(doc.id, doc.data())).toList();
  }

  Future<void> _loadAllSupplierTransactions() async {
    if (_supplierUid == null) return;
    final snap = await _db.collection('transactions').where('supplierId', isEqualTo: _supplierUid).get();
    _allSupplierTransactions = snap.docs.map((doc) => TransactionModel.fromMap(doc.id, doc.data())).toList();
  }

  Future<void> _loadAllSupplierRatings() async {
    if (_supplierUid == null) return;
    final snap = await _db.collection('ratings').where('supplierUid', isEqualTo: _supplierUid).get();
    _allSupplierRatings = snap.docs.map((doc) => RatingModel.fromMap(doc.id, doc.data())).toList();
  }

  void filterCompanyDirectoryByCity(String? city) {
    _directoryCityFilter = city;
    _applyCompanyDirectoryFilters();
  }

  void _applyCompanyDirectoryFilters() {
    var list = List<CompanyModel>.from(_allCompanyDirectory);
    final city = _directoryCityFilter;
    if (city != null && city != 'All' && city.isNotEmpty) list = list.where((c) => c.city == city).toList();
    final q = _directorySearchQuery;
    if (q.isNotEmpty) list = list.where((c) => c.name.toLowerCase().contains(q) || c.city.toLowerCase().contains(q)).toList();
    _companyDirectory = list;
    notifyListeners();
  }

  List<String> interestCategoriesFor(CompanyModel company) {
    final categories = <String>{};
    if (company.companyType != null && company.companyType!.isNotEmpty) categories.add(company.companyType!);
    return categories.take(3).toList();
  }

  void _onDashboardStreamError(String section, Object error) {
    _error = 'Some data failed to load ($section).';
    if (section == 'materials') _materialsInitialized = true;
    if (section == 'orders') _ordersInitialized = true;
    if (section == 'earnings') _earningsInitialized = true;
    if (section == 'ratings') _ratingsInitialized = true;
    _checkDashboardReady();
    notifyListeners();
  }
  void _checkDashboardReady() {
    if (_materialsInitialized && _ordersInitialized && _earningsInitialized && _ratingsInitialized) {
      _isDashboardLoading = false;
      notifyListeners();
    }
  }

  void watchStatus() {
    if (_supplierUid == null) return;
    _statusSubscription?.cancel();
    _statusSubscription = _userRepo.watchUserDoc(_supplierUid!).listen((user) {
            _status = user.status ?? 'pending';
            _rejectionReason = user.rejectionReason;
            notifyListeners();
          }, onError: (_) {});
  }

  Future<void> loadLinkedCompanies() async {
    if (_supplierUid == null) { _companiesLoaded = true; notifyListeners(); return; }
    _companiesSubscription?.cancel();
    _companiesLoadFailed = false;
    _companiesSubscription = _db.collection('suppliers').doc(_supplierUid).collection('companies').where('status', isEqualTo: 'active').snapshots().listen((snap) async {
            var list = <CompanyModel>[];
            for (var doc in snap.docs) {
              try { final c = await _companyRepo.getCompanyById(doc.id); if (c != null) list.add(c); } catch (_) {}
            }
            _companies = list;
            _companiesLoaded = true;
            _companiesLoadFailed = false;
            if (_selectedCompanyId == null && _companies.isNotEmpty) switchCompany(_companies.first.id);
            notifyListeners();
          }, onError: (e) {
            _companiesLoaded = true; _companiesLoadFailed = true; _error = e.toString();
            notifyListeners();
          });
  }

  void switchCompany(String companyId) {
    if (_selectedCompanyId == companyId) return;
    _selectedCompanyId = companyId;
    _error = null;
    _isDashboardLoading = true;
    loadMaterials(companyId);
    loadOrders(companyId, null);
    loadEarnings(monthKey());
    if (_supplierUid != null) loadRatings(_supplierUid!, companyId);
    _finishDashboardLoadingSoon();
    notifyListeners();
  }

  void _finishDashboardLoadingSoon() => Future.delayed(const Duration(milliseconds: 1000), () {
    _materialsInitialized = _ordersInitialized = _earningsInitialized = _ratingsInitialized = true;
    _isDashboardLoading = false;
    notifyListeners();
  });

  void loadInvitations() {
    if (_supplierUid == null) return;
    _invitationsSubscription?.cancel();
    _invitationsSubscription = _db.collection('invitations').where('supplierUid', isEqualTo: _supplierUid).snapshots().listen((snap) {
            _invitations = snap.docs.map((d) => InvitationModel.fromMap(d.id, d.data())).toList();
            notifyListeners();
          });
  }

  Future<void> acceptInvitation(String inviteId, String companyId) async {
    _isLoading = true; notifyListeners();
    try {
      await _cloudFunctions.callFunction('onInviteAccepted', {'token': inviteId, 'companyId': companyId, 'supplierUid': _supplierUid});
      _selectedCompanyId = companyId;
    } catch (e) { _error = e.toString(); } finally { _isLoading = false; notifyListeners(); }
  }

  Future<void> rejectInvitation(String inviteId) async => await _db.collection('invitations').doc(inviteId).update({'status': 'rejected'});

  Future<void> addMaterial(MaterialModel material, File? imageFile, String companyId) async {
    _isLoading = true; notifyListeners();
    try {
      String? imageUrl;
      if (imageFile != null) imageUrl = await CloudinaryService.uploadImage(filePath: imageFile.path, folder: 'ratebridge/materials');
      final newMat = material.copyWith(profileImageUrl: imageUrl, supplierId: _supplierUid);
      final batch = _db.batch();
      batch.set(_db.collection('companies').doc(companyId).collection('materials').doc(newMat.id), newMat.toMap());
      batch.set(_db.collection('materials').doc(newMat.id), newMat.toMap());
      await batch.commit();
      await _materialRepo.recordInitialMaterialPrice(materialId: newMat.id, price: newMat.pricePerUnit, supplierUid: _supplierUid);
    } catch (e) { _error = e.toString(); } finally { _isLoading = false; notifyListeners(); }
  }

  Future<void> updateMaterial(String matId, Map<String, dynamic> data, File? imageFile, String companyId) async {
    _isLoading = true; notifyListeners();
    try {
      if (imageFile != null) data['profileImageUrl'] = await CloudinaryService.uploadImage(filePath: imageFile.path, folder: 'ratebridge/materials');
      if (data.containsKey('pricePerUnit')) {
        final doc = await _db.collection('materials').doc(matId).get();
        final old = (doc.data()?['pricePerUnit'] as num?)?.toDouble() ?? 0.0;
        final newVal = (data['pricePerUnit'] as num).toDouble();
        if (old != newVal) await _materialRepo.archiveMaterialPriceChange(materialId: matId, previousPrice: old, newPrice: newVal, supplierUid: _supplierUid);
      }
      await _db.collection('materials').doc(matId).update(data);
      await _db.collection('companies').doc(companyId).collection('materials').doc(matId).update(data);
    } catch (e) { _error = e.toString(); } finally { _isLoading = false; notifyListeners(); }
  }

  Future<void> deleteMaterial(String matId, String companyId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      QuerySnapshot<Map<String, dynamic>> ordersSnap;
      try {
        ordersSnap = await _db
            .collection('orders')
            .where('materialId', isEqualTo: matId)
            .get();
      } catch (_) {
        ordersSnap = await _db
            .collection('orders')
            .where('supplierId', isEqualTo: _supplierUid)
            .get();
      }
      final related = ordersSnap.docs.where((doc) {
        return (doc.data()['materialId'] ?? '').toString() == matId;
      });
      const activeStatuses = {
        'pending',
        'pending_approval',
        'accepted',
        'delivered',
        'inprogress',
        'in_progress',
      };
      final activeCount = related.where((doc) {
        final status = (doc.data()['status'] ?? '').toString().trim().toLowerCase();
        return activeStatuses.contains(status);
      }).length;
      if (activeCount > 0) {
        throw AppException(
          'This material is used on $activeCount active order${activeCount == 1 ? '' : 's'}. Finish or cancel those orders before removing the listing.',
        );
      }

      await _db.collection('materials').doc(matId).delete();
      try {
        await _db
            .collection('companies')
            .doc(companyId)
            .collection('materials')
            .doc(matId)
            .delete();
      } catch (_) {}
      
      _successMessage = 'Material deleted successfully.';
    } catch (e) {
      _error = e is AppException ? e.message : e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMaterials(String companyId) async {
    if (_supplierUid == null) { _materialsInitialized = true; _checkDashboardReady(); notifyListeners(); return; }
    _materialsSubscription?.cancel();
    _materialsSubscription = _db.collection('companies').doc(companyId).collection('materials').where('supplierId', isEqualTo: _supplierUid).snapshots().listen((snap) {
          _materials = snap.docs.map((d) {
            final data = Map<String, dynamic>.from(d.data())..putIfAbsent('id', () => d.id);
            final material = MaterialModel.fromMap(data);
            return material;
          }).toList();
          _materialsInitialized = true; _checkDashboardReady(); notifyListeners();
        });
  }

  Future<void> loadOrders(String companyId, String? statusFilter) async {
    final uid = _supplierUid;
    if (uid == null) { _ordersInitialized = true; _checkDashboardReady(); notifyListeners(); return; }
    _ordersSubscription?.cancel();
    _ordersSubscription = _orderRepo.getOrdersForSupplier(uid, userId: uid).listen((data) {
        _orders = data.where((o) => o.companyId == companyId).toList();
        _ordersInitialized = true; _checkDashboardReady(); notifyListeners();
      });
  }

  Future<void> acceptOrder(String orderId, String companyId) async {
    _isLoading = true; notifyListeners();
    try {
      await _orderRepo.updateStatus(orderId, companyId, 'accepted');
      final order = _orders.firstWhere((o) => o.orderId == orderId);
      await _notificationService.notifyOrderAccepted(fieldUserUid: order.fieldUserUid, orderId: orderId, companyId: companyId, materialName: order.materialName, supplierName: order.supplierName);
    } catch (_) {} finally { _isLoading = false; notifyListeners(); }
  }

  Future<void> rejectOrder(String orderId, String companyId, String reason) async {
    _isLoading = true; notifyListeners();
    try {
      await _orderRepo.updateStatus(orderId, companyId, 'rejected', reason: reason);
      final order = _orders.firstWhere((o) => o.orderId == orderId);
      await _notificationService.notifyOrderRejected(fieldUserUid: order.fieldUserUid, orderId: orderId, companyId: companyId, materialName: order.materialName, supplierName: order.supplierName, reason: reason);
    } catch (_) {} finally { _isLoading = false; notifyListeners(); }
  }

  Future<void> markDelivered(String orderId, String companyId) async {
    _isLoading = true; notifyListeners();
    try {
      await _orderRepo.updateStatus(orderId, companyId, 'delivered', deliveredAt: DateTime.now());
      final order = _orders.firstWhere((o) => o.orderId == orderId);
      await _notificationService.notifyOrderDelivered(fieldUserUid: order.fieldUserUid, orderId: orderId, companyId: companyId, materialName: order.materialName, supplierName: order.supplierName);
    } catch (_) {} finally { _isLoading = false; notifyListeners(); }
  }

  Future<void> loadEarnings(String month) async {
    final uid = _supplierUid;
    if (uid == null) return;
    final start = DateTime.parse('$month-01');
    final end = DateTime(start.month == 12 ? start.year + 1 : start.year, start.month == 12 ? 1 : start.month + 1, 1);
    _transactions = _allCommissions.where((tx) => !tx.createdAt.isBefore(start) && tx.createdAt.isBefore(end)).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    try {
        final summary = await _transactionRepo.getMonthlyEarningsSummary(uid, 6);
        _monthlyEarnings = summary;
    } catch (_) {}
    notifyListeners();
  }

  Future<void> changeMonth(String month) => loadEarnings(month);

  Future<void> loadProfile() async {
    if (_supplierUid == null) return;
    _profile = await _userRepo.getUserDoc(_supplierUid!);
    notifyListeners();
  }

  Future<void> updateProfile(Map<String, dynamic> fields) async {
    if (_supplierUid == null) return;
    await _userRepo.updateUserDoc(_supplierUid!, fields);
    _profile = _userRepo.cachedUser ?? _profile;
    notifyListeners();
  }

  void clearAppealState() {
    _appealSubmitted = false;
    _error = null;
    notifyListeners();
  }

  Future<void> submitAppeal(String message, File? file, String? phone) async {
    _error = null;
    _isLoading = true;
    notifyListeners();
    try {
      final existing = await _db.collection('appeals')
          .where('uid', isEqualTo: _supplierUid)
          .where('status', isEqualTo: 'pending')
          .get();
      if (existing.docs.isNotEmpty) {
        _error = 'Your appeal is already under review.';
        return;
      }

      String? imageUrl;
      if (file != null) imageUrl = await _storageService.uploadFile(file: file, path: 'appeals/$_supplierUid');
      await _db.collection('appeals').add({
        'uid': _supplierUid,
        'supplierUid': _supplierUid,
        'role': 'Supplier',
        'name': _profile?.name ?? 'Supplier',
        'companyId': _selectedCompanyId ?? '',
        'message': message,
        'phone': phone,
        'imageUrl': imageUrl,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'pending',
        'rejectionReason': _rejectionReason ?? '',
      });
      _appealSubmitted = true;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadCompanyDirectory() async {
    ensurePartnershipStatusWatch();
    _isLoading = true; notifyListeners();
    try {
      final all = await _companyRepo.getAllCompanies();
      _allCompanyDirectory = all.where((c) => c.status.toLowerCase() == 'active').toList();
      _applyCompanyDirectoryFilters();
    } finally { _isLoading = false; notifyListeners(); }
  }

  Future<void> searchCompanies(String query) async {
    if (_allCompanyDirectory.isEmpty) await loadCompanyDirectory();
    _directorySearchQuery = query.trim().toLowerCase();
    _applyCompanyDirectoryFilters();
  }

  Future<bool> sendPartnershipRequest(String companyId, {String? message}) async {
    if (_supplierUid == null) return false;
    _isLoading = true; notifyListeners();
    try {
      final company = await _companyRepo.getCompanyById(companyId);
      if (company == null) return false;
      await _partnershipRepo.createRequest(companyId: companyId, companyName: company.name, supplierId: _supplierUid!, supplierName: _profile?.name ?? 'Supplier', initiatedBy: 'supplier', message: message, supplierEmail: _profile?.email, supplierCity: _profile?.city, supplierCategories: [], supplierRating: averageRating);
      return true;
    } catch (e) { _error = e.toString(); return false; } finally { _isLoading = false; notifyListeners(); }
  }

  Future<String?> acceptPartnershipRequest(String requestId) async {
    _isLoading = true; notifyListeners();
    try {
      final req = _allPartnershipRequests.cast<PartnershipRequestModel?>().firstWhere(
        (r) => r?.requestId == requestId,
        orElse: () => null,
      );
      await _partnershipRepo.acceptRequest(requestId);
      return req?.companyName;
    } catch (e) {
      _error = e.toString();
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> rejectPartnershipRequest(String requestId, String reason) async {
    _isLoading = true; notifyListeners();
    try {
      await _partnershipRepo.rejectRequest(requestId, reason);
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> withdrawPartnershipRequest(String requestId) async {
    _isLoading = true; notifyListeners();
    try { await _partnershipRepo.withdrawRequest(requestId); } finally { _isLoading = false; notifyListeners(); }
  }

  Future<String?> removePartnership(String companyId) async {
    if (_supplierUid == null) return null;
    _isLoading = true; notifyListeners();
    try {
      final company = await _companyRepo.getCompanyById(companyId);
      await _partnershipRepo.removePartnership(companyId: companyId, supplierId: _supplierUid!);
      return company?.name;
    } finally { _isLoading = false; notifyListeners(); }
  }

  void openCompanyContext(String companyId) => switchCompany(companyId);

  Future<void> loadRatings(String supplierUid, String companyId) async {
    _ratingsSubscription?.cancel();
    _ratingsSubscription = _db.collection('ratings').where('supplierUid', isEqualTo: supplierUid).snapshots().listen((snap) {
          _ratings = snap.docs.map((d) => RatingModel.fromMap(d.id, d.data())).toList();
          _ratingsInitialized = true; _checkDashboardReady(); notifyListeners();
        });
  }

  String? companyNameFor(String companyId) => _companies.cast<CompanyModel?>().firstWhere((c) => c?.id == companyId, orElse: () => null)?.name;

  Future<void> loadDashboard() async {
    if (_supplierUid == null || _selectedCompanyId == null) return;
    _isDashboardLoading = true; notifyListeners();
    await Future.wait([loadMaterials(_selectedCompanyId!), loadOrders(_selectedCompanyId!, null), loadEarnings(monthKey()), loadRatings(_supplierUid!, _selectedCompanyId!)]);
    _isDashboardLoading = false; notifyListeners();
  }

  Future<bool> submitCommissionPayment({required double amount, required String method, required XFile screenshotFile}) async {
    if (_supplierUid == null) return false;
    if (amount <= 0 || amount > commissionOwed + 0.01) { _error = "Invalid amount"; notifyListeners(); return false; }
    _isLoading = true; notifyListeners();
    try {
      final url = await _uploadImageBytes(bytes: await screenshotFile.readAsBytes(), folder: 'commission_proofs/$_supplierUid', filename: 'comm_${DateTime.now().millisecondsSinceEpoch}.jpg');
      if (url == null) throw Exception("Upload failed");

      final unsettledTxIds = _allCommissions
          .where((tx) => tx.status.toLowerCase() == 'unsettled' || tx.status.toLowerCase() == 'pending')
          .map((tx) => tx.txId)
          .toList();

      final proof = PaymentProofModel(
        id: '', 
        payerId: _supplierUid!, 
        companyId: '', 
        payerName: _profile?.name ?? 'Supplier', 
        payerRole: 'Supplier', 
        amount: amount, 
        method: method, 
        screenshotUrl: url, 
        status: 'pending', 
        type: 'commission', 
        createdAt: DateTime.now(),
        relatedTransactions: unsettledTxIds,
      );
      
      await _db.collection('payment_proofs').add(proof.toMap());
      _successMessage = 'Payment submitted.';
      return true;
    } catch (e) { _error = e.toString(); return false; } finally { _isLoading = false; notifyListeners(); }
  }

  Stream<List<RfqModel>> streamOpenRfqsForSupplier() {
    final uid = _supplierUid;
    if (uid == null) return Stream.value([]);
    return _db.collection('rfqs')
        .where('status', isEqualTo: 'open')
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => RfqModel.fromMap(doc.id, doc.data()))
            .where((r) => !r.hiddenBy.contains(uid))
            .toList());
  }

  Future<void> submitRfqBid({required String rfqId, required double bidPrice, required String deliveryTime, String? note}) async {
    final uid = _supplierUid;
    if (uid == null) return;
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final ref = _db.collection('rfq_bid_jobs').doc();
      await ref.set({
        'uid': uid,
        'rfqId': rfqId,
        'bidPrice': bidPrice,
        'estimatedDeliveryTime': deliveryTime,
        'note': note ?? '',
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
      final done = await ref.snapshots().firstWhere((snap) {
        final status = snap.data()?['status']?.toString();
        return status == 'complete' || status == 'error';
      }).timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          throw AppException(
            'Submitting the bid timed out. Please try again.',
            'deadline-exceeded',
          );
        },
      );
      final data = done.data() ?? {};
      if (data['status'] == 'error') {
        throw AppException(
          (data['error'] as String?)?.trim().isNotEmpty == true
              ? data['error'] as String
              : 'Could not submit the bid. Please try again.',
        );
      }
      _successMessage = 'Bid submitted.';
    } catch (e) {
      _error = e is AppException ? e.message : e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> withdrawRfqBid({required String rfqId}) async {
    final uid = _supplierUid;
    if (uid == null) return;
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final ref = _db.collection('rfq_bid_withdraw_jobs').doc();
      await ref.set({
        'uid': uid,
        'rfqId': rfqId,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
      final done = await ref.snapshots().firstWhere((snap) {
        final status = snap.data()?['status']?.toString();
        return status == 'complete' || status == 'error';
      }).timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          throw AppException(
            'Withdrawing the bid timed out. Please try again.',
            'deadline-exceeded',
          );
        },
      );
      final data = done.data() ?? {};
      if (data['status'] == 'error') {
        throw AppException(
          (data['error'] as String?)?.trim().isNotEmpty == true
              ? data['error'] as String
              : 'Could not withdraw this bid. Please try again.',
        );
      }
      _successMessage = 'Bid withdrawn.';
    } catch (e) {
      _error = e is AppException ? e.message : e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<RfqBidModel?> getMyBid(String rfqId) async {
    if (_supplierUid == null) return null;
    final doc = await _db.collection('rfqs').doc(rfqId).collection('bids').doc(_supplierUid).get();
    if (!doc.exists) return null;
    final bid = RfqBidModel.fromMap(doc.id, doc.data()!);
    if (bid.isWithdrawn) return null;
    return bid;
  }

  Future<void> hideTransaction(String txId) async {
    if (_supplierUid == null) return;
    try {
      await _transactionRepo.hideTransactionForUser(txId, _supplierUid!);
      _allCommissions.removeWhere((tx) => tx.txId == txId);
      _transactions.removeWhere((tx) => tx.txId == txId);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> clearPaymentHistory() async {
    if (_supplierUid == null) return;
    _isLoading = true;
    notifyListeners();
    try {
      await _transactionRepo.hideAllPaymentProofsForUser(_supplierUid!);
      _confirmedCommissionPayments.clear();
      _pendingCommissionPayments.clear();
      notifyListeners();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> hideOrder(String orderId) async {
    if (_supplierUid == null) return;
    try {
      await _orderRepo.hideOrderForUser(orderId, _supplierUid!);
      _orders.removeWhere((o) => o.orderId == orderId);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> hideOrders(List<String> orderIds) async {
    if (_supplierUid == null) return;
    try {
      await _orderRepo.hideOrdersForUser(orderIds, _supplierUid!);
      _orders.removeWhere((o) => orderIds.contains(o.orderId));
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  void _cancelSubscriptions() {
    _statusSubscription?.cancel(); _partnershipRequestsSub?.cancel(); _linkedCompaniesSub?.cancel();
    _companiesSubscription?.cancel(); _materialsSubscription?.cancel(); _ordersSubscription?.cancel();
    _commissionsSub?.cancel(); _paymentsSub?.cancel(); _invitationsSubscription?.cancel();
    _ratingsSubscription?.cancel(); _supplierRestrictionSub?.cancel();
  }
}
