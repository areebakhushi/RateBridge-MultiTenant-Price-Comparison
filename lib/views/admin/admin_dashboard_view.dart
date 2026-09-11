import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../constants/route_names.dart';
import '../../theme/admin_theme.dart';
import '../../utils/app_navigation.dart';
import '../../viewmodels/admin_viewmodel.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/notification_viewmodel.dart';
import '../../widgets/dashboard_hero_header.dart';

import 'admin_finance_view.dart';
import 'admin_ceo_management_view.dart';
import 'admin_profile_view.dart';
import 'admin_supplier_management_view.dart';

class AdminDashboardView extends StatefulWidget {
  const AdminDashboardView({
    super.key,
    @visibleForTesting this.debugFirestore,
  });

  final FirebaseFirestore? debugFirestore;

  @override
  State<AdminDashboardView> createState() => _AdminDashboardViewState();
}

class _AdminDashboardViewState extends State<AdminDashboardView> {
  final TabHistory _tabHistory = TabHistory();

  void _onTabTapped(int index) {
    if (_tabHistory.select(index)) setState(() {});
  }

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      _AdminHomeOverview(onAction: _onTabTapped),
      AdminSupplierManagementView(
        embedded: true,
        debugFirestore: widget.debugFirestore,
      ),
      const AdminFinanceView(),
      AdminCeoManagementView(
        embedded: true,
        debugFirestore: widget.debugFirestore,
      ),
      const AdminProfileView(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.watch<AdminViewModel>().isLoading;
    final isProfileTab = _tabHistory.index == 4;
    final isDashboardTab = _tabHistory.index == 0;

    return TabHistoryPopScope(
      history: _tabHistory,
      onChanged: () => setState(() {}),
      child: Scaffold(
      backgroundColor: AdminColors.screenBg,
      appBar: (isProfileTab || isDashboardTab)
          ? null
          : AdminAppBar(
              title: 'RateBridge Admin',
              showNotificationIcon: true,
              automaticallyImplyLeading: false,
              bottom: isLoading
                  ? const PreferredSize(
                      preferredSize: Size.fromHeight(2),
                      child: LinearProgressIndicator(
                        minHeight: 2,
                        backgroundColor: Colors.transparent,
                        color: AdminColors.amber,
                      ),
                    )
                  : null,
            ),
      body: SafeArea(
        top: false,
        child: IndexedStack(
          index: _tabHistory.index,
          children: _screens,
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _tabHistory.index,
          onTap: _onTabTapped,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: AdminColors.navy,
          unselectedItemColor: AdminColors.textGrey,
          selectedLabelStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 11),
          unselectedLabelStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w500, fontSize: 11),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_outlined),
              activeIcon: Icon(Icons.dashboard_rounded),
              label: 'Dashboard',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.storefront_outlined),
              activeIcon: Icon(Icons.storefront_rounded),
              label: 'Suppliers',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.account_balance_wallet_outlined),
              activeIcon: Icon(Icons.account_balance_wallet_rounded),
              label: 'Finance',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.business_center_outlined),
              activeIcon: Icon(Icons.business_center_rounded),
              label: 'CEOs',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.account_circle_outlined),
              activeIcon: Icon(Icons.account_circle_rounded),
              label: 'Profile',
            ),
          ],
        ),
      ),
    ),
    );
  }
}

class _AdminHomeOverview extends StatefulWidget {
  final Function(int) onAction;
  const _AdminHomeOverview({required this.onAction});

  @override
  State<_AdminHomeOverview> createState() => _AdminHomeOverviewState();
}

