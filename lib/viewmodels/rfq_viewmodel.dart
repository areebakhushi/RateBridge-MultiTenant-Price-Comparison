import 'package:flutter/material.dart';
import '../models/rfq_model.dart';
import '../models/rfq_bid_model.dart';
import '../models/supplier_model.dart';
import '../services/cloud_function_service.dart';
import '../services/firestore_service.dart';
import '../services/notification_service.dart';
import '../utils/app_exception.dart';

class RfqViewModel extends ChangeNotifier {
  final FirestoreService _firestoreService;
  final CloudFunctionService _cloudFunctions;
  final NotificationService? _notificationService;

  bool _isLoading = false;
  String? _error;

  RfqViewModel(
    this._firestoreService,
    this._cloudFunctions, [
    this._notificationService,
  ]);

  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> createRfq({
    required String uid,
    required String companyId,
    required String companyName,
    required String category,
    required String materialDescription,
    required double quantity,
    required String unit,
    required String city,
    required DateTime requiredByDate,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final rfqId = await _firestoreService.createRfqJob(
        uid: uid,
        companyId: companyId,
        companyName: companyName,
        category: category,
        materialDescription: materialDescription,
        quantity: quantity,
        unit: unit,
        city: city,
        requiredByDate: requiredByDate,
      );
      await _notifySuppliersNewRfq(
        rfqId: rfqId,
        category: category,
        companyName: companyName,
      );
    } catch (e) {
      _error = e is AppException ? e.message : e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Stream<List<RfqModel>> watchCompanyRfqs(String companyId) {
    return _firestoreService.streamCompanyRfqs(companyId);
  }

  Stream<RfqModel?> watchRfq(String rfqId) {
    return _firestoreService.streamRfq(rfqId);
  }

  Stream<List<RfqBidModel>> watchRfqBids(String rfqId) {
    return _firestoreService.streamRfqBids(rfqId);
  }

  Future<void> awardRfq({
    required RfqModel rfq,
    required RfqBidModel bid,
    required String ceoUid,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _firestoreService.createRfqAwardJob(
        uid: ceoUid,
        rfqId: rfq.id,
        bidId: bid.id,
      );
      await _notifyRfqClosed(rfq: rfq, winningBid: bid);
    } catch (e) {
      _error = e is AppException ? e.message : e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> cancelRfq({
    required String rfqId,
    required String uid,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      await _firestoreService.createRfqCancelJob(uid: uid, rfqId: rfqId);
    } catch (e) {
      _error = e is AppException ? e.message : e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Hides an RFQ from the user's history (soft-delete).
  Future<void> hideRfq(String rfqId, String userId) async {
    try {
      await _firestoreService.hideRfqForUser(rfqId, userId);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Bulk hides RFQs from history.
  Future<void> hideRfqs(List<String> rfqIds, String userId) async {
    try {
      await _firestoreService.hideRfqsForUser(rfqIds, userId);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  Future<void> _notifySuppliersNewRfq({
    required String rfqId,
    required String category,
    required String companyName,
  }) async {
    final notifications = _notificationService;
    if (notifications == null) return;
    try {
      final suppliers = await _firestoreService.streamSuppliers().first;
      for (final supplier in suppliers) {
        if (!_canSupplierBid(supplier) ||
            !_supplierMatchesRfqCategory(supplier, category)) {
          continue;
        }
        await notifications.notifyNewRfqAvailable(
          supplierId: supplier.id,
          rfqId: rfqId,
          category: category,
          companyName: companyName,
        );
      }
    } catch (_) {
      // RFQ already published; supplier alert is best-effort.
    }
  }

  Future<void> _notifyRfqClosed({
    required RfqModel rfq,
    required RfqBidModel winningBid,
  }) async {
    final notifications = _notificationService;
    if (notifications == null) return;
    try {
      final bids = await _firestoreService.getRfqBids(rfq.id);
      final suppliers = bids.isNotEmpty
          ? bids
          : [winningBid];
      for (final current in suppliers) {
        await notifications.notifyRfqClosed(
          supplierId: current.supplierId,
          rfqId: rfq.id,
          category: rfq.category,
          companyName: rfq.companyName,
          awarded: current.supplierId == winningBid.supplierId ||
              current.id == winningBid.id,
        );
      }
    } catch (_) {
      // Award already applied; closed-RFQ alert is best-effort.
    }
  }

  bool _canSupplierBid(SupplierModel supplier) {
    final status = supplier.status.trim().toLowerCase();
    return (status == 'active' || status == 'approved') &&
        !supplier.commissionRestricted;
  }

  bool _supplierMatchesRfqCategory(SupplierModel supplier, String category) {
    final categories = <String>{
      ...supplier.declaredCategories,
      ...supplier.categories,
    }
        .map((value) => value.trim().toLowerCase())
        .where((value) => value.isNotEmpty);
    if (categories.isEmpty) return false;
    final target = category.trim().toLowerCase();
    final targetStem = _stemCategory(target);
    return categories.any(
      (item) => item == target || _stemCategory(item) == targetStem,
    );
  }

  String _stemCategory(String value) {
    if (value.endsWith('ies')) return value.substring(0, value.length - 3);
    if (value.endsWith('s')) return value.substring(0, value.length - 1);
    return value;
  }
}
