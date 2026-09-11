import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../constants/route_names.dart';
import '../../../models/chat_thread_model.dart';
import '../../../theme/field_theme.dart';
import '../../../utils/app_navigation.dart';
import '../../../viewmodels/field_user/field_chat_viewmodel.dart';
import '../../../viewmodels/field_user/field_session_viewmodel.dart';
import '../widgets/field_async_states.dart';
import '../widgets/field_chat_list_skeleton.dart';
import 'field_chat_thread_args.dart';

class FieldChatListView extends StatefulWidget {
  const FieldChatListView({super.key});

  @override
  State<FieldChatListView> createState() => _FieldChatListViewState();
}

class _FieldChatListViewState extends State<FieldChatListView> {
  bool _isSelectionMode = false;
  final Set<String> _selectedChatIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  void _bootstrap() {
    final session = context.read<FieldSessionViewModel>();
    final uid = session.user?.uid;
    final companyId = session.companyId;
    if (uid == null || companyId == null) return;
    context.read<FieldChatViewModel>().watchConversations(companyId, uid);
  }

  void _openThread(ChatThreadModel thread) {
    if (_isSelectionMode) {
      _toggleSelection(thread.chatId);
      return;
    }
    context.push(
      RouteNames.fieldChatThread.replaceFirst(':orderId', thread.supplierId),
      extra: FieldChatThreadArgs(
        supplierUid: thread.supplierId,
        supplierName: thread.supplierName,
      ),
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

  void _enterSelectionMode(String chatId) {
    setState(() {
      _isSelectionMode = true;
      _selectedChatIds.add(chatId);
    });
  }

  Future<void> _confirmAndDeleteSelected() async {
    if (_selectedChatIds.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${_selectedChatIds.length} conversations?'),
        content: const Text('This will remove these conversations from your list. They will still be visible to the suppliers.'),
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
      final session = context.read<FieldSessionViewModel>();
      final uid = session.user?.uid;
      if (uid == null) return;

      try {
        final vm = context.read<FieldChatViewModel>();
        for (final chatId in _selectedChatIds) {
          await vm.hideConversation(chatId, uid);
        }
        setState(() {
          _selectedChatIds.clear();
          _isSelectionMode = false;
        });
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete conversations: $e')),
          );
        }
      }
    }
  }

  String _relativeTime(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM d').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<FieldChatViewModel>();

    return Theme(
      data: FieldTheme.theme,
      child: Scaffold(
        backgroundColor: FieldColors.screenBackground,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          leading: _isSelectionMode
              ? IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => setState(() {
                    _isSelectionMode = false;
                    _selectedChatIds.clear();
                  }),
                )
              : AppNavigation.leading(context),
          titleSpacing: AppNavigation.canPop(context) ? 4 : 20,
          title: _isSelectionMode
              ? Text('${_selectedChatIds.length} selected')
              : const Text('Messages'),
          actions: _isSelectionMode
              ? [
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded),
                    onPressed: _confirmAndDeleteSelected,
                  ),
                ]
              : null,
        ),
        body: vm.errorMessage != null && vm.threads.isEmpty
            ? FieldErrorState(
                title: 'Could not load messages',
                message: vm.errorMessage!,
                onRetry: _bootstrap,
              )
            : vm.isLoadingThreads && vm.threads.isEmpty
                ? const FieldChatListSkeleton()
                : vm.threads.isEmpty
                    ? const _ChatListEmpty()
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(
                          FieldSpacing.lg,
                          FieldSpacing.sm,
                          FieldSpacing.lg,
                          FieldSpacing.xxl,
                        ),
                        itemCount: vm.threads.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: FieldSpacing.sm),
                        itemBuilder: (context, index) {
                          final thread = vm.threads[index];
                          final isSelected = _selectedChatIds.contains(thread.chatId);
                          return _ChatListTile(
                            thread: thread,
                            isSelected: isSelected,
                            isSelectionMode: _isSelectionMode,
                            relativeTime: _relativeTime(thread.lastMessageAt),
                            onTap: () => _openThread(thread),
                            onLongPress: () => _enterSelectionMode(thread.chatId),
                          );
                        },
                      ),
      ),
    );
  }
}

class _ChatListTile extends StatelessWidget {
  final ChatThreadModel thread;
  final bool isSelected;
  final bool isSelectionMode;
  final String relativeTime;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _ChatListTile({
    required this.thread,
    this.isSelected = false,
    this.isSelectionMode = false,
    required this.relativeTime,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(FieldRadius.card),
        child: Ink(
          decoration: FieldTheme.cardDecoration().copyWith(
            color: isSelected ? FieldColors.accentAmber.withValues(alpha: 0.1) : Colors.white,
            border: isSelected ? Border.all(color: FieldColors.accentAmber, width: 1.5) : null,
          ),
          padding: const EdgeInsets.all(FieldSpacing.md),
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
                radius: 22,
                backgroundColor: FieldColors.primaryNavy.withValues(alpha: 0.08),
                child: Text(
                  thread.supplierName.isNotEmpty
                      ? thread.supplierName[0].toUpperCase()
                      : '?',
                  style: FieldTypography.titleMedium.copyWith(
                    color: FieldColors.primaryNavy,
                  ),
                ),
              ),
              const SizedBox(width: FieldSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      thread.supplierName,
                      style: FieldTypography.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: FieldSpacing.xs),
                    Text(
                      thread.lastMessage.isEmpty
                          ? 'No messages yet'
                          : thread.lastMessage,
                      style: FieldTypography.bodyMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: FieldSpacing.sm),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    relativeTime,
                    style: FieldTypography.labelSmall.copyWith(fontSize: 10),
                  ),
                  if (thread.unreadFieldUser > 0 && !isSelectionMode) ...[
                    const SizedBox(height: FieldSpacing.sm),
                    Container(
                      constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      decoration: BoxDecoration(
                        color: FieldColors.accentAmber,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        thread.unreadFieldUser > 99
                            ? '99+'
                            : '${thread.unreadFieldUser}',
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

class _ChatListEmpty extends StatelessWidget {
  const _ChatListEmpty();

  @override
  Widget build(BuildContext context) {
    return const FieldEmptyState(
      icon: Icons.chat_bubble_outline,
      title: 'No conversations yet',
      subtitle: 'Start a conversation from any order or supplier profile.',
    );
  }
}
