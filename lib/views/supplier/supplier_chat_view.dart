import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../theme/supplier_theme.dart';
import '../../constants/route_names.dart';
import '../../models/chat_thread_model.dart';
import '../../utils/app_navigation.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/chat_viewmodel.dart';
import '../../widgets/supplier_nav_bar.dart';

class SupplierChatView extends StatefulWidget {
  const SupplierChatView({super.key});

  @override
  State<SupplierChatView> createState() => _SupplierChatViewState();
}

class _SupplierChatViewState extends State<SupplierChatView> {
  bool _isSelectionMode = false;
  final Set<String> _selectedChatIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  void _bootstrap() {
    final uid = context.read<AuthViewModel>().user?.uid;
    if (uid == null) return;
    context.read<ChatViewModel>().watchSupplierThreads(uid);
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM d').format(dt);
  }

  String _displayName(ChatThreadModel thread) {
    if (thread.fieldUserName.isNotEmpty) return thread.fieldUserName;
    return 'Field User';
  }

  String _avatarLabel(ChatThreadModel thread) {
    final name = _displayName(thread);
    if (name.isNotEmpty && name != 'Field User') {
      return name[0].toUpperCase();
    }
    if (thread.fieldUserId.isNotEmpty) {
      return thread.fieldUserId.substring(0, 1).toUpperCase();
    }
    return '?';
  }

  void _openThread(ChatThreadModel thread) {
    if (_isSelectionMode) {
      _toggleSelection(thread.chatId);
      return;
    }
    context.push(
      '${RouteNames.supplierChat}/${thread.chatId}',
      extra: thread,
    );
  }

  void _toggleSelection(String chatId) {
    setState(() {
      if (_selectedChatIds.contains(chatId)) {
        _selectedChatIds.remove(chatId);
        if (_selectedChatIds.isEmpty) _isSelectionMode = false;
      } else {
        _selectedChatIds.add(chatId);
      }
    });
  }

  Future<void> _confirmAndDeleteSelected(String userId) async {
    if (_selectedChatIds.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${_selectedChatIds.length} conversations?'),
        content: const Text('These conversations will be removed from your list. They will still be visible to the field users.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        final vm = context.read<ChatViewModel>();
        for (final chatId in _selectedChatIds) {
          await vm.hideConversation(chatId, userId);
        }
        setState(() {
          _selectedChatIds.clear();
          _isSelectionMode = false;
        });
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = context.watch<AuthViewModel>().user?.uid ?? '';

    return RootTabPopScope(
      isHome: false,
      homeRoute: RouteNames.supplierDashboard,
      child: Scaffold(
      backgroundColor: FieldColors.screenBackground,
      appBar: SupplierAppBar(
        leading: _isSelectionMode
            ? IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => setState(() {
                  _isSelectionMode = false;
                  _selectedChatIds.clear();
                }),
              )
            : null,
        titleWidget: _isSelectionMode ? Text('${_selectedChatIds.length} selected') : null,
        title: _isSelectionMode ? null : 'Messages',
        actions: _isSelectionMode
            ? [
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded),
                  onPressed: () => _confirmAndDeleteSelected(userId),
                ),
              ]
            : null,
      ),
      bottomNavigationBar: _isSelectionMode
          ? null
          : const SupplierNavBar(currentIndex: SupplierNavBar.messagesTabIndex),
      body: Consumer<ChatViewModel>(
        builder: (context, vm, _) {
          if (vm.isLoading && vm.threads.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (vm.errorMessage != null && vm.threads.isEmpty) {
            return _MessagesError(message: vm.errorMessage!, onRetry: _bootstrap);
          }
          
          final threads = vm.threads.where((t) => !t.hiddenBy.contains(userId)).toList();
          
          if (threads.isEmpty) {
            return const _MessagesEmpty();
          }
          return RefreshIndicator(
            onRefresh: () async => _bootstrap(),
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              itemCount: threads.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final thread = threads[index];
                final hasUnread = thread.unreadSupplier > 0;
                final isSelected = _selectedChatIds.contains(thread.chatId);
                return _SupplierThreadTile(
                  displayName: _displayName(thread),
                  avatarLabel: _avatarLabel(thread),
                  lastMessage: thread.lastMessage,
                  timeAgo: _timeAgo(thread.lastMessageAt),
                  unreadCount: thread.unreadSupplier,
                  hasUnread: hasUnread,
                  isSelected: isSelected,
                  isSelectionMode: _isSelectionMode,
                  onTap: () => _openThread(thread),
                  onLongPress: () {
                    if (!_isSelectionMode) {
                      setState(() {
                        _isSelectionMode = true;
                        _selectedChatIds.add(thread.chatId);
                      });
                    }
                  },
                );
              },
            ),
          );
        },
      ),
    ),
    );
  }
}

