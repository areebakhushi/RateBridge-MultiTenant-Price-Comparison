import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

import '../../../constants/route_names.dart';
import '../../../models/order_model.dart';
import '../../../services/ai_context_service.dart';
import '../../../theme/field_theme.dart';
import '../../../utils/app_navigation.dart';
import '../../../utils/currency_formatter.dart';
import '../../../viewmodels/field_user/field_orders_viewmodel.dart';
import '../../../viewmodels/field_user/field_session_viewmodel.dart';
import '../chat/field_chat_thread_args.dart';
import '../widgets/field_async_states.dart';
import '../widgets/field_material_card.dart';
import 'field_order_status.dart';

enum _OrdersTab { pending, active, delivered, history }

class FieldOrdersView extends StatefulWidget {
  const FieldOrdersView({super.key});

  @override
  State<FieldOrdersView> createState() => _FieldOrdersViewState();
}

class _FieldOrdersViewState extends State<FieldOrdersView> {
  static const _appBarNavy = FieldColors.primaryNavy;

  _OrdersTab _selectedTab = _OrdersTab.pending;
  bool _ordersWatching = false;

  bool _isSelectionMode = false;
  final Set<String> _selectedOrderIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  void _applyRequestedSubTab(FieldOrdersViewModel vm) {
    final requestedSubTab = vm.consumeRequestedOrdersSubTab();
    if (requestedSubTab == null ||
        requestedSubTab < 0 ||
        requestedSubTab >= _OrdersTab.values.length) {
      return;
    }
    final nextTab = _OrdersTab.values[requestedSubTab];
    if (nextTab == _selectedTab) return;
    setState(() {
      _selectedTab = nextTab;
      _isSelectionMode = false;
      _selectedOrderIds.clear();
    });
  }

  void _bootstrap() {
    if (_ordersWatching) return;
    final session = context.read<FieldSessionViewModel>();
    final uid = session.user?.uid;
    final companyId = session.companyId;
    if (uid == null || companyId == null) return;
    _ordersWatching = true;
    context.read<FieldOrdersViewModel>().watchOrders(uid, companyId);
    context.read<AiContextService>().updateContext('orders', {
      'screen': 'my orders list',
    });
  }

  Future<void> _refresh() async {
    final session = context.read<FieldSessionViewModel>();
    final uid = session.user?.uid;
    final companyId = session.companyId;
    if (uid == null || companyId == null) return;
    context.read<FieldOrdersViewModel>().watchOrders(uid, companyId);
  }

  void _openDetail(OrderModel order) {
    if (_isSelectionMode) {
      _toggleSelection(order.orderId);
      return;
    }
    context.push(
      RouteNames.fieldOrderDetail.replaceFirst(':orderId', order.orderId),
      extra: order,
    );
  }

  void _toggleSelection(String orderId) {
    setState(() {
      if (_selectedOrderIds.contains(orderId)) {
        _selectedOrderIds.remove(orderId);
        if (_selectedOrderIds.isEmpty) _isSelectionMode = false;
      } else {
        _selectedOrderIds.add(orderId);
      }
    });
  }

  void _enterSelectionMode(String orderId) {
    setState(() {
      _isSelectionMode = true;
      _selectedOrderIds.add(orderId);
    });
  }

  void _openMarketplace() {
    context.push(RouteNames.fieldMarketplace);
  }

  List<OrderModel> _ordersForTab(FieldOrdersViewModel vm, _OrdersTab tab) {
    switch (tab) {
      case _OrdersTab.pending:
        return vm.ordersForTab(FieldOrderTab.pending);
      case _OrdersTab.active:
        return vm.ordersForTab(FieldOrderTab.active);
      case _OrdersTab.delivered:
        return vm.orders.where((o) {
          return FieldOrderStatus.normalize(o.status) == 'delivered';
        }).toList();
      case _OrdersTab.history:
        return vm.orders.where((o) {
          final s = FieldOrderStatus.normalize(o.status);
          return s == 'confirmed' || s == 'cancelled' || s == 'rejected';
        }).toList();
    }
  }

  int _countForTab(FieldOrdersViewModel vm, _OrdersTab tab) =>
      _ordersForTab(vm, tab).length;

