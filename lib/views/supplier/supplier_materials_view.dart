// MVVM: View — no business logic
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../viewmodels/supplier_viewmodel.dart';
import '../../models/material_model.dart';
import '../../theme/supplier_theme.dart';
import '../../constants/route_names.dart';
import '../../utils/app_navigation.dart';
import '../../utils/currency_formatter.dart';
import '../../utils/app_theme.dart';
import '../../widgets/app_network_image.dart';
import '../../widgets/supplier_nav_bar.dart';
import '../../widgets/supplier/supplier_async_states.dart';

class SupplierMaterialsView extends StatefulWidget {
  const SupplierMaterialsView({super.key});

  @override
  State<SupplierMaterialsView> createState() => _SupplierMaterialsViewState();
}

class _SupplierMaterialsViewState extends State<SupplierMaterialsView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final viewModel = context.read<SupplierViewModel>();
      if (viewModel.selectedCompanyId != null) {
        viewModel.loadMaterials(viewModel.selectedCompanyId!);
      }
    });
  }

  Future<void> _confirmDelete(MaterialModel material) async {
    final companyId = context.read<SupplierViewModel>().selectedCompanyId;
    if (companyId == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove listing?'),
        content: Text(
          material.archived
              ? '${material.name} is already removed from the marketplace.'
              : 'Remove "${material.name}" from the marketplace? Past orders keep their details. If this material has active orders, deletion will be blocked.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: FieldColors.statusDanger),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await context.read<SupplierViewModel>().deleteMaterial(material.id, companyId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Listing removed from the marketplace')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  IconData _categoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'steel':
        return Icons.construction_outlined;
      case 'cement':
        return Icons.foundation_outlined;
      case 'aggregates':
        return Icons.grain_outlined;
      case 'sand':
        return Icons.landscape_outlined;
      default:
        return Icons.inventory_2_outlined;
    }
  }

  (Color bg, Color fg, String label) _stockStyle(String? status) {
    final value = (status ?? 'Available').toLowerCase();
    if (value.contains('out')) {
      return (FieldColors.statusDanger.withValues(alpha: 0.12), FieldColors.statusDanger, 'Out of Stock');
    }
    if (value.contains('limited')) {
      return (FieldColors.accentAmberSoft, FieldColors.statusWarning, 'Limited');
    }
    return (FieldColors.statusSuccess.withValues(alpha: 0.12), FieldColors.statusSuccess, 'Available');
  }

  String _formatUpdatedDate(MaterialModel material) {
    final date = material.createdAt;
    if (date == null) return 'Updated recently';
    return 'Updated ${DateFormat('MMM dd, yyyy').format(date)}';
  }

  @override
  Widget build(BuildContext context) {
    return RootTabPopScope(
      isHome: false,
      homeRoute: RouteNames.supplierDashboard,
      child: Scaffold(
      backgroundColor: FieldColors.screenBackground,
      appBar: const SupplierAppBar(title: 'My Materials'),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push(RouteNames.supplierAddMaterial),
        child: const Icon(Icons.add),
      ),
      bottomNavigationBar: const SupplierNavBar(currentIndex: 1),
      body: Consumer<SupplierViewModel>(
        builder: (context, vm, child) {
          if (vm.isLoading && vm.materials.isEmpty) {
            return const SupplierMaterialListSkeleton(itemCount: 4);
          }

          if (vm.materials.isEmpty) {
            return SupplierEmptyState(
              icon: Icons.inventory_2_outlined,
              title: 'No materials yet',
              subtitle: 'Tap + to add your first material listing',
              action: FilledButton.icon(
                onPressed: () => context.push(RouteNames.supplierAddMaterial),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Material'),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: vm.materials.length,
            itemBuilder: (context, index) {
              final material = vm.materials[index];
              return _buildMaterialCard(material);
            },
          );
        },
      ),
    ),
    );
  }

  Widget _buildMaterialCard(MaterialModel material) {
    final stock = _stockStyle(material.stockStatus);
    final imageUrl = material.profileImageUrl;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: FieldColors.surfaceWhite,
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FieldRadius.card),
          side: const BorderSide(color: FieldColors.borderSubtle),
        ),
        child: InkWell(
          onTap: () {
            context.push(
              RouteNames.supplierMaterialDetail
                  .replaceFirst(':matId', material.id),
              extra: material,
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: FieldColors.screenBackground,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    border: Border.all(color: FieldColors.borderSubtle),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: AppNetworkImage(
                    url: imageUrl,
                    fit: BoxFit.cover,
                    width: 56,
                    height: 56,
                    debugLabel: 'materials:${material.id}',
                    fallback: Icon(
                      _categoryIcon(material.category),
                      color: FieldColors.primaryNavy,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        material.name,
                        style: AppTextStyles.body.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text(
                            CurrencyFormatter.formatPKR(material.pricePerUnit),
                            style: AppTextStyles.body.copyWith(
                              color: FieldColors.primaryNavy,
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '/ ${material.unit}',
                            style: AppTextStyles.caption,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: stock.$1,
                              borderRadius: BorderRadius.circular(AppRadius.pill),
                            ),
                            child: Text(
                              stock.$3,
                              style: AppTextStyles.caption.copyWith(
                                color: stock.$2,
                                fontWeight: FontWeight.w600,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          if (material.archived) ...[
                            const SizedBox(width: 8),
                            Text(
                              'ARCHIVED',
                              style: AppTextStyles.caption.copyWith(
                                color: FieldColors.statusDanger,
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                              ),
                            ),
                          ],
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _formatUpdatedDate(material),
                              style: AppTextStyles.caption.copyWith(
                                color: FieldColors.textMuted,
                                fontSize: 11,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () {
                    context.push(
                      RouteNames.supplierEditMaterial
                          .replaceFirst(':matId', material.id),
                      extra: material,
                    );
                  },
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  color: FieldColors.textSecondary,
                  tooltip: 'Edit material',
                ),
                IconButton(
                  onPressed: () => _confirmDelete(material),
                  icon: const Icon(Icons.delete_outline, size: 20),
                  color: FieldColors.statusDanger,
                  tooltip: 'Delete material',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
