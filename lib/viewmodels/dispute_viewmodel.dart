import 'package:flutter/material.dart';
import '../models/dispute_model.dart';
import '../services/cloud_function_service.dart';
import '../services/firestore_service.dart';
import '../services/notification_service.dart';
import '../utils/app_exception.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DisputeViewModel extends ChangeNotifier {
  final FirestoreService _firestoreService;
  final CloudFunctionService _cloudFunctions;
  final NotificationService? _notificationService;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  DisputeViewModel(
    this._firestoreService,
    this._cloudFunctions, [
    this._notificationService,
  ]);

  bool _isLoading = false;
  String? _error;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> raiseDispute({
    required String uid,
    required String orderId,
    required String companyId,
    required DisputeType type,
    required String description,
    String? photoUrl,
    String raisedByRole = 'field_user',
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _firestoreService.createDisputeJob(
        uid: uid,
        orderId: orderId,
        companyId: companyId,
        type: type.name,
        description: description,
        photoUrl: photoUrl,
      );
      await _notifyAdminsDisputeRaised(
        orderId: orderId,
        companyId: companyId,
        raisedByRole: raisedByRole,
      );
    } on AppException catch (error) {
      _error = error.message;
      rethrow;
    } catch (error) {
      _error = error.toString();
      throw AppException(_error!);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _notifyAdminsDisputeRaised({
    required String orderId,
    required String companyId,
    required String raisedByRole,
  }) async {
    final notifications = _notificationService;
    if (notifications == null) return;
    try {
      final adminIds = await _firestoreService.getAdminUserIds();
      for (final adminUid in adminIds) {
        await notifications.notifyDisputeRaised(
          adminUid: adminUid,
          orderId: orderId,
          companyId: companyId,
          raisedByRole: raisedByRole,
        );
      }
    } catch (_) {
      // Dispute already persisted; admin alert is best-effort.
    }
  }

  Stream<List<DisputeModel>> watchCompanyDisputes(String companyId, {String? userId}) {
    return _firestoreService.streamCompanyDisputes(companyId).map((list) {
      if (userId == null) return list;
      return list.where((d) => !d.hiddenBy.contains(userId)).toList();
    });
  }

  Stream<List<DisputeModel>> watchAllDisputes({String? status}) {
    return _firestoreService.streamAllDisputes(status: status);
  }

  Stream<List<DisputeModel>> watchMyDisputes(String uid) {
    return _firestoreService.streamRaisedByDisputes(uid).map((list) {
      return list.where((d) => !d.hiddenBy.contains(uid)).toList();
    });
  }

  Stream<DisputeModel?> watchDispute(String disputeId) {
    return _firestoreService.streamDispute(disputeId);
  }

  Future<void> withdrawDispute({
    required String uid,
    required String disputeId,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      await _firestoreService.createDisputeWithdrawJob(
        uid: uid,
        disputeId: disputeId,
      );
    } on AppException catch (error) {
      _error = error.message;
      rethrow;
    } catch (error) {
      _error = error.toString();
      throw AppException(_error!);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> resolveDispute(
    String id,
    String status,
    String notes, {
    required String adminUid,
    String? raisedByUid,
    String? raisedByRole,
    String? orderId,
    String? companyId,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      if (adminUid.trim().isEmpty) {
        throw AppException('You must be signed in as an administrator.');
      }
      await _firestoreService.createDisputeUpdateJob(
        uid: adminUid,
        disputeId: id,
        status: status,
        resolutionNotes: notes,
      );
      await _notifyRaisedByOutcome(
        disputeId: id,
        status: status,
        notes: notes,
        raisedByUid: raisedByUid,
        raisedByRole: raisedByRole,
        orderId: orderId,
        companyId: companyId,
      );
    } on AppException catch (error) {
      _error = error.message;
      rethrow;
    } catch (error) {
      _error = error.toString();
      throw AppException(_error!);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _notifyRaisedByOutcome({
    required String disputeId,
    required String status,
    required String notes,
    String? raisedByUid,
    String? raisedByRole,
    String? orderId,
    String? companyId,
  }) async {
    final notifications = _notificationService;
    final uid = raisedByUid?.trim() ?? '';
    final closed =
        status == 'resolved' || status == 'rejected';
    if (notifications == null || uid.isEmpty || !closed) return;
    try {
      await notifications.notifyDisputeResolved(
        recipientUid: uid,
        recipientRole: (raisedByRole ?? '').trim().isEmpty
            ? 'field_user'
            : raisedByRole!.trim(),
        orderId: orderId ?? '',
        companyId: companyId ?? '',
        status: status,
        resolutionNotes: notes,
        disputeId: disputeId,
      );
    } catch (_) {
      // Dispute already updated; in-app alert is best-effort.
    }
  }

  /// "Delete for Me" - hides a dispute from the user's view.
  Future<void> deleteDisputeForMe(String disputeId, String userId) async {
    try {
      await _db.collection('disputes').doc(disputeId).update({
        'hiddenBy': FieldValue.arrayUnion([userId]),
      });
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// "Delete for Me" - hides multiple disputes.
  Future<void> deleteDisputesForMe(List<String> disputeIds, String userId) async {
    try {
      final batch = _db.batch();
      for (final id in disputeIds) {
        batch.update(_db.collection('disputes').doc(id), {
          'hiddenBy': FieldValue.arrayUnion([userId]),
        });
      }
      await batch.commit();
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }
}
