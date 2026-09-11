import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../viewmodels/admin_viewmodel.dart';
import '../../theme/admin_theme.dart';
import '../../widgets/admin/admin_widgets.dart';

class AdminAppealsView extends StatefulWidget {
  const AdminAppealsView({super.key});

  @override
  State<AdminAppealsView> createState() => _AdminAppealsViewState();
}

class _AdminAppealsViewState extends State<AdminAppealsView> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdminColors.screenBg,
      appBar: AdminAppBar(
        title: 'Account Appeals',
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AdminColors.amber,
          tabs: const [
            Tab(text: 'Pending'),
            Tab(text: 'Accepted'),
            Tab(text: 'Rejected'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAppealList('pending'),
          _buildAppealList('accepted'),
          _buildAppealList('rejected'),
        ],
      ),
    );
  }

  Widget _buildAppealList(String status) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('appeals')
          .where('status', isEqualTo: status)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return AdminEmptyState(
            icon: Icons.history_edu_rounded,
            message: 'No $status appeals found.',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            return _AppealCard(appeal: data, appealId: doc.id);
          },
        );
      },
    );
  }
}

class _AppealCard extends StatelessWidget {
  final Map<String, dynamic> appeal;
  final String appealId;

  const _AppealCard({required this.appeal, required this.appealId});

  @override
  Widget build(BuildContext context) {
    final adminVM = Provider.of<AdminViewModel>(context, listen: false);
    final status = appeal['status'] ?? 'pending';
    final role = appeal['role'] ?? 'User';
    final name = appeal['name'] ?? 'Unknown';
    final createdAt = (appeal['createdAt'] as Timestamp?)?.toDate();

    return AdminCard(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: role == 'CEO' ? AdminColors.navy.withValues(alpha: 0.1) : AdminColors.amber.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  role.toUpperCase(),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: role == 'CEO' ? AdminColors.navy : AdminColors.darkAmber,
                  ),
                ),
              ),
              const Spacer(),
              if (createdAt != null)
                Text(
                  DateFormat('MMM dd, yyyy').format(createdAt),
                  style: AdminTheme.mutedStyle(size: 12),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(name, style: AdminTheme.titleStyle(size: 18)),
          const SizedBox(height: 8),
          _DetailRow(label: 'Original Rejection Reason', value: appeal['rejectionReason'] ?? 'None'),
          const Divider(height: 24),
          Text('APPEAL MESSAGE', style: AdminTheme.sectionHeaderStyle().copyWith(fontSize: 11)),
          const SizedBox(height: 8),
          Text(
            appeal['message'] ?? 'No message provided.',
            style: AdminTheme.bodyStyle(),
          ),
          if (appeal['phone'] != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.phone_outlined, size: 14, color: AdminColors.textGrey),
                const SizedBox(width: 6),
                Text(appeal['phone'], style: AdminTheme.mutedStyle(size: 13)),
              ],
            ),
          ],
          if (appeal['imageUrl'] != null) ...[
            const SizedBox(height: 16),
            InkWell(
              onTap: () => _showImageDialog(context, appeal['imageUrl']),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  appeal['imageUrl'],
                  height: 120,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 120,
                    color: Colors.grey.shade100,
                    child: const Icon(Icons.broken_image_outlined, color: Colors.grey),
                  ),
                ),
              ),
            ),
          ],
          if (status == 'pending') ...[
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _showConfirmDialog(context, 'Accept Appeal', 'This will restore the account to active status.', () => adminVM.acceptAppeal(appeal, appealId)),
                    style: AdminTheme.primaryButtonStyle(height: 44),
                    child: const Text('ACCEPT APPEAL'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _showRejectDialog(context, adminVM, appeal, appealId),
                    style: AdminTheme.destructiveButtonStyle(height: 44),
                    child: const Text('REJECT'),
                  ),
                ),
              ],
            ),
          ] else ...[
            const Divider(height: 32),
            Row(
              children: [
                Icon(
                  status == 'accepted' ? Icons.check_circle_outline : Icons.cancel_outlined,
                  size: 16,
                  color: status == 'accepted' ? Colors.green : AdminColors.red,
                ),
                const SizedBox(width: 8),
                Text(
                  'Decision: ${status.toUpperCase()}',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.bold,
                    color: status == 'accepted' ? Colors.green : AdminColors.red,
                  ),
                ),
              ],
            ),
            if (appeal['adminResponse'] != null) ...[
              const SizedBox(height: 8),
              Text(
                'Admin Response: ${appeal['adminResponse']}',
                style: AdminTheme.mutedStyle(size: 13),
              ),
            ],
          ],
        ],
      ),
    );
  }

  void _showImageDialog(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: const Text('Document View'),
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              leading: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ),
            InteractiveViewer(child: Image.network(url)),
          ],
        ),
      ),
    );
  }

  void _showConfirmDialog(BuildContext context, String title, String message, Future<void> Function() action) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await action();
            },
            child: const Text('CONFIRM', style: TextStyle(fontWeight: FontWeight.bold, color: AdminColors.navy)),
          ),
        ],
      ),
    );
  }

  void _showRejectDialog(BuildContext context, AdminViewModel adminVM, Map<String, dynamic> appeal, String appealId) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Appeal'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Reason for rejection'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          TextButton(
            onPressed: () async {
              if (controller.text.trim().isEmpty) return;
              Navigator.pop(context);
              await adminVM.rejectAppeal(appeal, appealId, controller.text.trim());
            },
            child: const Text('REJECT APPEAL', style: TextStyle(fontWeight: FontWeight.bold, color: AdminColors.red)),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AdminTheme.mutedStyle(size: 11).copyWith(fontWeight: FontWeight.bold)),
          Text(value, style: AdminTheme.bodyStyle().copyWith(fontSize: 13)),
        ],
      ),
    );
  }
}
