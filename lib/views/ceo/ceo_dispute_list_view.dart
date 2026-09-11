import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/dispute_model.dart';
import '../../constants/route_names.dart';
import '../../theme/ceo_theme.dart';
import '../../widgets/admin/admin_widgets.dart';
import '../../utils/chat_image_utils.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/ceo_viewmodel.dart';
import '../../viewmodels/dispute_viewmodel.dart';
import '../../widgets/ceo/ceo_widgets.dart';

class CeoDisputeListView extends StatefulWidget {
  const CeoDisputeListView({super.key});

  @override
  State<CeoDisputeListView> createState() => _CeoDisputeListViewState();
}

class _CeoDisputeListViewState extends State<CeoDisputeListView> {
  bool _isSelectionMode = false;
  final Set<String> _selectedDisputeIds = {};

  void _toggleSelection(String disputeId) {
    setState(() {
      if (_selectedDisputeIds.contains(disputeId)) {
        _selectedDisputeIds.remove(disputeId);
        if (_selectedDisputeIds.isEmpty) _isSelectionMode = false;
      } else {
        _selectedDisputeIds.add(disputeId);
      }
    });
  }

  Future<void> _confirmAndDeleteSelected(String userId) async {
    if (_selectedDisputeIds.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${_selectedDisputeIds.length} issues?'),
        content: const Text('These issues will be removed from your view. They will still be visible to the Admin and other parties.'),
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
        await context.read<DisputeViewModel>().deleteDisputesForMe(
              _selectedDisputeIds.toList(),
              userId,
            );
        setState(() {
          _selectedDisputeIds.clear();
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
    final auth = context.watch<AuthViewModel>();
    final companyId =
        context.watch<CeoViewModel>().company?.id ??
        auth.user?.companyId ??
        '';
    final userId = auth.user?.uid ?? '';
    final disputeVM = context.read<DisputeViewModel>();

    return Scaffold(
      backgroundColor: CeoColors.screenBg,
      appBar: CeoAppBar(
        leading: _isSelectionMode
            ? IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => setState(() {
                  _isSelectionMode = false;
                  _selectedDisputeIds.clear();
                }),
              )
            : null,
        titleWidget: _isSelectionMode ? Text('${_selectedDisputeIds.length} selected') : null,
        title: _isSelectionMode ? null : 'Reported Issues',
        actions: _isSelectionMode
            ? [
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded),
                  onPressed: () => _confirmAndDeleteSelected(userId),
                ),
              ]
            : null,
      ),
      body:
          companyId.isEmpty
              ? const Center(
                child: CircularProgressIndicator(),
              )
              : StreamBuilder<List<DisputeModel>>(
                stream: disputeVM.watchCompanyDisputes(companyId, userId: userId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error_outline_rounded, size: 48, color: CeoColors.red),
                            const SizedBox(height: 16),
                            Text(
                              'Could not load reported issues: ${snapshot.error}',
                              textAlign: TextAlign.center,
                              style: CeoTheme.mutedStyle(),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  final disputes = snapshot.data ?? [];

                  if (disputes.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: CeoColors.navy.withValues(alpha: 0.05),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.assignment_turned_in_rounded,
                              size: 64,
                              color: CeoColors.textGrey,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'No active issues',
                            style: CeoTheme.titleStyle(size: 20),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'All your orders are running smoothly',
                            style: CeoTheme.mutedStyle(),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: disputes.length,
                    itemBuilder:
                        (context, index) {
                          final dispute = disputes[index];
                          final isSelected = _selectedDisputeIds.contains(dispute.id);
                          return _DisputeCard(
                            dispute: dispute,
                            isSelected: isSelected,
                            isSelectionMode: _isSelectionMode,
                            onTap: () {
                              if (_isSelectionMode) {
                                _toggleSelection(dispute.id);
                              } else {
                                context.push(
                                  RouteNames.ceoDisputeDetail.replaceFirst(':disputeId', dispute.id),
                                );
                              }
                            },
                            onLongPress: () {
                              if (!_isSelectionMode) {
                                setState(() {
                                  _isSelectionMode = true;
                                  _selectedDisputeIds.add(dispute.id);
                                });
                              }
                            },
                          );
                        },
                  );
                },
              ),
    );
  }
}