class _SupplierThreadTile extends StatelessWidget {
  final String displayName;
  final String avatarLabel;
  final String lastMessage;
  final String timeAgo;
  final int unreadCount;
  final bool hasUnread;
  final bool isSelected;
  final bool isSelectionMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _SupplierThreadTile({
    required this.displayName,
    required this.avatarLabel,
    required this.lastMessage,
    required this.timeAgo,
    required this.unreadCount,
    required this.hasUnread,
    this.isSelected = false,
    this.isSelectionMode = false,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor =
        isSelected ? FieldColors.accentAmber : FieldColors.textMuted;
    final labelColor =
        isSelected ? FieldColors.primaryNavy : FieldColors.textMuted;
    final labelWeight = isSelected ? FontWeight.w600 : FontWeight.w400;

    return Material(
      color: isSelected ? FieldColors.accentAmber.withValues(alpha: 0.1) : FieldColors.surfaceWhite,
      borderRadius: BorderRadius.circular(FieldRadius.card),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(FieldRadius.card),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(FieldRadius.card),
            border: Border.all(
              color: isSelected
                  ? FieldColors.accentAmber
                  : (hasUnread
                      ? FieldColors.accentAmber.withValues(alpha: 0.5)
                      : FieldColors.borderSubtle),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              if (isSelectionMode) ...[
                Checkbox(
                  value: isSelected,
                  onChanged: (_) => onTap(),
                  activeColor: FieldColors.accentAmber,
                ),
                const SizedBox(width: 8),
              ],
              CircleAvatar(
                radius: 24,
                backgroundColor: FieldColors.primaryNavy.withValues(alpha: 0.1),
                child: Text(
                  avatarLabel,
                  style: FieldTypography.titleMedium.copyWith(
                    color: FieldColors.primaryNavy,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: FieldTypography.titleMedium.copyWith(
                        fontWeight:
                            hasUnread ? FontWeight.w700 : FontWeight.w600,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      lastMessage.isEmpty ? 'No messages yet' : lastMessage,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: FieldTypography.bodyMedium.copyWith(
                        color: hasUnread
                            ? FieldColors.textPrimary
                            : FieldColors.textMuted,
                        fontWeight:
                            hasUnread ? FontWeight.w500 : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    timeAgo,
                    style: FieldTypography.labelSmall.copyWith(
                      fontSize: 11,
                      color: FieldColors.textMuted,
                    ),
                  ),
                  if (hasUnread && !isSelectionMode) ...[
                    const SizedBox(height: 6),
                    Container(
                      constraints:
                          const BoxConstraints(minWidth: 20, minHeight: 20),
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      decoration: const BoxDecoration(
                        color: FieldColors.accentAmber,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        unreadCount > 99 ? '99+' : '$unreadCount',
                        style: FieldTypography.labelSmall.copyWith(
                          color: FieldColors.primaryNavy,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          height: 1,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessagesEmpty extends StatelessWidget {
  const _MessagesEmpty();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 56,
              color: FieldColors.textMuted,
            ),
            const SizedBox(height: 16),
            const Text(
              'No messages yet',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Field users can message you from orders, compare, or supplier profiles.',
              style: const TextStyle(color: FieldColors.textMuted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _MessagesError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _MessagesError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: FieldColors.statusDanger),
            const SizedBox(height: 12),
            const Text(
              'Could not load messages',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: FieldColors.textMuted),
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
