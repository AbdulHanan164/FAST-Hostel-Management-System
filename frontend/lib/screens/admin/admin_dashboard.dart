import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../config/theme.dart';
import '../../services/hostel_service.dart';
import '../../models/hostel_model.dart';
import '../../widgets/status_badge.dart';

class AdminDashboard extends ConsumerWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUserAsync = ref.watch(currentUserProvider);
    final isDarkMode = ref.watch(isDarkModeProvider);

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
        leading: Padding(
          padding: const EdgeInsets.all(10),
          child: Image.asset(
            'assets/images/fast_logo-removebg-preview.png',
            width: 28,
            height: 28,
            fit: BoxFit.contain,
          ),
        ),
        title: const Text(
          '🛡️ Admin Panel',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18),
        ),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(isDarkMode ? Icons.light_mode_outlined : Icons.dark_mode_outlined, color: Colors.white),
            onPressed: () => ref.read(themeModeProvider.notifier).toggleTheme(),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: (value) async {
              if (value == 'logout') {
                await ref.read(currentUserProvider.notifier).signOut();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, size: 18),
                    SizedBox(width: 8),
                    Text('Logout'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: currentUserAsync.when(
        data: (user) {
          if (user == null) return const Center(child: Text('No user data'));
          return _AdminDashboardContent(userName: user.name);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

class _AdminDashboardContent extends StatefulWidget {
  const _AdminDashboardContent({required this.userName});
  final String userName;

  @override
  State<_AdminDashboardContent> createState() => _AdminDashboardContentState();
}

class _AdminDashboardContentState extends State<_AdminDashboardContent>
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
    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _AdminHeader(userName: widget.userName),
              const SizedBox(height: 24),
              const _SectionTitle('System Overview 📊'),
              const SizedBox(height: 16),
              const _QuickStatsGrid(),
              const SizedBox(height: 24),
              const _SectionTitle('Management Modules 🗂️'),
              const SizedBox(height: 16),
              const _ManagementModulesGrid(),
              const SizedBox(height: 24),
              const _SectionTitle('Analytics 📈'),
              const SizedBox(height: 16),
              const _ApplicationStatusChart(),
              const SizedBox(height: 24),
              const _SectionTitle('Recent Activity 🕐'),
              const SizedBox(height: 16),
              const _RecentActivityFeed(),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
    );
  }
}

// ── Header ───────────────────────────────────────────────────────────────────

class _AdminHeader extends StatelessWidget {
  const _AdminHeader({required this.userName});
  final String userName;

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12 ? 'Good Morning' : hour < 17 ? 'Good Afternoon' : 'Good Evening';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primaryDark, AppColors.primary, AppColors.primaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.admin_panel_settings_rounded, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$greeting, ${userName.split(' ').first} 👋',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'FAST Hostel Administration Panel',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.85),
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

// ── Stats Grid ────────────────────────────────────────────────────────────────

class _QuickStatsGrid extends ConsumerWidget {
  const _QuickStatsGrid();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return StreamBuilder<List<HostelApplicationModel>>(
      stream: ref.watch(hostelServiceProvider).getAllApplications(),
      builder: (context, appsSnap) {
        return StreamBuilder<Map<String, dynamic>>(
          stream: ref.watch(hostelServiceProvider).getOccupancyStatsStream(),
          builder: (context, statsSnap) {
            final apps = appsSnap.data ?? [];
            final totalApps = apps.length;
            final pendingApps = apps.where((a) => a.status == 'pending').length;
            final stats = statsSnap.data ?? {};
            final totalRooms = stats.values.fold<int>(0, (sum, s) => sum + (s['totalRooms'] as int? ?? 0));
            final occupiedRooms = stats.values.fold<int>(0, (sum, s) => sum + (s['occupiedRooms'] as int? ?? 0));
            final availableRooms = totalRooms - occupiedRooms;

            return GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.6,
              children: [
                _StatCard(title: 'Total Applications', value: '$totalApps', emoji: '📋', color: AppColors.primary),
                _StatCard(title: 'Pending Reviews', value: '$pendingApps', emoji: '⏳', color: AppColors.warning),
                _StatCard(title: 'Active Residents', value: '$occupiedRooms', emoji: '👥', color: AppColors.success),
                _StatCard(title: 'Available Rooms', value: '$availableRooms', emoji: '🛏️', color: AppColors.info),
              ],
            );
          },
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.title, required this.value, required this.emoji, required this.color});
  final String title;
  final String value;
  final String emoji;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: AppColors.primary.withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, 4)),
        ],
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 20)),
              const Spacer(),
              Text(
                value,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: color),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

// ── Modules Grid ──────────────────────────────────────────────────────────────

class _ManagementModulesGrid extends StatelessWidget {
  const _ManagementModulesGrid();

