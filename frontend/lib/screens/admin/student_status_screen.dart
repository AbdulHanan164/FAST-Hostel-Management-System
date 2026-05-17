import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';

class StudentStatusScreen extends StatefulWidget {
  const StudentStatusScreen({super.key});

  @override
  State<StudentStatusScreen> createState() => _StudentStatusScreenState();
}

class _StudentStatusScreenState extends State<StudentStatusScreen> {
  String _search = '';
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Status Overview'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by name or roll number...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
              ),
              onChanged: (v) => setState(() => _search = v.trim().toLowerCase()),
            ),
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('profiles')
            .where('role', isEqualTo: 'student')
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }
          final docs = snap.data?.docs ?? [];
          final filtered = _search.isEmpty
              ? docs
              : docs.where((d) {
                  final data = d.data() as Map<String, dynamic>;
                  final name = (data['name'] ?? '').toString().toLowerCase();
                  final roll = (data['arnRollNumber'] ?? data['rollNumber'] ?? '').toString().toLowerCase();
                  return name.contains(_search) || roll.contains(_search);
                }).toList();

          if (filtered.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.people_outline, size: 64, color: Colors.grey),
                  const SizedBox(height: 12),
                  Text(_search.isEmpty ? 'No students found' : 'No results for "$_search"'),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final doc = filtered[index];
              final profile = doc.data() as Map<String, dynamic>;
              return _StudentStatusTile(userId: doc.id, profile: profile);
            },
          );
        },
      ),
    );
  }
}

// ── Per-student expandable tile ─────────────────────────────────────────

class _StudentStatusTile extends StatelessWidget {
  const _StudentStatusTile({required this.userId, required this.profile});

  final String userId;
  final Map<String, dynamic> profile;

  @override
  Widget build(BuildContext context) {
    final name = profile['name'] ?? 'Unknown';
    final roll = profile['arnRollNumber'] ?? profile['rollNumber'] ?? 'N/A';
    final email = profile['email'] ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: CircleAvatar(
            backgroundColor: AppColors.primary.withValues(alpha: 0.12),
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: AppColors.primary),
            ),
          ),
          title: Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text('$roll  •  $email',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          children: [
            _SectionLabel(icon: Icons.person_outline, label: 'Profile'),
            _ProfileNode(profile: profile),
            const SizedBox(height: 8),
            _SectionLabel(icon: Icons.assignment_outlined, label: 'Hostel Application'),
            _ApplicationNode(userId: userId),
            const SizedBox(height: 8),
            _SectionLabel(icon: Icons.payments_outlined, label: 'Fee & Balance'),
            _FeeNode(userId: userId),
            const SizedBox(height: 8),
            _SectionLabel(icon: Icons.bed_outlined, label: 'Room Assignment'),
            _RoomNode(userId: userId),
            const SizedBox(height: 8),
            _SectionLabel(icon: Icons.restaurant_outlined, label: 'Mess'),
            _MessNode(userId: userId),
            const SizedBox(height: 8),
            _SectionLabel(icon: Icons.fitness_center_outlined, label: 'Gym'),
            _GymNode(userId: userId),
          ],
        ),
      ),
    );
  }
}

// ── Section label ───────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(label,
              style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: AppColors.primary)),
        ],
      ),
    );
  }
}

// ── Tree row helper ─────────────────────────────────────────────────────

class _TreeRow extends StatelessWidget {
  const _TreeRow({required this.label, required this.value, this.valueColor});
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 0, 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('├─ ',
              style: TextStyle(color: Colors.grey, fontFamily: 'monospace')),
          Text('$label: ',
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary)),
          Expanded(
            child: Text(value,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: valueColor ?? AppColors.textPrimary)),
          ),
        ],
      ),
    );
  }
}

// ── Profile node ────────────────────────────────────────────────────────

class _ProfileNode extends StatelessWidget {
  const _ProfileNode({required this.profile});
  final Map<String, dynamic> profile;

  @override
  Widget build(BuildContext context) {
    final gender = profile['gender'] ?? 'N/A';
    final phone = profile['phone'] ?? profile['phoneNumber'] ?? 'N/A';
    final year = profile['year'] ?? profile['academicYear'] ?? 'N/A';
    final status = profile['status'] ?? 'active';
    final createdAt = (profile['createdAt'] as Timestamp?)?.toDate();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _TreeRow(label: 'Gender', value: gender),
      _TreeRow(label: 'Phone', value: phone),
      _TreeRow(label: 'Year', value: year),
      _TreeRow(
          label: 'Status',
          value: status,
          valueColor: status == 'active' ? Colors.green[700] : Colors.red),
      if (createdAt != null)
        _TreeRow(
            label: 'Joined',
            value: DateFormat('MMM dd, yyyy').format(createdAt)),
    ]);
  }
}

// ── Application node ────────────────────────────────────────────────────

