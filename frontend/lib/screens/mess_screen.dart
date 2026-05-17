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

class _MessScreenState extends ConsumerState<MessScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _animController.forward();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
          '🍽️ Mess Portal',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: AppColors.accent,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: '📅 Schedule'),
            Tab(text: '🧾 My Bill'),
          ],
        ),
      ),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SlideTransition(
          position: _slideAnim,
          child: TabBarView(
            controller: _tabController,
            children: [
              // ── Schedule Tab ─────────────────────────────────────────
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
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('🍽️', style: TextStyle(fontSize: 56)),
                          const SizedBox(height: 16),
                          const Text('No menu set for this week', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                          const SizedBox(height: 6),
                          const Text('Check back later', style: TextStyle(color: AppColors.textSecondary)),
                        ],
                      ),
                    );
                  }

                  menus.sort((a, b) => a.date.compareTo(b.date));

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: menus.length,
                    itemBuilder: (context, index) {
                      final menu = menus[index];
                      final dateLabel = DateFormat('EEEE, MMM d').format(menu.date);
                      final isToday = DateFormat('yyyy-MM-dd').format(menu.date) ==
                          DateFormat('yyyy-MM-dd').format(DateTime.now());

                      return Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.08),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                          border: Border.all(
                            color: isToday ? AppColors.accent : const Color(0xFFE5E7EB),
                            width: isToday ? 2 : 1,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text('📅', style: const TextStyle(fontSize: 18)),
                                  const SizedBox(width: 8),
                                  Text(
                                    dateLabel,
                                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.primary),
                                  ),
                                  if (isToday) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.accent,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Text('Today', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 10),
                              _DayMealSection(type: MealType.breakfast, items: menu.meals[MealType.breakfast] ?? const []),
                              _DayMealSection(type: MealType.lunch, items: menu.meals[MealType.lunch] ?? const []),
                              _DayMealSection(type: MealType.dinner, items: menu.meals[MealType.dinner] ?? const []),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),

              // ── My Bill Tab ──────────────────────────────────────────
              Consumer(
                builder: (context, ref, child) {
                  final user = ref.watch(currentUserProvider).value;
                  if (user == null) return const Center(child: CircularProgressIndicator());
                  return _MessBillingTab(userId: user.uid);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── My Bill Tab ───────────────────────────────────────────────────────────────

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
          // Outstanding Bill Card
          StreamBuilder<MessBillModel?>(
            stream: ref.watch(messServiceProvider).getStudentBill(userId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final bill = snapshot.data;
              final amount = bill?.amount ?? 0.0;
              final lastUpdated = bill != null ? DateFormat('MMM d, y').format(bill.lastUpdated) : null;
              final isDebt = amount > 0;

              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDebt
                        ? [Colors.red.shade700, Colors.red.shade400]
                        : [Colors.green.shade700, Colors.green.shade400],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: (isDebt ? Colors.red : Colors.green).withValues(alpha: 0.3),
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
                        Text(isDebt ? '🧾' : '✅', style: const TextStyle(fontSize: 24)),
                        const SizedBox(width: 12),
                        Text(
                          'Outstanding Mess Bill',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'PKR ${amount.toStringAsFixed(0)}',
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    if (lastUpdated != null) ...[
                      const SizedBox(height: 6),
                      Text('Last updated: $lastUpdated', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                    if (!isDebt) ...[
                      const SizedBox(height: 8),
                      const Text('✓ All dues cleared', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                    ],
                  ],
                ),
              );
            },
          ),

          const SizedBox(height: 24),

          const Row(
            children: [
              Text('📜', style: TextStyle(fontSize: 18)),
              SizedBox(width: 8),
              Text('Billing History', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            ],
          ),
          const SizedBox(height: 12),

          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('feePayments')
                .where('userId', isEqualTo: userId)
                .where('paymentType', isEqualTo: PaymentType.messFee.toString())
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('feePayments')
                      .where('userId', isEqualTo: userId)
                      .where('paymentType', isEqualTo: PaymentType.messFee.toString())
                      .snapshots(),
                  builder: (context, snap2) {
                    if (!snap2.hasData || snap2.data!.docs.isEmpty) return _emptyHistory();
                    return _buildHistoryList(context, snap2.data!.docs.toList());
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: const Center(
        child: Column(
          children: [
            Text('📭', style: TextStyle(fontSize: 36)),
            SizedBox(height: 8),
            Text('No billing history yet.', style: TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryList(BuildContext context, List<QueryDocumentSnapshot> docs) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: docs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final data = docs[index].data() as Map<String, dynamic>;
        final amount = (data['amount'] ?? 0).toDouble();
        final adminAccepted = data['adminAccepted'] as bool? ?? false;
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
        final proofUrl = data['proofUrl'] as String?;
        final dateStr = createdAt != null ? DateFormat('MMM d, y').format(createdAt) : 'Unknown date';

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(color: AppColors.primary.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 3)),
            ],
            border: Border.all(
              color: adminAccepted ? AppColors.success.withValues(alpha: 0.3) : AppColors.warning.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: adminAccepted ? AppColors.success.withValues(alpha: 0.1) : AppColors.warning.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Text(adminAccepted ? '✅' : '⏳', style: const TextStyle(fontSize: 18)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Mess Bill Payment', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    Text(dateStr, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'PKR ${amount.toStringAsFixed(0)}',
                    style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: adminAccepted ? AppColors.success.withValues(alpha: 0.1) : AppColors.warning.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      adminAccepted ? 'Approved' : 'Pending',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: adminAccepted ? AppColors.success : AppColors.warning,
                      ),
                    ),
                  ),
                  if (proofUrl != null) ...[
                    const SizedBox(height: 4),
                    const Text('Screenshot uploaded', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
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

// ── Schedule helpers ──────────────────────────────────────────────────────────

class _DayMealSection extends StatelessWidget {
  const _DayMealSection({required this.type, required this.items});
  final MealType type;
  final List<MessMenuItem> items;

  String get _emoji {
    switch (type) {
      case MealType.breakfast: return '🌅';
      case MealType.lunch: return '☀️';
      case MealType.dinner: return '🌙';
    }
  }

  String get _title {
    switch (type) {
      case MealType.breakfast: return 'Breakfast';
      case MealType.lunch: return 'Lunch';
      case MealType.dinner: return 'Dinner';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(_emoji, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
              Text(
                _title,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 6),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '• ${item.name}',
                      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                  ),
                  Text(
                    'Rs. ${item.price.toStringAsFixed(0)}',
                    style: const TextStyle(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
