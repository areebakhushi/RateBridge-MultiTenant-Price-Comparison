import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../models/chat_message_model.dart';
import '../../../repositories/order_repository.dart';
import '../../../services/cloudinary_service.dart';
import '../../../theme/field_theme.dart';
import '../../../utils/chat_image_utils.dart';
import '../../../utils/phone_launcher_utils.dart';
import '../../../viewmodels/field_user/field_chat_viewmodel.dart';
import '../../../viewmodels/field_user/field_session_viewmodel.dart';
import '../../../widgets/chat_attachment_image.dart';
import '../../../widgets/chat_pending_image_preview.dart';
import '../widgets/field_async_states.dart';

class FieldChatThreadView extends StatefulWidget {
  final String supplierUid;
  final String supplierName;
  final String? orderId;

  const FieldChatThreadView({
    super.key,
    required this.supplierUid,
    required this.supplierName,
    this.orderId,
  });

  @override
  State<FieldChatThreadView> createState() => _FieldChatThreadViewState();
}

class _FieldChatThreadViewState extends State<FieldChatThreadView>
    with WidgetsBindingObserver {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  FieldChatViewModel? _chatVm;
  int _lastMessageCount = 0;
  String? _supplierPhone;
  PendingChatImage? _pendingImage;

  bool _isSelectionMode = false;
  final Set<String> _selectedMessageIds = {};

  bool get _canSend =>
      _messageController.text.trim().isNotEmpty || _pendingImage != null;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _chatVm ??= context.read<FieldChatViewModel>();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _messageController.addListener(_onComposerChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _openThread());
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    if (!mounted) return;
    if (View.of(context).viewInsets.bottom > 0) {
      _scrollToBottom(force: true);
    }
  }

  void _onComposerChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _openThread() async {
    final session = context.read<FieldSessionViewModel>();
    final uid = session.user?.uid;
    final companyId = session.companyId;
    if (uid == null || companyId == null) return;

    await context.read<FieldChatViewModel>().openThread(
          companyId: companyId,
          fieldUserId: uid,
          fieldUserName: session.user?.name ?? 'Field User',
          supplierId: widget.supplierUid,
          supplierName: widget.supplierName,
        );

    if (!mounted) return;

    final orderRepo = context.read<OrderRepository>();
    try {
      final supplier = await orderRepo.getSupplierById(widget.supplierUid);
      if (mounted) setState(() => _supplierPhone = supplier?.contact);
    } catch (_) {}
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _messageController.removeListener(_onComposerChanged);
    _chatVm?.closeThread();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom({bool force = false}) {
    if (!_scrollController.hasClients) return;
    if (!force) {
      final position = _scrollController.position;
      if (position.maxScrollExtent - position.pixels >= 120) return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _callSupplier() async {
    await PhoneLauncherUtils.dial(context, _supplierPhone);
  }

  Future<void> _pickImage() async {
    final source = await ChatImageUtils.showSourceSheet(context);
    if (source == null || !mounted) return;

    final picked = await ChatImageUtils.pickImage(source);
    if (picked != null && mounted) {
      setState(() => _pendingImage = picked);
    }
  }

  void _removePendingImage() {
    setState(() => _pendingImage = null);
  }

  Future<void> _send() async {
    final text = _messageController.text.trim();
    final pending = _pendingImage;
    if (text.isEmpty && pending == null) return;

    final session = context.read<FieldSessionViewModel>();
    final uid = session.user?.uid;
    final companyId = session.companyId;
    if (uid == null || companyId == null) return;

    String? attachmentUrl;
    if (pending != null) {
      attachmentUrl = await CloudinaryService.uploadImageBytes(
        bytes: pending.bytes,
        folder: 'ratebridge/chat',
        filename: pending.name ?? 'chat.jpg',
      );
      if (!mounted) return;
      if (attachmentUrl == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image upload failed. Please try again.')),
        );
        return;
      }
    }

    final success = await context.read<FieldChatViewModel>().sendMessage(
          companyId: companyId,
          fieldUserId: uid,
          fieldUserName: session.user?.name ?? 'Field User',
          supplierId: widget.supplierUid,
          supplierName: widget.supplierName,
          content: text,
          attachmentUrl: attachmentUrl,
        );

    if (!mounted) return;

    if (success) {
      _messageController.clear();
      setState(() => _pendingImage = null);
      _scrollToBottom(force: true);
    } else {
      final error = context.read<FieldChatViewModel>().errorMessage ??
          'Could not send message. Please try again.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error)),
      );
    }
  }

  void _toggleMessageSelection(String messageId) {
    setState(() {
      if (_selectedMessageIds.contains(messageId)) {
        _selectedMessageIds.remove(messageId);
        if (_selectedMessageIds.isEmpty) _isSelectionMode = false;
      } else {
        _selectedMessageIds.add(messageId);
      }
    });
  }

  Future<void> _confirmAndDeleteSelected(String userId) async {
    if (_selectedMessageIds.isEmpty) return;

    final vm = context.read<FieldChatViewModel>();
    final selectedMessages = vm.messages.where((m) => _selectedMessageIds.contains(m.id)).toList();
    
    if (selectedMessages.isEmpty) {
      setState(() {
        _selectedMessageIds.clear();
        _isSelectionMode = false;
      });
      return;
    }

    // Logic: "Delete for Everyone" is available only if ALL selected messages were sent by ME.
    final allSentByMe = selectedMessages.every((m) => m.senderId == userId && userId.isNotEmpty);

    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text('Delete ${selectedMessages.length} message(s)?'),
        children: [
          if (allSentByMe)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, 'everyone'),
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('Delete for everyone', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              ),
            ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'me'),
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('Delete for me'),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'cancel'),
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
          ),
        ],
      ),
    );

    if (action == null || action == 'cancel' || !mounted) return;

    final companyId = context.read<FieldSessionViewModel>().companyId!;
    final chatId = FieldChatViewModel.chatIdFor(
      companyId: companyId,
      fieldUserId: userId,
      supplierId: widget.supplierUid,
    );

    try {
      if (action == 'me') {
        await vm.deleteMessagesForMe(chatId, _selectedMessageIds.toList(), userId);
      } else if (action == 'everyone') {
        await vm.deleteMessagesForEveryone(chatId, _selectedMessageIds.toList());
      }
      setState(() {
        _selectedMessageIds.clear();
        _isSelectionMode = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete messages: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<FieldChatViewModel>();
    final session = context.watch<FieldSessionViewModel>();
    final currentUid = session.user?.uid ?? '';

    if (vm.messages.length != _lastMessageCount) {
      final wasEmpty = _lastMessageCount == 0;
      _lastMessageCount = vm.messages.length;
      _scrollToBottom(force: wasEmpty);
    }

    final groups = _groupMessages(vm.messages, currentUid);

    return Theme(
      data: FieldTheme.theme,
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        backgroundColor: FieldColors.screenBackground,
        appBar: FieldAppBar(
          leading: _isSelectionMode
              ? IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => setState(() {
                    _isSelectionMode = false;
                    _selectedMessageIds.clear();
                  }),
                )
              : null,
          titleWidget: _isSelectionMode
              ? Text('${_selectedMessageIds.length} selected')
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.supplierName,
                      style: FieldTypography.titleMedium.copyWith(
                        color: FieldColors.surfaceWhite,
                        fontSize: 16,
                      ),
                    ),
                    if (widget.orderId != null)
                      Text(
                        'Order #${widget.orderId}',
                        style: FieldTypography.labelSmall.copyWith(
                          color: FieldColors.surfaceWhite.withValues(alpha: 0.75),
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
          actions: _isSelectionMode
              ? [
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded),
                    onPressed: () => _confirmAndDeleteSelected(currentUid),
                  ),
                ]
              : [
                  IconButton(
                    icon: const Icon(Icons.phone_outlined),
                    tooltip: 'Call supplier',
                    onPressed: _callSupplier,
                  ),
                ],
        ),
        body: vm.errorMessage != null && vm.messages.isEmpty
            ? FieldErrorState(
                title: 'Could not load messages',
                message: vm.errorMessage!,
                onRetry: _openThread,
              )
            : vm.isLoadingMessages
                ? const FieldChatThreadSkeleton()
                : vm.messages.isEmpty
                    ? const _ThreadEmpty()
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(
                          FieldSpacing.lg,
                          FieldSpacing.md,
                          FieldSpacing.lg,
                          FieldSpacing.md,
                        ),
                        itemCount: groups.length,
                        itemBuilder: (context, index) {
                          return _MessageGroupBubble(
                            group: groups[index],
                            currentUid: currentUid,
                            isSelectionMode: _isSelectionMode,
                            selectedIds: _selectedMessageIds,
                            onMessageTap: (id) {
                              if (_isSelectionMode) {
                                _toggleMessageSelection(id);
                              }
                            },
                            onMessageLongPress: (id) {
                              final msg = vm.messages.firstWhere((m) => m.id == id);
                              if (!_isSelectionMode && !msg.isDeletedForEveryone) {
                                setState(() {
                                  _isSelectionMode = true;
                                  _selectedMessageIds.add(id);
                                });
                              }
                            },
                          );
                        },
                      ),
        bottomNavigationBar: _isSelectionMode
            ? null
            : SafeArea(
                top: false,
                child: _MessageInputBar(
                  controller: _messageController,
                  isSending: vm.isSending,
                  canSend: _canSend,
                  pendingImage: _pendingImage,
                  onAttach: _pickImage,
                  onRemoveImage: _removePendingImage,
                  onSend: _send,
                ),
              ),
      ),
    );
  }

  List<_MessageGroup> _groupMessages(
    List<ChatMessageModel> messages,
    String currentUid,
  ) {
    if (messages.isEmpty) return [];

    final groups = <_MessageGroup>[];
    var current = _MessageGroup(
      senderId: messages.first.senderId,
      isSelf: messages.first.senderId == currentUid,
      messages: [messages.first],
      timestamp: messages.first.timestamp,
    );

    for (var i = 1; i < messages.length; i++) {
      final msg = messages[i];
      if (msg.senderId == current.senderId) {
        current.messages.add(msg);
      } else {
        groups.add(current);
        current = _MessageGroup(
          senderId: msg.senderId,
          isSelf: msg.senderId == currentUid,
          messages: [msg],
          timestamp: msg.timestamp,
        );
      }
    }
    groups.add(current);
    return groups;
  }
}

