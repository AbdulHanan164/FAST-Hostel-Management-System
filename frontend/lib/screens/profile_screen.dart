import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/profile_service.dart';
import '../providers/auth_provider.dart';
import '../models/user_model.dart';
import '../config/theme.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _rollNumberController;
  Gender? _selectedGender;
  bool _isLoading = false;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _phoneController = TextEditingController();
    _emailController = TextEditingController();
    _rollNumberController = TextEditingController();
    _loadProfile();

    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _animController.forward();
  }

  Future<void> _loadProfile() async {
    final currentUser = ref.read(currentUserProvider).value;
    if (currentUser != null) {
      setState(() {
        _nameController.text = currentUser.name;
        _phoneController.text = currentUser.phone;
        _emailController.text = currentUser.email;
        _rollNumberController.text = currentUser.arnRollNumber;
        _selectedGender = currentUser.gender;
      });
    }
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedGender == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select your gender')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final profileService = ref.read(profileServiceProvider);
      final userId = ref.read(currentUserProvider).value?.uid;
      if (userId != null) {
        await profileService.updateProfile(userId, {
          'name': _nameController.text.trim(),
          'phone': _phoneController.text.trim(),
          'email': _emailController.text.trim(),
          'arnRollNumber': _rollNumberController.text.trim(),
          'gender': _selectedGender.toString().split('.').last,
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile updated successfully'), backgroundColor: AppColors.success),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error updating profile: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool _isFieldMissing(String? value) => value == null || value.isEmpty;

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider).value;
    final initials = currentUser != null && currentUser.name.isNotEmpty
        ? currentUser.name.trim().split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join().toUpperCase()
        : '?';

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
          '👤 My Profile',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SlideTransition(
          position: _slideAnim,
          child: SingleChildScrollView(
            child: Column(
              children: [
                // ── Gradient avatar header ──────────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.primaryDark, AppColors.primary, AppColors.primaryLight],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.25),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 2),
                        ),
                        child: Center(
                          child: Text(
                            initials,
                            style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        currentUser?.name ?? 'Student',
                        style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        currentUser?.email ?? '',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.80), fontSize: 13),
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Profile completion status
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, 4))],
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Text('📊', style: TextStyle(fontSize: 18)),
                                SizedBox(width: 8),
                                Text('Profile Completion', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.textPrimary)),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _buildFieldIndicator('Gender', currentUser?.gender.toString().split('.').last),
                            _buildFieldIndicator('Email', currentUser?.email),
                            _buildFieldIndicator('Roll Number', currentUser?.arnRollNumber),
                            _buildFieldIndicator('Phone Number', currentUser?.phone),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      const Row(
                        children: [
                          Text('✏️', style: TextStyle(fontSize: 18)),
                          SizedBox(width: 8),
                          Text('Update Profile', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                        ],
                      ),
                      const SizedBox(height: 14),

                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, 4))],
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              TextFormField(
                                controller: _nameController,
                                decoration: const InputDecoration(
                                  labelText: 'Full Name',
                                  prefixIcon: Text('  👤  ', style: TextStyle(fontSize: 18)),
                                  prefixIconConstraints: BoxConstraints(minWidth: 48, minHeight: 48),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) return 'Please enter your name';
                                  return null;
                                },
                              ),
                              const SizedBox(height: 14),

                              DropdownButtonFormField<Gender>(
                                value: _selectedGender,
                                decoration: const InputDecoration(
                                  labelText: 'Gender',
                                  prefixIcon: Text('  ⚧️  ', style: TextStyle(fontSize: 18)),
                                  prefixIconConstraints: BoxConstraints(minWidth: 48, minHeight: 48),
                                ),
                                items: Gender.values.map((gender) {
                                  return DropdownMenuItem(
                                    value: gender,
                                    child: Text(gender.toString().split('.').last.toUpperCase()),
                                  );
                                }).toList(),
                                onChanged: (value) => setState(() => _selectedGender = value),
                                validator: (value) {
                                  if (value == null) return 'Please select your gender';
                                  return null;
                                },
                              ),
                              const SizedBox(height: 14),

                              TextFormField(
                                controller: _emailController,
                                decoration: const InputDecoration(
                                  labelText: 'Email',
                                  prefixIcon: Text('  📧  ', style: TextStyle(fontSize: 18)),
                                  prefixIconConstraints: BoxConstraints(minWidth: 48, minHeight: 48),
                                ),
                                keyboardType: TextInputType.emailAddress,
                                validator: (value) {
                                  if (value == null || value.isEmpty) return 'Please enter your email';
                                  if (!value.contains('@')) return 'Please enter a valid email';
                                  return null;
                                },
                              ),
                              const SizedBox(height: 14),

                              TextFormField(
                                controller: _rollNumberController,
                                decoration: const InputDecoration(
                                  labelText: 'Roll Number',
                                  hintText: 'e.g., 24A-1234',
                                  prefixIcon: Text('  🎫  ', style: TextStyle(fontSize: 18)),
                                  prefixIconConstraints: BoxConstraints(minWidth: 48, minHeight: 48),
                                  helperText: 'Format: XXN-XXXX (e.g., 24A-1234)',
                                ),
                                textCapitalization: TextCapitalization.characters,
                                validator: (value) {
                                  if (value == null || value.isEmpty) return 'Please enter your roll number';
                                  final pattern = RegExp(r'^\d{2}[A-Za-z]-\d{4}$');
                                  if (!pattern.hasMatch(value.toUpperCase())) return 'Invalid format. Use XXN-XXXX (e.g., 24A-1234)';
                                  return null;
                                },
                              ),
                              const SizedBox(height: 14),

                              TextFormField(
                                controller: _phoneController,
                                decoration: const InputDecoration(
                                  labelText: 'Phone Number',
                                  prefixIcon: Text('  📞  ', style: TextStyle(fontSize: 18)),
                                  prefixIconConstraints: BoxConstraints(minWidth: 48, minHeight: 48),
                                ),
                                keyboardType: TextInputType.phone,
                                validator: (value) {
                                  if (value == null || value.isEmpty) return 'Please enter your phone number';
                                  return null;
                                },
                              ),

                              const SizedBox(height: 20),

                              GestureDetector(
                                onTap: _isLoading ? null : _updateProfile,
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
                                      : const Text('💾 Update Profile', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFieldIndicator(String label, String? value, {bool isRequired = true}) {
    final isMissing = isRequired && _isFieldMissing(value);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isMissing ? AppColors.warning.withValues(alpha: 0.08) : AppColors.success.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isMissing ? AppColors.warning.withValues(alpha: 0.4) : AppColors.success.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          Text(isMissing ? '⚠️' : '✅', style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$label: ${isMissing ? "Missing" : "Complete"}',
              style: TextStyle(
                color: isMissing ? AppColors.warning : AppColors.success,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _rollNumberController.dispose();
    _animController.dispose();
    super.dispose();
  }
}
