// MVVM: Widgets — pure presentation, no business logic.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/admin_theme.dart';
import '../../utils/chat_image_utils.dart';

/// Compact stat card for the admin dashboard grid.
class AdminStatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const AdminStatCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.color = AdminColors.amber,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AdminTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: AdminColors.navy,
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: AdminTheme.mutedStyle(size: 11).copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

/// Section header with optional trailing action.
class AdminSectionHeader extends StatelessWidget {
  final String title;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  const AdminSectionHeader({
    super.key,
    required this.title,
    this.icon,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 20, color: AdminColors.navy),
              const SizedBox(width: 8),
            ],
            Text(title, style: AdminTheme.titleStyle(size: 16)),
          ],
        ),
        if (actionLabel != null)
          TextButton.icon(
            onPressed: onAction,
            icon: const Icon(Icons.arrow_forward_rounded, size: 14),
            label: Text(actionLabel!),
          ),
      ],
    );
  }
}

/// Status pill for admin lists.
class StatusChip extends StatelessWidget {
  final String status;

  const StatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final style = AdminTheme.statusColors(status);
    final label = status.isEmpty
        ? status
        : status[0].toUpperCase() + status.substring(1).replaceAll('_', ' ');
        
    IconData statusIcon = Icons.info_outline_rounded;
    if (status == 'active' || status == 'confirmed' || status == 'approved') statusIcon = Icons.check_circle_rounded;
    if (status == 'pending') statusIcon = Icons.hourglass_empty_rounded;
    if (status == 'rejected' || status == 'suspended' || status == 'failed') statusIcon = Icons.cancel_rounded;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: style.bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: style.fg.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(statusIcon, size: 10, color: style.fg),
          const SizedBox(width: 4),
          Text(
            label.toUpperCase(),
            style: GoogleFonts.plusJakartaSans(
              color: style.fg,
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// Placeholder shown when a list is empty.
class AdminEmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? subMessage;

  const AdminEmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.subMessage,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 64, horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AdminColors.navy.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 48, color: AdminColors.textGrey.withValues(alpha: 0.5)),
            ),
            const SizedBox(height: 24),
            Text(
              message,
              style: AdminTheme.titleStyle(size: 18).copyWith(color: AdminColors.navy.withValues(alpha: 0.7)),
              textAlign: TextAlign.center,
            ),
            if (subMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                subMessage!,
                style: AdminTheme.mutedStyle(size: 13),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Approve / Reject action row used on pending approval cards.
class ApprovalActions extends StatelessWidget {
  final VoidCallback onApprove;
  final ValueChanged<String> onReject;
  final bool isLoading;

  const ApprovalActions({
    super.key,
    required this.onApprove,
    required this.onReject,
    this.isLoading = false,
  });

  Future<void> _showRejectDialog(BuildContext context) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.cancel_outlined, color: AdminColors.red),
            const SizedBox(width: 10),
            const Text('Reject Application'),
          ],
        ),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: AdminTheme.inputDecoration(
            labelText: 'Reason for rejection',
            hintText: 'This will be shown to the applicant...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              if (controller.text.trim().isEmpty) return;
              Navigator.pop(context, controller.text.trim());
            },
            icon: const Icon(Icons.close_rounded, size: 18),
            label: const Text('REJECT'),
            style: ElevatedButton.styleFrom(backgroundColor: AdminColors.red),
          ),
        ],
      ),
    );

    if (reason != null && reason.isNotEmpty) {
      onReject(reason);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: isLoading ? null : () => _showRejectDialog(context),
            icon: const Icon(Icons.close_rounded, size: 18),
            label: const Text('REJECT'),
            style: AdminTheme.destructiveButtonStyle(height: 46),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: isLoading ? null : onApprove,
            icon: isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.check_rounded, size: 18),
            label: const Text('APPROVE'),
            style: AdminTheme.primaryButtonStyle(height: 46).copyWith(
              backgroundColor: WidgetStateProperty.all(AdminColors.green),
            ),
          ),
        ),
      ],
    );
  }
}

/// Titled block inside an admin approval card.
class AdminApprovalSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const AdminApprovalSection({
    super.key,
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AdminSectionLabel(title),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AdminColors.screenBg.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AdminColors.border.withValues(alpha: 0.5)),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
}

/// Label + value row for admin approval detail panels.
class AdminDetailRow extends StatelessWidget {
  final String label;
  final String value;
  final int maxLines;

  const AdminDetailRow({
    super.key,
    required this.label,
    required this.value,
    this.maxLines = 3,
  });

  @override
  Widget build(BuildContext context) {
    final display = value.trim().isEmpty ? 'Not Provided' : value.trim();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: AdminTheme.mutedStyle(size: 11).copyWith(fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              display,
              maxLines: maxLines,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AdminColors.navy,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Horizontal chip list for coverage areas, categories, etc.
class AdminChipList extends StatelessWidget {
  final List<String> items;
  final Color? color;

  const AdminChipList({
    super.key,
    required this.items,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Text('None declared', style: AdminTheme.mutedStyle(size: 12).copyWith(fontStyle: FontStyle.italic));
    }
    final chipColor = color ?? AdminColors.navy;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: items.map((item) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: chipColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: chipColor.withValues(alpha: 0.2)),
          ),
          child: Text(
            item,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: chipColor,
              letterSpacing: 0.3,
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// One tappable document thumbnail; opens fullscreen via [ChatImageUtils].
class AdminDocumentThumbnail extends StatelessWidget {
  final String label;
  final String? imageUrl;

  const AdminDocumentThumbnail({
    super.key,
    required this.label,
    this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl != null && imageUrl!.trim().isNotEmpty;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.description_rounded, size: 12, color: AdminColors.textGrey),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AdminTheme.mutedStyle(size: 10).copyWith(fontWeight: FontWeight.w800, letterSpacing: 0.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          AspectRatio(
            aspectRatio: 16 / 10,
            child: Material(
              color: AdminColors.screenBg,
              borderRadius: BorderRadius.circular(10),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: hasImage
                    ? () => ChatImageUtils.showFullscreen(
                          context,
                          imageUrl: imageUrl,
                        )
                    : null,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: AdminColors.border),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: hasImage
                      ? Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.network(
                              imageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  const _MissingDocPlaceholder(),
                              loadingBuilder: (context, child, progress) =>
                                  progress == null ? child : const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                            ),
                            Positioned(
                              right: 6,
                              bottom: 6,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Icon(
                                  Icons.zoom_in_rounded,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                          ],
                        )
                      : const _MissingDocPlaceholder(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MissingDocPlaceholder extends StatelessWidget {
  const _MissingDocPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.image_not_supported_rounded,
              size: 24, color: AdminColors.textGrey.withValues(alpha: 0.5)),
          const SizedBox(height: 4),
          Text('NO DOCUMENT', style: AdminTheme.mutedStyle(size: 9).copyWith(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

/// Row of document thumbnails with consistent spacing.
class AdminDocumentThumbnailRow extends StatelessWidget {
  final List<({String label, String? url})> documents;

  const AdminDocumentThumbnailRow({super.key, required this.documents});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < documents.length; i++) ...[
          if (i > 0) const SizedBox(width: 12),
          AdminDocumentThumbnail(
            label: documents[i].label,
            imageUrl: documents[i].url,
          ),
        ],
      ],
    );
  }
}

/// White card container matching admin panel style.
class AdminCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final Color? color;

  const AdminCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.margin,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding,
      decoration: AdminTheme.cardDecoration().copyWith(color: color),
      child: child,
    );
  }
}
