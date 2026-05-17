import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/hostel_service.dart';
import '../../../services/hall_floor_room_service.dart';
import '../../../models/hostel_model.dart' show HostelModel, HostelApplicationModel;
import '../../../models/hall_floor_room_model.dart' show FloorModel, RoomModel, HallModel;
import '../../../config/theme.dart';

class RoomSelectionScreen extends ConsumerStatefulWidget {
  const RoomSelectionScreen({super.key});

  @override
  ConsumerState<RoomSelectionScreen> createState() =>
      _RoomSelectionScreenState();
}

class _RoomSelectionScreenState extends ConsumerState<RoomSelectionScreen> {
  HostelModel? _selectedHostel;
  HallModel? _selectedHall;
  FloorModel? _selectedFloor;
  RoomModel? _selectedRoom;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Room'),
        actions: [
          if (_selectedRoom != null)
            TextButton(
              onPressed: _isLoading ? null : _confirmRoomSelection,
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Confirm'),
            ),
        ],
      ),
      body: currentUser.when(
        data: (user) {
          if (user == null) {
            return const Center(child: Text('User not found'));
          }

          final hostelService = ref.watch(hostelServiceProvider);

          return StreamBuilder<HostelApplicationModel?>(
            stream: hostelService.getUserApplicationStream(user.uid),
            builder: (context, appSnapshot) {
              if (appSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final application = appSnapshot.data;

              // If no application, prompt user to apply first
              if (application == null) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.assignment_late, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('No hostel application found.'),
                      SizedBox(height: 8),
                      Text(
                          'Please submit your application before selecting a room.'),
                    ],
                  ),
                );
              }

              // If fee not confirmed yet, show message and block selection
              if (!application.feeConfirmed) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.payment,
                            size: 64, color: Colors.orange),
                        const SizedBox(height: 16),
                        const Text('Payment pending'),
                        const SizedBox(height: 8),
                        const Text(
                            'Your fee must be accepted by administration before you can select a room.'),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () =>
                              context.go('/student/dashboard/payments'),
                          child: const Text('Go to Payments'),
                        ),
                      ],
                    ),
                  ),
                );
              }

              // Fee confirmed: allow room selection
              return Column(
                children: [
                  // Hostel Selection
                  if (_selectedHostel == null) ...[
                    Expanded(
                      child: _buildHostelSelection(
                          user.gender.toString().split('.').last),
                    ),
                  ] else if (_selectedHall == null) ...[
                    Expanded(
                      child: _buildHallSelection(_selectedHostel?.id ?? ''),
                    ),
                  ] else if (_selectedFloor == null) ...[
                    Expanded(
                      child: _buildFloorSelection(_selectedHall?.id ?? ''),
                    ),
                  ] else ...[
                    Expanded(
                      child: _buildRoomSelection(_selectedFloor?.id ?? ''),
                    ),
                  ],

                  // Selection Summary
                  if (_selectedRoom != null) _buildSelectionSummary(),
                ],
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error loading data: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.refresh(currentUserProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHostelSelection(String gender) {
    final hostelService = ref.watch(hostelServiceProvider);

    return StreamBuilder<List<HostelModel>>(
      stream: hostelService.getHostelsForStudent(
          ref.read(currentUserProvider).when(
                data: (u) => u?.year ?? '',
                loading: () => '',
                error: (_, __) => '',
              ),
          gender),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text('Error loading hostels: ${snapshot.error}'),
              ],
            ),
          );
        }

        final hostels = snapshot.data ?? [];

        if (hostels.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.home_work, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('No hostels available for your gender'),
              ],
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Select Hostel',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: hostels.length,
                itemBuilder: (context, index) {
                  final hostel = hostels[index];
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.home_work),
                      title: Text(hostel.name),
                      subtitle: Text(hostel.description),
                      trailing: const Icon(Icons.arrow_forward_ios),
                      onTap: () {
                        setState(() => _selectedHostel = hostel);
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHallSelection(String hostelId) {
    final hallService = ref.watch(hallFloorRoomServiceProvider);

    return StreamBuilder<List<HallModel>>(
      stream: hallService.getHallsForHostel(hostelId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text('Error loading halls: ${snapshot.error}'),
              ],
            ),
          );
        }

        final halls = snapshot.data ?? [];

        if (halls.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.meeting_room_outlined, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                Text(
                  'No halls available for this hostel',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () {
                      setState(() => _selectedHostel = null);
                    },
                  ),
                  Text(
                    'Select Hall - ${_selectedHostel?.name}',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: halls.length,
                itemBuilder: (context, index) {
                  final hall = halls[index];
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.meeting_room),
                      title: Text(hall.name),
                      subtitle: Text(hall.description ?? ''),
                      trailing: const Icon(Icons.arrow_forward_ios),
                      onTap: () {
                        setState(() => _selectedHall = hall);
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFloorSelection(String hallId) {
    final hallService = ref.watch(hallFloorRoomServiceProvider);

    return StreamBuilder<List<FloorModel>>(
      stream: hallService.getFloorsForHall(hallId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text('Error loading floors: ${snapshot.error}'),
              ],
            ),
          );
        }

        final floors = snapshot.data ?? [];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Back button
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () {
                      setState(() => _selectedHall = null);
                    },
                  ),
                  Text(
                    'Select Floor - ${_selectedHall?.name}',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: floors.length,
                itemBuilder: (context, index) {
                  final floor = floors[index];
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.layers),
                      title: Text(floor.name),
                      subtitle: Text('Floor ${floor.floorNumber}'),
                      trailing: const Icon(Icons.arrow_forward_ios),
                      onTap: () {
                        setState(() => _selectedFloor = floor);
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildRoomSelection(String floorId) {
    final hallService = ref.watch(hallFloorRoomServiceProvider);

    return StreamBuilder<List<RoomModel>>(
      stream: hallService.getRoomsForFloor(floorId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text('Error loading rooms: ${snapshot.error}'),
              ],
            ),
          );
        }

        final rooms = snapshot.data ?? [];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Back button
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () {
                      setState(() {
                        _selectedFloor = null;
                        _selectedRoom = null;
                      });
                    },
                  ),
                  Text(
                    'Select Room - ${_selectedFloor?.name}',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: rooms.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.room, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text('No available rooms on this floor'),
                        ],
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 1.2,
                      ),
                      itemCount: rooms.length,
                      itemBuilder: (context, index) {
                        final room = rooms[index];
                        final isSelected = _selectedRoom?.id == room.id;

                        return Card(
                          color: isSelected
                              ? AppTheme.primaryColor.withValues(alpha:0.1)
                              : null,
                          child: InkWell(
                            onTap: () {
                              setState(() => _selectedRoom = room);
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.room,
                                    size: 32,
                                    color: isSelected
                                        ? AppTheme.primaryColor
                                        : Colors.grey[600],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Room ${room.name}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: isSelected
                                              ? AppTheme.primaryColor
                                              : null,
                                        ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Capacity: ${room.capacity} beds',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: Colors.grey[600],
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSelectionSummary() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedHostel?.name ?? '',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_selectedHall?.name ?? ''} • ${_selectedFloor?.name ?? ''}',
                        style: Theme.of(context).textTheme.bodySmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Room ${_selectedRoom?.name ?? ''}',
                        style: Theme.of(context).textTheme.bodySmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Capacity: ${_selectedRoom?.capacity ?? 0} beds',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _isLoading ? null : _confirmRoomSelection,
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Confirm'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmRoomSelection() async {
    if (_selectedRoom == null) return;

    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final currentUser = ref.read(currentUserProvider).value;
      if (currentUser == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('User not found. Please log in again.'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
        return;
      }

      final hostelService = ref.read(hostelServiceProvider);
      
      HostelApplicationModel? application;
      try {
        application = await hostelService.getUserApplication(currentUser.uid);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error loading application: $e'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
        return;
      }

      if (application == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No application found. Please submit an application first.'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
        return;
      }

      // Check if room is still available before confirming
      final room = _selectedRoom;
      if (room == null || !room.isAvailable || room.occupied >= room.capacity) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('This room is no longer available. Please select another room.'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
        return;
      }

      // Create a room request for admin approval instead of directly assigning
      await hostelService.createRoomRequest(
        applicationId: application.id,
        studentId: currentUser.uid,
        roomId: _selectedRoom?.id ?? '',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Room selection submitted for admin approval'),
            backgroundColor: AppTheme.successColor,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error assigning room: ${e.toString()}'),
            backgroundColor: AppTheme.errorColor,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}