class _ApplicationNode extends StatelessWidget {
  const _ApplicationNode({required this.userId});
  final String userId;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('hostelApplications')
          .doc(userId)
          .get(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.only(left: 16),
            child: Text('Loading...', style: TextStyle(fontSize: 12, color: Colors.grey)),
          );
        }
        if (!snap.hasData || !snap.data!.exists) {
          return const _TreeRow(
              label: 'Status', value: 'No application submitted', valueColor: Colors.grey);
        }
        final d = snap.data!.data() as Map<String, dynamic>;
        final status = d['status'] ?? 'pending';
        final queue = (d['queueNumber'] as num?)?.toInt() ?? 0;
        final roomType = d['roomType'] ?? 'N/A';
        final feeAmount = (d['feeAmount'] as num?)?.toDouble() ?? 0;
        final submittedAt = (d['createdAt'] as Timestamp?)?.toDate();
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _TreeRow(
              label: 'Status',
              value: status.replaceAll('_', ' ').toUpperCase(),
              valueColor: _appStatusColor(status)),
          if (queue > 0) _TreeRow(label: 'Queue Position', value: '#$queue'),
          _TreeRow(label: 'Room Type', value: roomType.toUpperCase()),
          _TreeRow(
              label: 'Fee Amount', value: 'Rs. ${feeAmount.toStringAsFixed(0)}'),
          if (submittedAt != null)
            _TreeRow(
                label: 'Submitted',
                value: DateFormat('MMM dd, yyyy').format(submittedAt)),
        ]);
      },
    );
  }

  Color _appStatusColor(String s) {
    switch (s) {
      case 'pending': return Colors.orange;
      case 'approved': return Colors.blue;
      case 'fee_challan_generated': return Colors.purple;
      case 'fee_confirmed': return Colors.teal;
      case 'room_assigned': return Colors.green;
      case 'rejected': return Colors.red;
      default: return Colors.grey;
    }
  }
}

// ── Fee node ────────────────────────────────────────────────────────────

class _FeeNode extends StatelessWidget {
  const _FeeNode({required this.userId});
  final String userId;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('studentBalance')
          .doc(userId)
          .get(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.only(left: 16),
            child: Text('Loading...', style: TextStyle(fontSize: 12, color: Colors.grey)),
          );
        }
        if (!snap.hasData || !snap.data!.exists) {
          return const _TreeRow(label: 'Balance', value: 'No fee records', valueColor: Colors.grey);
        }
        final d = snap.data!.data() as Map<String, dynamic>;
        final remaining = ((d['remainingBalance'] as num?) ?? 0).toDouble();
        final credit = ((d['creditBalance'] as num?) ?? 0).toDouble();
        final updated = (d['lastUpdated'] as Timestamp?)?.toDate();
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _TreeRow(
              label: 'Remaining Balance',
              value: remaining > 0 ? 'Rs. ${remaining.toStringAsFixed(0)}' : 'None',
              valueColor: remaining > 0 ? Colors.red[700] : Colors.green[700]),
          _TreeRow(
              label: 'Credit Balance',
              value: credit > 0 ? 'Rs. ${credit.toStringAsFixed(0)}' : 'None',
              valueColor: credit > 0 ? Colors.green[700] : Colors.grey),
          if (updated != null)
            _TreeRow(
                label: 'Last Updated',
                value: DateFormat('MMM dd, yyyy').format(updated)),
        ]);
      },
    );
  }
}

// ── Room node ───────────────────────────────────────────────────────────

class _RoomNode extends StatelessWidget {
  const _RoomNode({required this.userId});
  final String userId;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection('beds')
          .where('studentId', isEqualTo: userId)
          .limit(1)
          .get(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.only(left: 16),
            child: Text('Loading...', style: TextStyle(fontSize: 12, color: Colors.grey)),
          );
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return const _TreeRow(label: 'Room', value: 'Not assigned', valueColor: Colors.grey);
        }
        final bed = docs.first.data() as Map<String, dynamic>;
        final bedNum = bed['bedNumber'] ?? 'N/A';
        final roomId = bed['roomId'] ?? '';
        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance.collection('rooms').doc(roomId).get(),
          builder: (ctx, roomSnap) {
            String roomName = 'Room ID: $roomId';
            if (roomSnap.hasData && roomSnap.data!.exists) {
              final rd = roomSnap.data!.data() as Map<String, dynamic>;
              roomName = rd['name'] ?? roomName;
            }
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _TreeRow(label: 'Room', value: roomName, valueColor: Colors.green[700]),
              _TreeRow(label: 'Bed', value: bedNum),
            ]);
          },
        );
      },
    );
  }
}

// ── Mess node ───────────────────────────────────────────────────────────

class _MessNode extends StatelessWidget {
  const _MessNode({required this.userId});
  final String userId;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection('messRegistrations')
          .where('studentId', isEqualTo: userId)
          .limit(1)
          .get(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.only(left: 16),
            child: Text('Loading...', style: TextStyle(fontSize: 12, color: Colors.grey)),
          );
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return const _TreeRow(label: 'Mess', value: 'Not registered', valueColor: Colors.grey);
        }
        final d = docs.first.data() as Map<String, dynamic>;
        final status = d['status'] ?? 'inactive';
        return _TreeRow(
            label: 'Registration',
            value: status.toUpperCase(),
            valueColor: status == 'active' ? Colors.green[700] : Colors.orange);
      },
    );
  }
}

// ── Gym node ────────────────────────────────────────────────────────────

class _GymNode extends StatelessWidget {
  const _GymNode({required this.userId});
  final String userId;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection('gymRegistrations')
          .where('studentId', isEqualTo: userId)
          .limit(1)
          .get(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.only(left: 16),
            child: Text('Loading...', style: TextStyle(fontSize: 12, color: Colors.grey)),
          );
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return const _TreeRow(label: 'Gym', value: 'Not registered', valueColor: Colors.grey);
        }
        final d = docs.first.data() as Map<String, dynamic>;
        final status = d['status'] ?? 'pending_payment';
        final expiry = (d['expiryDate'] as Timestamp?)?.toDate();
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _TreeRow(
              label: 'Status',
              value: status.replaceAll('_', ' ').toUpperCase(),
              valueColor: status == 'active' ? Colors.green[700] : Colors.orange),
          if (expiry != null)
            _TreeRow(
                label: 'Expires',
                value: DateFormat('MMM dd, yyyy').format(expiry)),
        ]);
      },
    );
  }
}