class _MessageGroup {
  final String senderId;
  final bool isSelf;
  final List<ChatMessageModel> messages;
  final DateTime timestamp;

  _MessageGroup({
    required this.senderId,
    required this.isSelf,
    required this.messages,
    required this.timestamp,
  });
}

class _MessageGroupBubble extends StatelessWidget {
  final _MessageGroup group;
  final String currentUid;
  final bool isSelectionMode;
  final Set<String> selectedIds;
  final ValueChanged<String> onMessageTap;
  final ValueChanged<String> onMessageLongPress;

  const _MessageGroupBubble({
    required this.group,
    required this.currentUid,
    required this.isSelectionMode,
    required this.selectedIds,
    required this.onMessageTap,
    required this.onMessageLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final timeFmt = DateFormat('h:mm a');

    return Padding(
      padding: const EdgeInsets.only(bottom: FieldSpacing.md),
      child: Column(
        crossAxisAlignment:
            group.isSelf ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          ...group.messages.map(
            (msg) => Padding(
              padding: const EdgeInsets.only(bottom: FieldSpacing.xs),
              child: _ChatBubble(
                message: msg,
                isSelf: msg.senderId == currentUid,
                isSelected: selectedIds.contains(msg.id),
                isSelectionMode: isSelectionMode,
                onTap: () => onMessageTap(msg.id),
                onLongPress: () => onMessageLongPress(msg.id),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: FieldSpacing.xs),
            child: Text(
              timeFmt.format(group.timestamp),
              style: FieldTypography.labelSmall.copyWith(
                fontSize: 10,
                color: FieldColors.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final ChatMessageModel message;
  final bool isSelf;
  final bool isSelected;
  final bool isSelectionMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _ChatBubble({
    required this.message,
    required this.isSelf,
    required this.isSelected,
    required this.isSelectionMode,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    if (message.isDeletedForEveryone) {
      return _buildDeletedBubble();
    }

    final hasText = message.content.trim().isNotEmpty;
    final hasImage =
        message.attachmentUrl != null && message.attachmentUrl!.isNotEmpty;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (isSelectionMode && !isSelf) ...[
            Checkbox(
              value: isSelected,
              onChanged: (_) => onTap(),
              activeColor: FieldColors.accentAmber,
            ),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width * 0.72,
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: isSelected
                      ? (isSelf ? FieldColors.primaryNavy.withValues(alpha: 0.8) : FieldColors.accentAmber.withValues(alpha: 0.2))
                      : (isSelf ? FieldColors.primaryNavy : FieldColors.chatBubbleReceived),
                  borderRadius: BorderRadius.circular(12),
                  border: isSelected && !isSelf ? Border.all(color: FieldColors.accentAmber) : null,
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: hasImage && !hasText ? FieldSpacing.xs : FieldSpacing.sm + 2,
                    vertical: FieldSpacing.sm,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (hasImage)
                        ChatAttachmentImage(
                          imageUrl: message.attachmentUrl!,
                          borderRadius: BorderRadius.circular(10),
                          onTap: () => ChatImageUtils.showFullscreen(
                            context,
                            imageUrl: message.attachmentUrl,
                          ),
                        ),
                      if (hasImage && hasText) const SizedBox(height: FieldSpacing.sm),
                      if (hasText)
                        Text(
                          message.content,
                          style: FieldTypography.bodyLarge.copyWith(
                            fontSize: 14,
                            color: isSelf
                                ? FieldColors.surfaceWhite
                                : FieldColors.textPrimary,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (isSelectionMode && isSelf) ...[
            const SizedBox(width: 4),
            Checkbox(
              value: isSelected,
              onChanged: (_) => onTap(),
              activeColor: FieldColors.accentAmber,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDeletedBubble() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: FieldColors.chatBubbleReceived.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: FieldColors.borderSubtle),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.block_flipped, size: 14, color: FieldColors.textMuted),
          const SizedBox(width: 6),
          Text(
            'This message was deleted',
            style: FieldTypography.bodyMedium.copyWith(
              color: FieldColors.textMuted,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageInputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool isSending;
  final bool canSend;
  final PendingChatImage? pendingImage;
  final VoidCallback onAttach;
  final VoidCallback onRemoveImage;
  final VoidCallback onSend;

  const _MessageInputBar({
    required this.controller,
    required this.isSending,
    required this.canSend,
    required this.pendingImage,
    required this.onAttach,
    required this.onRemoveImage,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        FieldSpacing.lg,
        FieldSpacing.sm,
        FieldSpacing.lg,
        FieldSpacing.sm,
      ),
      decoration: const BoxDecoration(
        color: FieldColors.surfaceWhite,
        border: Border(top: BorderSide(color: FieldColors.borderSubtle)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (pendingImage != null)
            ChatPendingImagePreview(
              imageBytes: pendingImage!.bytes,
              onRemove: onRemoveImage,
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              IconButton(
                onPressed: isSending ? null : onAttach,
                icon: const Icon(Icons.image_outlined),
                color: FieldColors.primaryNavy,
                tooltip: 'Attach image',
                visualDensity: VisualDensity.compact,
              ),
              Expanded(
                child: TextField(
                  controller: controller,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) {
                    if (canSend && !isSending) onSend();
                  },
                  decoration: const InputDecoration(
                    hintText: 'Type a message…',
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: FieldSpacing.md,
                      vertical: FieldSpacing.sm,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: FieldSpacing.sm),
              Material(
                color: canSend && !isSending
                    ? FieldColors.accentAmber
                    : FieldColors.accentAmber.withValues(alpha: 0.45),
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: canSend && !isSending ? onSend : null,
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: isSending
                        ? const Padding(
                            padding: EdgeInsets.all(FieldSpacing.sm),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: FieldColors.textPrimary,
                            ),
                          )
                        : const Icon(
                            Icons.send_rounded,
                            color: FieldColors.textPrimary,
                            size: 20,
                          ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ThreadEmpty extends StatelessWidget {
  const _ThreadEmpty();

  @override
  Widget build(BuildContext context) {
    return const FieldEmptyState(
      icon: Icons.waving_hand_outlined,
      title: 'No messages yet',
      subtitle: 'Say hello to start the conversation with your supplier.',
    );
  }
}
