import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../constants/route_names.dart';
import '../../models/payment_proof_model.dart';
import '../../models/transaction_model.dart';
import '../../theme/supplier_theme.dart';
import '../../utils/app_theme.dart';
import '../../utils/currency_formatter.dart';
import '../../viewmodels/supplier_viewmodel.dart';
import '../../widgets/app_network_image.dart';
import '../../utils/app_navigation.dart';
import '../../widgets/supplier/supplier_async_states.dart';
import '../../widgets/supplier_nav_bar.dart';
import 'commission_payment_view.dart';

class SupplierEarningsView extends StatefulWidget {
  const SupplierEarningsView({super.key});

  @override
  State<SupplierEarningsView> createState() => _SupplierEarningsViewState();
}

class _SupplierEarningsViewState extends State<SupplierEarningsView> {
  DateTime _currentMonth = DateTime.now();
  int _historyIndex = 0;

  bool _isSelectionMode = false;
  final Set<String> _selectedIds = {};

  String get _monthLabel => DateFormat('MMMM yyyy').format(_currentMonth);
  String get _monthKey => DateFormat('yyyy-MM').format(_currentMonth);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SupplierViewModel>().loadEarnings(_monthKey);
    });
  }

  Future<void> _selectMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _currentMonth,
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
    );
    if (picked == null || !mounted) return;
    setState(() => _currentMonth = picked);
    context.read<SupplierViewModel>().changeMonth(
      DateFormat('yyyy-MM').format(picked),
    );
  }

  void _openPayCommission() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SupplierTheme.wrap(const CommissionPaymentView()),
      ),
    );
  }

  void _openProofImage(String url) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _FullScreenProofView(imageUrl: url),
      ),
    );
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) _isSelectionMode = false;
      } else {
        _selectedIds.add(id);
      }
    });
  }

  Future<void> _confirmAndDeleteSelected() async {
    if (_selectedIds.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Remove ${_selectedIds.length} items?'),
        content: const Text('This will remove these records from your view. They will remain in the platform ledger for audit purposes.'),
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
      final vm = context.read<SupplierViewModel>();
      try {
        if (_historyIndex == 0) {
          for (final id in _selectedIds) {
            await vm.hideTransaction(id);
          }
        } else {
          // If clearing all payment proofs
          await vm.clearPaymentHistory();
        }
        setState(() {
          _selectedIds.clear();
          _isSelectionMode = false;
        });
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to remove items: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
                  _selectedIds.clear();
                }),
              )
            : null,
        title: _isSelectionMode ? '${_selectedIds.length} selected' : 'Earnings & Commissions',
        actions: _isSelectionMode
            ? [
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded),
                  onPressed: _confirmAndDeleteSelected,
                ),
              ]
            : null,
      ),
      bottomNavigationBar: const SupplierNavBar(currentIndex: 4),
      body: Consumer<SupplierViewModel>(
        builder: (context, vm, _) {
          final commissionOwed = vm.commissionOwed;
          final totalPaid = vm.totalCommissionPaid;
          final grossSales = vm.grossSalesForMonth(_monthKey);
          final netEarnings = vm.netEarningsForMonth(_monthKey);
          final transactions = vm.transactions;
          final payments = vm.paymentHistory;

          return ListView(
            padding: const EdgeInsets.fromLTRB(
              FieldSpacing.md,
              FieldSpacing.md,
              FieldSpacing.md,
              FieldSpacing.xl,
            ),
            children: [
              if (!_isSelectionMode) ...[
                _NetEarningsHero(
                  netEarnings: netEarnings,
                  monthLabel: _monthLabel,
                ),
                const SizedBox(height: FieldSpacing.md),
                _CommissionStatusCard(
                  amountOwed: commissionOwed,
                  onPay: _openPayCommission,
                ),
                const SizedBox(height: FieldSpacing.lg),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Monthly summary',
                        style: AppTextStyles.h3.copyWith(
                          color: FieldColors.primaryNavy,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _selectMonth,
                      icon: const Icon(Icons.calendar_month_outlined, size: 18),
                      label: Text(_monthLabel),
                    ),
                  ],
                ),
                const SizedBox(height: FieldSpacing.sm),
                _SummaryCard(
                  grossSales: grossSales,
                  netEarnings: netEarnings,
                  totalPaid: totalPaid,
                ),
                const SizedBox(height: FieldSpacing.lg),
              ],
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'History',
                      style: AppTextStyles.h3.copyWith(
                        color: FieldColors.primaryNavy,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (_historyIndex == 1 && payments.isNotEmpty && !_isSelectionMode)
                    TextButton(
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Clear history?'),
                            content: const Text('Remove all payment proofs from your view?'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                              TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Clear All', style: TextStyle(color: Colors.red))),
                            ],
                          ),
                        );
                        if (confirm == true) await vm.clearPaymentHistory();
                      },
                      child: const Text('Clear All'),
                    ),
                ],
              ),
              const SizedBox(height: FieldSpacing.sm),
              _HistorySegment(
                selectedIndex: _historyIndex,
                onChanged: (index) => setState(() {
                  _historyIndex = index;
                  _isSelectionMode = false;
                  _selectedIds.clear();
                }),
              ),
              const SizedBox(height: FieldSpacing.md),
              if (_historyIndex == 0)
                ..._orderCards(transactions)
              else
                ..._paymentCards(payments),
            ],
          );
        },
      ),
    ),
    );
  }

  List<Widget> _orderCards(List<TransactionModel> txs) {
    if (txs.isEmpty) {
      return const [
        SizedBox(
          height: 220,
          child: SupplierEmptyState(
            icon: Icons.receipt_long_outlined,
            title: 'No commissions this month',
            subtitle: 'Order commissions will appear here as sales come in.',
          ),
        ),
      ];
    }
    return [
      for (final tx in txs)
        Padding(
          padding: const EdgeInsets.only(bottom: FieldSpacing.sm),
          child: _OrderCommissionCard(
            transaction: tx,
            isSelected: _selectedIds.contains(tx.txId),
            isSelectionMode: _isSelectionMode,
            onTap: () {
              if (_isSelectionMode) {
                _toggleSelection(tx.txId);
              }
            },
            onLongPress: () {
              if (!_isSelectionMode) {
                setState(() {
                  _isSelectionMode = true;
                  _selectedIds.add(tx.txId);
                });
              }
            },
          ),
        ),
    ];
  }

  List<Widget> _paymentCards(List<PaymentProofModel> payments) {
    if (payments.isEmpty) {
      return const [
        SizedBox(
          height: 220,
          child: SupplierEmptyState(
            icon: Icons.payments_outlined,
            title: 'No payment proofs yet',
            subtitle: 'Screenshots you upload when paying commission will show here.',
          ),
        ),
      ];
    }
    return [
      for (final payment in payments)
        Padding(
          padding: const EdgeInsets.only(bottom: FieldSpacing.sm),
          child: _PaymentProofCard(
            payment: payment,
            onOpenImage: payment.screenshotUrl.trim().isEmpty || _isSelectionMode
                ? null
                : () => _openProofImage(payment.screenshotUrl),
            isSelected: _selectedIds.contains(payment.id),
            isSelectionMode: _isSelectionMode,
            onTap: () {
              if (_isSelectionMode) {
                _toggleSelection(payment.id);
              }
            },
            onLongPress: () {
              if (!_isSelectionMode) {
                setState(() {
                  _isSelectionMode = true;
                  _selectedIds.add(payment.id);
                });
              }
            },
          ),
        ),
    ];
  }
}

