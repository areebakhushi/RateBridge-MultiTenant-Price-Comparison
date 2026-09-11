// MVVM: View — no business logic
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/ceo_viewmodel.dart';
import '../../models/user_model.dart';
import '../../theme/ceo_theme.dart';
import '../../constants/route_names.dart';
import 'package:intl/intl.dart';

class CeoPendingView extends StatefulWidget {
  const CeoPendingView({super.key});

  @override
  State<CeoPendingView> createState() => _CeoPendingViewState();
}

class _CeoPendingViewState extends State<CeoPendingView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CeoViewModel>().watchCeoStatus();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<AuthViewModel, CeoViewModel>(
      builder: (context, authVM, ceoVM, child) {
        final user = authVM.user;

        if (user?.status == 'active') {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) context.go(RouteNames.ceoDashboard);
          });
        }

        return Scaffold(
          backgroundColor: CeoColors.screenBg,
          body: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('appeals')
                .where('uid', isEqualTo: user?.uid)
                .where('status', isEqualTo: 'pending')
                .limit(1)
                .snapshots(),
            builder: (context, appealSnap) {
              final hasPendingAppeal = appealSnap.hasData && appealSnap.data!.docs.isNotEmpty;

              return SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: user?.status == 'rejected'
                      ? (hasPendingAppeal ? _buildAppealPendingState(context, authVM) : _buildRejectedState(context, authVM, user!))
                      : _buildPendingState(context, authVM, user),
                ),
              );
            }
          ),
        );
      },
    );
  }

  Widget _buildPendingState(
    BuildContext context,
    AuthViewModel authVM,
    UserModel? user,
  ) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Spacer(),
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: CeoColors.amber.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.hourglass_empty_rounded,
            size: 56,
            color: CeoColors.amber,
          ),
        ),
        const SizedBox(height: 32),
        Text(
          'Application Under Review',
          style: CeoTheme.titleStyle(size: 24),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Text(
          'Your company registration is under review.',
          textAlign: TextAlign.center,
          style: CeoTheme.mutedStyle(size: 15).copyWith(height: 1.6),
        ),
        const SizedBox(height: 32),
        if (user != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: CeoTheme.cardDecoration().copyWith(
              border: Border.all(color: CeoColors.amber.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: CeoColors.amber,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Status: Pending Admin Approval',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w600,
                        color: CeoColors.darkAmber,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _infoRow('Name', user.name),
                _infoRow('Email', user.email),
                _infoRow(
                  'Submitted',
                  DateFormat('MMM dd, yyyy').format(user.createdAt),
                ),
              ],
            ),
          ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Text(
              'Waiting for admin review...',
              style: CeoTheme.mutedStyle(size: 13),
            ),
          ],
        ),
        const Spacer(),
        _signOutButton(context, authVM),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildRejectedState(
    BuildContext context,
    AuthViewModel authVM,
    UserModel user,
  ) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Spacer(),
        const Icon(Icons.cancel_rounded, size: 80, color: CeoColors.red),
        const SizedBox(height: 24),
        Text(
          'Registration Rejected',
          style: CeoTheme.titleStyle(size: 24),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: CeoColors.red.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: CeoColors.red.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'REASON:',
                style: TextStyle(fontWeight: FontWeight.bold, color: CeoColors.red, fontSize: 12),
              ),
              const SizedBox(height: 4),
              Text(
                user.rejectionReason ??
                    'Information provided was insufficient for verification.',
                style: GoogleFonts.plusJakartaSans(color: CeoColors.red),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        ElevatedButton(
          onPressed: () {
            context.read<CeoViewModel>().clearAppealState();
            context.push(RouteNames.ceoAppeal);
          },
          style: CeoTheme.primaryButtonStyle(height: 56),
          child: const Text('SUBMIT APPEAL', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
        const Spacer(),
        _signOutButton(context, authVM),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildAppealPendingState(BuildContext context, AuthViewModel authVM) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Spacer(),
        const Icon(Icons.hourglass_top_rounded, size: 80, color: CeoColors.amber),
        const SizedBox(height: 24),
        Text(
          'Appeal Under Review',
          style: CeoTheme.titleStyle(size: 24),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Text(
          'Your appeal has been submitted and is currently being reviewed by our administration. Please check back later.',
          textAlign: TextAlign.center,
          style: CeoTheme.mutedStyle(size: 15).copyWith(height: 1.6),
        ),
        const Spacer(),
        _signOutButton(context, authVM),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _signOutButton(BuildContext context, AuthViewModel authVM) {
    return OutlinedButton.icon(
      onPressed: () async {
        await authVM.signOut();
        if (context.mounted) context.go(RouteNames.login);
      },
      style: CeoTheme.destructiveButtonStyle(height: 44),
      icon: const Icon(Icons.logout, size: 18),
      label: const Text('Sign Out'),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Text('$label: ', style: CeoTheme.mutedStyle(size: 13)),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w500,
              fontSize: 13,
              color: CeoColors.navy,
            ),
          ),
        ],
      ),
    );
  }
}
