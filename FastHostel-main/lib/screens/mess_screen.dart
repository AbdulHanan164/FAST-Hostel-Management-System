import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/mess_service.dart';
import '../models/mess_model.dart';
import '../models/mess_bill_model.dart';
import '../models/payment_model.dart';
import '../providers/auth_provider.dart';
import '../config/theme.dart';

class MessScreen extends ConsumerStatefulWidget {
  const MessScreen({super.key});

  @override
  ConsumerState<MessScreen> createState() => _MessScreenState();
}

class _MessScreenState extends ConsumerState<MessScreen> {

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mess Schedule'),
      ),
      body: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            const TabBar(
              tabs: [
                Tab(text: 'Schedule'),
                Tab(text: 'My Bill'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  // ── Schedule Tab ───────────────────────────────────────
                  StreamBuilder<List<MessMenu>>(
                    stream: ref.watch(messServiceProvider).getCurrentWeekMenu(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (snapshot.hasError) {
                        return Center(child: Text('Error: ${snapshot.error}'));
                      }

                      final menus = snapshot.data ?? [];
                      if (menus.isEmpty) {
                        return const Center(
                          child: Text('No mess menu has been set for this week yet.'),
                        );
                      }

                      menus.sort((a, b) => a.date.compareTo(b.date));

                      return ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: menus.length,
                        itemBuilder: (context, index) {
                          final menu = menus[index];
                          final dateLabel =
                              DateFormat('EEEE, MMM d').format(menu.date);

                          return Card(
                            margin: const EdgeInsets.only(bottom: 16),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    dateLabel,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.primaryColor,
                                        ),
                                  ),
                                  const SizedBox(height: 8),
                                  _DayMealSection(
                                    type: MealType.breakfast,
                                    items: menu.meals[MealType.breakfast] ?? const [],
                                  ),
                                  _DayMealSection(
                                    type: MealType.lunch,
                                    items: menu.meals[MealType.lunch] ?? const [],
                                  ),
                                  _DayMealSection(
                                    type: MealType.dinner,
                                    items: menu.meals[MealType.dinner] ?? const [],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),

                  // ── My Bill Tab ────────────────────────────────────────
                  Consumer(
                    builder: (context, ref, child) {
                      final user = ref.watch(currentUserProvider).value;
                      if (user == null) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      return _MessBillingTab(userId: user.uid);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── My Bill Tab ──────────────────────────────────────────────────────────────

class _MessBillingTab extends ConsumerWidget {
  const _MessBillingTab({required this.userId});
  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Outstanding Bill Card ──────────────────────────────────────
          StreamBuilder<MessBillModel?>(
            stream: ref.watch(messServiceProvider).getStudentBill(userId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final bill = snapshot.data;
              final amount = bill?.amount ?? 0.0;
              final lastUpdated = bill != null
                  ? DateFormat('MMM d, y').format(bill.lastUpdated)
                  : null;

              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: amount > 0
                        ? [Colors.red.shade700, Colors.red.shade400]
                        : [Colors.green.shade700, Colors.green.shade400],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: (amount > 0 ? Colors.red : Colors.green)
                          .withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.receipt_long,
                            color: Colors.white, size: 28),
                        const SizedBox(width: 12),
                        Text(
                          'Outstanding Mess Bill',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'PKR ${amount.toStringAsFixed(0)}',
                      style: Theme.of(context)
                          .textTheme
                          .displaySmall
                          ?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    if (lastUpdated != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Last updated: $lastUpdated',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                    if (amount <= 0) ...[
                      const SizedBox(height: 8),
                      const Text(
                        '✓ All dues cleared',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),

          const SizedBox(height: 24),

          // ── Billing History ────────────────────────────────────────────
          Text(
            'Billing History',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 12),

          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('feePayments')
                .where('userId', isEqualTo: userId)
                .where('paymentType',
                    isEqualTo: PaymentType.messFee.toString())
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                // Try without orderBy if index is missing
                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('feePayments')
                      .where('userId', isEqualTo: userId)
                      .where('paymentType',
                          isEqualTo: PaymentType.messFee.toString())
                      .snapshots(),
                  builder: (context, snap2) {
                    if (!snap2.hasData || snap2.data!.docs.isEmpty) {
                      return _emptyHistory();
                    }
                    final docs = snap2.data!.docs.toList();
                    return _buildHistoryList(context, docs);
                  },
                );
              }

              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) return _emptyHistory();
              return _buildHistoryList(context, docs);
            },
          ),
        ],
      ),
    );
  }

  Widget _emptyHistory() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: const Center(
        child: Text(
          'No billing history yet.',
          style: TextStyle(color: Colors.grey),
        ),
      ),
    );
  }

  Widget _buildHistoryList(BuildContext context, List<QueryDocumentSnapshot> docs) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: docs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final data = docs[index].data() as Map<String, dynamic>;
        final amount = (data['amount'] ?? 0).toDouble();
        final adminAccepted = data['adminAccepted'] as bool? ?? false;
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
        final proofUrl = data['proofUrl'] as String?;

        final dateStr = createdAt != null
            ? DateFormat('MMM d, y').format(createdAt)
            : 'Unknown date';

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: adminAccepted
                  ? Colors.green.withValues(alpha: 0.3)
                  : Colors.orange.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: adminAccepted
                      ? Colors.green.withValues(alpha: 0.1)
                      : Colors.orange.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  adminAccepted
                      ? Icons.check_circle_outline
                      : Icons.pending_actions,
                  color: adminAccepted ? Colors.green : Colors.orange,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mess Bill Payment',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    Text(
                      dateStr,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey,
                          ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'PKR ${amount.toStringAsFixed(0)}',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: adminAccepted
                          ? Colors.green.withValues(alpha: 0.1)
                          : Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      adminAccepted ? 'Approved' : 'Pending',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color:
                            adminAccepted ? Colors.green : Colors.orange,
                      ),
                    ),
                  ),
                  if (proofUrl != null) ...[
                    const SizedBox(height: 4),
                    const Text(
                      'Screenshot uploaded',
                      style: TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Schedule helpers ─────────────────────────────────────────────────────────

class _DayMealSection extends StatelessWidget {
  const _DayMealSection({
    required this.type,
    required this.items,
  });

  final MealType type;
  final List<MessMenuItem> items;

  String get _title {
    switch (type) {
      case MealType.breakfast:
        return 'Breakfast';
      case MealType.lunch:
        return 'Lunch';
      case MealType.dinner:
        return 'Dinner';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _title,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 4),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      item.name,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  Text(
                    'Rs. ${item.price.toStringAsFixed(0)}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}