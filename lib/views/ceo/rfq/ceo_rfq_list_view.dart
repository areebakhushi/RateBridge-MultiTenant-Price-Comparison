import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../constants/route_names.dart';
import '../../../models/rfq_model.dart';
import '../../../services/plan_limit_service.dart';
import '../../../theme/ceo_theme.dart';
import '../../../viewmodels/auth_viewmodel.dart';
import '../../../viewmodels/ceo_viewmodel.dart';
import '../../../viewmodels/rfq_viewmodel.dart';
import '../../../widgets/ceo_nav_bar.dart';
import '../../../widgets/ceo/ceo_widgets.dart';

class CeoRfqListView extends StatefulWidget {
  final bool fieldUser;

  const CeoRfqListView({
    super.key,
    this.fieldUser = false,
    @visibleForTesting this.debugFirestore,
  });

  final FirebaseFirestore? debugFirestore;

  @override
  State<CeoRfqListView> createState() => _CeoRfqListViewState();
}

class _CeoRfqListViewState extends State<CeoRfqListView> {
  bool _isSelectionMode = false;
  final Set<String> _selectedRfqIds = {};

  void _toggleSelection(String rfqId) {
    setState(() {
      if (_selectedRfqIds.contains(rfqId)) {
        _selectedRfqIds.remove(rfqId);
        if (_selectedRfqIds.isEmpty) _isSelectionMode = false;
      } else {
        _selectedRfqIds.add(rfqId);
      }
    });
  }

  Future<void> _confirmAndDeleteSelected(String userId) async {
    if (_selectedRfqIds.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Remove ${_selectedRfqIds.length} RFQs?'),
        content: const Text('This will remove these quote requests from your view. The records remain for audit purposes.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await context.read<RfqViewModel>().hideRfqs(_selectedRfqIds.toList(), userId);
        setState(() {
          _selectedRfqIds.clear();
          _isSelectionMode = false;
        });
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to remove RFQs: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final company = context.watch<CeoViewModel>().company;
    final auth = context.watch<AuthViewModel>();
    final companyId = company?.id ?? auth.user?.companyId ?? '';
    final userId = auth.user?.uid ?? '';

    return Scaffold(
      backgroundColor: CeoColors.screenBg,
      appBar: CeoAppBar(
        leading: _isSelectionMode
            ? IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => setState(() {
                  _isSelectionMode = false;
                  _selectedRfqIds.clear();
                }),
              )
            : null,
        titleWidget: _isSelectionMode
            ? Text('${_selectedRfqIds.length} selected')
            : null,
        title: _isSelectionMode
            ? null
            : (widget.fieldUser ? 'Bulk Quotes' : 'Request for Quotations'),
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
              ? const Center(child: CircularProgressIndicator())
              : StreamBuilder<List<RfqModel>>(
                stream: context.read<RfqViewModel>().watchCompanyRfqs(
                  companyId,
                ),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  var rfqs = snapshot.data ?? [];
                  
                  // Filter hidden RFQs locally if the stream doesn't yet
                  if (userId.isNotEmpty) {
                    rfqs = rfqs.where((r) => !r.hiddenBy.contains(userId)).toList();
                  }

                  if (rfqs.isEmpty) {
                    return _buildEmptyState(context);
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: rfqs.length,
                    itemBuilder:
                        (context, index) {
                          final rfq = rfqs[index];
                          final isSelected = _selectedRfqIds.contains(rfq.id);
                          return _RfqTile(
                            rfq: rfq,
                            isSelected: isSelected,
                            isSelectionMode: _isSelectionMode,
                            onLongPress: () {
                              setState(() {
                                _isSelectionMode = true;
                                _selectedRfqIds.add(rfq.id);
                              });
                            },
                            onTap: () {
                              if (_isSelectionMode) {
                                _toggleSelection(rfq.id);
                              } else {
                                context.push(
                                  (widget.fieldUser
                                      ? RouteNames.fieldRfqDetail
                                      : RouteNames.ceoRfqDetail)
                                      .replaceFirst(':rfqId', rfq.id),
                                );
                              }
                            },
                          );
                        },
                  );
                },
              ),
      floatingActionButton: _isSelectionMode ? null : Padding(
        padding: const EdgeInsets.only(right: 4, bottom: 4),
        child: FloatingActionButton.extended(
          onPressed: () async {
            final effectivePlan = await PlanLimitService.companyPlan(
              widget.debugFirestore ?? FirebaseFirestore.instance,
              companyId,
            );
            if (!context.mounted) return;
            if (effectivePlan.planKey != 'premium') {
              _showPremiumRequiredDialog(context);
            } else {
              context.push(
                widget.fieldUser ? RouteNames.fieldCreateRfq : RouteNames.ceoCreateRfq,
              );
            }
          },
          elevation: 5,
          highlightElevation: 8,
          backgroundColor: CeoColors.navy,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          icon: const Icon(Icons.add_circle_rounded, color: Colors.white),
          label: Text(
            'CREATE RFQ',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
      bottomNavigationBar: widget.fieldUser ? null : const CeoNavBar(currentIndex: 2),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: const Padding(
              padding: EdgeInsets.fromLTRB(32, 32, 32, 104),
              child: _RfqEmptyState(),
            ),
          ),
        );
      },
    );
  }

  void _showPremiumRequiredDialog(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.workspace_premium_rounded, color: CeoColors.amber),
                const SizedBox(width: 10),
                const Text('Premium Access'),
              ],
            ),
            content: Text(
              widget.fieldUser
                  ? 'Bulk Quote Requests (RFQ) are only available on the Premium plan. Please ask your CEO to upgrade the company workspace.'
                  : 'Bulk Quote Requests (RFQ) are only available on the Premium plan. Upgrade now to start receiving competitive bids and save on materials.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(widget.fieldUser ? 'CLOSE' : 'MAYBE LATER'),
              ),
              if (!widget.fieldUser)
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    context.push(RouteNames.ceoSubscription);
                  },
                  icon: const Icon(Icons.upgrade_rounded),
                  label: const Text('UPGRADE NOW'),
                ),
            ],
          ),
    );
  }
}

