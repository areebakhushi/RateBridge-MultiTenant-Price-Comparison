import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../constants/route_names.dart';
import '../../models/company_model.dart';
import '../../repositories/user_repository.dart';
import '../../services/cloudinary_service.dart';
import '../../theme/ceo_theme.dart';
import '../../theme/field_theme.dart';
import '../../utils/app_navigation.dart';
import '../../utils/chat_image_utils.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/ceo_viewmodel.dart';
import '../../widgets/ceo_nav_bar.dart';
import '../../widgets/field_user_invite_validity_text.dart';
import '../../widgets/profile_layout.dart';

class CeoCompanyProfileView extends StatefulWidget {
  const CeoCompanyProfileView({super.key});

  @override
  State<CeoCompanyProfileView> createState() => _CeoCompanyProfileViewState();
}

class _CeoCompanyProfileViewState extends State<CeoCompanyProfileView> {
  final _thresholdController = TextEditingController();
  final _nameController = TextEditingController();
  final _designationController = TextEditingController();
  String? _lastCompanyId;
  Stream<Map<String, dynamic>>? _statsStream;
  bool _isUploadingImage = false;
  bool _savingCompany = false;

  @override
  void initState() {
    super.initState();
    final company = context.read<CeoViewModel>().company;
    if (company != null) {
      _thresholdController.text =
          company.autoApprovalThreshold.toStringAsFixed(0);
      _nameController.text = company.name;
      _designationController.text = company.designation ?? '';
      _lastCompanyId = company.id;
      _statsStream =
          context.read<CeoViewModel>().watchDashboardStats(company.id);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ceoVM = Provider.of<CeoViewModel>(context);
    final company = ceoVM.company;
    if (company != null && company.id != _lastCompanyId) {
      setState(() {
        _lastCompanyId = company.id;
        _statsStream = ceoVM.watchDashboardStats(company.id);
        _thresholdController.text =
            company.autoApprovalThreshold.toStringAsFixed(0);
        _nameController.text = company.name;
        _designationController.text = company.designation ?? '';
      });
    }
  }

  @override
  void dispose() {
    _thresholdController.dispose();
    _nameController.dispose();
    _designationController.dispose();
    super.dispose();
  }

  String _maskCnic(String? cnic) {
    if (cnic == null || cnic.isEmpty) return 'N/A';
    String digits = cnic.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 13) return cnic;
    return '${digits.substring(0, 5)}-*******-${digits.substring(12)}';
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

  Future<void> _logout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: FieldColors.statusDanger,
            ),
            child: const Text('Log out'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    await context.read<AuthViewModel>().signOut();
    if (context.mounted) {
      context.go(RouteNames.login);
    }
  }

  Future<void> _pickProfileImage() async {
    final source = await ChatImageUtils.showSourceSheet(context);
    if (source == null || !mounted) return;

    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: source,
      maxWidth: 1000,
      imageQuality: 80,
    );

    if (pickedFile == null || !mounted) return;

    setState(() => _isUploadingImage = true);

