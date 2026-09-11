import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../models/notification_model.dart';
import '../theme/field_theme.dart';
import '../utils/app_navigation.dart';
import '../utils/notification_utils.dart';
import '../viewmodels/notification_viewmodel.dart';

typedef NotificationTapHandler = void Function(
  BuildContext context,
  NotificationModel notification,
);

/// Shared notifications list used by field, CEO, and admin screens.
class AppNotificationsScaffold extends StatefulWidget {
  final String title;
  final NotificationTapHandler onNotificationTap;
  final Color? backgroundColor;

  const AppNotificationsScaffold({
    super.key,
    required this.title,
    required this.onNotificationTap,
    this.backgroundColor,
  });

  @override
  State<AppNotificationsScaffold> createState() => _AppNotificationsScaffoldState();
}

class _AppNotificationsScaffoldState extends State<AppNotificationsScaffold> {
  bool _isSelectionMode = false;
  final Set<String> _selectedNotifIds = {};

  Future<void> _markAllRead(BuildContext context) async {
    final vm = context.read<NotificationViewModel>();
    final uid = vm.uid;
    if (uid == null) return;
    await vm.markAllRead(uid);
  }

  void _retryLoad(BuildContext context) {
    final vm = context.read<NotificationViewModel>();
    final uid = vm.uid;
    if (uid == null) return;
    vm.loadNotifications(uid);
  }

  Future<void> _handleTap(
    BuildContext context,
    NotificationModel notification,
  ) async {
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
    if (!context.mounted) return;
    widget.onNotificationTap(context, notification);
  }

  void _handleLongPress(NotificationModel notification) {
    setState(() {
      _isSelectionMode = true;
      _selectedNotifIds.add(notification.notifId);
    });
  }

  Future<void> _confirmAndDeleteSelected(BuildContext context) async {
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

    if (confirmed == true && context.mounted) {
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

  Future<void> _confirmAndClearAll(BuildContext context) async {
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

    if (confirmed == true && context.mounted) {
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

  Future<void> _deleteSingleNotification(BuildContext context, NotificationModel notification) async {
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

    if (confirmed == true && context.mounted) {
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
      backgroundColor: widget.backgroundColor ?? FieldColors.screenBackground,
      appBar: AppBar(
        automaticallyImplyLeading: false,
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
            : AppNavigation.leading(context),
        title: _isSelectionMode
            ? Text('${_selectedNotifIds.length} selected')
            : Row(
                children: [
                  const Icon(Icons.notifications_active_rounded, size: 22),
                  const SizedBox(width: 10),
                  Text(widget.title),
                ],
              ),
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
                  onPressed: () => _confirmAndDeleteSelected(context),
                ),
              ]
            : [
                if (vm.notifications.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.delete_sweep_rounded),
                    tooltip: 'Clear All',
                    onPressed: () => _confirmAndClearAll(context),
                  ),
                if (vm.unreadCount > 0)
                  TextButton.icon(
                    onPressed: () => _markAllRead(context),
                    icon: const Icon(Icons.done_all_rounded, size: 16),
                    label: const Text('Mark all read'),
                  ),
              ],
      ),
      body: vm.uid == null
          ? const Center(child: CircularProgressIndicator())
          : vm.errorMessage != null && vm.notifications.isEmpty
              ? _NotificationsError(
                  message: vm.errorMessage!,
                  onRetry: () => _retryLoad(context),
                )
              : vm.isLoading && vm.notifications.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : vm.notifications.isEmpty
                      ? const _NotificationsEmpty()
                      : RefreshIndicator(
                          onRefresh: () async => _retryLoad(context),
                          child: ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: vm.notifications.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 12),
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
                                onTap: () => _handleTap(context, notification),
                                onLongPress: () => _handleLongPress(notification),
                                onDeleteSingle: () => _deleteSingleNotification(context, notification),
                              );
                            },
                          ),
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

  @override
  Widget build(BuildContext context) {
    final iconConfig = notificationIconForType(notification.type);
    final isUnread = !notification.isRead;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          decoration: BoxDecoration(
            color: isSelected
                ? iconConfig.color.withValues(alpha: 0.08)
                : (isUnread ? Colors.white : Colors.white.withValues(alpha: 0.7)),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? iconConfig.color
                  : (isUnread
                      ? iconConfig.color.withValues(alpha: 0.3)
                      : Colors.grey.withValues(alpha: 0.1)),
              width: (isSelected || isUnread) ? 1.5 : 1,
            ),
            boxShadow: isUnread ? [
              BoxShadow(
                color: iconConfig.color.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              )
            ] : null,
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isSelectionMode) ...[
                  Checkbox(
                    value: isSelected,
                    activeColor: iconConfig.color,
                    onChanged: (_) => onTap(),
                  ),
                  const SizedBox(width: 8),
                ],
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: iconConfig.color.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    iconConfig.icon,
                    size: 20,
                    color: iconConfig.color,
                  ),
                ),
                const SizedBox(width: 14),
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
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: isUnread ? FontWeight.w800 : FontWeight.w600,
                                fontSize: 14,
                                color: const Color(0xFF1E326E),
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
                            )
                          else if (isUnread)
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: iconConfig.color,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        notification.body,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          color: isUnread ? const Color(0xFF1E326E).withValues(alpha: 0.8) : Colors.grey,
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.access_time_rounded, size: 12, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                            relativeTime,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              color: Colors.grey,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NotificationsEmpty extends StatelessWidget {
  const _NotificationsEmpty();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF1E326E).withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.notifications_off_rounded,
                size: 64,
                color: Colors.grey.withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'All caught up!',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF1E326E),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'No new notifications at the moment. We\'ll let you know when something important happens.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                color: Colors.grey,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationsError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _NotificationsError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 64,
              color: Color(0xFFE25730),
            ),
            const SizedBox(height: 16),
            Text(
              'Could not load notifications',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}
