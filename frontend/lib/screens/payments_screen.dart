import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/payment_model.dart';
import '../services/payment_service.dart';
import '../providers/auth_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:url_launcher/url_launcher.dart';
import '../platform_io.dart';
import 'package:http/http.dart' as http;
import '../config/theme.dart';

class PaymentsScreen extends ConsumerStatefulWidget {
  const PaymentsScreen({super.key});

  @override
  ConsumerState<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends ConsumerState<PaymentsScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ref.watch(currentUserProvider).when(
      data: (user) {
        if (user == null) {
          return const Scaffold(body: Center(child: Text('Please login to view payments')));
        }

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            flexibleSpace: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primaryDark, AppColors.primary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            title: const Text(
              '💰 My Payments',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
            ),
            iconTheme: const IconThemeData(color: Colors.white),
            elevation: 0,
          ),
          body: FadeTransition(
            opacity: _fadeAnim,
            child: SlideTransition(
              position: _slideAnim,
              child: _DuePaymentsTab(userId: user.uid),
            ),
          ),
        );
      },
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stack) => Scaffold(body: Center(child: Text('Error: $error'))),
    );
  }
}

class _DuePaymentsTab extends ConsumerWidget {
  final String userId;
  const _DuePaymentsTab({required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return StreamBuilder<List<PaymentModel>>(
      stream: ref.watch(paymentServiceProvider).getDuePayments(userId),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final payments = snapshot.data ?? [];

        return Column(
          children: [
            // Balance banner
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('studentBalance')
                  .doc(userId)
                  .snapshots(),
              builder: (context, balSnap) {
                if (!balSnap.hasData || !balSnap.data!.exists) return const SizedBox.shrink();
                final data = balSnap.data!.data() as Map<String, dynamic>;
                final remaining = ((data['remainingBalance'] as num?) ?? 0).toDouble();
                final credit = ((data['creditBalance'] as num?) ?? 0).toDouble();
                if (remaining <= 0 && credit <= 0) return const SizedBox.shrink();

                final isDebt = remaining > 0;
                return Container(
                  margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDebt
                          ? [const Color(0xFFDC2626), const Color(0xFFEF4444)]
                          : [const Color(0xFF059669), const Color(0xFF10B981)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: (isDebt ? Colors.red : Colors.green).withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Text(isDebt ? '⚠️' : '💚', style: const TextStyle(fontSize: 24)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: isDebt
                            ? Text(
                                'Pending Balance: Rs. ${remaining.toStringAsFixed(0)}\nPlease pay the remaining amount.',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, height: 1.5),
                              )
                            : Text(
                                'Credit Balance: Rs. ${credit.toStringAsFixed(0)}\nWill be deducted from your next challan.',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, height: 1.5),
                              ),
                      ),
                    ],
                  ),
                );
              },
            ),

            if (payments.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('✅', style: TextStyle(fontSize: 56)),
                      const SizedBox(height: 16),
                      const Text('No due payments', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                      const SizedBox(height: 6),
                      const Text('You are all caught up!', style: TextStyle(color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: payments.length,
                  itemBuilder: (context, index) => PaymentCard(payment: payments[index]),
                ),
              ),
          ],
        );
      },
    );
  }
}

Future<void> _viewChallan(BuildContext context, String challanUrl) async {
  try {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );
    final response = await http.get(Uri.parse(challanUrl));
    if (!context.mounted) return;
    Navigator.of(context).pop();

    if (response.statusCode == 200) {
      final challanText = response.body;
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Fee Challan'),
            content: SingleChildScrollView(
              child: SelectableText(challanText, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
            ),
            actions: [
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text('Close', style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.w600, fontSize: 14)),
                ),
              ),
              GestureDetector(
                onTap: () async {
                  final url = Uri.parse(challanUrl);
                  if (await canLaunchUrl(url)) await launchUrl(url, mode: LaunchMode.externalApplication);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text('Open in Browser', style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.w600, fontSize: 14)),
                ),
              ),
            ],
          ),
        );
      }
    } else {
      final url = Uri.parse(challanUrl);
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not load challan. Please try again later.')));
        }
      }
    }
  } catch (e) {
    if (!context.mounted) return;
    Navigator.of(context).pop();
    try {
      final url = Uri.parse(challanUrl);
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading challan: $e')));
      }
    } catch (e2) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error opening challan: $e2')));
    }
  }
}