  Future<void> _confirmAndDeleteSelected() async {
    if (_selectedOrderIds.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Remove ${_selectedOrderIds.length} orders?'),
        content: const Text('This will remove these orders from your history. The underlying records will remain for other participants.'),
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
      final session = context.read<FieldSessionViewModel>();
      final uid = session.user?.uid;
      if (uid == null) return;

      try {
        await context.read<FieldOrdersViewModel>().hideOrders(
              _selectedOrderIds.toList(),
              uid,
            );
        setState(() {
          _selectedOrderIds.clear();
          _isSelectionMode = false;
        });
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
    final vm = context.watch<FieldOrdersViewModel>();
    final session = context.watch<FieldSessionViewModel>();

    if (vm.hasPendingOrdersSubTab) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _applyRequestedSubTab(vm);
      });
    }

    if (!_ordersWatching &&
        session.companyId != null &&
        session.user?.uid != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
    }

    return Theme(
      data: FieldTheme.theme,
      child: Scaffold(
        backgroundColor: FieldColors.screenBackground,
        appBar: AppBar(
          backgroundColor: _appBarNavy,
          foregroundColor: Colors.white,
          automaticallyImplyLeading: false,
          leading: _isSelectionMode
              ? IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () {
                    setState(() {
                      _isSelectionMode = false;
                      _selectedOrderIds.clear();
                    });
                  },
                )
              : AppNavigation.leading(context, color: Colors.white),
          title: _isSelectionMode
              ? Text('${_selectedOrderIds.length} selected')
              : Text(
                  'My Orders',
                  style: FieldTypography.titleMedium.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
          actions: _isSelectionMode
              ? [
                  IconButton(
                    icon: const Icon(Icons.select_all_rounded),
                    onPressed: () {
                      setState(() {
                        final currentOrders = _ordersForTab(vm, _selectedTab);
                        _selectedOrderIds.addAll(currentOrders.map((o) => o.orderId));
                      });
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded),
                    onPressed: _confirmAndDeleteSelected,
                  ),
                ]
              : null,
        ),
        body: vm.errorMessage != null && vm.orders.isEmpty
            ? FieldErrorState(
                title: 'Could not load orders',
                message: vm.errorMessage!,
                onRetry: () {
                  _ordersWatching = false;
                  _bootstrap();
                },
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _DarazOrdersTabBar(
                    selected: _selectedTab,
                    counts: {
                      _OrdersTab.pending: _countForTab(vm, _OrdersTab.pending),
                      _OrdersTab.active: _countForTab(vm, _OrdersTab.active),
                      _OrdersTab.delivered:
                          _countForTab(vm, _OrdersTab.delivered),
                      _OrdersTab.history: _countForTab(vm, _OrdersTab.history),
                    },
                    onSelected: (tab) {
                      setState(() {
                        _selectedTab = tab;
                        _isSelectionMode = false;
                        _selectedOrderIds.clear();
                      });
                    },
                  ),
                  Expanded(
                    child: vm.isLoadingOrders && vm.orders.isEmpty
                        ? const _OrdersLoadingList()
                        : _OrdersTabList(
                            key: ValueKey(_selectedTab),
                            orders: _ordersForTab(vm, _selectedTab),
                            tab: _selectedTab,
                            isSelectionMode: _isSelectionMode,
                            selectedOrderIds: _selectedOrderIds,
                            onRefresh: _refresh,
                            onOrderTap: _openDetail,
                            onOrderLongPress: _enterSelectionMode,
                            onBrowse: _openMarketplace,
                          ),
                  ),
                ],
              ),
      ),
    );
  }
}

// ─── Custom tab bar ────────────────────────────────────────────────────────────

class _DarazOrdersTabBar extends StatelessWidget {
  final _OrdersTab selected;
  final Map<_OrdersTab, int> counts;
  final ValueChanged<_OrdersTab> onSelected;

  const _DarazOrdersTabBar({
    required this.selected,
    required this.counts,
    required this.onSelected,
  });

