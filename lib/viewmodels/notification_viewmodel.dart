// MVVM: ViewModel — business logic for all roles
import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import '../models/notification_model.dart';
import '../repositories/notification_repository.dart';
import 'auth_viewmodel.dart';

class NotificationViewModel extends ChangeNotifier {
  final NotificationRepository _notificationRepo;
  NotificationViewModel(this._notificationRepo);

  String? _uid;
  List<NotificationModel> _notifications = [];
  int _unreadCount = 0;
  bool _isLoading = false;
  String? _errorMessage;
  StreamSubscription? _notifSubscription;
  StreamSubscription? _unreadSubscription;

  /// Automatically called by ProxyProvider in main.dart when Auth state changes.
  void updateAuth(AuthViewModel auth) {
    final newUid = auth.user?.uid;

    if (newUid == _uid) return;

    developer.log('NOTIFICATION: Auth update. Old UID: $_uid, New UID: $newUid');
    
    _uid = newUid;

    if (_uid != null) {
      _startListening();
    } else {
      _stopListening();
    }
  }

  /// Explicitly reload/start listening if needed (e.g. after error).
  void loadNotifications(String uid) {
    if (uid != _uid) {
      _uid = uid;
      _startListening();
    } else if (_notifSubscription == null) {
      _startListening();
    }
  }

  /// Legacy support for widgets that expect this method.
  void watchNotifications(String uid) => loadNotifications(uid);
  void watchUnreadCount(String uid) => loadNotifications(uid);

  void _startListening() {
    if (_uid == null) return;

    developer.log('NOTIFICATION: Listening to notifications for UID: $_uid');
    
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    _notifSubscription?.cancel();
    _notifSubscription = _notificationRepo
      .watchNotifications(_uid!)
      .listen((notifs) {
        developer.log('NOTIFICATION: Received ${notifs.length} notifications');
        _notifications = notifs;
        _isLoading = false;
        notifyListeners();
      }, onError: (e) {
        developer.log('NOTIFICATION ERROR: $e');
        _errorMessage = e.toString();
        _isLoading = false;
        notifyListeners();
      });

    _unreadSubscription?.cancel();
    _unreadSubscription = _notificationRepo
      .watchUnreadCount(_uid!)
      .listen((count) {
        _unreadCount = count;
        notifyListeners();
      }, onError: (e) {
        developer.log('NOTIFICATION UNREAD ERROR: $e');
        _errorMessage = e.toString();
        notifyListeners();
      });
  }

  void _stopListening() {
    developer.log('NOTIFICATION: Stopping listeners for UID: $_uid');
    _notifSubscription?.cancel();
    _unreadSubscription?.cancel();
    _notifSubscription = null;
    _unreadSubscription = null;
    _notifications = [];
    _unreadCount = 0;
    _isLoading = false;
    notifyListeners();
  }

  String? get uid => _uid;
  List<NotificationModel> get notifications => _notifications;
  int get unreadCount => _unreadCount;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Marks a notification as read.
  /// Standardized to use only notifId as it is unique in the root collection.
  Future<void> markAsRead(String notifId, [String? _]) async {
    try {
      await _notificationRepo.markAsRead(notifId);
    } catch (e) {
      developer.log('NOTIFICATION MARK READ ERROR: $e');
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  /// Marks all notifications for the current user as read.
  Future<void> markAllRead([String? uid]) async {
    final targetUid = uid ?? _uid;
    if (targetUid == null) return;
    try {
      await _notificationRepo.markAllRead(targetUid);
    } catch (e) {
      developer.log('NOTIFICATION MARK ALL READ ERROR: $e');
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  /// Deletes a specific notification.
  Future<void> deleteNotification(String notifId) async {
    try {
      await _notificationRepo.deleteNotification(notifId);
    } catch (e) {
      developer.log('NOTIFICATION DELETE ERROR: $e');
      _errorMessage = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Deletes multiple notifications.
  Future<void> deleteNotifications(List<String> notifIds) async {
    try {
      await _notificationRepo.deleteNotifications(notifIds);
    } catch (e) {
      developer.log('NOTIFICATIONS BULK DELETE ERROR: $e');
      _errorMessage = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Deletes all notifications for the current user.
  Future<void> deleteAllNotifications() async {
    if (_uid == null) return;
    try {
      await _notificationRepo.deleteAllNotifications(_uid!);
    } catch (e) {
      developer.log('NOTIFICATIONS CLEAR ALL ERROR: $e');
      _errorMessage = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  @override
  void dispose() {
    _stopListening();
    super.dispose();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