    try {
      final bytes = await pickedFile.readAsBytes();
      final url = await CloudinaryService.uploadImageBytes(
        bytes: bytes,
        folder: 'ratebridge/profiles',
        filename: 'ceo_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

      if (url != null && mounted) {
        final uid = context.read<AuthViewModel>().user?.uid;
        if (uid != null) {
          await context.read<UserRepository>().updateUserDoc(uid, {
            'profileImageUrl': url,
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile image updated successfully'),
            ),
          );
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to upload image')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  Future<void> _saveCompanyDetails() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Company name is required')),
      );
      return;
    }
    final threshold = double.tryParse(_thresholdController.text.trim()) ?? 0;
    setState(() => _savingCompany = true);
    try {
      await context.read<CeoViewModel>().updateCompanyProfile({
        'name': name,
        'designation': _designationController.text.trim(),
        'autoApprovalThreshold': threshold,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Company details saved')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save: $e')),
      );
    } finally {
      if (mounted) setState(() => _savingCompany = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authVM = context.watch<AuthViewModel>();
    final ceoVM = context.watch<CeoViewModel>();
    final user = authVM.user;
    final company = ceoVM.company;
    final topPadding = MediaQuery.paddingOf(context).top;

    if (company == null) {
      return const Scaffold(
        backgroundColor: FieldColors.screenBackground,
        body: Center(child: CircularProgressIndicator()),
        bottomNavigationBar: CeoNavBar(currentIndex: 5),
      );
    }

    final displayName = user?.name ?? company.ceoFullName ?? 'CEO';
    final imageUrl = (user?.profileImageUrl?.trim().isNotEmpty == true)
        ? user!.profileImageUrl
        : company.logoUrl;

    return RootTabPopScope(
      isHome: false,
      homeRoute: RouteNames.ceoDashboard,
      child: Scaffold(
      backgroundColor: FieldColors.screenBackground,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        leading: AppNavigation.leading(context, color: Colors.white),
        systemOverlayStyle: SystemUiOverlayStyle.light,
        title: Text(
          'My Profile',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<Map<String, dynamic>>(
        stream: _statsStream,
        builder: (context, snapshot) {
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            children: [
              ProfileHeroHeader(
                topPadding: topPadding,
                initials: _initials(displayName),
                name: displayName,
                subtitle: company.name,
                imageUrl: imageUrl,
                isUploadingImage: _isUploadingImage,
                onPickImage: _pickProfileImage,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                child: Column(
                  children: [
                    ProfileSectionCard(
                      title: 'Personal Information',
                      children: [
                        ProfileDetailRow(
                          icon: Icons.person_rounded,
                          label: 'Full Name',
                          value: user?.name ?? company.ceoFullName ?? 'N/A',
                        ),
                        ProfileDetailRow(
                          icon: Icons.badge_outlined,
                          label: 'Designation',
                          value:
                              user?.jobTitle ?? company.designation ?? 'CEO',
                        ),
                        ProfileDetailRow(
                          icon: Icons.credit_card_rounded,
                          label: 'CNIC',
                          value: _maskCnic(user?.cnic ?? company.cnicNumber),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ProfileSectionCard(
                      title: 'Company Information',
                      children: [
                        TextField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: 'Company name',
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _designationController,
                          decoration: const InputDecoration(
                            labelText: 'Your designation',
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _thresholdController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Auto-approval threshold (Rs)',
                            helperText:
                                'Orders at or below this amount skip CEO approval',
                          ),
                        ),
                        ProfileDetailRow(
                          icon: Icons.app_registration_rounded,
                          label: 'Registration #',
                          value: company.registrationNumber.isEmpty
                              ? 'Not Provided'
                              : company.registrationNumber,
                        ),
                        ProfileDetailRow(
                          icon: Icons.category_outlined,
                          label: 'Company Type',
                          value: company.companyType ?? 'N/A',
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: _savingCompany ? null : _saveCompanyDetails,
                          child: Text(_savingCompany ? 'Saving…' : 'Save company details'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _VerificationCard(company: company),
                    const SizedBox(height: 12),
                    _SubscriptionCard(company: company),
                    const SizedBox(height: 12),
                    _InviteKeyCard(
                      company: company,
                      onRegenerate: () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Regenerate invite code?'),
                            content: const Text(
                              'The current field-user invite code will stop working immediately.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Keep current'),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('Regenerate'),
                              ),
                            ],
                          ),
                        );
                        if (confirmed != true || !context.mounted) return;
                        await context.read<CeoViewModel>().regenerateInviteCode();
                      },
                    ),
                    const SizedBox(height: 12),
                    ProfileSignOutCard(
                      label: 'Logout Session',
                      onSignOut: () => _logout(context),
                    ),
                    const SizedBox(height: 20),
                    const ProfileVersionFooter(caption: 'Company Portal'),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: const CeoNavBar(currentIndex: 5),
    ),
    );
  }
}

class _VerificationCard extends StatelessWidget {
  final CompanyModel company;

  const _VerificationCard({required this.company});

  @override
  Widget build(BuildContext context) {
    final statusData = CeoTheme.statusColors(company.status);
    final isActive = company.status == 'active';

    return ProfileSectionCard(
      title: 'Verification Status',
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: statusData.bg,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isActive ? Icons.verified_rounded : Icons.pending_rounded,
                color: statusData.fg,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isActive
                        ? 'Verified Account'
                        : 'Account ${company.status.toUpperCase()}',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w700,
                      color: FieldColors.primaryNavy,
                    ),
                  ),
                  Text(
                    isActive
                        ? 'Your business is verified on RateBridge'
                        : 'Awaiting administrator confirmation',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: FieldColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (company.status == 'rejected' &&
            company.rejectionReason != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: FieldColors.statusDanger.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: FieldColors.statusDanger.withValues(alpha: 0.1),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  color: FieldColors.statusDanger,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Reason: ${company.rejectionReason}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: FieldColors.statusDanger,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _SubscriptionCard extends StatelessWidget {
  final CompanyModel company;

  const _SubscriptionCard({required this.company});

  @override
  Widget build(BuildContext context) {
    final plan = company.plan?.toString().toUpperCase() ?? 'FREE';
    final isPremium = company.plan == 'premium';

    return ProfileSectionCard(
      title: 'Subscription Plan',
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: FieldColors.primaryNavy.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isPremium ? Icons.auto_awesome_rounded : Icons.eco_rounded,
                color: FieldColors.accentAmber,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$plan PLAN',
                    style: GoogleFonts.plusJakartaSans(
                      color: FieldColors.primaryNavy,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Text(
                    isPremium ? 'Full Access' : 'Limited Access',
                    style: GoogleFonts.plusJakartaSans(
                      color: FieldColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => context.push(RouteNames.ceoSubscription),
            icon: Icon(
              isPremium ? Icons.settings_rounded : Icons.upgrade_rounded,
              size: 18,
            ),
            label: Text(isPremium ? 'MANAGE PLAN' : 'UPGRADE TO PREMIUM'),
            style: ElevatedButton.styleFrom(
              backgroundColor: FieldColors.accentAmber,
              foregroundColor: FieldColors.primaryNavy,
              elevation: 0,
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(FieldRadius.button),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _InviteKeyCard extends StatelessWidget {
  final CompanyModel company;
  final VoidCallback onRegenerate;

  const _InviteKeyCard({
    required this.company,
    required this.onRegenerate,
  });

  @override
  Widget build(BuildContext context) {
    return ProfileSectionCard(
      title: 'Team Access',
      children: [
        Text(
          'Field User Invite Code',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: FieldColors.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: FieldColors.screenBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: FieldColors.borderSubtle),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  company.inviteCode ?? 'RB-XXXXXX',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: FieldColors.primaryNavy,
                    letterSpacing: 2,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.content_copy_rounded,
                  size: 20,
                  color: FieldColors.primaryNavy,
                ),
                onPressed: () {
                  Clipboard.setData(
                    ClipboardData(text: company.inviteCode ?? ''),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Code copied to clipboard')),
                  );
                },
                tooltip: 'Copy',
              ),
              IconButton(
                icon: const Icon(
                  Icons.share_rounded,
                  size: 20,
                  color: FieldColors.primaryNavy,
                ),
                onPressed: () => Share.share(
                  'Join our construction team on RateBridge using this invite code: ${company.inviteCode}',
                ),
                tooltip: 'Share',
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        FieldUserInviteValidityText(
          generatedAt: company.inviteCodeGeneratedAt,
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: onRegenerate,
            child: const Text('Regenerate code'),
          ),
        ),
        Text(
          'Share this code with your field engineers to link them to your company.',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            color: FieldColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
