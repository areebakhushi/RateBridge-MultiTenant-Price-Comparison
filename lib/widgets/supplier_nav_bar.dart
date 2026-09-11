import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../constants/route_names.dart';
import '../theme/supplier_theme.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../viewmodels/chat_viewmodel.dart';

class SupplierNavBar extends StatefulWidget {
  final int currentIndex;

  const SupplierNavBar({super.key, required this.currentIndex});

  static const int messagesTabIndex = 3;

  static const _routes = [
    RouteNames.supplierDashboard,
    RouteNames.supplierMaterials,
    RouteNames.supplierOrders,
    RouteNames.supplierChat,
    RouteNames.supplierEarnings,
    RouteNames.supplierProfile,
  ];

  static const _tabs = [
    _NavTab(
      label: 'Home',
      outlinedIcon: Icons.home_outlined,
      filledIcon: Icons.home_rounded,
    ),
    _NavTab(
      label: 'Materials',
      outlinedIcon: Icons.inventory_2_outlined,
      filledIcon: Icons.inventory_2_rounded,
    ),
    _NavTab(
      label: 'Orders',
      outlinedIcon: Icons.receipt_long_outlined,
      filledIcon: Icons.receipt_long_rounded,
    ),
    _NavTab(
      label: 'Messages',
      outlinedIcon: Icons.chat_bubble_outline_rounded,
      filledIcon: Icons.chat_bubble_rounded,
    ),
    _NavTab(
      label: 'Earnings',
      outlinedIcon: Icons.account_balance_wallet_outlined,
      filledIcon: Icons.account_balance_wallet_rounded,
    ),
    _NavTab(
      label: 'Profile',
      outlinedIcon: Icons.person_outline_rounded,
      filledIcon: Icons.person_rounded,
    ),
  ];

  @override
  State<SupplierNavBar> createState() => _SupplierNavBarState();
}

class _NavTab {
  final String label;
  final IconData outlinedIcon;
  final IconData filledIcon;

  const _NavTab({
    required this.label,
    required this.outlinedIcon,
    required this.filledIcon,
  });
}

class _SupplierNavBarState extends State<SupplierNavBar> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _watchMessages());
  }

  void _watchMessages() {
    final uid = context.read<AuthViewModel>().user?.uid;
    if (uid == null) return;
    context.read<ChatViewModel>().watchSupplierThreads(uid);
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = context.watch<ChatViewModel>().unreadMessageCount;

    return Container(
      decoration: const BoxDecoration(
        color: FieldColors.surfaceWhite,
        border: Border(
          top: BorderSide(color: FieldColors.borderSubtle, width: 1),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: FieldSpacing.sm,
            vertical: FieldSpacing.sm,
          ),
          child: Row(
            children: List.generate(SupplierNavBar._tabs.length, (index) {
              final tab = SupplierNavBar._tabs[index];
              final badgeCount =
                  index == SupplierNavBar.messagesTabIndex ? unreadCount : 0;
              return Expanded(
                child: _SupplierNavItem(
                  label: tab.label,
                  outlinedIcon: tab.outlinedIcon,
                  filledIcon: tab.filledIcon,
                  isSelected: widget.currentIndex == index,
                  badgeCount: badgeCount,
                  onTap: () {
                    if (index == widget.currentIndex) return;
                    context.go(SupplierNavBar._routes[index]);
                  },
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _SupplierNavItem extends StatelessWidget {
  final String label;
  final IconData outlinedIcon;
  final IconData filledIcon;
  final bool isSelected;
  final int badgeCount;
  final VoidCallback onTap;

  const _SupplierNavItem({
    required this.label,
    required this.outlinedIcon,
    required this.filledIcon,
    required this.isSelected,
    required this.badgeCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor =
        isSelected ? FieldColors.accentAmber : FieldColors.textMuted;
    final labelColor =
        isSelected ? FieldColors.primaryNavy : FieldColors.textMuted;
    final labelWeight = isSelected ? FontWeight.w600 : FontWeight.w400;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(FieldRadius.button),
        splashColor: FieldColors.accentAmber.withValues(alpha: 0.12),
        highlightColor: FieldColors.accentAmber.withValues(alpha: 0.06),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: FieldSpacing.sm),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    isSelected ? filledIcon : outlinedIcon,
                    size: 24,
                    color: iconColor,
                  ),
                  if (badgeCount > 0)
                    Positioned(
                      right: -10,
                      top: -5,
                      child: Container(
                        constraints:
                            const BoxConstraints(minWidth: 18, minHeight: 18),
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        decoration: BoxDecoration(
                          color: FieldColors.statusDanger,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: FieldColors.surfaceWhite,
                            width: 1.5,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          badgeCount > 99 ? '99+' : '$badgeCount',
                          style: FieldTypography.labelSmall.copyWith(
                            color: FieldColors.surfaceWhite,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            height: 1,
                            letterSpacing: 0,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: FieldSpacing.xs),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: FieldTypography.labelSmall.copyWith(
                  color: labelColor,
                  fontWeight: labelWeight,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
