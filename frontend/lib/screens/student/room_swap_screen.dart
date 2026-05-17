import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../services/hostel_service.dart';
import '../../models/hostel_model.dart' show HostelApplicationModel;
import '../../models/hall_floor_room_model.dart' show RoomModel;
import '../../config/theme.dart';

class RoomSwapScreen extends ConsumerStatefulWidget {
  const RoomSwapScreen({super.key});

  @override
  ConsumerState<RoomSwapScreen> createState() => _RoomSwapScreenState();
}

class _RoomSwapScreenState extends ConsumerState<RoomSwapScreen>
    with SingleTickerProviderStateMixin {
  final _reasonController = TextEditingController();
  RoomModel? _selectedToRoom;
  bool _isLoading = false;

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
    _reasonController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _submitSwapRequest() async {
    if (_selectedToRoom == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a room to swap with'), backgroundColor: AppTheme.errorColor),
      );
      return;
    }

    if (_reasonController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide a reason for the swap'), backgroundColor: AppTheme.errorColor),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final currentUser = ref.read(currentUserProvider).value;
      if (currentUser == null) throw Exception('User not found');

      final hostelService = ref.read(hostelServiceProvider);
      final application = await hostelService.getUserApplication(currentUser.uid);

      if (application == null || application.selectedRoomId == null) {
        throw Exception('You must have an assigned room to request a swap');
      }

      final fromRoomId = application.selectedRoomId;
      final toRoomId = _selectedToRoom?.id;

      if (fromRoomId == null || toRoomId == null) throw Exception('Room information is missing');

      await hostelService.createSwapRequest(
        fromRoomId: fromRoomId,
        toRoomId: toRoomId,
        studentId: currentUser.uid,
        reason: _reasonController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Swap request submitted successfully! Awaiting admin approval.'),
            backgroundColor: AppTheme.successColor,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.errorColor),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);

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
          '🔄 Room Swap',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SlideTransition(
          position: _slideAnim,
          child: currentUser.when(
            data: (user) {
              if (user == null) return const Center(child: Text('User not found'));

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Hero banner
                    Container(
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
                          BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 8)),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Text('🔄', style: TextStyle(fontSize: 32)),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Room Swap Request',
                                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                        color: Colors.white, fontWeight: FontWeight.bold,
                                      ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Request to swap your current room with another',
                                  style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Important notice card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, 4))],
                        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Text('⚠️', style: TextStyle(fontSize: 18)),
                              SizedBox(width: 8),
                              Text('Important Notice', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.warning, fontSize: 14)),
                            ],
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            '• Only one room swap is allowed per student\n'
                            '• Swap requests require admin approval\n'
                            '• You will be notified once your request is reviewed\n'
                            '• Both rooms must be available for the swap to be approved',
                            style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.7),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Current Room Info
                    FutureBuilder<HostelApplicationModel?>(
                      future: ref.read(hostelServiceProvider).getUserApplication(user.uid),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }

                        final application = snapshot.data;
                        if (application?.selectedRoomId == null) {
                          return Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFE5E7EB)),
                            ),
                            child: const Center(
                              child: Text(
                                'You must have an assigned room to request a swap',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: AppColors.textSecondary),
                              ),
                            ),
                          );
                        }

                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, 4))],
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Text('🛏️', style: TextStyle(fontSize: 18)),
                                  SizedBox(width: 8),
                                  Text('Current Room', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text('Room ID: ${application?.selectedRoomId ?? 'Unknown'}', style: const TextStyle(color: AppColors.textSecondary)),
                              const SizedBox(height: 4),
                              const Text('Status: Assigned', style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 20),

                    // Available rooms
                    const Row(
                      children: [
                        Text('🔍', style: TextStyle(fontSize: 18)),
                        SizedBox(width: 8),
                        Text('Select Room to Swap With', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                      ],
                    ),
                    const SizedBox(height: 12),

                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, 4))],
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text('🏠', style: TextStyle(fontSize: 18)),
                              SizedBox(width: 8),
                              Text('Available Rooms', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                            ],
                          ),
                          SizedBox(height: 10),
                          Text(
                            'Room selection will be available here.\nStudents can browse and select from available rooms.',
                            style: TextStyle(fontStyle: FontStyle.italic, color: AppColors.textSecondary, fontSize: 13),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Reason for Swap
                    const Row(
                      children: [
                        Text('📋', style: TextStyle(fontSize: 18)),
                        SizedBox(width: 8),
                        Text('Reason for Swap', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                      ],
                    ),
                    const SizedBox(height: 12),

                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, 4))],
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: TextField(
                        controller: _reasonController,
                        decoration: const InputDecoration(
                          labelText: 'Please explain why you want to swap rooms',
                          hintText: 'Enter your reason...',
                          prefixIcon: Text('  📝  ', style: TextStyle(fontSize: 18)),
                          prefixIconConstraints: BoxConstraints(minWidth: 48, minHeight: 48),
                          alignLabelWithHint: true,
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.all(16),
                        ),
                        maxLines: 4,
                      ),
                    ),

                    const SizedBox(height: 24),

                    GestureDetector(
                      onTap: _isLoading ? null : _submitSwapRequest,
                      child: Container(
                        width: double.infinity,
                        height: 54,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: _isLoading
                                ? [AppColors.primary.withValues(alpha: 0.5), AppColors.primaryLight.withValues(alpha: 0.5)]
                                : const [AppColors.primary, AppColors.primaryLight],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: _isLoading
                              ? null
                              : [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))],
                        ),
                        alignment: Alignment.center,
                        child: _isLoading
                            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                            : const Text('🔄 Submit Swap Request', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                      ),
                    ),

                    const SizedBox(height: 32),
                  ],
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: $error'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