class _AdminHomeOverviewState extends State<_AdminHomeOverview> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final uid = context.read<AuthViewModel>().user?.uid;
      if (uid != null) {
        final notif = context.read<NotificationViewModel>();
        notif.loadNotifications(uid);
        notif.watchUnreadCount(uid);
      }
      context.read<AdminViewModel>().loadPaymentQueue();
    });
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String _initials(String? name) {
    final trimmed = name?.trim() ?? '';
    if (trimmed.isEmpty) return 'A';
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts.first[0].toUpperCase();
  }

  Future<void> _refresh() {
    return context.read<AdminViewModel>().loadPaymentQueue();
  }

  @override
  Widget build(BuildContext context) {
    final adminVM = context.watch<AdminViewModel>();
    final auth = context.watch<AuthViewModel>();
    final notifVM = context.watch<NotificationViewModel>();
    final user = auth.user;
    final pendingPayments = adminVM.pendingPayments.length;

    return RefreshIndicator(
      color: AdminColors.navy,
      onRefresh: _refresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          SliverToBoxAdapter(
            child: StreamBuilder<int>(
              stream: adminVM.watchPendingUsersCount(),
              builder: (context, pendingSnap) {
                return StreamBuilder<int>(
                  stream: adminVM.watchActiveUsersCount(),
                  builder: (context, activeSnap) {
                    return StreamBuilder<int>(
                      stream: adminVM.watchSuspendedUsersCount(),
                      builder: (context, suspendedSnap) {
                        final pending = pendingSnap.data ?? 0;
                        final active = activeSnap.data ?? 0;
                        final suspended = suspendedSnap.data ?? 0;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            DashboardHeroHeader(
                              greeting: _greeting(),
                              headline: 'RateBridge Admin',
                              initials: _initials(user?.name),
                              unreadCount: notifVM.unreadCount,
                              isLoading: adminVM.isLoading,
                              onNotifications: () =>
                                  context.push(RouteNames.adminNotifications),
                              onProfile: () => widget.onAction(4),
                              stats: [
                                DashboardHeroStat(
                                  value: '$pending',
                                  label: 'Pending',
                                  onTap: () => widget.onAction(3),
                                ),
                                DashboardHeroStat(
                                  value: '$active',
                                  label: 'Active',
                                  onTap: () => widget.onAction(1),
                                ),
                                DashboardHeroStat(
                                  value: '$suspended',
                                  label: 'Suspended',
                                  onTap: () => widget.onAction(3),
                                ),
                              ],
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  if (pending > 0) ...[
                                    _AttentionBanner(
                                      message: pending == 1
                                          ? 'You have 1 account waiting for approval'
                                          : 'You have $pending accounts waiting for approval',
                                      actionLabel: 'Review now →',
                                      onTap: () => widget.onAction(3),
                                    ),
                                    const SizedBox(height: 16),
                                  ] else if (pendingPayments > 0) ...[
                                    _AttentionBanner(
                                      message: pendingPayments == 1
                                          ? 'You have 1 payment waiting for review'
                                          : 'You have $pendingPayments payments waiting for review',
                                      actionLabel: 'Review now →',
                                      onTap: () => widget.onAction(2),
                                    ),
                                    const SizedBox(height: 16),
                                  ],
                                  StreamBuilder<QuerySnapshot>(
                                    stream: FirebaseFirestore.instance.collection('appeals').where('status', isEqualTo: 'pending').snapshots(),
                                    builder: (context, snapshot) {
                                      final pendingAppeals = snapshot.data?.docs.length ?? 0;
                                      if (pendingAppeals > 0) {
                                        return Padding(
                                          padding: const EdgeInsets.only(bottom: 16),
                                          child: _AttentionBanner(
                                            message: 'You have $pendingAppeals pending account appeals',
                                            actionLabel: 'Review now →',
                                            onTap: () => context.push(RouteNames.adminAppeals),
                                          ),
                                        );
                                      }
                                      return const SizedBox.shrink();
                                    },
                                  ),
                                  DashboardSummaryStatCard(
                                    icon: Icons.insights_rounded,
                                    value: 'Active',
                                    label: 'Revenue',
                                    color: AdminColors.green,
                                    onTap: () => widget.onAction(2),
                                  ),
                                  const SizedBox(height: 24),
                                  Text(
                                'Quick Actions',
                                style: AdminTheme.titleStyle(size: 16).copyWith(
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
                                    label: 'Review CEOs',
                                    icon: Icons.manage_accounts_outlined,
                                    onTap: () => widget.onAction(3),
                                  ),
                                  DashboardQuickActionTile(
                                    label: 'Review Suppliers',
                                    icon: Icons.inventory_2_outlined,
                                    onTap: () => widget.onAction(1),
                                  ),
                                  DashboardQuickActionTile(
                                    label: 'Account Appeals',
                                    icon: Icons.history_edu_rounded,
                                    onTap: () =>
                                        context.push(RouteNames.adminAppeals),
                                  ),
                                  DashboardQuickActionTile(
                                    label: 'Dispute Center',
                                    icon: Icons.gavel_rounded,
                                    onTap: () =>
                                        context.push(RouteNames.adminDisputes),
                                  ),
                                  DashboardQuickActionTile(
                                    label: 'Finance Center',
                                    icon: Icons.account_balance_outlined,
                                    onTap: () => widget.onAction(2),
                                  ),
                                  DashboardQuickActionTile(
                                    label: 'Manage Taxonomy',
                                    icon: Icons.category_outlined,
                                    onTap: () =>
                                        context.push(RouteNames.adminCategories),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _AttentionBanner extends StatelessWidget {
  final String message;
  final String actionLabel;
  final VoidCallback onTap;

  const _AttentionBanner({
    required this.message,
    required this.actionLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AdminColors.amber.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: const Border(
              left: BorderSide(color: AdminColors.amber, width: 4),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  message,
                  style: AdminTheme.bodyStyle().copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
              TextButton(
                onPressed: onTap,
                style: TextButton.styleFrom(
                  foregroundColor: AdminColors.navy,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                child: Text(actionLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