  static const _labels = {
    _OrdersTab.pending: 'Pending',
    _OrdersTab.active: 'Active',
    _OrdersTab.delivered: 'Delivered',
    _OrdersTab.history: 'History',
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: _OrdersTab.values.map((tab) {
            final isActive = tab == selected;
            final count = counts[tab] ?? 0;
            return _DarazTabItem(
              label: _labels[tab]!,
              count: count,
              isActive: isActive,
              onTap: () => onSelected(tab),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _DarazTabItem extends StatelessWidget {
  final String label;
  final int count;
  final bool isActive;
  final VoidCallback onTap;

  const _DarazTabItem({
    required this.label,
    required this.count,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isActive ? FieldColors.accentAmber : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: FieldTypography.bodyMedium.copyWith(
                color: isActive
                    ? FieldColors.primaryNavy
                    : FieldColors.textSecondary,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                fontSize: 13,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 6),
              Container(
                constraints: const BoxConstraints(minWidth: 18),
                height: 18,
                padding: const EdgeInsets.symmetric(horizontal: 5),
                decoration: const BoxDecoration(
                  color: FieldColors.accentAmber,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  count > 99 ? '99+' : '$count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    height: 1,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Tab list ────────────────────────────────────────────────────────────────

class _OrdersTabList extends StatelessWidget {
  final List<OrderModel> orders;
  final _OrdersTab tab;
  final bool isSelectionMode;
  final Set<String> selectedOrderIds;
  final Future<void> Function() onRefresh;
  final ValueChanged<OrderModel> onOrderTap;
  final ValueChanged<String> onOrderLongPress;
  final VoidCallback onBrowse;

  const _OrdersTabList({
    super.key,
    required this.orders,
    required this.tab,
    required this.isSelectionMode,
    required this.selectedOrderIds,
    required this.onRefresh,
    required this.onOrderTap,
    required this.onOrderLongPress,
    required this.onBrowse,
  });

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return _TabEmptyState(tab: tab, onBrowse: onBrowse);
    }

    return RefreshIndicator(
      color: FieldColors.primaryNavy,
      onRefresh: onRefresh,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        itemCount: orders.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final order = orders[index];
          final isSelected = selectedOrderIds.contains(order.orderId);
          return _OrderCard(
            order: order,
            isSelected: isSelected,
            isSelectionMode: isSelectionMode,
            onViewDetails: () => onOrderTap(order),
            onLongPress: () => onOrderLongPress(order.orderId),
          );
        },
      ),
    );
  }
}

class _TabEmptyState extends StatelessWidget {
  final _OrdersTab tab;
  final VoidCallback onBrowse;

  const _TabEmptyState({required this.tab, required this.onBrowse});

  @override
  Widget build(BuildContext context) {
    final (title, subtitle, showBrowse) = switch (tab) {
      _OrdersTab.pending => (
          'No pending orders',
          'Orders awaiting supplier response appear here.',
          false,
        ),
      _OrdersTab.active => (
          'No active orders',
          'Accepted orders awaiting delivery show here.',
          false,
        ),
      _OrdersTab.delivered => (
          'No delivered orders',
          'Orders ready for delivery confirmation appear here.',
          false,
        ),
      _OrdersTab.history => (
          'No order history yet',
          'Completed and closed orders will show up here.',
          true,
        ),
    };

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.45,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.receipt_long_outlined,
                size: 56,
                color: FieldColors.textMuted.withValues(alpha: 0.65),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: FieldTypography.titleMedium.copyWith(
                  color: FieldColors.primaryNavy,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: FieldTypography.bodyMedium.copyWith(
                    color: FieldColors.textSecondary,
                  ),
                ),
              ),
              if (showBrowse) ...[
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: onBrowse,
                  style: FilledButton.styleFrom(
                    backgroundColor: FieldColors.accentAmber,
                    foregroundColor: FieldColors.primaryNavy,
                  ),
                  child: const Text('Start browsing'),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Order card ──────────────────────────────────────────────────────────────

class _OrderCard extends StatelessWidget {
  final OrderModel order;
  final bool isSelected;
  final bool isSelectionMode;
  final VoidCallback onViewDetails;
  final VoidCallback onLongPress;

  const _OrderCard({
    required this.order,
    this.isSelected = false,
    this.isSelectionMode = false,
    required this.onViewDetails,
    required this.onLongPress,
  });

  String get _shortOrderId {
    final id = order.orderId;
    if (id.length <= 8) return id;
    return '${id.substring(0, 8)}...';
  }

  String _guessCategory(String materialName) {
    final n = materialName.toLowerCase();
    const keywords = {
      'cement': 'Cement',
      'steel': 'Steel',
      'brick': 'Bricks',
      'sand': 'Sand',
      'timber': 'Timber',
      'wood': 'Timber',
      'paint': 'Paint',
      'pipe': 'Pipes',
      'tile': 'Tiles',
      'glass': 'Glass',
    };
    for (final entry in keywords.entries) {
      if (n.contains(entry.key)) return entry.value;
    }
    return 'Materials';
  }

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('MMM d, yyyy');
    final requiredLabel = order.requiredDate != null
        ? dateFmt.format(order.requiredDate!)
        : 'Not set';

    return GestureDetector(
      onLongPress: onLongPress,
      onTap: onViewDetails,
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? FieldColors.accentAmber.withValues(alpha: 0.1) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? FieldColors.accentAmber : FieldColors.borderSubtle,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                if (isSelectionMode) ...[
                  SizedBox(
                    height: 24,
                    width: 24,
                    child: Checkbox(
                      value: isSelected,
                      onChanged: (_) => onViewDetails(),
                      activeColor: FieldColors.accentAmber,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Text(
                  _shortOrderId,
                  style: FieldTypography.labelSmall.copyWith(
                    fontSize: 11,
                    color: FieldColors.textSecondary,
                  ),
                ),
                const Spacer(),
                if (!isSelectionMode) _DarazStatusBadge(status: order.status),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: FieldColors.primaryNavy.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    fieldMaterialCategoryIcon(_guessCategory(order.materialName)),
                    size: 20,
                    color: FieldColors.primaryNavy,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.materialName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: FieldTypography.titleMedium.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: FieldColors.primaryNavy,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        order.supplierName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: FieldTypography.bodyMedium.copyWith(
                          fontSize: 12,
                          color: FieldColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_formatQty(order.quantity)} ${order.unit}',
                        style: FieldTypography.bodyMedium.copyWith(
                          fontSize: 12,
                          color: FieldColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  CurrencyFormatter.formatPKR(order.totalAmount),
                  style: FieldTypography.titleMedium.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: FieldColors.accentAmber,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '📍 ${order.deliveryAddress}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: FieldTypography.bodyMedium.copyWith(
                fontSize: 11,
                color: FieldColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '📅 Required: $requiredLabel',
              style: FieldTypography.bodyMedium.copyWith(
                fontSize: 11,
                color: FieldColors.textSecondary,
              ),
            ),
            if (!isSelectionMode) ...[
              const SizedBox(height: 12),
              _OrderActionRow(order: order, onViewDetails: onViewDetails),
            ],
          ],
        ),
      ),
    );
  }

  String _formatQty(double qty) {
    if (qty == qty.roundToDouble()) return qty.toInt().toString();
    return qty.toStringAsFixed(1);
  }
}

class _OrderActionRow extends StatelessWidget {
  final OrderModel order;
  final VoidCallback onViewDetails;

  const _OrderActionRow({
    required this.order,
    required this.onViewDetails,
  });

  @override
  Widget build(BuildContext context) {
    final status = FieldOrderStatus.normalize(order.status);

    if (status == 'pending' || status == 'pendingapproval') {
      return Row(
        children: [
          TextButton(
            onPressed: () => _cancelOrder(context, order),
            style: TextButton.styleFrom(
              foregroundColor: FieldColors.statusDanger,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            child: const Text('Cancel Order'),
          ),
          const Spacer(),
          _OutlinedDetailsButton(onPressed: onViewDetails),
        ],
      );
    }

    if (status == 'accepted' || status == 'inprogress') {
      return Row(
        children: [
          FilledButton(
            onPressed: () => _messageSupplier(context, order),
            style: FilledButton.styleFrom(
              backgroundColor: FieldColors.accentAmber,
              foregroundColor: FieldColors.primaryNavy,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              minimumSize: const Size(0, 36),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              textStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Message Supplier'),
          ),
          const Spacer(),
          _OutlinedDetailsButton(onPressed: onViewDetails),
        ],
      );
    }

    if (status == 'delivered') {
      return SizedBox(
        width: double.infinity,
        height: 40,
        child: FilledButton(
          onPressed: () => _confirmDelivery(context, order),
          style: FilledButton.styleFrom(
            backgroundColor: FieldColors.accentAmber,
            foregroundColor: FieldColors.primaryNavy,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            textStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          child: const Text('Confirm Delivery'),
        ),
      );
    }

    if (status == 'confirmed') {
      return Row(
        children: [
          FutureBuilder<bool>(
            future: _hasRated(context, order),
            builder: (context, snapshot) {
              final rated = snapshot.data == true;
              if (rated) return const SizedBox.shrink();
              return TextButton(
                onPressed: () => _rateSupplier(context, order),
                style: TextButton.styleFrom(
                  foregroundColor: FieldColors.accentAmber,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: const Text('Rate Supplier'),
              );
            },
          ),
          const SizedBox(width: 8),
          _OrderAgainButton(order: order),
          const Spacer(),
          _OutlinedDetailsButton(onPressed: onViewDetails),
        ],
      );
    }

    if (status == 'cancelled' || status == 'rejected') {
      return Row(
        children: [
          _OrderAgainButton(order: order),
          const Spacer(),
          _OutlinedDetailsButton(onPressed: onViewDetails),
        ],
      );
    }

    return Align(
      alignment: Alignment.centerRight,
      child: _OutlinedDetailsButton(onPressed: onViewDetails),
    );
  }

  Future<bool> _hasRated(BuildContext context, OrderModel order) async {
    final uid = context.read<FieldSessionViewModel>().user?.uid;
    if (uid == null) return false;
    return context.read<FieldOrdersViewModel>().hasUserRatedOrder(
          order.orderId,
          uid,
        );
  }

  Future<void> _cancelOrder(BuildContext context, OrderModel order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel order?'),
        content: const Text(
          'This order will be cancelled. You can place a new order anytime.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep order'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancel order'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final success = await context.read<FieldOrdersViewModel>().cancelOrder(
          order.orderId,
          order.companyId,
        );
    if (!context.mounted) return;
    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.read<FieldOrdersViewModel>().errorMessage ??
                'Could not cancel order',
          ),
        ),
      );
    }
  }

  Future<void> _confirmDelivery(BuildContext context, OrderModel order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm delivery?'),
        content: const Text(
          'Confirm that you have received this order. The supplier will be notified.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Not yet'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final success =
        await context.read<FieldOrdersViewModel>().confirmDelivery(
              orderId: order.orderId,
              companyId: order.companyId,
            );
    if (!context.mounted) return;
    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.read<FieldOrdersViewModel>().errorMessage ??
                'Could not confirm delivery',
          ),
        ),
      );
    }
  }

  void _messageSupplier(BuildContext context, OrderModel order) {
    context.push(
      RouteNames.fieldChatThread.replaceFirst(':orderId', order.supplierId),
      extra: FieldChatThreadArgs(
        supplierUid: order.supplierId,
        supplierName: order.supplierName,
        orderId: order.orderId,
      ),
    );
  }

  void _rateSupplier(BuildContext context, OrderModel order) {
    context.push(
      RouteNames.fieldRateSupplier.replaceFirst(':orderId', order.orderId),
      extra: order,
    );
  }
}

class _OutlinedDetailsButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _OutlinedDetailsButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: FieldColors.primaryNavy,
        side: const BorderSide(color: FieldColors.primaryNavy),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        minimumSize: const Size(0, 36),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: const Text('View Details'),
    );
  }
}

class _OrderAgainButton extends StatelessWidget {
  final OrderModel order;
  const _OrderAgainButton({required this.order});

