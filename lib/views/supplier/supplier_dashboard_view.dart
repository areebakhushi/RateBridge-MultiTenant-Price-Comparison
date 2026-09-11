import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

import '../../constants/app_constants.dart';
import '../../constants/route_names.dart';
import '../../models/material_model.dart';
import '../../models/order_model.dart';
import '../../models/rating_model.dart';
import '../../theme/supplier_theme.dart';
import '../../utils/app_navigation.dart';
import '../../utils/app_theme.dart';
import '../../utils/currency_formatter.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/notification_viewmodel.dart';
import '../../viewmodels/supplier_viewmodel.dart';
import '../../widgets/app_network_image.dart';
import '../../widgets/notification_badge_icon.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/supplier_nav_bar.dart';

class SupplierDashboardView extends StatefulWidget {
  const SupplierDashboardView({super.key});

  @override
  State<SupplierDashboardView> createState() => _SupplierDashboardViewState();
}

class _SupplierDashboardViewState extends State<SupplierDashboardView> {
  String? _bootstrappedCompanyId;
  String? _scheduledDashboardCompanyId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  void _bootstrap() {
    final auth = context.read<AuthViewModel>();
    final vm = context.read<SupplierViewModel>();
    vm.updateAuth(auth);

    final uid = auth.user?.uid;
    if (uid != null) {
      final notifVM = context.read<NotificationViewModel>();
      notifVM.loadNotifications(uid);
      notifVM.watchUnreadCount(uid);
    }

    if (vm.selectedCompanyId != null) {
      vm.loadDashboard();
      _bootstrappedCompanyId = vm.selectedCompanyId;
    }
  }

