import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../viewmodels/ceo_viewmodel.dart';
import '../../theme/ceo_theme.dart';

class CeoAppealView extends StatefulWidget {
  const CeoAppealView({super.key});

  @override
  State<CeoAppealView> createState() => _CeoAppealViewState();
}

class _CeoAppealViewState extends State<CeoAppealView> {
  final _formKey = GlobalKey<FormState>();
  final _messageController = TextEditingController();
  final _phoneController = TextEditingController();
  File? _selectedFile;

  Future<void> _pickDocument() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _selectedFile = File(image.path);
      });
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<CeoViewModel>(context);

    return Scaffold(
      backgroundColor: CeoColors.screenBg,
      appBar: AppBar(
        title: const Text('Submit Appeal'),
        backgroundColor: CeoColors.navy,
        foregroundColor: Colors.white,
      ),
      body: viewModel.appealSubmitted 
        ? _buildSuccessCard()
        : Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: CeoTheme.cardDecoration(),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: CeoColors.navy),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'One appeal per rejection cycle only. Please provide clear evidence or clarification regarding your business registration.',
                          style: TextStyle(fontSize: 13, color: Colors.black54),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _messageController,
                  maxLines: 6,
                  decoration: CeoTheme.inputDecoration(
                    labelText: 'Appeal Message',
                    hintText: 'Describe why your account should be reconsidered...',
                  ),
                  validator: (v) => (v == null || v.length < 50) ? 'Please enter at least 50 characters' : null,
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _phoneController,
                  decoration: CeoTheme.inputDecoration(
                    labelText: 'Contact Phone (Optional)',
                    hintText: 'Enter phone number',
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 32),
                const Text('SUPPORTING DOCUMENT', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black54)),
                const SizedBox(height: 12),
                InkWell(
                  onTap: _pickDocument,
                  child: Container(
                    height: 150,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
                    ),
                    child: _selectedFile == null
                        ? const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.cloud_upload_outlined, size: 40, color: Colors.grey),
                              SizedBox(height: 8),
                              Text('Tap to upload proof/license', style: TextStyle(color: Colors.grey)),
                            ],
                          )
                        : Stack(
                            fit: StackFit.expand,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.file(_selectedFile!, fit: BoxFit.cover),
                              ),
                              Positioned(
                                right: 8,
                                top: 8,
                                child: CircleAvatar(
                                  backgroundColor: CeoColors.red,
                                  radius: 14,
                                  child: IconButton(
                                    icon: const Icon(Icons.close, size: 14, color: Colors.white),
                                    onPressed: () => setState(() => _selectedFile = null),
                                  ),
                                ),
                              )
                            ],
                          ),
                  ),
                ),
                if (viewModel.errorMessage != null) ...[
                  const SizedBox(height: 20),
                  Text(
                    viewModel.errorMessage!,
                    style: const TextStyle(color: CeoColors.red, fontSize: 14),
                  ),
                ],
                const SizedBox(height: 48),
                ElevatedButton(
                  onPressed: viewModel.isLoading ? null : () async {
                    if (_formKey.currentState!.validate()) {
                      await viewModel.submitAppeal(
                        _messageController.text,
                        _selectedFile,
                        _phoneController.text.isEmpty ? null : _phoneController.text,
                      );
                    }
                  },
                  style: CeoTheme.primaryButtonStyle(height: 50),
                  child: viewModel.isLoading 
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('SUBMIT APPEAL', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
    );
  }

  Widget _buildSuccessCard() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle_outline, size: 80, color: Colors.green),
            const SizedBox(height: 24),
            const Text(
              'Appeal Submitted',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'Your appeal has been received and added to our review queue. We will notify you once a decision is made.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54, fontSize: 16),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: CeoTheme.primaryButtonStyle(height: 50),
                child: const Text('BACK TO STATUS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
