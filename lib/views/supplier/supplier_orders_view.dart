import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../utils/app_navigation.dart';
import '../../utils/notification_utils.dart';
import '../../utils/phone_launcher_utils.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/supplier_viewmodel.dart';
import '../../models/order_model.dart';
import '../../theme/supplier_theme.dart';
import '../../constants/app_constants.dart';
import '../../constants/route_names.dart';
import '../../utils/currency_formatter.dart';
import '../../utils/app_theme.dart';
import '../../widgets/dispute_report_sheet.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/supplier_nav_bar.dart';
import '../../widgets/supplier/supplier_async_states.dart';

class SupplierOrdersView extends StatefulWidget {
  final int initialTabIndex;

  const SupplierOrdersView({super.key, this.initialTabIndex = 0});

  @override
  State<SupplierOrdersView> createState() => _SupplierOrdersViewState();
}

class _SupplierOrdersViewState extends State<SupplierOrdersView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _tabs = [
    'Pending',
    'Accepted',
    'Delivered',
    'Confirmed',
    'Rejected',
  ];

  bool _isSelectionMode = false;
  final Set<String> _selectedOrderIds = {};

  @override
  void initState() {
    super.initState();
    final initialTab = widget.initialTabIndex.clamp(0, _tabs.length - 1);
    _tabController = TabController(
      length: _tabs.length,
      vsync: this,
      initialIndex: initialTab,
    );
    _tabController.addListener(_handleTabChange);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final vm = context.read<SupplierViewModel>();
      final companyId = vm.selectedCompanyId;
      if (companyId != null) {
        vm.loadOrders(companyId, null);
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

  Future<void> _confirmAndDeleteSelected(SupplierViewModel viewModel) async {
    if (_selectedOrderIds.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${_selectedOrderIds.length} orders?'),
        content: const Text('This will remove these orders from your history. They will remain available for the other participants.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete for Me', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await viewModel.hideOrders(_selectedOrderIds.toList());
        setState(() {
          _selectedOrderIds.clear();
          _isSelectionMode = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Orders removed from your history.')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to remove orders: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<SupplierViewModel>(context);

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
                  _selectedOrderIds.clear();
                }),
              )
            : null,
        title: _isSelectionMode ? '${_selectedOrderIds.length} selected' : 'Orders',
        actions: _isSelectionMode
            ? [
                IconButton(
                  icon: const Icon(Icons.select_all_rounded),
                  tooltip: 'Select All',
                  onPressed: () {
                    setState(() {
                      final currentTabLabel = _tabs[_tabController.index];
                      final currentOrders = _getOrdersForTab(viewModel, currentTabLabel);
                      _selectedOrderIds.addAll(currentOrders.map((o) => o.orderId));
                    });
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded),
                  tooltip: 'Delete for Me',
                  onPressed: () => _confirmAndDeleteSelected(viewModel),
                ),
              ]
            : null,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: _tabs.map((t) => Tab(text: t)).toList(),
        ),
      ),
      bottomNavigationBar: _isSelectionMode ? null : const SupplierNavBar(currentIndex: 2),
      body: TabBarView(
        controller: _tabController,
        children:
            _tabs.map((status) => _buildOrderList(viewModel, status)).toList(),
      ),
    ),
    );
  }

  List<OrderModel> _getOrdersForTab(SupplierViewModel viewModel, String tab) {
    return viewModel.orders.where((o) {
      final status = o.status.toLowerCase().trim();
      switch (tab) {
        case 'Pending':
          return status == 'pending' || status == 'pending_approval';
        case 'Accepted':
          return status == 'accepted' || status == 'inprogress';
        case 'Delivered':
          return status == 'delivered';
        case 'Confirmed':
          return status == 'confirmed';
        case 'Rejected':
          return status == 'rejected' || status == 'cancelled';
        default:
          return false;
      }
    }).toList();
  }

  Widget _buildOrderList(SupplierViewModel viewModel, String tab) {
    final filteredOrders = _getOrdersForTab(viewModel, tab);

    if (viewModel.isLoading && viewModel.orders.isEmpty) {
      return const SupplierListSkeleton(itemCount: 4, itemHeight: 160);
    }

    if (filteredOrders.isEmpty) {
      return _buildTabEmptyState(tab);
    }

    return RefreshIndicator(
      onRefresh: () => viewModel.loadOrders(viewModel.selectedCompanyId!, null),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: filteredOrders.length,
        itemBuilder: (context, index) {
          final order = filteredOrders[index];
          final isSelected = _selectedOrderIds.contains(order.orderId);
          return _buildOrderCard(viewModel, order, tab, isSelected);
        },
      ),
    );
  }

  Widget _buildTabEmptyState(String tab) {
    final (title, subtitle) = switch (tab) {
      'Pending' => (
        'No pending orders',
        'New orders from field users will appear here for you to accept',
      ),
      'Accepted' => (
        'No accepted orders',
        'Orders you accept will show here until marked as delivered',
      ),
      'Delivered' => (
        'No delivered orders',
        'Mark accepted orders as delivered once they reach the site',
      ),
      'Confirmed' => (
        'No confirmed orders',
        'Completed and confirmed orders will appear here',
      ),
      'Rejected' => (
        'No rejected orders',
        'Rejected or cancelled orders are listed in this tab',
      ),
      _ => ('No orders found', 'Orders matching this status will appear here'),
    };

    return SupplierEmptyState(
      icon: Icons.receipt_long_outlined,
      title: title,
      subtitle: subtitle,
    );
  }

  Widget _buildOrderCard(
    SupplierViewModel viewModel,
    OrderModel order,
    String tab,
    bool isSelected,
  ) {
    final netPayout = order.totalAmount * (1 - AppConstants.commissionRate);
    final isRemovableTab = tab == 'Confirmed' || tab == 'Rejected';

    return GestureDetector(
      onLongPress: isRemovableTab ? () {
        setState(() {
          _isSelectionMode = true;
          _selectedOrderIds.add(order.orderId);
        });
      } : null,
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
          _showOrderDetail(viewModel, order);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: SupplierTheme.cardDecoration(
          borderColor: isSelected ? FieldColors.accentAmber : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                            activeColor: FieldColors.accentAmber,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        'ID: #${order.orderId.substring(order.orderId.length > 6 ? order.orderId.length - 6 : 0).toUpperCase()}',
                        style: AppTextStyles.label.copyWith(letterSpacing: 0.5),
                      ),
                      Text(
                        DateFormat('MMM dd, hh:mm a').format(order.createdAt),
                        style: AppTextStyles.caption,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(order.materialName, style: AppTextStyles.h3),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.person_outline,
                        size: 14,
                        color: FieldColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        order.fieldUserName,
                        style: AppTextStyles.bodyMuted.copyWith(fontSize: 13),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('QUANTITY', style: AppTextStyles.label),
                          const SizedBox(height: 4),
                          Text(
                            '${order.quantity} ${order.unit}',
                            style: AppTextStyles.body.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('NET PAYOUT', style: AppTextStyles.label),
                          const SizedBox(height: 4),
                          Text(
                            CurrencyFormatter.formatPKR(netPayout),
                            style: AppTextStyles.h3.copyWith(
                              color: FieldColors.statusSuccess,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  StatusBadge(
                    label: order.status.toUpperCase(),
                    status: order.status,
                  ),
                  const Spacer(),
                  if (!_isSelectionMode)
                    TextButton(
                      onPressed: () => _showOrderDetail(viewModel, order),
                      child: const Text('DETAILS'),
                    ),
                ],
              ),
            ),
            if (!_isSelectionMode) ...[
              if (tab == 'Pending') ...[
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _showRejectDialog(viewModel, order),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: FieldColors.statusDanger),
                            foregroundColor: FieldColors.statusDanger,
                          ),
                          child: const Text('REJECT'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _confirmAccept(viewModel, order),
                          child: const Text('ACCEPT'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (tab == 'Accepted') ...[
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => _confirmDelivered(viewModel, order),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: FieldColors.statusSuccess,
                      ),
                      child: const Text('MARK AS DELIVERED'),
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

  void _showOrderDetail(SupplierViewModel viewModel, OrderModel order) {
    final commission = order.totalAmount * AppConstants.commissionRate;
    final netPayout = order.totalAmount * (1 - AppConstants.commissionRate);
    final commissionPercent = (AppConstants.commissionRate * 100)
        .toStringAsFixed(0);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => Container(
            height: MediaQuery.of(context).size.height * 0.85,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(AppRadius.xl),
              ),
            ),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: FieldColors.borderSubtle,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Order Details', style: AppTextStyles.h2),
                          StatusBadge(
                            label: order.status.toUpperCase(),
                            status: order.status,
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      _detailItem(
                        'Material',
                        order.materialName,
                        Icons.inventory_2_outlined,
                      ),
                      _detailItem(
                        'Quantity',
                        '${order.quantity} ${order.unit}',
                        Icons.straighten_outlined,
                      ),
                      _detailItem(
                        'Unit Price',
                        CurrencyFormatter.formatPKR(order.unitPrice),
                        Icons.price_change_outlined,
                      ),
                      const Divider(height: 48),
                      _detailItem(
                        'Customer',
                        order.fieldUserName,
                        Icons.person_outline,
                      ),
                      _detailItem(
                        'Company',
                        viewModel.companyNameFor(order.companyId) ?? 'Company',
                        Icons.business_outlined,
                      ),
                      _detailItem(
                        'Delivery Address',
                        order.deliveryAddress,
                        Icons.location_on_outlined,
                      ),
                      const Divider(height: 48),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Total Amount', style: AppTextStyles.body),
                          Text(
                            CurrencyFormatter.formatPKR(order.totalAmount),
                            style: AppTextStyles.h3,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Commission ($commissionPercent%)',
                            style: AppTextStyles.bodyMuted,
                          ),
                          Text(
                            '- ${CurrencyFormatter.formatPKR(commission)}',
                            style: const TextStyle(
                              color: FieldColors.statusDanger,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: FieldColors.statusSuccess.withValues(
                            alpha: 0.12,
                          ),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Net Payout',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: FieldColors.statusSuccess,
                              ),
                            ),
                            Text(
                              CurrencyFormatter.formatPKR(netPayout),
                              style: AppTextStyles.h3.copyWith(
                                color: FieldColors.statusSuccess,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (DisputeReportSheet.canReportOrder(order)) ...[
                        const SizedBox(height: 24),
                        TextButton.icon(
                          onPressed:
                              () => DisputeReportSheet.show(context, order),
                          icon: const Icon(
                            Icons.report_problem_outlined,
                            size: 16,
                          ),
                          label: const Text('Report an issue'),
                          style: TextButton.styleFrom(
                            foregroundColor: FieldColors.statusWarning,
                          ),
                        ),
                      ],
                      const SizedBox(height: 40),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed:
                                  () => PhoneLauncherUtils.dial(
                                    context,
                                    order.fieldUserPhone,
                                  ),
                              icon: const Icon(Icons.phone_outlined, size: 18),
                              label: const Text('CALL'),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _openOrderChat(context, order),
                              icon: const Icon(
                                Icons.chat_bubble_outline,
                                size: 18,
                              ),
                              label: const Text('CHAT'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ],
            ),
          ),
    );
  }

  void _openOrderChat(BuildContext context, OrderModel order) {
    final supplierUid =
        context.read<AuthViewModel>().user?.uid ?? order.supplierId;
    final thread = supplierChatThreadFromOrder(
      order: order,
      supplierUid: supplierUid,
    );
    context.push(
      RouteNames.supplierChatThread.replaceFirst(':orderId', thread.chatId),
      extra: thread,
    );
  }

  Widget _detailItem(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: FieldColors.screenBackground,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: FieldColors.primaryNavy),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTextStyles.caption),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _confirmAccept(SupplierViewModel viewModel, OrderModel order) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Accept Order'),
            content: const Text(
              'Confirm that you can fulfill this order. This will notify the field user.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('CANCEL'),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await viewModel.acceptOrder(order.orderId, order.companyId);
                },
                child: const Text('CONFIRM'),
              ),
            ],
          ),
    );
  }

  void _showRejectDialog(SupplierViewModel viewModel, OrderModel order) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Reject Order'),
            content: TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'Enter reason for rejection',
              ),
              maxLines: 3,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('CANCEL'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (controller.text.isEmpty) return;
                  Navigator.pop(context);
                  await viewModel.rejectOrder(
                    order.orderId,
                    order.companyId,
                    controller.text,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: FieldColors.statusDanger,
                ),
                child: const Text('REJECT'),
              ),
            ],
          ),
    );
  }

  void _confirmDelivered(SupplierViewModel viewModel, OrderModel order) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Mark as Delivered'),
            content: const Text('Has the shipment reached the site location?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('CANCEL'),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await viewModel.markDelivered(order.orderId, order.companyId);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: FieldColors.statusSuccess,
                ),
                child: const Text('CONFIRM'),
              ),
            ],
          ),
    );
  }
}