class PaymentCard extends StatelessWidget {
  final PaymentModel payment;
  const PaymentCard({super.key, required this.payment});

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'en_US', symbol: 'Rs. ');

    Color statusColor;
    String statusEmoji;
    switch (payment.status) {
      case PaymentStatus.completed:
        statusColor = AppColors.success;
        statusEmoji = '✅';
        break;
      case PaymentStatus.pending:
        statusColor = AppColors.warning;
        statusEmoji = '⏳';
        break;
      case PaymentStatus.failed:
        statusColor = AppColors.error;
        statusEmoji = '❌';
        break;
      case PaymentStatus.refunded:
        statusColor = AppColors.info;
        statusEmoji = '🔄';
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: AppColors.primary.withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, 4)),
        ],
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('💰', style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    payment.description,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.textPrimary),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(statusEmoji, style: const TextStyle(fontSize: 12)),
                      const SizedBox(width: 4),
                      Text(
                        payment.status.toString().split('.').last,
                        style: TextStyle(color: statusColor, fontWeight: FontWeight.w700, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                const Icon(Icons.calendar_today_outlined, size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Text(
                  'Due: ${DateFormat('MMM dd, yyyy').format(payment.dueDate)}',
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
                const Spacer(),
                Text(
                  currencyFormat.format(payment.amount),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.primary),
                ),
              ],
            ),

            if ((payment.type == PaymentType.hostelFee ||
                    payment.type == PaymentType.messFee ||
                    payment.type == PaymentType.gymFee) &&
                payment.bankName != null &&
                payment.accountNumber != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Text('🏦', style: TextStyle(fontSize: 14)),
                        SizedBox(width: 6),
                        Text('Payment Details', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textPrimary)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('Bank: ${payment.bankName}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    Text('Account No: ${payment.accountNumber}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    if (payment.accountTitle != null)
                      Text('Account Title: ${payment.accountTitle}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ],

            if (payment.challanUrl != null) ...[
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () async => await _viewChallan(context, payment.challanUrl!),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryLight]),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.receipt_long, color: Colors.white, size: 18),
                      SizedBox(width: 8),
                      Text('📄 View Challan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                    ],
                  ),
                ),
              ),
            ],

            if ((payment.type == PaymentType.hostelFee ||
                    payment.type == PaymentType.messFee ||
                    payment.type == PaymentType.gymFee) &&
                payment.status == PaymentStatus.pending) ...[
              const SizedBox(height: 10),
              _UploadChallanButton(payment: payment),
            ],
          ],
        ),
      ),
    );
  }
}

class _UploadChallanButton extends ConsumerStatefulWidget {
  final PaymentModel payment;
  const _UploadChallanButton({required this.payment});

  @override
  ConsumerState<_UploadChallanButton> createState() => _UploadChallanButtonState();
}

class _UploadChallanButtonState extends ConsumerState<_UploadChallanButton> {
  bool _uploading = false;

  Future<void> _pickAndUpload() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked == null) return;

    double? amountOverride;
    if (widget.payment.type == PaymentType.messFee) {
      final controller = TextEditingController(text: widget.payment.amount.toStringAsFixed(0));
      amountOverride = await showDialog<double>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Confirm Payment Amount'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Enter the actual amount you have paid as shown on your challan.'),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Paid Amount (Rs.)', border: OutlineInputBorder(), prefixText: 'Rs. '),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                final val = double.tryParse(controller.text);
                if (val != null && val > 0) {
                  Navigator.pop(context, val);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a valid amount')));
                }
              },
              child: const Text('Confirm & Upload'),
            ),
          ],
        ),
      );
      if (amountOverride == null) return;
    }

    setState(() => _uploading = true);
    try {
      Object file;
      if (kIsWeb) {
        file = picked;
      } else {
        file = File(picked.path);
      }
      final paymentId = widget.payment.id;
      final userId = widget.payment.userId;
      final applicationId = widget.payment.metadata?.containsKey('applicationId') == true
          ? widget.payment.metadata!['applicationId'] as String?
          : null;

      await ref.read(paymentServiceProvider).uploadFeeChallanProof(
            paymentId: paymentId,
            userId: userId,
            applicationId: applicationId,
            imageFile: file,
            paidAmount: amountOverride,
          );

      if (!mounted) return;
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Challan uploaded — awaiting admin confirmation')));
    } catch (e) {
      debugPrint('[PaymentsScreen] Challan upload failed: $e');
      if (!mounted) return;
      if (mounted) {
        String errorMsg = e.toString();
        if (errorMsg.startsWith('Exception: ')) errorMsg = errorMsg.substring('Exception: '.length);
        while (errorMsg.startsWith('Exception: ')) errorMsg = errorMsg.substring('Exception: '.length);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to upload challan: $errorMsg')));
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _uploading ? null : _pickAndUpload,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: _uploading
                ? [AppColors.primary.withValues(alpha: 0.5), AppColors.primaryLight.withValues(alpha: 0.5)]
                : const [AppColors.primary, AppColors.primaryLight],
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_uploading)
              const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            else
              const Icon(Icons.upload_file, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(
              _uploading ? 'Uploading...' : '📤 Upload Challan',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