class _DisputeCard extends StatelessWidget {
  final DisputeModel dispute;
  final bool isSelected;
  final bool isSelectionMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _DisputeCard({
    required this.dispute,
    this.isSelected = false,
    this.isSelectionMode = false,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(dispute.status);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(16),
        child: AdminCard(
      margin: const EdgeInsets.only(bottom: 12),
      color: isSelected ? CeoColors.amber.withValues(alpha: 0.1) : Colors.white,
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (isSelectionMode) ...[
                  Checkbox(
                    value: isSelected,
                    onChanged: (_) => onTap(),
                    activeColor: CeoColors.amber,
                  ),
                  const SizedBox(width: 8),
                ],
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: CeoColors.navy.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(_getIconForType(dispute.type.label), color: CeoColors.navy, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    dispute.type.label,
                    style: CeoTheme.titleStyle(size: 16),
                  ),
                ),
                if (!isSelectionMode)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: statusColor.withOpacity(0.2)),
                    ),
                    child: Text(
                      dispute.status.toUpperCase().replaceAll('_', ' '),
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: CeoColors.screenBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                dispute.description, 
                style: GoogleFonts.plusJakartaSans(fontSize: 14, height: 1.5, color: CeoColors.navy)
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _raisedByLine(dispute),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: CeoColors.textGrey,
              ),
            ),
            if (dispute.photoUrl != null && dispute.photoUrl!.isNotEmpty) ...[
              const SizedBox(height: 16),
              InkWell(
                onTap:
                    () => ChatImageUtils.showFullscreen(
                      context,
                      imageUrl: dispute.photoUrl,
                    ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Image.network(
                        dispute.photoUrl!,
                        height: 180,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder:
                            (_, __, ___) => const SizedBox(
                              height: 100,
                              child: Center(
                                child: Icon(Icons.broken_image_rounded, size: 32, color: CeoColors.textGrey),
                              ),
                            ),
                      ),
                      Container(
                        margin: const EdgeInsets.all(8),
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.fullscreen_rounded, color: Colors.white, size: 20),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            if (dispute.resolutionNotes != null &&
                dispute.resolutionNotes!.isNotEmpty) ...[
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.verified_rounded, color: CeoColors.green, size: 16),
                  const SizedBox(width: 8),
                  Text('RESOLUTION NOTES', style: CeoTheme.sectionHeaderStyle().copyWith(fontSize: 10)),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: CeoColors.green.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: CeoColors.green.withValues(alpha: 0.1)),
                ),
                child: Text(
                  dispute.resolutionNotes!,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    color: CeoColors.green,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.receipt_long_rounded, size: 12, color: CeoColors.textGrey),
                const SizedBox(width: 6),
                Text(
                  'Order #${dispute.orderId.substring(dispute.orderId.length - 8)}',
                  style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.w600, color: CeoColors.textGrey),
                ),
                const Spacer(),
                const Icon(Icons.access_time_rounded, size: 12, color: CeoColors.textGrey),
                const SizedBox(width: 4),
                Text(
                  DateFormat('MMM dd, yyyy').format(dispute.createdAt),
                  style: CeoTheme.mutedStyle(size: 11),
                ),
              ],
            ),
          ],
        ),
        ),
      ),
    );
  }

  String _raisedByLine(DisputeModel dispute) {
    final name = dispute.raisedByName?.trim() ?? '';
    final role = dispute.raisedByRole.replaceAll('_', ' ');
    final who = name.isEmpty ? role : '$name ($role)';
    final material = dispute.materialName?.trim();
    if (material != null && material.isNotEmpty) {
      return '$who · $material';
    }
    return who;
  }

  IconData _getIconForType(String label) {
    final l = label.toLowerCase();
    if (l.contains('quality')) return Icons.high_quality_rounded;
    if (l.contains('delivery')) return Icons.local_shipping_rounded;
    if (l.contains('price')) return Icons.sell_rounded;
    if (l.contains('payment')) return Icons.payments_rounded;
    return Icons.report_problem_rounded;
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'open':
        return CeoColors.red;
      case 'under_review':
        return CeoColors.amber;
      case 'resolved':
        return CeoColors.green;
      default:
        return CeoColors.textGrey;
    }
  }
}
