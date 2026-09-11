import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../constants/route_names.dart';
import '../../../models/rfq_model.dart';
import '../../../theme/supplier_theme.dart';
import '../../../viewmodels/supplier_viewmodel.dart';
import '../../../viewmodels/rfq_viewmodel.dart';
import '../../../viewmodels/auth_viewmodel.dart';
import '../../../widgets/supplier_nav_bar.dart';

class SupplierRfqListView extends StatefulWidget {
  const SupplierRfqListView({super.key});

  @override
  State<SupplierRfqListView> createState() => _SupplierRfqListViewState();
}

class _SupplierRfqListViewState extends State<SupplierRfqListView> {
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
        title: Text('Delete ${_selectedRfqIds.length} requests?'),
        content: const Text('This will remove these quote requests from your list. Other participants will still see them.'),
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
        await context.read<RfqViewModel>().hideRfqs(_selectedRfqIds.toList(), userId);
        setState(() {
          _selectedRfqIds.clear();
          _isSelectionMode = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Requests deleted from your view.')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete requests: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final supplierVM = context.watch<SupplierViewModel>();
    final userId = context.watch<AuthViewModel>().user?.uid ?? '';

    return Scaffold(
      backgroundColor: FieldColors.screenBackground,
      appBar: SupplierAppBar(
        leading: _isSelectionMode
            ? IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => setState(() {
                  _isSelectionMode = false;
                  _selectedRfqIds.clear();
                }),
              )
            : null,
        title: _isSelectionMode ? '${_selectedRfqIds.length} selected' : 'Open Quote Requests',
        actions: _isSelectionMode
            ? [
                IconButton(
                  icon: const Icon(Icons.select_all_rounded),
                  onPressed: () {
                    // This is tricky because it's a stream. We'd need the current data.
                    // For now, let's keep it simple or just handle what's visible.
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded),
                  onPressed: () => _confirmAndDeleteSelected(userId),
                ),
              ]
            : null,
      ),
      body: StreamBuilder<List<RfqModel>>(
        stream: supplierVM.streamOpenRfqsForSupplier(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          final rfqs = snapshot.data ?? [];

          if (rfqs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.request_quote_outlined, size: 64, color: FieldColors.textMuted.withOpacity(0.3)),
                  const SizedBox(height: 16),
                  Text('No open requests matching you', style: FieldTypography.titleMedium),
                  const SizedBox(height: 8),
                  Text('Requests will appear here when companies look for materials in your categories and area.', textAlign: TextAlign.center, style: FieldTypography.bodyMedium),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: rfqs.length,
            itemBuilder: (context, index) {
              final rfq = rfqs[index];
              final isSelected = _selectedRfqIds.contains(rfq.id);
              return _SupplierRfqTile(
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
                    context.push(RouteNames.supplierSubmitBid.replaceFirst(':rfqId', rfq.id));
                  }
                },
              );
            },
          );
        },
      ),
      bottomNavigationBar: const SupplierNavBar(currentIndex: 2), // Example index
    );
  }
}

class _SupplierRfqTile extends StatelessWidget {
  final RfqModel rfq;
  final bool isSelected;
  final bool isSelectionMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _SupplierRfqTile({
    required this.rfq,
    this.isSelected = false,
    this.isSelectionMode = false,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: isSelected ? FieldColors.accentAmber.withValues(alpha: 0.1) : FieldColors.surfaceWhite,
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FieldRadius.card),
          side: BorderSide(
            color: isSelected ? FieldColors.accentAmber : FieldColors.borderSubtle,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(
            padding: const EdgeInsets.all(16),
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(rfq.category, style: FieldTypography.titleMedium),
                      const SizedBox(height: 8),
                      Text(rfq.materialDescription, maxLines: 2, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _Badge(icon: Icons.numbers, label: '${rfq.quantity} ${rfq.unit}'),
                          const SizedBox(width: 8),
                          _Badge(icon: Icons.location_on, label: rfq.city),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('Ends: ${DateFormat('MMM dd').format(rfq.requiredByDate)}', style: FieldTypography.labelSmall),
                    ],
                  ),
                ),
                if (!isSelectionMode) const Icon(Icons.chevron_right),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Badge({required this.icon, required this.label});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: FieldColors.primaryNavy.withOpacity(0.05), borderRadius: BorderRadius.circular(4)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: FieldColors.primaryNavy),
          const SizedBox(width: 4),
          Text(label, style: FieldTypography.labelSmall.copyWith(color: FieldColors.primaryNavy)),
        ],
      ),
    );
  }
}