  void _maybeLoadDashboard(SupplierViewModel vm) {
    final companyId = vm.selectedCompanyId;
    if (companyId == null || companyId == _bootstrappedCompanyId) return;
    if (_scheduledDashboardCompanyId == companyId) return;
    _scheduledDashboardCompanyId = companyId;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduledDashboardCompanyId = null;
      if (!mounted) return;

      final currentVm = context.read<SupplierViewModel>();
      final currentId = currentVm.selectedCompanyId;
      if (currentId == null || currentId == _bootstrappedCompanyId) return;

      _bootstrappedCompanyId = currentId;
      currentVm.loadDashboard();
    });
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String _firstName(String fullName) {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    return parts.isNotEmpty ? parts.first : fullName;
  }

  String _initials(String fullName) {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    if (parts.isNotEmpty && parts.first.isNotEmpty) {
      return parts.first[0].toUpperCase();
    }
    return 'S';
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM d').format(dt);
  }

  int _todaysOrdersCount(List<OrderModel> orders) {
    final now = DateTime.now();
    return orders.where((o) {
      final d = o.createdAt;
      return d.year == now.year && d.month == now.month && d.day == now.day;
    }).length;
  }

  int _confirmedThisMonth(List<OrderModel> orders) {
    final now = DateTime.now();
    return orders.where((o) {
      if (o.status.toLowerCase() != 'confirmed') return false;
      final d = o.confirmedAt ?? o.createdAt;
      return d.year == now.year && d.month == now.month;
    }).length;
  }

  double _monthlyGross(SupplierViewModel vm) =>
      vm.transactions.fold(0.0, (a, t) => a + t.totalAmount);

  double _monthlyCommission(SupplierViewModel vm) =>
      vm.transactions.fold(0.0, (a, t) => a + t.commissionAmount);

  double _responseRate(List<OrderModel> orders) {
    if (orders.isEmpty) return 0;
    final positive = orders.where((o) {
      final s = o.status.toLowerCase();
      return s == 'accepted' || s == 'delivered' || s == 'confirmed';
    }).length;
    return positive / orders.length * 100;
  }

  double _deliveryRate(List<OrderModel> orders) {
    final accepted = orders.where((o) {
      final s = o.status.toLowerCase();
      return s == 'accepted' || s == 'delivered' || s == 'confirmed';
    }).length;
    if (accepted == 0) return 0;
    final delivered = orders.where((o) {
      final s = o.status.toLowerCase();
      return s == 'delivered' || s == 'confirmed';
    }).length;
    return delivered / accepted * 100;
  }

  List<RatingModel> _recentReviews(SupplierViewModel vm) {
    final sorted = List<RatingModel>.from(vm.ratings)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sorted.take(3).toList();
  }

  String _orderSubtitle(SupplierViewModel vm, OrderModel order) {
    final company = vm.companyNameFor(order.companyId);
    if (company != null && company.isNotEmpty) return company;
    if (order.fieldUserName.isNotEmpty) return order.fieldUserName;
    return 'Company';
  }

  void _showOrderDetail(SupplierViewModel viewModel, OrderModel order) {
    final commission = order.totalAmount * AppConstants.commissionRate;
    final netPayout = order.totalAmount * (1 - AppConstants.commissionRate);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: const BoxDecoration(
          color: FieldColors.surfaceWhite,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(FieldRadius.card),
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: FieldColors.borderSubtle,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Order Details', style: AppTextStyles.h2),
                _SolidStatusBadge(status: order.status),
              ],
            ),
            const SizedBox(height: 24),
            _detailRow('Material', order.materialName),
            _detailRow('Quantity', '${order.quantity} ${order.unit}'),
            _detailRow(
              'Customer',
              order.fieldUserName.isNotEmpty ? order.fieldUserName : 'Field user',
            ),
            _detailRow(
              'Company',
              viewModel.companyNameFor(order.companyId) ?? 'Company',
            ),
            _detailRow('Total', CurrencyFormatter.formatPKR(order.totalAmount)),
            _detailRow('Net payout', CurrencyFormatter.formatPKR(netPayout)),
            _detailRow('Commission', CurrencyFormatter.formatPKR(commission)),
            _detailRow('Placed', _timeAgo(order.createdAt)),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 110, child: Text(label, style: AppTextStyles.caption)),
          Expanded(
            child: Text(
              value,
              style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<SupplierViewModel>();
    final authVM = context.watch<AuthViewModel>();
    final notifVM = context.watch<NotificationViewModel>();
    final user = authVM.user;

    _maybeLoadDashboard(viewModel);

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final supplierName = _firstName(user.name);
    final loading = viewModel.isDashboardLoading;
    final orders = viewModel.orders;
    final pendingCount = viewModel.pendingOrdersCount;
    final showCompanyError = viewModel.companiesLoadFailed;
    final showCompanyEmpty = viewModel.companiesLoaded &&
        !viewModel.companiesLoadFailed &&
        viewModel.companies.isEmpty;
    final waitingForCompanies = !viewModel.companiesLoaded;

    return RootTabPopScope(
      isHome: true,
      homeRoute: RouteNames.supplierDashboard,
      child: Scaffold(
      backgroundColor: FieldColors.screenBackground,
      bottomNavigationBar: const SupplierNavBar(currentIndex: 0),
      body: RefreshIndicator(
                  color: FieldColors.primaryNavy,
                  onRefresh: viewModel.loadDashboard,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _TopHeaderCard(
                          greeting: _greeting(),
                          storeName: "$supplierName's Store",
                          initials: _initials(user.name),
                          unreadCount: notifVM.unreadCount,
                          onNotifications: () =>
                              context.push(RouteNames.supplierNotifications),
                          pendingCount: pendingCount,
                          todayCount: _todaysOrdersCount(orders),
                          confirmedCount: _confirmedThisMonth(orders),
                        ),
                        if (viewModel.isCommissionRestricted)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: FieldColors.statusDanger.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: FieldColors.statusDanger.withValues(alpha: 0.35),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Account restricted — commission overdue',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: FieldColors.statusDanger,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  const Text(
                                    'Your listings are hidden from buyers and you cannot submit new bulk-quote bids until outstanding commission is settled. Existing orders are not affected.',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                  const SizedBox(height: 10),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton(
                                      onPressed: () => context.push(RouteNames.supplierEarnings),
                                      child: const Text('Go to Earnings'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        if (viewModel.companies.isNotEmpty) ...[
                          if (viewModel.companies.length > 1)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                              child: _CompanySwitcher(viewModel: viewModel),
                            ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () =>
                                    context.push(RouteNames.supplierMyCompanies),
                                child: const Text('My Companies & Partnerships'),
                              ),
                            ),
                          ),
                        ],
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (showCompanyError) ...[
                                _FirestoreErrorBanner(
                                  message: viewModel.error ??
                                      'Could not load your companies.',
                                  onRetry: viewModel.retryInitialLoad,
                                ),
                                const SizedBox(height: 12),
                              ],
                              if (showCompanyEmpty) ...[
                                const _NoCompanyLinkedBanner(),
                                const SizedBox(height: 12),
                              ],
                              if (viewModel.error != null &&
                                  viewModel.error!.isNotEmpty &&
                                  !showCompanyError) ...[
                                _FirestoreErrorBanner(
                                  message: viewModel.error!,
                                  onRetry: viewModel.loadDashboard,
                                ),
                                const SizedBox(height: 12),
                              ],
                              if (pendingCount > 0) ...[
                                _UrgentBanner(
                                  pendingCount: pendingCount,
                                  onReview: () =>
                                      context.push(RouteNames.supplierOrders),
                                ),
                                const SizedBox(height: 16),
                              ],
                              if (waitingForCompanies || loading)
                                const _SectionShimmer(height: 180)
                              else
                                _SectionWrapper(
                                  error: viewModel.error,
                                  onRetry: viewModel.loadDashboard,
                                  child: _EarningsCard(
                                    netEarnings: viewModel.monthlyEarningsTotal,
                                    grossSales: _monthlyGross(viewModel),
                                    commissionOwed: _monthlyCommission(viewModel),
                                    completedOrders: _confirmedThisMonth(orders),
                                    onViewDetails: () =>
                                        context.push(RouteNames.supplierEarnings),
                                  ),
                                ),
                              const SizedBox(height: 16),
                              if (waitingForCompanies || loading)
                                const _SectionShimmer(height: 160)
                              else
                                _SectionWrapper(
                                  error: viewModel.error,
                                  onRetry: viewModel.loadDashboard,
                                  child: _PerformanceCard(
                                    responseRate: _responseRate(orders),
                                    deliveryRate: _deliveryRate(orders),
                                    averageRating: viewModel.averageRating,
                                    hasOrders: orders.isNotEmpty,
                                  ),
                                ),
                              const SizedBox(height: 24),
                              _SectionHeader(
                                title: 'Open Quotes (RFQ)',
                                actionLabel: 'View all',
                                onAction: () =>
                                    context.push(RouteNames.supplierRfqs),
                              ),
                              const SizedBox(height: 12),
                              _RfqBanner(onTap: () => context.push(RouteNames.supplierRfqs)),
                              const SizedBox(height: 24),
                              _SectionHeader(
                                title: 'Recent Orders',
                                actionLabel: 'View all',
                                onAction: () =>
                                    context.push(RouteNames.supplierOrders),
                              ),
                              const SizedBox(height: 12),
                              if (waitingForCompanies || loading)
                                const _SectionShimmer(height: 88)
                              else
                                _SectionWrapper(
                                  error: viewModel.error,
                                  onRetry: () async {
                                    final id = viewModel.selectedCompanyId;
                                    if (id != null) {
                                      await viewModel.loadOrders(id, null);
                                    }
                                  },
                                  child: viewModel.recentOrders.isEmpty
                                      ? const _OrdersEmptyState()
                                      : Column(
                                          children: viewModel.recentOrders
                                              .map(
                                                (order) => _RecentOrderCard(
                                                  order: order,
                                                  subtitle: _orderSubtitle(
                                                    viewModel,
                                                    order,
                                                  ),
                                                  timeAgo:
                                                      _timeAgo(order.createdAt),
                                                  onTap: () => _showOrderDetail(
                                                    viewModel,
                                                    order,
                                                  ),
                                                ),
                                              )
                                              .toList(),
                                        ),
                                ),
                              const SizedBox(height: 24),
                              _SectionHeader(
                                title: 'My Materials',
                                actionLabel: 'Add new +',
                                actionColor: FieldColors.accentAmber,
                                onAction: () => context.push(
                                  RouteNames.supplierAddMaterial,
                                ),
                              ),
                              const SizedBox(height: 12),
                              if (waitingForCompanies || loading)
                                const _SectionShimmer(height: 120)
                              else
                                _SectionWrapper(
                                  error: viewModel.error,
                                  onRetry: () async {
                                    final id = viewModel.selectedCompanyId;
                                    if (id != null) {
                                      await viewModel.loadMaterials(id);
                                    }
                                  },
                                  child: viewModel.recentMaterials.isEmpty
                                      ? _AddFirstMaterialCard(
                                          onTap: () => context.push(
                                            RouteNames.supplierAddMaterial,
                                          ),
                                        )
                                      : _MaterialsCarousel(
                                          materials: viewModel.recentMaterials,
                                        ),
                                ),
                              if (!waitingForCompanies && !loading && viewModel.ratingsCount > 0) ...[
                                const SizedBox(height: 24),
                                _SectionHeader(
                                  title: 'Recent Reviews',
                                  actionLabel: 'View all',
                                  onAction: () =>
                                      context.push(RouteNames.supplierRatings),
                                ),
                                const SizedBox(height: 12),
                                ..._recentReviews(viewModel).map(
                                  (r) => _ReviewCard(
                                    rating: r,
                                    timeAgo: _timeAgo(r.createdAt),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 24),
                              const _QuickActionsGrid(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
      ),
    );
  }
}

class _NoCompanyLinkedBanner extends StatelessWidget {
  const _NoCompanyLinkedBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: FieldColors.accentAmber.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(FieldRadius.card),
        border: Border.all(
          color: FieldColors.accentAmber.withValues(alpha: 0.45),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.business_outlined,
                color: FieldColors.primaryNavy,
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'No company linked yet',
                      style: AppTextStyles.body.copyWith(
                        fontWeight: FontWeight.w700,
                        color: FieldColors.primaryNavy,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Send a partnership request to a company, or respond when a CEO invites you.',
                      style: AppTextStyles.caption.copyWith(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed: () => context.push(RouteNames.supplierMyCompanies),
                child: const Text('My Companies & Partnerships'),
              ),
              OutlinedButton(
                onPressed: () =>
                    context.push(RouteNames.supplierCompanyDirectory),
                child: const Text('Find Companies'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared widgets
// ---------------------------------------------------------------------------

class _FirestoreErrorBanner extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _FirestoreErrorBanner({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final isPermission = message.contains('permission-denied');
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: FieldColors.statusDanger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(FieldRadius.card),
        border: Border.all(
          color: FieldColors.statusDanger.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, size: 18, color: FieldColors.statusDanger),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isPermission
                  ? 'Could not load dashboard data. Check your connection and try again.'
                  : 'Some data failed to load.',
              style: AppTextStyles.caption.copyWith(fontSize: 12),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _SectionWrapper extends StatelessWidget {
  final String? error;
  final Future<void> Function() onRetry;
  final Widget child;

  const _SectionWrapper({
    required this.error,
    required this.onRetry,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        child,
        if (error != null && error!.isNotEmpty)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String actionLabel;
  final VoidCallback onAction;
  final Color? actionColor;

  const _SectionHeader({
    required this.title,
    required this.actionLabel,
    required this.onAction,
    this.actionColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: AppTextStyles.h3.copyWith(
            color: FieldColors.primaryNavy,
            fontWeight: FontWeight.w800,
          ),
        ),
        TextButton(
          onPressed: onAction,
          style: TextButton.styleFrom(
            foregroundColor: actionColor ?? FieldColors.accentAmber,
            padding: EdgeInsets.zero,
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(actionLabel),
        ),
      ],
    );
  }
}

class _CompanySwitcher extends StatelessWidget {
  final SupplierViewModel viewModel;

  const _CompanySwitcher({required this.viewModel});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: SupplierTheme.cardDecoration(),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: viewModel.selectedCompanyId,
          isExpanded: true,
          icon: const Icon(Icons.unfold_more, size: 20),
          items: viewModel.companies
              .map(
                (c) => DropdownMenuItem(
                  value: c.id,
                  child: Text(c.name, style: AppTextStyles.body),
                ),
              )
              .toList(),
          onChanged: (val) {
            if (val != null) viewModel.switchCompany(val);
          },
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Part 1 — Top header
// ---------------------------------------------------------------------------

class _TopHeaderCard extends StatelessWidget {
  final String greeting;
  final String storeName;
  final String initials;
  final int unreadCount;
  final VoidCallback onNotifications;
  final int pendingCount;
  final int todayCount;
  final int confirmedCount;

  const _TopHeaderCard({
    required this.greeting,
    required this.storeName,
    required this.initials,
    required this.unreadCount,
    required this.onNotifications,
    required this.pendingCount,
    required this.todayCount,
    required this.confirmedCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [FieldColors.primaryNavy, FieldColors.primaryNavyDark],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        greeting,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.6),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        storeName,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                NotificationBadgeIcon(
                  unreadCount: unreadCount,
                  iconColor: Colors.white,
                  onPressed: onNotifications,
                ),
                const SizedBox(width: 10),
                CircleAvatar(
                  radius: 18,
                  backgroundColor: FieldColors.accentAmber,
                  child: Text(
                    initials,
                    style: const TextStyle(
                      color: FieldColors.primaryNavy,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _HeaderStatChip(
                    value: '$pendingCount',
                    label: 'Pending',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _HeaderStatChip(value: '$todayCount', label: 'Today'),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _HeaderStatChip(
                    value: '$confirmedCount',
                    label: 'Confirmed',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderStatChip extends StatelessWidget {
  final String value;
  final String label;

  const _HeaderStatChip({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Part 2 — Urgent banner
// ---------------------------------------------------------------------------

class _UrgentBanner extends StatelessWidget {
  final int pendingCount;
  final VoidCallback onReview;

  const _UrgentBanner({
    required this.pendingCount,
    required this.onReview,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: FieldColors.accentAmber.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(FieldRadius.card),
        border: const Border(
          left: BorderSide(color: FieldColors.accentAmber, width: 4),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '⚡ You have $pendingCount order${pendingCount == 1 ? '' : 's'} waiting for your response',
              style: AppTextStyles.body.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
          TextButton(
            onPressed: onReview,
            style: TextButton.styleFrom(
              foregroundColor: FieldColors.primaryNavy,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            child: const Text('Review now →'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Part 3 — Earnings card
// ---------------------------------------------------------------------------

class _EarningsCard extends StatelessWidget {
  final double netEarnings;
  final double grossSales;
  final double commissionOwed;
  final int completedOrders;
  final VoidCallback onViewDetails;

  const _EarningsCard({
    required this.netEarnings,
    required this.grossSales,
    required this.commissionOwed,
    required this.completedOrders,
    required this.onViewDetails,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: SupplierTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.calendar_today_outlined,
                size: 16,
                color: FieldColors.textMuted,
              ),
              const SizedBox(width: 8),
              Text(
                "This Month's Earnings",
                style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            CurrencyFormatter.formatPKR(netEarnings),
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: FieldColors.primaryNavy,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'After 2% platform commission',
            style: AppTextStyles.caption.copyWith(fontSize: 12),
          ),
          const Divider(height: 28),
          Row(
            children: [
              Expanded(
                child: _EarningsMiniStat(
                  value: CurrencyFormatter.formatPKR(grossSales),
                  label: 'Gross sales',
                ),
              ),
              Expanded(
                child: _EarningsMiniStat(
                  value: CurrencyFormatter.formatPKR(commissionOwed),
                  label: 'Commission owed',
                ),
              ),
              Expanded(
                child: _EarningsMiniStat(
                  value: '$completedOrders',
                  label: 'Orders done',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onViewDetails,
              child: const Text('View details →'),
            ),
          ),
        ],
      ),
    );
  }
}

class _EarningsMiniStat extends StatelessWidget {
  final String value;
  final String label;

  const _EarningsMiniStat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.body.copyWith(
            fontWeight: FontWeight.w700,
            fontSize: 13,
            color: FieldColors.primaryNavy,
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: AppTextStyles.caption.copyWith(fontSize: 11)),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Part 4 — Performance card
// ---------------------------------------------------------------------------

class _PerformanceCard extends StatelessWidget {
  final double responseRate;
  final double deliveryRate;
  final double averageRating;
  final bool hasOrders;

  const _PerformanceCard({
    required this.responseRate,
    required this.deliveryRate,
    required this.averageRating,
    required this.hasOrders,
  });

  Color _rateColor(double percent) {
    if (percent > 80) return FieldColors.statusSuccess;
    if (percent >= 50) return FieldColors.accentAmber;
    return FieldColors.statusDanger;
  }

  Color _ratingBarColor(double rating) {
    if (rating > 4) return FieldColors.statusSuccess;
    if (rating >= 3) return FieldColors.accentAmber;
    return FieldColors.statusDanger;
  }

  @override
  Widget build(BuildContext context) {
    final ratingPercent = averageRating / 5 * 100;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: SupplierTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.emoji_events_outlined,
                size: 18,
                color: FieldColors.accentAmber,
              ),
              const SizedBox(width: 8),
              Text(
                'Your Performance',
                style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (!hasOrders)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'Complete your first order to see your performance',
                style: AppTextStyles.caption,
              ),
            ),
          _PerformanceBar(
            label: 'Response Rate',
            percent: hasOrders ? responseRate : 0,
            color: _rateColor(hasOrders ? responseRate : 0),
          ),
          const SizedBox(height: 14),
          _PerformanceBar(
            label: 'Delivery Rate',
            percent: hasOrders ? deliveryRate : 0,
            color: _rateColor(hasOrders ? deliveryRate : 0),
          ),
          const SizedBox(height: 14),
          _PerformanceBar(
            label: 'Rating Score',
            percent: ratingPercent,
            color: _ratingBarColor(averageRating),
            trailing: averageRating > 0
                ? '${averageRating.toStringAsFixed(1)}/5'
                : '0/5',
          ),
        ],
      ),
    );
  }
}

class _PerformanceBar extends StatelessWidget {
  final String label;
  final double percent;
  final Color color;
  final String? trailing;

  const _PerformanceBar({
    required this.label,
    required this.percent,
    required this.color,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final display = trailing ?? '${percent.round()}%';
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: AppTextStyles.caption),
            Text(
              display,
              style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: (percent / 100).clamp(0.0, 1.0),
            minHeight: 6,
            backgroundColor: FieldColors.borderSubtle,
            color: color,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Part 5 — Recent orders
// ---------------------------------------------------------------------------

class _SolidStatusBadge extends StatelessWidget {
  final String status;

  const _SolidStatusBadge({required this.status});

  ({Color bg, Color fg}) _style() {
    final s = status.toLowerCase().replaceAll('_', '');
    if (s == 'pending' || s == 'pendingapproval') {
      return (
        bg: FieldColors.accentAmber,
        fg: FieldColors.statusWarning,
      );
    }
    if (s == 'accepted' || s == 'inprogress') {
      return (bg: FieldColors.primaryNavy, fg: Colors.white);
    }
    if (s == 'delivered') {
      return (bg: FieldColors.statusPurple, fg: Colors.white);
    }
    if (s == 'confirmed') {
      return (bg: FieldColors.statusSuccess, fg: Colors.white);
    }
    if (s == 'rejected') {
      return (bg: FieldColors.statusDanger, fg: Colors.white);
    }
    if (s == 'cancelled') {
      return (bg: FieldColors.borderSubtle, fg: FieldColors.textPrimary);
    }
    return (bg: FieldColors.borderSubtle, fg: FieldColors.textSecondary);
  }

  @override
  Widget build(BuildContext context) {
    final style = _style();
    final label = status[0].toUpperCase() + status.substring(1);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: style.bg,
        borderRadius: BorderRadius.circular(FieldRadius.chip),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: style.fg,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

Color _statusIconColor(String status) {
  final s = status.toLowerCase().replaceAll('_', '');
  if (s == 'pending' || s == 'pendingapproval') return FieldColors.accentAmber;
  if (s == 'accepted' || s == 'inprogress') return FieldColors.primaryNavy;
  if (s == 'delivered') return FieldColors.statusPurple;
  if (s == 'confirmed') return FieldColors.statusSuccess;
  if (s == 'rejected') return FieldColors.statusDanger;
  return FieldColors.statusMuted;
}

class _RecentOrderCard extends StatelessWidget {
  final OrderModel order;
  final String subtitle;
  final String timeAgo;
  final VoidCallback onTap;

  const _RecentOrderCard({
    required this.order,
    required this.subtitle,
    required this.timeAgo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: FieldColors.surfaceWhite,
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FieldRadius.card),
          side: const BorderSide(color: FieldColors.borderSubtle),
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _statusIconColor(order.status).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.inventory_2_outlined,
                    size: 18,
                    color: _statusIconColor(order.status),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.materialName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: FieldColors.primaryNavy,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(subtitle, style: AppTextStyles.caption),
                      Text(
                        '${order.quantity} ${order.unit}',
                        style: AppTextStyles.caption.copyWith(fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _SolidStatusBadge(status: order.status),
                    const SizedBox(height: 6),
                    Text(
                      timeAgo,
                      style: AppTextStyles.caption.copyWith(fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OrdersEmptyState extends StatelessWidget {
  const _OrdersEmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
      decoration: SupplierTheme.cardDecoration(),
      child: Column(
        children: [
          const Icon(
            Icons.receipt_long_outlined,
            size: 40,
            color: FieldColors.textMuted,
          ),
          const SizedBox(height: 10),
          Text(
            'No orders yet. Customers will appear here when they order your materials.',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMuted.copyWith(fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Part 6 — Materials carousel
// ---------------------------------------------------------------------------

class _MaterialsCarousel extends StatelessWidget {
  final List<MaterialModel> materials;

  const _MaterialsCarousel({required this.materials});

  Color _stockDotColor(String? stock) {
    final s = (stock ?? 'available').toLowerCase();
    if (s.contains('out') || s.contains('none')) return FieldColors.statusDanger;
    if (s.contains('limit') || s.contains('low')) return FieldColors.accentAmber;
    return FieldColors.statusSuccess;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 210,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: materials.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final m = materials[index];
          final imageUrl = m.profileImageUrl;
          return Material(
            color: FieldColors.surfaceWhite,
            elevation: 0,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(FieldRadius.card),
              side: const BorderSide(color: FieldColors.borderSubtle),
            ),
            child: InkWell(
              onTap: () => context.push(
                RouteNames.supplierMaterialDetail.replaceFirst(':matId', m.id),
                extra: m,
              ),
              child: SizedBox(
                width: 150,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: 80,
                      width: double.infinity,
                      child: AppNetworkImage(
                        url: imageUrl,
                        fit: BoxFit.cover,
                        width: 150,
                        height: 80,
                        debugLabel: 'dashboard:${m.id}',
                        fallback: _categoryFallback(m),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              m.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: FieldColors.primaryNavy,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              CurrencyFormatter.formatPKR(m.pricePerUnit),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: FieldColors.accentAmber,
                              ),
                            ),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    m.unit,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTextStyles.caption.copyWith(
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: _stockDotColor(m.stockStatus),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _categoryFallback(MaterialModel m) {
    return Container(
      color: FieldColors.primaryNavy.withValues(alpha: 0.08),
      child: Center(
        child: Icon(
          Icons.category_outlined,
          size: 32,
          color: FieldColors.primaryNavy.withValues(alpha: 0.5),
        ),
      ),
    );
  }
}

class _AddFirstMaterialCard extends StatelessWidget {
  final VoidCallback onTap;

  const _AddFirstMaterialCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(FieldRadius.card),
        splashColor: FieldColors.accentAmber.withValues(alpha: 0.2),
        child: CustomPaint(
          painter: _DashedBorderPainter(
            color: FieldColors.accentAmber.withValues(alpha: 0.7),
            radius: FieldRadius.card,
          ),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 36),
            child: Column(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: FieldColors.accentAmber.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.add,
                    color: FieldColors.accentAmber,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Add your first material',
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w700,
                    color: FieldColors.primaryNavy,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double radius;

  _DashedBorderPainter({required this.color, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(1, 1, size.width - 2, size.height - 2),
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);
    const dash = 6.0;
    const gap = 4.0;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = (distance + dash).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color;
}

// ---------------------------------------------------------------------------
// Part 7 — Reviews
// ---------------------------------------------------------------------------

class _ReviewCard extends StatelessWidget {
  final RatingModel rating;
  final String timeAgo;

  const _ReviewCard({required this.rating, required this.timeAgo});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: SupplierTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              RatingStars(value: rating.rating, size: 16),
              Text(timeAgo, style: AppTextStyles.caption.copyWith(fontSize: 11)),
            ],
          ),
          if (rating.comment.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              rating.comment,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.bodyMuted.copyWith(fontSize: 13),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            'For: ${rating.materialName}',
            style: AppTextStyles.caption.copyWith(
              color: FieldColors.primaryNavy,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Part 8 — Quick actions
// ---------------------------------------------------------------------------

class _QuickActionsGrid extends StatelessWidget {
  const _QuickActionsGrid();

  @override
  Widget build(BuildContext context) {
    final items = [
      (
        'Add Material',
        Icons.inventory_2_outlined,
        () => context.push(RouteNames.supplierAddMaterial),
      ),
      (
        'View Orders',
        Icons.shopping_bag_outlined,
        () => context.push(RouteNames.supplierOrders),
      ),
      (
        'Messages',
        Icons.chat_bubble_outline,
        () => context.push(RouteNames.supplierChat),
      ),
      (
        'My Earnings',
        Icons.bar_chart_outlined,
        () => context.push(RouteNames.supplierEarnings),
      ),
    ];

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.35,
      children: items
          .map(
            (item) => _QuickActionTile(
              label: item.$1,
              icon: item.$2,
              onTap: item.$3,
            ),
          )
          .toList(),
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _QuickActionTile({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: FieldColors.surfaceWhite,
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(FieldRadius.card),
        side: const BorderSide(color: FieldColors.borderSubtle),
      ),
      child: InkWell(
        onTap: onTap,
        splashColor: FieldColors.accentAmber.withValues(alpha: 0.25),
        highlightColor: FieldColors.accentAmber.withValues(alpha: 0.12),
        child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 28, color: FieldColors.primaryNavy),
              const SizedBox(height: 8),
              Text(
                label,
                style: AppTextStyles.caption.copyWith(fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Section shimmer (per-section loading)
// ---------------------------------------------------------------------------

class _SectionShimmer extends StatelessWidget {
  final double height;

  const _SectionShimmer({required this.height});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: FieldColors.borderSubtle.withValues(alpha: 0.5),
      highlightColor: FieldColors.surfaceWhite,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: FieldColors.borderSubtle,
          borderRadius: BorderRadius.circular(FieldRadius.card),
        ),
      ),
    );
  }
}

class _RfqBanner extends StatelessWidget {
  final VoidCallback onTap;
  const _RfqBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return RootTabPopScope(
      isHome: true,
      homeRoute: RouteNames.supplierDashboard,
      child: Material(
      color: FieldColors.surfaceWhite,
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(FieldRadius.card),
        side: const BorderSide(color: FieldColors.borderSubtle),
      ),
      child: ListTile(
        leading: Container(
          width: 40, height: 40,
          decoration: BoxDecoration(color: FieldColors.accentAmber.withValues(alpha: 0.1), shape: BoxShape.circle),
          child: const Icon(Icons.request_quote_outlined, color: FieldColors.accentAmber, size: 20),
        ),
        title: Text('Quote Requests', style: FieldTypography.titleMedium),
        subtitle: Text('Bids on bulk material requests in your area.', style: FieldTypography.bodyMedium),
        trailing: const Icon(Icons.arrow_forward_ios, size: 14),
        onTap: onTap,
      ),
    ),
    );
  }
}
