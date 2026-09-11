// MVVM: ViewModel — business logic only
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../models/invitation_model.dart';
import '../repositories/invitation_repository.dart';
import '../repositories/join_request_repository.dart';
import '../services/dynamic_link_service.dart';
import '../services/cloud_function_service.dart';
import 'auth_viewmodel.dart';

class InviteViewModel extends ChangeNotifier {
  final InvitationRepository _invitationRepo;
  final JoinRequestRepository _joinRequestRepo;
  final DynamicLinkService _dynamicLinks;
  final CloudFunctionService _cloudFunctions;
  final Future<void> Function(String text, {String? subject}) _shareText;

  String? _supplierUid;
  String? _companyId;

  InvitationModel? _currentInvitation;
  bool _isLoading = false;
  bool _isExpired = false;
  bool _isAccepted = false;
  bool _isRejected = false;
  String? _error;

  InviteViewModel(
    this._invitationRepo,
    this._joinRequestRepo,
    this._dynamicLinks,
    this._cloudFunctions, {
    Future<void> Function(String text, {String? subject})? shareText,
  }) : _shareText = shareText ??
            ((text, {subject}) async {
              await Share.share(text, subject: subject);
            });

  void updateAuth(AuthViewModel auth) {
    _supplierUid = auth.user?.uid;
    _companyId = auth.user?.companyId;
    notifyListeners();
  }

  InvitationModel? get invitation => _currentInvitation;
  bool get isLoading => _isLoading;
  bool get isExpired => _isExpired;
  bool get isAccepted => _isAccepted;
  bool get isRejected => _isRejected;
  String? get error => _error;

  Future<void> loadInvitation(String token) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _currentInvitation = await _invitationRepo.getInvitation(token);
      if (_currentInvitation == null) {
        _error = 'Invitation not found or has been used.';
      } else if (_currentInvitation!.status == 'expired') {
        _isExpired = true;
      }
    } catch(e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> acceptInvite(String token) async {
    if (_currentInvitation == null) return;
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      await _cloudFunctions.callFunction('onInviteAccepted', {
        'token': token,
        'companyId': _currentInvitation!.companyId,
        'supplierUid': _supplierUid,
      });
      _isAccepted = true;
    } catch(e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> rejectInvite(String token) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      await _invitationRepo.updateStatus(token, 'rejected');
      _isRejected = true;
    } catch(e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> sendInvitation(
    String targetSupplierUid,
    String companyId,
    String ceoUid,
    String companyName,
  ) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final token = await _invitationRepo.createInvitation(
        companyId, ceoUid, targetSupplierUid, companyName,
      );
      final link = await _dynamicLinks.generateInviteLink(token);
      await _shareText(
        'You have been invited to supply on RateBridge.\nTap to accept: $link',
        subject: 'RateBridge Supplier Invitation',
      );
    } catch(e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> sendSupplierInvite({
    required String email,
    required String companyId,
    required String ceoUid,
    required String companyName,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final token = await _invitationRepo.createSupplierInvite(
        companyId, ceoUid, email, companyName,
      );
      final link = await _dynamicLinks.generateInviteLink(token);
      await _shareText(
        'You have been invited to supply for $companyName on RateBridge.\nTap to accept: $link',
        subject: 'RateBridge Supplier Invitation',
      );
    } catch(e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> sendJoinRequest(
    String supplierUid,
    String companyId,
    String supplierName,
    String supplierCity,
    List<String> categories,
    double rating,
    String? message,
  ) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final reqId = await _joinRequestRepo.createJoinRequest(
        supplierUid, companyId, supplierName, supplierCity, categories, rating, message,
      );
      await _cloudFunctions.callFunction('sendJoinRequestNotification', {
        'companyId': companyId,
        'supplierName': supplierName,
        'reqId': reqId,
      });
    } catch(e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> acceptJoinRequest(String reqId, String supplierUid) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      await _cloudFunctions.callFunction('onInviteAccepted', {
        'reqId': reqId,
        'companyId': _companyId,
        'supplierUid': supplierUid,
      });
    } catch(e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> rejectJoinRequest(String reqId, String? reason) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      await _joinRequestRepo.updateRequestStatus(reqId, 'rejected', reason: reason);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