class _RfqEmptyState extends StatelessWidget {
  const _RfqEmptyState();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                CeoColors.amber.withValues(alpha: 0.42),
                CeoColors.navy.withValues(alpha: 0.16),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: CeoColors.amber.withValues(alpha: 0.28),
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Center(
            child: Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.request_quote_rounded,
                size: 36,
                color: CeoColors.navy,
              ),
            ),
          ),
        ),
        const SizedBox(height: 28),
        Text(
          'No active RFQs',
          textAlign: TextAlign.center,
          style: CeoTheme.titleStyle(size: 22).copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
            height: 1.25,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Get competitive bulk pricing by requesting quotes from multiple suppliers at once.',
          textAlign: TextAlign.center,
          style: CeoTheme.mutedStyle(size: 14).copyWith(
            height: 1.55,
            color: const Color(0xFF6B7396),
          ),
        ),
        const SizedBox(height: 24),
        const _PremiumFeatureBadge(),
      ],
    );
  }
}

class _PremiumFeatureBadge extends StatelessWidget {
  const _PremiumFeatureBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 7, 14, 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [
            CeoColors.amber.withValues(alpha: 0.28),
            CeoColors.amber.withValues(alpha: 0.10),
          ],
        ),
        border: Border.all(color: CeoColors.amber.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: CeoColors.amber.withValues(alpha: 0.22),
            blurRadius: 14,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.auto_awesome_rounded,
            color: CeoColors.darkAmber,
            size: 15,
          ),
          const SizedBox(width: 6),
          Text(
            'Premium Feature',
            style: GoogleFonts.plusJakartaSans(
              color: CeoColors.darkAmber,
              fontWeight: FontWeight.w800,
              fontSize: 12,
              height: 1.15,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _RfqTile extends StatelessWidget {
  final RfqModel rfq;
  final bool isSelected;
  final bool isSelectionMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _RfqTile({
    required this.rfq,
    this.isSelected = false,
    this.isSelectionMode = false,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final isOpen = rfq.status == 'open';
    final statusColor = isOpen ? CeoColors.green : CeoColors.textGrey;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: isSelected ? CeoColors.amber.withValues(alpha: 0.08) : Colors.white,
        elevation: 1,
        shadowColor: Colors.black.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isSelectionMode) ...[
                  Center(
                    child: Checkbox(
                      value: isSelected,
                      onChanged: (_) => onTap(),
                      activeColor: CeoColors.amber,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: CeoColors.navy.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.request_quote_rounded, color: CeoColors.navy, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              rfq.category,
                              style: CeoTheme.titleStyle(size: 16),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              children: [
                                Icon(isOpen ? Icons.bolt_rounded : Icons.lock_clock_rounded, size: 10, color: statusColor),
                                const SizedBox(width: 4),
                                Text(
                                  rfq.status.toUpperCase(),
                                  style: TextStyle(
                                    color: statusColor,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        rfq.materialDescription,
                        style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w500, color: CeoColors.navy),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _iconDetail(Icons.inventory_2_outlined, '${rfq.quantity} ${rfq.unit}'),
                          const SizedBox(width: 12),
                          _iconDetail(Icons.location_on_outlined, rfq.city),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.event_note_rounded, size: 12, color: CeoColors.textGrey),
                          const SizedBox(width: 6),
                          Text(
                            'Deadline: ${DateFormat('MMM dd, yyyy').format(rfq.requiredByDate)}',
                            style: CeoTheme.mutedStyle(size: 12).copyWith(
                              color: rfq.requiredByDate.isBefore(DateTime.now()) ? CeoColors.red : null,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (!isSelectionMode)
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Icon(Icons.arrow_forward_ios_rounded, size: 14, color: CeoColors.textGrey),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _iconDetail(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: CeoColors.textGrey),
        const SizedBox(width: 4),
        Text(text, style: CeoTheme.mutedStyle(size: 12)),
      ],
    );
  }
}
