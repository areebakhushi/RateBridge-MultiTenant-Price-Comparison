// MVVM: Repository — Firestore access only
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/invitation_model.dart';
import '../services/firestore_service.dart';
import '../services/plan_limit_service.dart';
import '../constants/firestore_paths.dart';
import '../constants/app_constants.dart';
import '../utils/app_exception.dart';

class InvitationRepository {
  final FirebaseFirestore _db;

  InvitationRepository(FirestoreService _, {FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  /// Generates a random alphanumeric code: RB-XXXXXX
  String _generateShortCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; 
    final rnd = Random();
    return 'RB-${Iterable.generate(6, (_) => chars[rnd.nextInt(chars.length)]).join()}';
  }

  /// Creates a unique invitation document for a Field User
  Future<String> createFieldUserInvite(
    String companyId,
    String ceoUid,
    String companyName,
  ) async {
    try {
      final code = _generateShortCode();
      // Document ID is the code itself for instant lookup
      final expiresAt = DateTime.now().add(const Duration(days: 30));
      
      await _db
          .collection(FirestorePaths.invitationsCol)
          .doc(code)
          .set({
            'companyId': companyId,
            'ceoUid': ceoUid,
            'companyName': companyName,
            'role': 'field_user',
            'status': 'pending',
            'expiresAt': Timestamp.fromDate(expiresAt),
            'createdAt': FieldValue.serverTimestamp(),
          });
      return code;
    } on FirebaseException catch(e) {
      throw AppException('Failed to create invitation: ${e.message}');
    }
  }

  /// Retrieves an invitation by its token/code and handles auto-expiry
  Future<InvitationModel?> getInvitation(String token) async {
    try {
      final doc = await _db
          .collection(FirestorePaths.invitationsCol)
          .doc(token)
          .get();
      if (!doc.exists) return null;
      
      final invitation = InvitationModel.fromMap(token, doc.data() as Map<String, dynamic>);
      
      if (invitation.isExpired && invitation.status == 'pending') {
        // Auto-expire the invitation if the date has passed
        await _db.collection(FirestorePaths.invitationsCol).doc(token).update({'status': 'expired'});
        return invitation.copyWith(status: 'expired');
      }
      return invitation;
    } on FirebaseException catch(e) {
      throw AppException('Failed to get invitation: ${e.message}');
    }
  }

  Future<void> updateStatus(String token, String status) async {
    try {
      await _db.collection(FirestorePaths.invitationsCol).doc(token).update({'status': status});
    } on FirebaseException catch (e) {
      throw AppException('Failed to update invitation status: ${e.message}');
    }
  }

  /// Creates a standard invitation (e.g., for Suppliers)
  Future<String> createInvitation(String companyId, String ceoUid, String supplierUid, String companyName) async {
    try {
      await PlanLimitService.ensureSupplierCapacity(
        _db,
        companyId,
        supplierId: supplierUid,
      );
      final docId = _db.collection(FirestorePaths.invitationsCol).doc().id;
      final expiresAt = DateTime.now().add(AppConstants.inviteTokenExpiry);
      await _db.collection(FirestorePaths.invitationsCol).doc(docId).set({
        'companyId': companyId,
        'ceoUid': ceoUid,
        'supplierUid': supplierUid,
        'companyName': companyName,
        'status': 'pending',
        'expiresAt': Timestamp.fromDate(expiresAt),
        'createdAt': FieldValue.serverTimestamp(),
      });
      return docId;
    } on FirebaseException catch(e) {
      throw AppException('Failed to create invitation: ${e.message}');
    }
  }

  /// Creates a supplier invitation by email
  Future<String> createSupplierInvite(
    String companyId,
    String ceoUid,
    String email,
    String companyName,
  ) async {
    try {
      final docId = _db.collection(FirestorePaths.invitationsCol).doc().id;
      final expiresAt = DateTime.now().add(AppConstants.inviteTokenExpiry);
      await _db.collection(FirestorePaths.invitationsCol).doc(docId).set({
        'companyId': companyId,
        'ceoUid': ceoUid,
        'email': email,
        'companyName': companyName,
        'role': 'supplier',
        'status': 'pending',
        'expiresAt': Timestamp.fromDate(expiresAt),
        'createdAt': FieldValue.serverTimestamp(),
      });
      return docId;
    } on FirebaseException catch (e) {
      throw AppException('Failed to create supplier invitation: ${e.message}');
    }
  }
}
