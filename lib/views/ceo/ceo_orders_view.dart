// MVVM: View — no business logic

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../constants/route_names.dart';
import '../../theme/ceo_theme.dart';
import '../../utils/app_navigation.dart';
import '../../utils/formatters.dart';
import '../../viewmodels/ceo_viewmodel.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../models/order_model.dart';
import '../../widgets/ceo_nav_bar.dart';
import '../../widgets/ceo/ceo_widgets.dart';

const _statusTabs = [
  'All',
  'Pending',
  'Confirmed',
  'Cancelled',
];

class CeoOrdersView extends StatefulWidget {
  final int initialTab;

  const CeoOrdersView({super.key, this.initialTab = 0});

  @override
  State<CeoOrdersView> createState() => _CeoOrdersViewState();
}

class _CeoOrdersViewState extends State<CeoOrdersView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  bool _isSelectionMode = false;
  final Set<String> _selectedOrderIds = {};

  @override
  void initState() {
    super.initState();
    final initial = widget.initialTab.clamp(0, _statusTabs.length - 1);
    _tabController = TabController(
      length: _statusTabs.length,
      vsync: this,
      initialIndex: initial,
    );
    _tabController.addListener(_handleTabChange);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final vm = context.read<CeoViewModel>();
      if (vm.company == null) {
        vm.loadDashboard();
      }
    });
  }

  void _handleTabChange() {
    if (_tabController.indexIsChanging && _isSelectionMode) {
      setState(() {
        _isSelectionMode = false;
        _selectedOrderIds.clear();
      });
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _confirmAndDeleteSelected(CeoViewModel vm) async {
    if (_selectedOrderIds.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Remove ${_selectedOrderIds.length} orders?'),
        content: const Text('This will remove these orders from your view. The records will remain for other users and audit purposes.'),
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

    if (confirmed == true) {
      await vm.hideOrders(_selectedOrderIds.toList());
      setState(() {
        _selectedOrderIds.clear();
        _isSelectionMode = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authVm = context.watch<AuthViewModel>();
    final vm = context.watch<CeoViewModel>();
    final companyId = vm.company?.id ?? authVm.companyId ?? '';

    return RootTabPopScope(
      isHome: false,
      homeRoute: RouteNames.ceoDashboard,
      child: Scaffold(
      backgroundColor: CeoColors.screenBg,
      appBar: CeoAppBar(
        leading: _isSelectionMode
            ? IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => setState(() {
                  _isSelectionMode = false;
                  _selectedOrderIds.clear();
                }),
              )
            : null,
        title: _isSelectionMode
            ? '${_selectedOrderIds.length} selected'
            : 'Company Orders',
        actions: _isSelectionMode
            ? [
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded),
                  onPressed: () => _confirmAndDeleteSelected(vm),
                ),
              ]
            : null,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: false,
          indicatorColor: CeoColors.amber,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: CeoColors.textGrey,
          labelStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 13),
          unselectedLabelStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w500, fontSize: 13),
          tabs: _statusTabs.map((s) => Tab(text: s)).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _statusTabs.map((status) {
          return StreamBuilder<List<OrderModel>>(
            stream: vm.watchCompanyOrders(companyId, status),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline_rounded, size: 48, color: CeoColors.red),
                        const SizedBox(height: 16),
                        Text(
                          'Could not load orders. Pull to refresh or try again shortly.',
                          style: CeoTheme.mutedStyle(),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              }
              if (companyId.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.business_rounded, size: 48, color: CeoColors.textGrey),
                      const SizedBox(height: 16),
                      Text(
                        'Company profile not loaded yet.',
                        style: CeoTheme.mutedStyle(),
                      ),
                    ],
                  ),
                );
              }
              final orders = snap.data ?? [];
              if (orders.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.receipt_long_rounded, size: 48, color: CeoColors.textGrey),
                      const SizedBox(height: 16),
                      Text(
                        'No orders found',
                        style: CeoTheme.mutedStyle(),
                      ),
                    ],
                  ),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: orders.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, i) {
                  final order = orders[i];
                  final isSelected = _selectedOrderIds.contains(order.orderId);
                  return _orderCard(context, vm, order, isSelected);
                },
              );
            },
          );
        }).toList(),
      ),
      bottomNavigationBar: const CeoNavBar(currentIndex: 4),
    ),
    );
  }

  Widget _orderCard(
      BuildContext context, CeoViewModel vm, OrderModel order, bool isSelected) {
    final canCancel = order.status == 'pending' || order.status == 'accepted';
    final awaitingApproval = isCeoAwaitingApproval(order.status);

    return GestureDetector(
      onLongPress: () {
        setState(() {
          _isSelectionMode = true;
          _selectedOrderIds.add(order.orderId);
        });
      },
      onTap: () {
        if (_isSelectionMode) {
          setState(() {
            if (_selectedOrderIds.contains(order.orderId)) {
              _selectedOrderIds.remove(order.orderId);
              if (_selectedOrderIds.isEmpty) _isSelectionMode = false;
            } else {
              _selectedOrderIds.add(order.orderId);
            }
          });
        } else {
          _showOrderDetail(context, order);
        }
      },
      child: AdminCard(
        color: isSelected ? CeoColors.amber.withValues(alpha: 0.1) : Colors.white,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                if (_isSelectionMode) ...[
                  SizedBox(
                    height: 24,
                    width: 24,
                    child: Checkbox(
                      value: isSelected,
                      onChanged: (val) {
                        setState(() {
                          if (val == true) {
                            _selectedOrderIds.add(order.orderId);
                          } else {
                            _selectedOrderIds.remove(order.orderId);
                            if (_selectedOrderIds.isEmpty) _isSelectionMode = false;
                          }
                        });
                      },
                      activeColor: CeoColors.amber,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: CeoColors.navy.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.inventory_2_rounded, size: 18, color: CeoColors.navy),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    order.materialName,
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: CeoColors.navy,
                    ),
                  ),
                ),
                if (!_isSelectionMode) CeoStatusBadge(status: order.status),
              ],
            ),
            const SizedBox(height: 12),
            _iconInfoRow(Icons.store_rounded, 'Supplier: ${order.supplierName}'),
            const SizedBox(height: 6),
            _iconInfoRow(Icons.engineering_rounded, 'Requested by: ${order.fieldUserName}'),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: CeoColors.border,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${order.quantity} ${order.unit}',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: CeoColors.navy,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  AppFormatters.formatPKRCurrency(order.totalAmount),
                  style: GoogleFonts.plusJakartaSans(
                    color: CeoColors.navy,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.calendar_today_rounded, size: 12, color: CeoColors.textGrey),
                const SizedBox(width: 6),
                Text(
                  AppFormatters.date(order.createdAt),
                  style: CeoTheme.mutedStyle(size: 11),
                ),
              ],
            ),
            if (!_isSelectionMode) ...[
              if (awaitingApproval) ...[
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _confirmReject(context, vm, order),
                        icon: const Icon(Icons.close_rounded, size: 18),
                        label: const Text('Reject'),
                        style: CeoTheme.destructiveButtonStyle(height: 44),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => vm.approveOrder(order),
                        icon: const Icon(Icons.check_rounded, size: 18),
                        label: const Text('Approve'),
                        style: CeoTheme.primaryButtonStyle(height: 44),
                      ),
                    ),
                  ],
                ),
              ],
              if (canCancel) ...[
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => _confirmCancel(context, vm, order),
                    icon: const Icon(Icons.cancel_outlined, size: 16, color: CeoColors.red),
                    label: Text(
                      'Cancel Order',
                      style: GoogleFonts.plusJakartaSans(
                        color: CeoColors.red,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _iconInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 14, color: CeoColors.textGrey),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: CeoTheme.mutedStyle(size: 13),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  void _confirmReject(
      BuildContext context, CeoViewModel vm, OrderModel order) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.report_problem_rounded, color: CeoColors.red),
            const SizedBox(width: 10),
            const Text('Reject order?'),
          ],
        ),
        content: TextField(
          controller: reasonController,
          decoration: CeoTheme.inputDecoration(
            labelText: 'Reason for rejection (optional)',
            hintText: 'e.g. Price too high, redundant request...',
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          OutlinedButton.icon(
            style: CeoTheme.destructiveButtonStyle(height: 40),
            onPressed: () {
              Navigator.pop(ctx);
              vm.rejectOrder(order, reason: reasonController.text);
            },
            icon: const Icon(Icons.close_rounded, size: 18),
            label: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  void _confirmCancel(
      BuildContext context, CeoViewModel vm, OrderModel order) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning_rounded, color: CeoColors.amber),
            const SizedBox(width: 10),
            const Text('Cancel order?'),
          ],
        ),
        content: Text(
            'Are you sure you want to cancel order #${order.id}? '
            'This action cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('No, keep it')),
          OutlinedButton.icon(
            style: CeoTheme.destructiveButtonStyle(height: 40),
            onPressed: () {
              Navigator.pop(ctx);
              vm.cancelOrder(order.id,
                  context.read<AuthViewModel>().companyId ?? '');
            },
            icon: const Icon(Icons.check_rounded, size: 18),
            label: const Text('Yes, cancel'),
          ),
        ],
      ),
    );
  }

  void _showOrderDetail(BuildContext context, OrderModel order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: CeoColors.screenBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: CeoColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.receipt_long_rounded, color: CeoColors.navy, size: 24),
                const SizedBox(width: 12),
                Text(
                  'Order Detail',
                  style: CeoTheme.titleStyle(size: 20),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '#${order.id}',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                color: CeoColors.textGrey,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Center(child: CeoStatusBadge(status: order.status)),
            const SizedBox(height: 24),
            _detailSection(Icons.category_rounded, 'Material', order.materialName),
            _detailSection(Icons.inventory_rounded, 'Quantity', '${order.quantity} ${order.unit}'),
            _detailSection(Icons.store_rounded, 'Supplier', order.supplierName),
            _detailSection(Icons.person_rounded, 'Field User', order.fieldUserName),
            _detailSection(Icons.location_on_rounded, 'Delivery Address', order.deliveryAddress),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1),
            ),
            _detailSection(Icons.sell_rounded, 'Unit Price',
                AppFormatters.formatPKRCurrency(order.unitPrice)),
            _detailSection(Icons.payments_rounded, 'Total Amount',
                AppFormatters.formatPKRCurrency(order.totalAmount),
                valueColor: CeoColors.navy, isBold: true),
            _detailSection(Icons.account_balance_wallet_rounded, 'Platform Fee',
                '-${AppFormatters.formatPKRCurrency(order.commissionAmount)}',
                valueColor: CeoColors.red),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _detailSection(IconData icon, String label, String value, {Color? valueColor, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: CeoColors.textGrey),
          const SizedBox(width: 10),
          Text(label, style: CeoTheme.mutedStyle(size: 13)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: GoogleFonts.plusJakartaSans(
                fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
                fontSize: 14,
                color: valueColor ?? CeoColors.navy,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