class _NetEarningsHero extends StatelessWidget {
  final double netEarnings;
  final String monthLabel;

  const _NetEarningsHero({
    required this.netEarnings,
    required this.monthLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(FieldSpacing.md),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [FieldColors.primaryNavy, FieldColors.primaryNavyDark],
        ),
        borderRadius: BorderRadius.all(Radius.circular(FieldRadius.card)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'NET EARNINGS · $monthLabel'.toUpperCase(),
            style: AppTextStyles.label.copyWith(
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            CurrencyFormatter.formatPKR(netEarnings),
            style: FieldTypography.displayLarge.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'After 2% platform commission',
            style: AppTextStyles.caption.copyWith(
              color: Colors.white.withValues(alpha: 0.75),
            ),
          ),
        ],
      ),
    );
  }
}

class _CommissionStatusCard extends StatelessWidget {
  final double amountOwed;
  final VoidCallback onPay;

  const _CommissionStatusCard({
    required this.amountOwed,
    required this.onPay,
  });

  @override
  Widget build(BuildContext context) {
    final owed = amountOwed > 0;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(FieldSpacing.md),
      decoration: SupplierTheme.cardDecoration(
        borderColor: owed
            ? FieldColors.statusDanger.withValues(alpha: 0.35)
            : FieldColors.statusSuccess.withValues(alpha: 0.35),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                owed ? Icons.warning_amber_rounded : Icons.check_circle_outline,
                size: 20,
                color: owed ? FieldColors.statusDanger : FieldColors.statusSuccess,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  owed ? 'Commission outstanding' : 'Commission settled',
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w700,
                    color: FieldColors.primaryNavy,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            CurrencyFormatter.formatPKR(amountOwed),
            style: AppTextStyles.h2.copyWith(
              color: owed ? FieldColors.statusDanger : FieldColors.statusSuccess,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            owed
                ? 'Pay outstanding commission to keep listings visible to buyers.'
                : 'All commission payments are up to date.',
            style: AppTextStyles.caption,
          ),
          if (owed) ...[
            const SizedBox(height: FieldSpacing.md),
            FilledButton.icon(
              onPressed: onPay,
              icon: const Icon(Icons.payments_outlined, size: 18),
              label: const Text('Pay commission'),
            ),
          ],
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final double grossSales;
  final double netEarnings;
  final double totalPaid;

  const _SummaryCard({
    required this.grossSales,
    required this.netEarnings,
    required this.totalPaid,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(FieldSpacing.md),
      decoration: SupplierTheme.cardDecoration(),
      child: Row(
        children: [
          Expanded(
            child: _MiniStat(
              value: CurrencyFormatter.formatPKR(grossSales),
              label: 'Gross sales',
            ),
          ),
          Expanded(
            child: _MiniStat(
              value: CurrencyFormatter.formatPKR(netEarnings),
              label: 'Net payout',
            ),
          ),
          Expanded(
            child: _MiniStat(
              value: CurrencyFormatter.formatPKR(totalPaid),
              label: 'Commission paid',
              valueColor: FieldColors.statusSuccess,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String value;
  final String label;
  final Color? valueColor;

  const _MiniStat({
    required this.value,
    required this.label,
    this.valueColor,
  });

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
            color: valueColor ?? FieldColors.primaryNavy,
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: AppTextStyles.caption.copyWith(fontSize: 11)),
      ],
    );
  }
}

class _HistorySegment extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  const _HistorySegment({
    required this.selectedIndex,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: FieldColors.borderSubtle.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(FieldRadius.button),
      ),
      child: Row(
        children: [
          Expanded(
            child: _SegmentChip(
              label: 'Orders',
              selected: selectedIndex == 0,
              onTap: () => onChanged(0),
            ),
          ),
          Expanded(
            child: _SegmentChip(
              label: 'Payment proofs',
              selected: selectedIndex == 1,
              onTap: () => onChanged(1),
            ),
          ),
        ],
      ),
    );
  }
}

class _SegmentChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SegmentChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? FieldColors.surfaceWhite : Colors.transparent,
      borderRadius: BorderRadius.circular(FieldRadius.button - 2),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(FieldRadius.button - 2),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: AppTextStyles.caption.copyWith(
              fontWeight: FontWeight.w700,
              color: selected ? FieldColors.primaryNavy : FieldColors.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}

class _OrderCommissionCard extends StatelessWidget {
  final TransactionModel transaction;
  final bool isSelected;
  final bool isSelectionMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _OrderCommissionCard({
    required this.transaction,
    this.isSelected = false,
    this.isSelectionMode = false,
    required this.onTap,
    required this.onLongPress,
  });

  String get _shortId {
    final id = transaction.orderId;
    if (id.isEmpty) return '—';
    return id.length <= 6 ? id.toUpperCase() : id.substring(id.length - 6).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final settled = transaction.isSettled;
    final status = _chipStyle(
      settled,
      settledLabel: 'Settled',
      pendingLabel: 'Unsettled',
    );

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(FieldRadius.card),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: SupplierTheme.cardDecoration(
          borderColor: isSelected ? FieldColors.accentAmber : null,
        ).copyWith(
          color: isSelected ? FieldColors.accentAmber.withValues(alpha: 0.05) : Colors.white,
        ),
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
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: FieldColors.primaryNavy.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: const Icon(
                Icons.receipt_long_outlined,
                color: FieldColors.primaryNavy,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Order #$_shortId',
                    style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('MMM d, yyyy').format(transaction.createdAt),
                    style: AppTextStyles.caption,
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  CurrencyFormatter.formatPKR(transaction.commissionAmount),
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w700,
                    color: settled
                        ? FieldColors.statusSuccess
                        : FieldColors.statusDanger,
                  ),
                ),
                const SizedBox(height: 4),
                _StatusChip(bg: status.bg, fg: status.fg, label: status.label),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentProofCard extends StatelessWidget {
  final PaymentProofModel payment;
  final VoidCallback? onOpenImage;
  final bool isSelected;
  final bool isSelectionMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _PaymentProofCard({
    required this.payment,
    this.onOpenImage,
    this.isSelected = false,
    this.isSelectionMode = false,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final status = _paymentStatusStyle(payment.status);

    return Material(
      color: isSelected ? FieldColors.accentAmber.withValues(alpha: 0.05) : FieldColors.surfaceWhite,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(FieldRadius.card),
        side: BorderSide(color: isSelected ? FieldColors.accentAmber : FieldColors.borderSubtle, width: isSelected ? 1.5 : 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.all(12),
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
              _ProofThumbnail(imageUrl: payment.screenshotUrl),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      CurrencyFormatter.formatPKR(payment.amount),
                      style: AppTextStyles.body.copyWith(
                        fontWeight: FontWeight.w700,
                        color: FieldColors.primaryNavy,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (payment.method.trim().isNotEmpty) payment.method,
                        DateFormat('MMM d, yyyy').format(payment.createdAt),
                      ].join(' · '),
                      style: AppTextStyles.caption,
                    ),
                    const SizedBox(height: 6),
                    _StatusChip(bg: status.bg, fg: status.fg, label: status.label),
                  ],
                ),
              ),
              if (!isSelectionMode)
                GestureDetector(
                  onTap: onOpenImage,
                  child: Icon(
                    onOpenImage == null
                        ? Icons.image_not_supported_outlined
                        : Icons.zoom_in_outlined,
                    size: 18,
                    color: FieldColors.textMuted,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProofThumbnail extends StatelessWidget {
  final String imageUrl;

  const _ProofThumbnail({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    final url = imageUrl.trim();
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: SizedBox(
        width: 56,
        height: 56,
        child: url.isEmpty
            ? const _ImageFallback(icon: Icons.image_not_supported_outlined)
            : AppNetworkImage(
                url: url,
                fit: BoxFit.cover,
                width: 56,
                height: 56,
                debugLabel: 'proof-thumb',
                loading: const _ImageFallback(
                  icon: Icons.image_outlined,
                  loading: true,
                ),
                fallback: const _ImageFallback(
                  icon: Icons.broken_image_outlined,
                ),
              ),
      ),
    );
  }
}

class _ImageFallback extends StatelessWidget {
  final IconData icon;
  final bool loading;

  const _ImageFallback({
    required this.icon,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: FieldColors.primaryNavy.withValues(alpha: 0.06),
      child: Center(
        child: loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(icon, size: 22, color: FieldColors.textMuted),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final Color bg;
  final Color fg;
  final String label;

  const _StatusChip({
    required this.bg,
    required this.fg,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label,
        style: AppTextStyles.caption.copyWith(
          color: fg,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _FullScreenProofView extends StatelessWidget {
  final String imageUrl;

  const _FullScreenProofView({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: AppNavigation.leading(context, color: Colors.white),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Payment proof'),
      ),
      body: Center(
        child: InteractiveViewer(
          child: AppNetworkImage(
            url: imageUrl,
            fit: BoxFit.contain,
            debugLabel: 'proof-full',
            loading: const CircularProgressIndicator(
              color: FieldColors.accentAmber,
            ),
            fallback: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.broken_image_outlined, color: Colors.white54, size: 48),
                SizedBox(height: 12),
                Text(
                  'Could not load this image',
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

({Color bg, Color fg, String label}) _chipStyle(
  bool positive, {
  required String settledLabel,
  required String pendingLabel,
}) {
  if (positive) {
    return (
      bg: FieldColors.statusSuccess.withValues(alpha: 0.12),
      fg: FieldColors.statusSuccess,
      label: settledLabel,
    );
  }
  return (
    bg: FieldColors.accentAmberSoft,
    fg: FieldColors.statusWarning,
    label: pendingLabel,
  );
}

({Color bg, Color fg, String label}) _paymentStatusStyle(String status) {
  final value = status.toLowerCase();
  if (value.contains('reject')) {
    return (
      bg: FieldColors.statusDanger.withValues(alpha: 0.12),
      fg: FieldColors.statusDanger,
      label: 'Rejected',
    );
  }
  if (value.contains('settle') ||
      value.contains('confirm') ||
      value.contains('approv')) {
    return (
      bg: FieldColors.statusSuccess.withValues(alpha: 0.12),
      fg: FieldColors.statusSuccess,
      label: 'Settled',
    );
  }
  return (
    bg: FieldColors.accentAmberSoft,
    fg: FieldColors.statusWarning,
    label: 'Pending review',
  );
}