  @override
  Widget build(BuildContext context) {
    final vm = context.read<FieldOrdersViewModel>();
    return TextButton.icon(
      onPressed: vm.isSubmitting ? null : () => vm.reorder(context, order),
      icon: const Icon(Icons.refresh_rounded, size: 16),
      label: const Text('Order Again'),
      style: TextButton.styleFrom(
        foregroundColor: FieldColors.primaryNavy,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }
}

// ─── Status badge ────────────────────────────────────────────────────────────

class _DarazStatusBadge extends StatelessWidget {
  final String status;

  const _DarazStatusBadge({required this.status});

  static ({Color bg, Color fg}) _colorsFor(String status) {
    final s = FieldOrderStatus.normalize(status);
    switch (s) {
      case 'pending':
      case 'pendingapproval':
        return (
          bg: FieldColors.accentAmber.withValues(alpha: 0.2),
          fg: FieldColors.statusWarning,
        );
      case 'accepted':
      case 'inprogress':
        return (bg: FieldColors.primaryNavy, fg: Colors.white);
      case 'delivered':
        return (bg: FieldColors.statusPurple, fg: Colors.white);
      case 'confirmed':
        return (bg: FieldColors.statusSuccess, fg: Colors.white);
      case 'rejected':
        return (bg: FieldColors.statusDanger, fg: Colors.white);
      case 'cancelled':
        return (
          bg: FieldColors.statusMuted.withValues(alpha: 0.2),
          fg: FieldColors.textPrimary,
        );
      default:
        return (
          bg: FieldColors.borderSubtle,
          fg: FieldColors.textSecondary,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = _colorsFor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colors.bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        FieldOrderStatus.displayLabel(status),
        style: TextStyle(
          color: colors.fg,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ─── Loading ─────────────────────────────────────────────────────────────────

class _OrdersLoadingList extends StatelessWidget {
  const _OrdersLoadingList();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      itemCount: 3,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, __) => Shimmer.fromColors(
        baseColor: FieldColors.borderSubtle,
        highlightColor: FieldColors.surfaceWhite,
        child: Container(
          height: 200,
          decoration: BoxDecoration(
            color: FieldColors.borderSubtle,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
