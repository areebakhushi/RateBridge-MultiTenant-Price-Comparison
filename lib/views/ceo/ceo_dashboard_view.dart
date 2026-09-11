// MVVM: View — no business logic

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../../constants/route_names.dart';
import '../../models/order_model.dart';
import '../../theme/ceo_theme.dart';
import '../../theme/field_theme.dart';
import '../../utils/app_navigation.dart';
import '../../utils/formatters.dart';
import '../../viewmodels/ceo_viewmodel.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/notification_viewmodel.dart';
import '../../widgets/ceo_nav_bar.dart';
import '../../widgets/ceo/ceo_widgets.dart';
import '../../widgets/dashboard_hero_header.dart';

class CeoDashboardView extends StatefulWidget {
  const CeoDashboardView({super.key});

  @override
  State<CeoDashboardView> createState() => _CeoDashboardViewState();
}

class _CeoDashboardViewState extends State<CeoDashboardView> {
  bool _regeneratingCode = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CeoViewModel>().loadDashboard();
      final uid = context.read<AuthViewModel>().user?.uid;
      if (uid != null) {
        final notif = context.read<NotificationViewModel>();
        notif.loadNotifications(uid);
        notif.watchUnreadCount(uid);
      }
    });
  }

  Future<void> _copyInviteCode(String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Invite code copied')),
    );
  }

  Future<void> _regenerateCode(CeoViewModel vm) async {
    setState(() => _regeneratingCode = true);
    await vm.regenerateInviteCode();
    if (mounted) setState(() => _regeneratingCode = false);
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String _initials(String? name) {
    final trimmed = name?.trim() ?? '';
    if (trimmed.isEmpty) return 'C';
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts.first[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final authVm = context.watch<AuthViewModel>();
    final notifVm = context.watch<NotificationViewModel>();
    final companyId = authVm.user?.companyId ?? '';

    return RootTabPopScope(
      isHome: true,
      homeRoute: RouteNames.ceoDashboard,
      child: Scaffold(
        backgroundColor: CeoColors.screenBg,
        body: Consumer<CeoViewModel>(
          builder: (context, vm, _) {
            if (vm.isLoading && vm.company == null) {
              return const Center(child: CircularProgressIndicator());
            }

            final inviteCode = vm.company?.inviteCode ?? 'RB-XXXXXX';
            final companyName = vm.company?.name ?? 'Dashboard';

            return RefreshIndicator(
              onRefresh: () => vm.loadDashboard(),
              color: FieldColors.primaryNavy,
              child: StreamBuilder<Map<String, dynamic>>(
                stream: vm.watchDashboardStats(companyId),
                builder: (context, snapshot) {
                  final stats = snapshot.data ?? {};
                  final pendingOrders =
                      (stats['pendingOrderApprovals'] ?? 0) as int;
                  final pendingJoin = (stats['pendingJoinCount'] ?? 0) as int;
                  final fieldUserCount = (stats['fieldUserCount'] ?? 0) as int;
                  final supplierCount =
                      (stats['activeSupplierCount'] ?? 0) as int;
                  final plan = stats['plan'] ?? 'Free';
                  final expiresAt = stats['expiresAt'] as DateTime?;
                  final daysLeft = expiresAt != null
                      ? expiresAt.difference(DateTime.now()).inDays
                      : 0;

                  return CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    slivers: [
                      SliverToBoxAdapter(
                        child: DashboardHeroHeader(
                          greeting: _greeting(),
                          headline: companyName,
                          initials: _initials(authVm.user?.name ?? vm.name),
                          unreadCount: notifVm.unreadCount,
                          isLoading: vm.isLoading,
                          onNotifications: () =>
                              context.push(RouteNames.ceoNotifications),
                          onProfile: () => context.push(RouteNames.ceoProfile),
                          stats: [
                            DashboardHeroStat(
                              value: '$fieldUserCount',
                              label: 'Team',
                              onTap: () =>
                                  context.push(RouteNames.ceoFieldUsers),
                            ),
                            DashboardHeroStat(
                              value: '$supplierCount',
                              label: 'Partners',
                              onTap: () =>
                                  context.push(RouteNames.ceoMySuppliers),
                            ),
                            DashboardHeroStat(
                              value: '$pendingOrders',
                              label: 'To review',
                              onTap: () => context.push(
                                '${RouteNames.ceoOrders}?tab=1',
                              ),
                            ),
                          ],
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                        sliver: SliverToBoxAdapter(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              CeoInviteCodeCard(
                                inviteCode: inviteCode,
                                inviteCodeGeneratedAt:
                                    vm.company?.inviteCodeGeneratedAt,
                                onCopy: () => _copyInviteCode(inviteCode),
                                onRegenerate: () => _regenerateCode(vm),
                                isRegenerating: _regeneratingCode,
                              ),
                              if (pendingOrders > 0) ...[
                                const SizedBox(height: 16),
                                CeoPendingApprovalBanner(
                                  count: pendingOrders,
                                  onTap: () => context.push(
                                    '${RouteNames.ceoOrders}?tab=1',
                                  ),
                                ),
                              ],
                              const SizedBox(height: 16),
                              DashboardSummaryStatCard(
                                icon: Icons.pending_actions_rounded,
                                value: '$pendingJoin',
                                label: 'Pending Requests',
                                color: CeoColors.amber,
                                onTap: () =>
                                    context.push(RouteNames.ceoJoinRequests),
                              ),
                              const SizedBox(height: 16),
                              _SubscriptionCard(
                                plan: plan.toString(),
                                expiresAt: expiresAt,
                                daysLeft: daysLeft,
                              ),
                              if (expiresAt != null && daysLeft < 7) ...[
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: CeoColors.red.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.warning_amber_rounded,
                                        color: CeoColors.amber,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Subscription expiring in $daysLeft days — Renew now',
                                          style: GoogleFonts.plusJakartaSans(
                                            color: CeoColors.darkAmber,
                                            fontWeight: FontWeight.w500,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: () => context.push(
                                          RouteNames.ceoSubscription,
                                        ),
                                        child: const Text('Renew'),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              const SizedBox(height: 24),
                              Text(
                                'Quick Actions',
                                style: CeoTheme.titleStyle(size: 16).copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 12),
                              GridView.count(
                                crossAxisCount: 2,
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                childAspectRatio: 1.35,
                                children: [
                                  DashboardQuickActionTile(
                                    label: 'My Suppliers',
                                    icon: Icons.store_rounded,
                                    onTap: () =>
                                        context.push(RouteNames.ceoMySuppliers),
                                  ),
                                  DashboardQuickActionTile(
                                    label: 'Invite Suppliers',
                                    icon: Icons.person_add_rounded,
                                    onTap: () =>
                                        context.push(RouteNames.ceoInvite),
                                  ),
                                  DashboardQuickActionTile(
                                    label: 'Field Users',
                                    icon: Icons.groups_rounded,
                                    onTap: () =>
                                        context.push(RouteNames.ceoFieldUsers),
                                  ),
                                  DashboardQuickActionTile(
                                    label: 'All Orders',
                                    icon: Icons.receipt_long_rounded,
                                    onTap: () =>
                                        context.push(RouteNames.ceoOrders),
                                  ),
                                  DashboardQuickActionTile(
                                    label: 'Bulk Quotes',
                                    icon: Icons.request_quote_rounded,
                                    onTap: () =>
                                        context.push(RouteNames.ceoRfqs),
                                  ),
                                  DashboardQuickActionTile(
                                    label: 'Issues',
                                    icon: Icons.report_problem_rounded,
                                    onTap: () =>
                                        context.push(RouteNames.ceoDisputes),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),
                              Text(
                                'Recent Orders',
                                style: CeoTheme.titleStyle(size: 16).copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 8),
                              StreamBuilder<List<OrderModel>>(
                                stream: vm.watchCompanyOrders(companyId, 'All'),
                                builder: (context, snap) {
                                  final orders =
                                      (snap.data ?? []).take(5).toList();
                                  if (orders.isEmpty) {
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                      child: Text(
                                        'No orders yet',
                                        style: CeoTheme.mutedStyle(),
                                      ),
                                    );
                                  }
                                  return Column(
                                    children: orders
                                        .map((order) => _orderRow(order))
                                        .toList(),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            );
          },
        ),
        bottomNavigationBar: const CeoNavBar(currentIndex: 0),
      ),
    );
  }

  Widget _orderRow(OrderModel order) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: FieldColors.surfaceWhite,
        borderRadius: BorderRadius.circular(FieldRadius.card),
        border: Border.all(color: FieldColors.borderSubtle),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: CeoColors.navy.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.shopping_bag_rounded,
              size: 16,
              color: CeoColors.navy,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  order.materialName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w500,
                    color: CeoColors.navy,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Flexible(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: CeoStatusBadge(status: order.status),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        AppFormatters.formatPKRCurrency(order.totalAmount),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w700,
                          color: CeoColors.navy,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SubscriptionCard extends StatelessWidget {
  final String plan;
  final DateTime? expiresAt;
  final int daysLeft;

  const _SubscriptionCard({
    required this.plan,
    required this.expiresAt,
    required this.daysLeft,
  });

  @override
  Widget build(BuildContext context) {
    final isFree = plan.toLowerCase() == 'free';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isFree ? FieldColors.surfaceWhite : CeoColors.navy,
        borderRadius: BorderRadius.circular(FieldRadius.card),
        border: isFree ? Border.all(color: FieldColors.borderSubtle) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    isFree
                        ? Icons.eco_rounded
                        : Icons.workspace_premium_rounded,
                    color: isFree ? CeoColors.navy : CeoColors.amber,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isFree ? 'Free Plan' : '$plan Plan',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: isFree ? CeoColors.navy : Colors.white,
                    ),
                  ),
                ],
              ),
              TextButton.icon(
                onPressed: () => context.push(RouteNames.ceoSubscription),
                icon: Icon(
                  isFree ? Icons.upgrade_rounded : Icons.settings_rounded,
                  size: 16,
                  color: isFree ? CeoColors.amber : Colors.white,
                ),
                label: Text(
                  isFree ? 'Upgrade' : 'Manage',
                  style: TextStyle(
                    color: isFree ? CeoColors.amber : Colors.white,
                  ),
                ),
              ),
            ],
          ),
          if (expiresAt != null) ...[
            Padding(
              padding: const EdgeInsets.only(left: 28),
              child: Text(
                'Expires: ${AppFormatters.date(expiresAt!)}',
                style: GoogleFonts.plusJakartaSans(
                  color: isFree ? CeoColors.textGrey : Colors.white70,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (daysLeft / 30).clamp(0.0, 1.0),
                minHeight: 6,
                backgroundColor:
                    isFree ? CeoColors.border : Colors.white24,
                color: CeoColors.amber,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
