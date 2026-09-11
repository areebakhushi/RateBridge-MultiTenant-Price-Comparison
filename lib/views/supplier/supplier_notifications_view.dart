import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../theme/supplier_theme.dart';
import '../../models/notification_model.dart';
import '../../utils/app_theme.dart';
import '../../utils/notification_utils.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/notification_viewmodel.dart';
import '../../widgets/supplier/supplier_async_states.dart';

class SupplierNotificationsView extends StatefulWidget {
  const SupplierNotificationsView({super.key});

  @override
  State<SupplierNotificationsView> createState() =>
      _SupplierNotificationsViewState();
}

class _SupplierNotificationsViewState extends State<SupplierNotificationsView> {
  bool _isSelectionMode = false;
  final Set<String> _selectedNotifIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startWatching());
  }

  void _startWatching() {
    final uid = context.read<AuthViewModel>().user?.uid ??
        context.read<NotificationViewModel>().uid;
    if (uid == null) return;
    final vm = context.read<NotificationViewModel>();
    vm.loadNotifications(uid);
    vm.watchUnreadCount(uid);
  }

  Future<void> _markAllRead() async {
    final uid = context.read<NotificationViewModel>().uid;
    if (uid == null) return;
    await context.read<NotificationViewModel>().markAllRead(uid);
  }

  Future<void> _onNotificationTap(NotificationModel notification) async {
    if (_isSelectionMode) {
      setState(() {
        if (_selectedNotifIds.contains(notification.notifId)) {
          _selectedNotifIds.remove(notification.notifId);
          if (_selectedNotifIds.isEmpty) {
            _isSelectionMode = false;
          }
        } else {
          _selectedNotifIds.add(notification.notifId);
        }
      });
      return;
    }

    final vm = context.read<NotificationViewModel>();
    final uid = vm.uid;
    if (uid == null) return;

    if (!notification.isRead) {
      await vm.markAsRead(uid, notification.notifId);
    }

    if (!mounted) return;
    navigateForSupplierNotification(context, notification);
  }

  void _handleLongPress(NotificationModel notification) {
    setState(() {
      _isSelectionMode = true;
      _selectedNotifIds.add(notification.notifId);
    });
  }

  Future<void> _confirmAndDeleteSelected() async {
    if (_selectedNotifIds.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${_selectedNotifIds.length} items?'),
        content: const Text('Are you sure you want to delete these items? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final vm = context.read<NotificationViewModel>();
      try {
        await vm.deleteNotifications(_selectedNotifIds.toList());
        setState(() {
          _selectedNotifIds.clear();
          _isSelectionMode = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notifications deleted successfully.')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to delete items: $e')),
        );
      }
    }
  }

  Future<void> _confirmAndClearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete all?'),
        content: const Text('This will permanently remove all removable items from your panel.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete All', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final vm = context.read<NotificationViewModel>();
      try {
        await vm.deleteAllNotifications();
        setState(() {
          _selectedNotifIds.clear();
          _isSelectionMode = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All notifications cleared.')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to clear items: $e')),
        );
      }
    }
  }

  Future<void> _deleteSingleNotification(NotificationModel notification) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete item?'),
        content: const Text('Are you sure you want to delete this item? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final vm = context.read<NotificationViewModel>();
      try {
        await vm.deleteNotification(notification.notifId);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notification deleted.')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to delete item: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<NotificationViewModel>();

    return Scaffold(
      backgroundColor: FieldColors.screenBackground,
      appBar: SupplierAppBar(
        title: _isSelectionMode ? '${_selectedNotifIds.length} selected' : 'Notifications',
        leading: _isSelectionMode
            ? IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () {
                  setState(() {
                    _isSelectionMode = false;
                    _selectedNotifIds.clear();
                  });
                },
              )
            : null,
        actions: _isSelectionMode
            ? [
                IconButton(
                  icon: const Icon(Icons.select_all_rounded),
                  tooltip: 'Select All',
                  onPressed: () {
                    setState(() {
                      _selectedNotifIds.addAll(vm.notifications.map((n) => n.notifId));
                    });
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete_rounded),
                  tooltip: 'Delete Selected',
                  onPressed: _confirmAndDeleteSelected,
                ),
              ]
            : [
                if (vm.notifications.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.delete_sweep_rounded),
                    tooltip: 'Clear All',
                    onPressed: _confirmAndClearAll,
                  ),
                if (vm.unreadCount > 0)
                  TextButton(
                    onPressed: _markAllRead,
                    child: Text(
                      'Mark all read',
                      style: AppTextStyles.caption.copyWith(
                        color: FieldColors.accentAmber,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
      ),
      body: vm.uid == null
          ? const Center(child: CircularProgressIndicator())
          : vm.errorMessage != null && vm.notifications.isEmpty
              ? _NotificationsError(
                  message: vm.errorMessage!,
                  onRetry: _startWatching,
                )
              : vm.isLoading && vm.notifications.isEmpty
                  ? const SupplierListSkeleton(itemCount: 5, itemHeight: 88)
                  : vm.notifications.isEmpty
                      ? const SupplierEmptyState(
                          icon: Icons.notifications_none_outlined,
                          title: 'No notifications yet',
                          subtitle:
                              'Updates about your orders and messages will appear here.',
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                          itemCount: vm.notifications.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final notification = vm.notifications[index];
                            final isSelected = _selectedNotifIds.contains(notification.notifId);
                            return _NotificationTile(
                              notification: notification,
                              relativeTime: notificationRelativeTime(
                                notification.createdAt,
                              ),
                              isSelectionMode: _isSelectionMode,
                              isSelected: isSelected,
                              onTap: () => _onNotificationTap(notification),
                              onLongPress: () => _handleLongPress(notification),
                              onDeleteSingle: () => _deleteSingleNotification(notification),
                            );
                          },
                        ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final NotificationModel notification;
  final String relativeTime;
  final bool isSelectionMode;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onDeleteSingle;

  const _NotificationTile({
    required this.notification,
    required this.relativeTime,
    required this.isSelectionMode,
    required this.isSelected,
    required this.onTap,
    required this.onLongPress,
    required this.onDeleteSingle,
  });

  NotificationIconConfig _iconConfig(String type) {
    final normalized = type.toLowerCase();
    if (normalized.contains('chat')) {
      return const NotificationIconConfig(
        Icons.chat_bubble_outline,
        FieldColors.primaryNavy,
      );
    }
    if (normalized.contains('delivery') || normalized.contains('delivered')) {
      return const NotificationIconConfig(
        Icons.local_shipping_outlined,
        FieldColors.statusSuccess,
      );
    }
    if (normalized.contains('neworder')) {
      return const NotificationIconConfig(
        Icons.add_shopping_cart_outlined,
        FieldColors.primaryNavy,
      );
    }
    if (normalized.contains('rating')) {
      return const NotificationIconConfig(
        Icons.star_outline_rounded,
        FieldColors.statusWarning,
      );
    }
    if (normalized.contains('approval')) {
      return const NotificationIconConfig(
        Icons.verified_outlined,
        FieldColors.statusWarning,
      );
    }
    if (normalized.contains('commission') || normalized.contains('payment')) {
      return const NotificationIconConfig(
        Icons.payments_outlined,
        FieldColors.statusSuccess,
      );
    }
    if (normalized.contains('partnership')) {
      return const NotificationIconConfig(
        Icons.handshake_outlined,
        FieldColors.accentAmber,
      );
    }
    if (normalized.contains('cancel') || normalized.contains('reject')) {
      return const NotificationIconConfig(
        Icons.cancel_outlined,
        FieldColors.statusDanger,
      );
    }
    return const NotificationIconConfig(
      Icons.receipt_long_outlined,
      FieldColors.primaryNavy,
    );
  }

  @override
  Widget build(BuildContext context) {
    final iconConfig = _iconConfig(notification.type);
    final isUnread = !notification.isRead;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Ink(
          decoration: BoxDecoration(
            color: isSelected
                ? iconConfig.color.withValues(alpha: 0.08)
                : (isUnread ? FieldColors.primaryNavy.withValues(alpha: 0.04) : Colors.white),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: isSelected
                  ? iconConfig.color
                  : (isUnread ? FieldColors.primaryNavy.withValues(alpha: 0.15) : FieldColors.borderSubtle),
              width: (isSelected || isUnread) ? 1.5 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isSelectionMode) ...[
                const SizedBox(width: 8),
                Center(
                  child: Checkbox(
                    value: isSelected,
                    activeColor: iconConfig.color,
                    onChanged: (_) => onTap(),
                  ),
                ),
              ],
              if (isUnread && !isSelectionMode)
                Container(
                  width: 3,
                  margin: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: FieldColors.primaryNavy.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: iconConfig.color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                        child: Icon(
                          iconConfig.icon,
                          size: 20,
                          color: iconConfig.color,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    notification.title,
                                    style: AppTextStyles.h3.copyWith(
                                      fontSize: 15,
                                      fontWeight:
                                          isUnread ? FontWeight.w700 : FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (!isSelectionMode)
                                  PopupMenuButton<String>(
                                    icon: const Icon(Icons.more_vert_rounded, size: 18, color: Colors.grey),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    onSelected: (val) {
                                      if (val == 'delete') {
                                        onDeleteSingle();
                                      }
                                    },
                                    itemBuilder: (ctx) => [
                                      const PopupMenuItem(
                                        value: 'delete',
                                        child: Row(
                                          children: [
                                            Icon(Icons.delete_outline_rounded, size: 16, color: Colors.red),
                                            SizedBox(width: 8),
                                            Text('Delete'),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              notification.body,
                              style: AppTextStyles.bodyMuted,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              relativeTime,
                              style: AppTextStyles.caption.copyWith(
                                fontSize: 11,
                                color: FieldColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificationsError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _NotificationsError({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              size: 48,
              color: FieldColors.statusDanger,
            ),
            const SizedBox(height: 16),
            Text(
              'Could not load notifications',
              style: AppTextStyles.h3,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: AppTextStyles.bodyMuted,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: onRetry,
              style: FilledButton.styleFrom(
                backgroundColor: FieldColors.primaryNavy,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
