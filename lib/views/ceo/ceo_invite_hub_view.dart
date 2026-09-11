import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../../constants/route_names.dart';
import '../../theme/ceo_theme.dart';
import '../../utils/app_navigation.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/invite_viewmodel.dart';
import '../../viewmodels/ceo_viewmodel.dart';
import '../../widgets/ceo_nav_bar.dart';
import '../../widgets/ceo/ceo_widgets.dart';

class CeoInviteHubView extends StatefulWidget {
  const CeoInviteHubView({super.key});

  @override
  State<CeoInviteHubView> createState() => _CeoInviteHubViewState();
}

class _CeoInviteHubViewState extends State<CeoInviteHubView> {
  final _emailController = TextEditingController();
  bool _isSending = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendInvite() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) return;

    setState(() => _isSending = true);
    try {
      final inviteVM = context.read<InviteViewModel>();
      final authVM = context.read<AuthViewModel>();
      final ceoVM = context.read<CeoViewModel>();

      final companyId = authVM.user?.companyId ?? '';
      final ceoUid = authVM.user?.uid ?? '';
      final companyName = ceoVM.company?.name ?? 'Company';

      await inviteVM.sendSupplierInvite(
        email: email,
        companyId: companyId,
        ceoUid: ceoUid,
        companyName: companyName,
      );
      
      if (mounted) {
        _emailController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invite sent successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RootTabPopScope(
      isHome: false,
      homeRoute: RouteNames.ceoDashboard,
      child: Scaffold(
      backgroundColor: CeoColors.screenBg,
      appBar: const CeoAppBar(title: 'Marketplace & Invites'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _MarketplaceCard(
              onTap: () => context.push(RouteNames.ceoMarketplace),
            ),
            const SizedBox(height: 24),
            const CeoSectionLabel('Direct Invitation'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: CeoTheme.cardDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Invite a Supplier',
                    style: CeoTheme.titleStyle(size: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Invite a supplier you already work with by entering their email address.',
                    style: CeoTheme.mutedStyle(size: 13),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: CeoTheme.inputDecoration(
                      hintText: 'supplier@email.com',
                      prefixIcon: const Icon(Icons.email_outlined),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _isSending ? null : _sendInvite,
                    style: CeoTheme.primaryButtonStyle(height: 48),
                    child: Text(_isSending ? 'SENDING...' : 'SEND INVITE'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const CeoNavBar(currentIndex: 2),
    ),
    );
  }
}

class _MarketplaceCard extends StatelessWidget {
  final VoidCallback onTap;
  const _MarketplaceCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [CeoColors.navy, Color(0xFF1A2A4D)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: CeoColors.navy.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.storefront_rounded,
                    color: CeoColors.amber, size: 28),
              ),
              const SizedBox(height: 16),
              Text(
                'Supplier Marketplace',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Browse and connect with verified suppliers across Pakistan.',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white70,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Text(
                    'EXPLORE NOW',
                    style: GoogleFonts.plusJakartaSans(
                      color: CeoColors.amber,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward_rounded,
                      color: CeoColors.amber, size: 16),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
