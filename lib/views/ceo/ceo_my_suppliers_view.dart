// MVVM: View — no business logic

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../constants/route_names.dart';
import '../../theme/ceo_theme.dart';
import '../../utils/app_navigation.dart';
import '../../viewmodels/ceo_viewmodel.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../widgets/ceo_nav_bar.dart';
import '../../widgets/ceo/ceo_widgets.dart';
import '../../widgets/supplier_performance_scorecard.dart';

const _citiesAll = [
  'All',
  'Rawalpindi',
  'Islamabad',
  'Lahore',
  'Karachi',
  'Peshawar'
];

class CeoMySuppliersView extends StatefulWidget {
  const CeoMySuppliersView({super.key});

  @override
  State<CeoMySuppliersView> createState() => _CeoMySuppliersViewState();
}

class _CeoMySuppliersViewState extends State<CeoMySuppliersView>
    with SingleTickerProviderStateMixin {
  late final TabController _cityTabController;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _cityTabController =
        TabController(length: _citiesAll.length, vsync: this);
  }

  @override
  void dispose() {
    _cityTabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _filterByCity(
      List<Map<String, dynamic>> all, String selectedCity) {
    var result = all;
    
    if (selectedCity != 'All') {
      result = result.where((s) {
        final supplierCity = (s['city'] ?? '').toString().trim().toLowerCase();
        final targetCity = selectedCity.trim().toLowerCase();
        return supplierCity == targetCity;
      }).toList();
    }
    
    if (_searchQuery.isNotEmpty) {
      result = result
          .where((s) => (s['name'] ?? '')
              .toString()
              .toLowerCase()
              .contains(_searchQuery.toLowerCase()))
          .toList();
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final companyId =
        context.read<AuthViewModel>().user?.companyId ?? '';

    return RootTabPopScope(
      isHome: false,
      homeRoute: RouteNames.ceoDashboard,
      child: Scaffold(
      backgroundColor: CeoColors.screenBg,
      appBar: CeoAppBar(
        title: 'Partner Directory',
        bottom: TabBar(
          controller: _cityTabController,
          isScrollable: true,
          indicatorColor: CeoColors.amber,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: CeoColors.textGrey,
          labelStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 13),
          unselectedLabelStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w500, fontSize: 13),
          tabs: _citiesAll.map((c) => Tab(text: c)).toList(),
        ),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _searchQuery = v),
              style: GoogleFonts.plusJakartaSans(fontSize: 14),
              decoration: CeoTheme.inputDecoration(
                hintText: 'Search by business name...',
                prefixIcon: const Icon(Icons.search_rounded, color: CeoColors.navy, size: 22),
                suffixIcon: _searchQuery.isNotEmpty 
                  ? IconButton(
                      icon: const Icon(Icons.cancel_rounded, size: 20, color: CeoColors.textGrey),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              ),
            ),
          ),
          Expanded(
            child: Consumer<CeoViewModel>(
              builder: (context, vm, _) {
                return StreamBuilder<List<Map<String, dynamic>>>(
                  stream: vm.watchMySuppliers(companyId),
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final allConnectedSuppliers = snap.data ?? [];

                    return TabBarView(
                      controller: _cityTabController,
                      children: _citiesAll.map((city) {
                        final suppliers = _filterByCity(allConnectedSuppliers, city);
                        if (suppliers.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: CeoColors.navy.withValues(alpha: 0.05),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    _searchQuery.isNotEmpty ? Icons.search_off_rounded : Icons.store_rounded,
                                    size: 48, 
                                    color: CeoColors.textGrey,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  _searchQuery.isNotEmpty 
                                    ? 'No matches found'
                                    : (city == 'All'
                                        ? 'No partners linked yet'
                                        : 'No partners in $city'),
                                  style: CeoTheme.titleStyle(size: 16).copyWith(color: CeoColors.textGrey),
                                ),
                              ],
                            ),
                          );
                        }
                        return ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: suppliers.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, i) => _supplierCard(
                              context, vm, suppliers[i], companyId),
                        );
                      }).toList(),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: const CeoNavBar(currentIndex: 1),
    ),
    );
  }

  Widget _supplierCard(BuildContext context, CeoViewModel vm,
      Map<String, dynamic> supplier, String companyId) {
    final supplierId = supplier['id'] as String? ?? '';
    final name = supplier['name'] as String? ?? 'Supplier';
    final city = supplier['city'] as String? ?? '';
    final materialType = supplier['materialType'] as String? ?? '';
    final status = (supplier['status'] as String? ?? 'active').toLowerCase();
    final isActive = status == 'active' || status == 'approved';
    final linkedAt = supplier['linkedAt'];

    return AdminCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isActive
                      ? CeoColors.navy.withValues(alpha: 0.08)
                      : CeoColors.red.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : 'S',
                    style: GoogleFonts.plusJakartaSans(
                      color: isActive ? CeoColors.navy : CeoColors.red,
                      fontWeight: FontWeight.w800,
                      fontSize: 20,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: CeoColors.navy,
                      ),
                    ),
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined, size: 12, color: CeoColors.textGrey),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '$city · $materialType',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: CeoTheme.mutedStyle(size: 12),
                          ),
                        ),
                      ],
                    ),
                    if (linkedAt != null)
                      Row(
                        children: [
                          const Icon(Icons.link_rounded, size: 12, color: CeoColors.textGrey),
                          const SizedBox(width: 4),
                          Text(
                            'Joined ${_formatTimestamp(linkedAt)}',
                            style: CeoTheme.mutedStyle(size: 11),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              CeoStatusBadge(status: isActive ? 'active' : 'deactivated'),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              isActive
                  ? _actionButton(
                      onPressed: () => _confirmToggle(
                          context, vm, supplierId, companyId,
                          activate: false),
                      icon: Icons.block_rounded,
                      label: 'Deactivate',
                      color: CeoColors.darkAmber,
                      isOutlined: true,
                    )
                  : _actionButton(
                      onPressed: () => _confirmToggle(
                          context, vm, supplierId, companyId,
                          activate: true),
                      icon: Icons.check_circle_rounded,
                      label: 'Reactivate',
                      color: CeoColors.green,
                      isOutlined: false,
                    ),
              _actionButton(
                onPressed: () => _showProfileSheet(context, supplier),
                icon: Icons.analytics_outlined,
                label: 'Performance',
                color: CeoColors.navy,
                isOutlined: true,
              ),
              _actionButton(
                onPressed: () =>
                    _confirmRemove(context, vm, supplierId, name),
                icon: Icons.link_off_rounded,
                label: 'Remove',
                color: CeoColors.red,
                isOutlined: true,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required VoidCallback onPressed,
    required IconData icon,
    required String label,
    required Color color,
    required bool isOutlined,
  }) {
    if (isOutlined) {
      return OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 16),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color.withValues(alpha: 0.5)),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      );
    }
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }

  void _confirmToggle(BuildContext context, CeoViewModel vm, String supplierId,
      String companyId,
      {required bool activate}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(activate ? Icons.bolt_rounded : Icons.block_rounded, 
                 color: activate ? CeoColors.green : CeoColors.amber),
            const SizedBox(width: 10),
            Text(activate ? 'Reactivate Supplier?' : 'Deactivate Supplier?'),
          ],
        ),
        content: Text(
          activate
              ? 'This supplier will regain access to your material inventory and can receive orders.'
              : 'This supplier will no longer receive new orders. Existing orders are not affected.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('CANCEL')),
          ElevatedButton(
            style: activate
                ? CeoTheme.primaryButtonStyle(height: 40)
                : ElevatedButton.styleFrom(
                    backgroundColor: CeoColors.darkAmber,
                    foregroundColor: Colors.white,
                  ),
            onPressed: () {
              Navigator.pop(ctx);
              vm.toggleSupplierStatus(supplierId, companyId, activate);
            },
            child: Text(activate ? 'ACTIVATE' : 'DEACTIVATE'),
          ),
        ],
      ),
    );
  }

  void _confirmRemove(
      BuildContext context, CeoViewModel vm, String supplierId, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning_rounded, color: CeoColors.red),
            const SizedBox(width: 10),
            const Text('Remove Partnership?'),
          ],
        ),
        content: Text(
          'Are you sure you want to remove $name? This will break the link, and their materials will be hidden from your field engineers.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('CANCEL')),
          OutlinedButton.icon(
            style: CeoTheme.destructiveButtonStyle(height: 40),
            onPressed: () {
              Navigator.pop(ctx);
              vm.removeSupplier(supplierId);
            },
            icon: const Icon(Icons.link_off_rounded, size: 18),
            label: const Text('REMOVE PERMANENTLY'),
          ),
        ],
      ),
    );
  }

  void _showProfileSheet(
      BuildContext context, Map<String, dynamic> supplier) {
    final companyId = context.read<AuthViewModel>().user?.companyId ?? '';
    final rating = (supplier['rating'] as num? ?? 0.0).toDouble();

    showModalBottomSheet(
      context: context,
      backgroundColor: CeoColors.screenBg,
      isScrollControlled: true,
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
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                const Icon(Icons.analytics_rounded, color: CeoColors.navy, size: 24),
                const SizedBox(width: 12),
                Text('Partner Insights',
                    style: CeoTheme.titleStyle(size: 20)),
              ],
            ),
            const SizedBox(height: 4),
            Text(supplier['name'] ?? 'Supplier',
                style: CeoTheme.mutedStyle(size: 14)),
            const SizedBox(height: 24),
            SupplierPerformanceScorecard(
              supplierId: supplier['id'] ?? '',
              companyId: companyId,
              averageRating: rating,
            ),
            const SizedBox(height: 24),
            const CeoSectionLabel('Business Details'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: CeoTheme.cardDecoration(),
              child: Column(
                children: [
                  _profileRow(Icons.location_on_rounded, 'Location',
                      supplier['city'] ?? '—'),
                  const Divider(height: 16),
                  _profileRow(Icons.category_rounded, 'Category',
                      supplier['materialType'] ?? '—'),
                  const Divider(height: 16),
                  _profileRow(Icons.info_outline_rounded, 'Status',
                      (supplier['status'] ?? 'active').toString().toUpperCase()),
                ],
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: CeoTheme.primaryButtonStyle(height: 52),
              child: const Text('CLOSE'),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _profileRow(IconData icon, String label, String text) {
    return Row(
      children: [
        Icon(icon, size: 18, color: CeoColors.textGrey),
        const SizedBox(width: 12),
        Text(label, style: CeoTheme.mutedStyle(size: 14)),
        const Spacer(),
        Text(text, style: CeoTheme.bodyStyle().copyWith(fontWeight: FontWeight.w600)),
      ],
    );
  }

  String _formatTimestamp(dynamic ts) {
    try {
      final date = ts.toDate() as DateTime;
      return '${date.day}/${date.month}/${date.year}';
    } catch (_) {
      return '—';
    }
  }
}
