// MVVM: View — no business logic
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../viewmodels/supplier_viewmodel.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../theme/supplier_theme.dart';
import '../../constants/route_names.dart';
import 'package:intl/intl.dart';

class SupplierPendingView extends StatelessWidget {
  const SupplierPendingView({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SupplierViewModel>(
      builder: (context, viewModel, child) {
        if (viewModel.status == 'active') {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.go(RouteNames.supplierDashboard);
          });
        }

        return Scaffold(
          backgroundColor: FieldColors.screenBackground,
          body: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('appeals')
                .where('uid', isEqualTo: viewModel.supplierUid)
                .where('status', isEqualTo: 'pending')
                .limit(1)
                .snapshots(),
            builder: (context, appealSnap) {
              final hasPendingAppeal = appealSnap.hasData && appealSnap.data!.docs.isNotEmpty;

              return Padding(
                padding: const EdgeInsets.all(32.0),
                child: viewModel.status == 'rejected'
                    ? (hasPendingAppeal ? _buildAppealPendingState(context, viewModel) : _buildRejectedState(context, viewModel))
                    : _buildPendingState(context, viewModel),
              );
            }
          ),
        );
      },
    );
  }

  Widget _buildPendingState(BuildContext context, SupplierViewModel viewModel) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.access_time_filled_rounded,
          size: 80,
          color: FieldColors.accentAmber,
        ),
        const SizedBox(height: 24),
        Text(
          'Account Under Review',
          style: FieldTypography.headlineMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Text(
          'Your supplier application is under review. You\'ll be notified once approved.',
          textAlign: TextAlign.center,
          style: FieldTypography.bodyLarge.copyWith(color: FieldColors.textSecondary),
        ),
        const SizedBox(height: 32),
        if (viewModel.profile != null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Text('Submitted: ${DateFormat('MMM dd, yyyy').format(viewModel.profile!.createdAt)}',
                      style: const TextStyle(color: FieldColors.textSecondary)),
                ],
              ),
            ),
          ),
        const SizedBox(height: 40),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () => viewModel.loadProfile(),
            child: const Text('Refresh Status'),
          ),
        ),
        TextButton(
          onPressed: () async {
            await context.read<AuthViewModel>().signOut();
            if (context.mounted) {
              context.go(RouteNames.roleSelection);
            }
          },
          child: const Text('Sign Out', style: TextStyle(color: FieldColors.statusDanger)),
        ),
      ],
    );
  }

  Widget _buildRejectedState(BuildContext context, SupplierViewModel viewModel) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.cancel_rounded, size: 80, color: FieldColors.statusDanger),
        const SizedBox(height: 24),
        Text(
          'Registration Rejected',
          style: FieldTypography.headlineMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: FieldColors.statusDanger.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(FieldRadius.card),
            border: Border.all(color: FieldColors.statusDanger.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('REASON:', style: TextStyle(fontWeight: FontWeight.bold, color: FieldColors.statusDanger, fontSize: 12)),
              const SizedBox(height: 4),
              Text(viewModel.rejectionReason ?? 'Information provided was insufficient for verification.',
                  style: const TextStyle(color: FieldColors.statusDanger)),
            ],
          ),
        ),
        const SizedBox(height: 32),
        ElevatedButton(
          onPressed: () {
            viewModel.clearAppealState();
            context.push(RouteNames.supplierAppeal);
          },
          style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 56)),
          child: const Text('SUBMIT APPEAL'),
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: () async {
            await context.read<AuthViewModel>().signOut();
            if (context.mounted) {
              context.go(RouteNames.roleSelection);
            }
          },
          child: const Text('Sign Out', style: TextStyle(color: FieldColors.statusDanger)),
        ),
      ],
    );
  }

  Widget _buildAppealPendingState(BuildContext context, SupplierViewModel viewModel) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.hourglass_top_rounded, size: 80, color: FieldColors.accentAmber),
        const SizedBox(height: 24),
        Text(
          'Appeal Under Review',
          style: FieldTypography.headlineMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Text(
          'Your appeal has been submitted and is currently being reviewed by our administration. Please check back later.',
          textAlign: TextAlign.center,
          style: FieldTypography.bodyLarge.copyWith(color: FieldColors.textSecondary),
        ),
        const SizedBox(height: 40),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () => viewModel.loadProfile(),
            child: const Text('Refresh Status'),
          ),
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: () async {
            await context.read<AuthViewModel>().signOut();
            if (context.mounted) {
              context.go(RouteNames.roleSelection);
            }
          },
          child: const Text('Sign Out', style: TextStyle(color: FieldColors.statusDanger)),
        ),
      ],
    );
  }
}
