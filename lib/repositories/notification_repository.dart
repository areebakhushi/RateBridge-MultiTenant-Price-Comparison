// MVVM: Repository — Firestore access only
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/notification_model.dart';
import '../services/firestore_service.dart';
import '../utils/app_exception.dart';

class NotificationRepository {
  final FirebaseFirestore _db;

  NotificationRepository([
    FirestoreService? _,
    FirebaseFirestore? firestore,
  ]) : _db = firestore ?? FirebaseFirestore.instance;


  /// Watches notifications for a specific user in the root 'notifications' collection.
  Stream<List<NotificationModel>> watchNotifications(String uid) {
    return _db
        .collection('notifications')
        .where('recipientUserId', isEqualTo: uid)
        .snapshots()
        .map((snapshot) {
      final notifications = snapshot.docs
          .map((doc) => NotificationModel.fromMap(
                doc.id,
                doc.data(),
              ))
          .toList();
      notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return notifications;
    }).handleError((Object error) {
      if (error is FirebaseException &&
          error.code == 'failed-precondition') {
        throw AppException(
          'Notifications index is building. Please wait 2 minutes and retry.',
        );
      }
      throw error;
    });
  }

  Stream<int> watchUnreadCount(String uid) {
    return _db
        .collection('notifications')
        .where('recipientUserId', isEqualTo: uid)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length)
        .handleError((Object error) {
      if (error is FirebaseException &&
          error.code == 'failed-precondition') {
        // This query (uid + isRead) specifically requires a composite index.
        throw AppException(
          'Unread count index is missing. Please create a composite index for recipientUserId and isRead in Firestore.',
        );
      }
      throw error;
    });
  }

  Future<void> createNotification(NotificationModel notification) async {
    try {
      await _db
          .collection('notifications')
          .doc(notification.notifId.isEmpty ? null : notification.notifId)
          .set({
        ...notification.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      throw AppException('Failed to create notification: ${e.message}');
    }
  }

  Future<void> markAsRead(String notifId) async {
    try {
      await _db.collection('notifications').doc(notifId).update({'isRead': true});
    } on FirebaseException catch (e) {
      throw AppException('Failed to mark notification as read: ${e.message}');
    }
  }

  Future<void> markAllRead(String uid) async {
    try {
      final batch = _db.batch();
      final unread = await _db
          .collection('notifications')
          .where('recipientUserId', isEqualTo: uid)
          .where('isRead', isEqualTo: false)
          .get();

      for (final doc in unread.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
    } on FirebaseException catch (e) {
      throw AppException('Failed to mark all notifications as read: ${e.message}');
    }
  }

  Future<void> deleteNotification(String notifId) async {
    try {
      await _db.collection('notifications').doc(notifId).delete();
    } on FirebaseException catch (e) {
      throw AppException('Failed to delete notification: ${e.message}');
    }
  }

  Future<void> deleteNotifications(List<String> notifIds) async {
    try {
      final batch = _db.batch();
      for (final id in notifIds) {
        batch.delete(_db.collection('notifications').doc(id));
      }
      await batch.commit();
    } on FirebaseException catch (e) {
      throw AppException('Failed to delete notifications: ${e.message}');
    }
  }

  Future<void> deleteAllNotifications(String uid) async {
    try {
      final snapshots = await _db
          .collection('notifications')
          .where('recipientUserId', isEqualTo: uid)
          .get();

      final batch = _db.batch();
      for (final doc in snapshots.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } on FirebaseException catch (e) {
      throw AppException('Failed to clear notifications: ${e.message}');
    }
  }
}