  @override
  Widget build(BuildContext context) {
    const modules = [
      _AdminModuleItem(title: 'Applications', emoji: '📋', color: AppColors.primary, route: '/admin/dashboard/applications'),
      _AdminModuleItem(title: 'Hostels', emoji: '🏢', color: Color(0xFF0D9488), route: '/admin/dashboard/hostel-management'),
      _AdminModuleItem(title: 'Complaints', emoji: '📝', color: AppColors.warning, route: '/admin/dashboard/complaints'),
      _AdminModuleItem(title: 'Mess', emoji: '🍽️', color: AppColors.success, route: '/admin/dashboard/mess-management'),
      _AdminModuleItem(title: 'Gym', emoji: '🏋️', color: AppColors.error, route: '/admin/dashboard/gym-management'),
      _AdminModuleItem(title: 'Mess Billing', emoji: '💰', color: Color(0xFF7C3AED), route: '/admin/dashboard/mess-billing'),
      _AdminModuleItem(title: 'Halls', emoji: '🏠', color: AppColors.info, route: '/admin/dashboard/halls'),
      _AdminModuleItem(title: 'Notices', emoji: '📢', color: Color(0xFF0D9488), route: '/admin/dashboard/notice-board'),
      _AdminModuleItem(title: 'Fee Payments', emoji: '💳', color: Colors.green, route: '/admin/dashboard/fee-payments'),
      _AdminModuleItem(title: 'Bank Settings', emoji: '🏦', color: Colors.teal, route: '/admin/dashboard/bank-settings'),
      _AdminModuleItem(title: 'Student Status', emoji: '👥', color: Color(0xFF6366F1), route: '/admin/dashboard/student-status'),
      _AdminModuleItem(title: 'DB Management', emoji: '🗑️', color: Colors.red, route: '/admin/dashboard/db-management'),
    ];

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 0.9,
      children: modules
          .asMap()
          .entries
          .map((e) => _AnimatedAdminCard(item: e.value, index: e.key))
          .toList(),
    );
  }
}

class _AdminModuleItem {
  const _AdminModuleItem({required this.title, required this.emoji, required this.color, required this.route});
  final String title;
  final String emoji;
  final Color color;
  final String route;
}

class _AnimatedAdminCard extends StatefulWidget {
  const _AnimatedAdminCard({required this.item, required this.index});
  final _AdminModuleItem item;
  final int index;

  @override
  State<_AnimatedAdminCard> createState() => _AnimatedAdminCardState();
}

class _AnimatedAdminCardState extends State<_AnimatedAdminCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _fadeAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    Future.delayed(Duration(milliseconds: widget.index * 55), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: _ModuleCard(item: widget.item),
      ),
    );
  }
}

class _ModuleCard extends StatelessWidget {
  const _ModuleCard({required this.item});
  final _AdminModuleItem item;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push(item.route),
      borderRadius: BorderRadius.circular(16),
      child: Container(
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
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: item.color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Text(item.emoji, style: const TextStyle(fontSize: 22)),
            ),
            const SizedBox(height: 8),
            Text(
              item.title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Analytics Chart ──────────────────────────────────────────────────────────

class _ApplicationStatusChart extends ConsumerWidget {
  const _ApplicationStatusChart();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return StreamBuilder<List<HostelApplicationModel>>(
      stream: ref.watch(hostelServiceProvider).getAllApplications(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final apps = snapshot.data ?? [];
        if (apps.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: const Center(child: Text('No application data available')),
          );
        }

        int pending = 0, challan = 0, roomAssigned = 0, rejected = 0;
        for (final app in apps) {
          if (app.status == 'pending') pending++;
          else if (app.status == 'fee_challan_generated' || app.status == 'fee_confirmed') challan++;
          else if (app.status == 'room_assigned') roomAssigned++;
          else if (app.status == 'rejected') rejected++;
        }

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: AppColors.primary.withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, 4)),
            ],
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Text('📊', style: TextStyle(fontSize: 18)),
                  SizedBox(width: 8),
                  Text('Application Distribution', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 200,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 40,
                    sections: [
                      PieChartSectionData(color: AppColors.warning, value: pending.toDouble(), title: '$pending', radius: 50,
                          titleStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                      PieChartSectionData(color: AppColors.info, value: challan.toDouble(), title: '$challan', radius: 50,
                          titleStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                      PieChartSectionData(color: AppColors.success, value: roomAssigned.toDouble(), title: '$roomAssigned', radius: 50,
                          titleStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                      if (rejected > 0)
                        PieChartSectionData(color: AppColors.error, value: rejected.toDouble(), title: '$rejected', radius: 50,
                            titleStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _LegendItem(color: AppColors.warning, label: 'Pending'),
                  SizedBox(width: 8),
                  _LegendItem(color: AppColors.info, label: 'Fee Stage'),
                  SizedBox(width: 8),
                  _LegendItem(color: AppColors.success, label: 'Assigned'),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }
}

// ── Recent Activity Feed ──────────────────────────────────────────────────────

class _RecentActivityFeed extends ConsumerWidget {
  const _RecentActivityFeed();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return StreamBuilder<List<HostelApplicationModel>>(
      stream: ref.watch(hostelServiceProvider).getAllApplications(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final apps = snapshot.data ?? [];
        if (apps.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: const Center(child: Text('No recent activity')),
          );
        }

        apps.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        final recentApps = apps.take(5).toList();

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: AppColors.primary.withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, 4)),
            ],
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: recentApps.length,
            separatorBuilder: (_, __) => const Divider(height: 1, indent: 16, endIndent: 16),
            itemBuilder: (context, index) {
              final app = recentApps[index];
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.person_outline, color: AppColors.primary, size: 20),
                ),
                title: Text(app.studentName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: Text(
                  DateFormat('MMM dd, yyyy • hh:mm a').format(app.createdAt),
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: StatusBadge(
                  label: _formatStatus(app.status),
                  type: _getStatusType(app.status),
                ),
              );
            },
          ),
        );
      },
    );
  }

  String _formatStatus(String status) {
    switch (status) {
      case 'pending': return 'Pending';
      case 'fee_challan_generated': return 'Fee Gen';
      case 'fee_confirmed': return 'Fee Conf';
      case 'room_assigned': return 'Assigned';
      case 'rejected': return 'Rejected';
      default: return status.toUpperCase();
    }
  }

  StatusType _getStatusType(String status) {
    switch (status) {
      case 'room_assigned':
      case 'fee_confirmed': return StatusType.success;
      case 'rejected': return StatusType.error;
      case 'fee_challan_generated': return StatusType.info;
      default: return StatusType.warning;
    }
  }
}
