import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;

import '../../config/theme.dart';
import '../../config/app_keys.dart';
import 'loading_auth_screen.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String email;
  const ResetPasswordScreen({super.key, required this.email});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen>
    with SingleTickerProviderStateMixin {
  final _formKey      = GlobalKey<FormState>();
  final _passCtrl     = TextEditingController();
  final _confirmCtrl  = TextEditingController();
  bool _isLoading     = false;
  bool _obscurePass   = true;
  bool _obscureConfirm = true;

  late AnimationController _animController;
  late Animation<double>   _fadeAnim;
  late Animation<Offset>   _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 450),
    );
    _fadeAnim  = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.08), end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _animController.forward();
  }

  @override
  void dispose() {
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) return;
    final messenger = AppKeys.scaffoldMessengerKey.currentState;

    setState(() => _isLoading = true);
    if (mounted) {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) =>
            const LoadingAuthScreen(message: 'Updating password...'),
        fullscreenDialog: true,
      ));
    }

    try {
      final response = await http.post(
        Uri.parse('http://localhost:8000/reset-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email':        widget.email,
          'new_password': _passCtrl.text,
        }),
      ).timeout(const Duration(seconds: 15));

      final body = jsonDecode(response.body) as Map<String, dynamic>;

      if (!mounted) return;
      Navigator.of(context).pop(); // dismiss loading

      if (response.statusCode == 200 && body['success'] == true) {
        messenger?.showSnackBar(const SnackBar(
          content: Text(
            'Password updated successfully! Please sign in with your new password.',
          ),
          backgroundColor: AppTheme.successColor,
          duration: Duration(seconds: 4),
        ));
        // Clear entire navigation stack and go to login
        context.go('/auth/login');
      } else {
        messenger?.showSnackBar(SnackBar(
          content: Text(
            body['message']?.toString() ??
                'Failed to update password. Please try again.',
          ),
          backgroundColor: AppTheme.errorColor,
          duration: const Duration(seconds: 5),
        ));
      }
    } on http.ClientException {
      if (mounted) Navigator.of(context).pop();
      messenger?.showSnackBar(const SnackBar(
        content: Text(
          'Cannot connect to server. '
          'Make sure the backend is running (backend/email_api/start.bat).',
        ),
        backgroundColor: AppTheme.errorColor,
        duration: Duration(seconds: 5),
      ));
    } catch (e) {
      if (mounted) Navigator.of(context).pop();
      messenger?.showSnackBar(SnackBar(
        content: Text(e.toString().replaceFirst('Exception: ', '')),
        backgroundColor: AppTheme.errorColor,
        duration: const Duration(seconds: 5),
      ));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.primaryDark, AppColors.primary, AppColors.primaryLight],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: SlideTransition(
              position: _slideAnim,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWide      = constraints.maxWidth >= 600;
                  final cardPadding = isWide ? 40.0 : 28.0;

                  Widget content = Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // No back button — this is a one-way screen after OTP
                      const SizedBox(height: 16),

                      // Icon
                      Container(
                        width: 80, height: 80,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.lock_outline,
                            size: 40, color: Colors.white),
                      ),
                      const SizedBox(height: 20),

                      const Text(
                        'Set New Password',
                        style: TextStyle(
                          color: Colors.white, fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        widget.email,
                        style: const TextStyle(
                          color: AppColors.accent, fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 28),

                      // White card
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(cardPadding),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(isWide ? 24 : 20),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primaryDark.withValues(alpha: 0.25),
                              blurRadius: 32, offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text(
                                'Create a new password',
                                style: TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Your new password must be at least 8 characters and include uppercase, lowercase, and a number.',
                                style: TextStyle(
                                  fontSize: 13, color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 24),

                              // New password
                              TextFormField(
                                controller: _passCtrl,
                                obscureText: _obscurePass,
                                decoration: InputDecoration(
                                  labelText: 'New Password',
                                  prefixIcon: const Icon(Icons.lock_outline),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePass
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                      color: AppColors.textSecondary,
                                    ),
                                    onPressed: () => setState(
                                        () => _obscurePass = !_obscurePass),
                                  ),
                                ),
                                validator: (v) {
                                  if (v == null || v.isEmpty) {
                                    return 'Please enter a new password';
                                  }
                                  if (v.length < 8) {
                                    return 'Password must be at least 8 characters';
                                  }
                                  if (!v.contains(RegExp(r'[A-Z]'))) {
                                    return 'Must contain at least one uppercase letter';
                                  }
                                  if (!v.contains(RegExp(r'[a-z]'))) {
                                    return 'Must contain at least one lowercase letter';
                                  }
                                  if (!v.contains(RegExp(r'[0-9]'))) {
                                    return 'Must contain at least one number';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),

                              // Confirm password
                              TextFormField(
                                controller: _confirmCtrl,
                                obscureText: _obscureConfirm,
                                decoration: InputDecoration(
                                  labelText: 'Confirm New Password',
                                  prefixIcon: const Icon(Icons.lock_outline),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscureConfirm
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                      color: AppColors.textSecondary,
                                    ),
                                    onPressed: () => setState(() =>
                                        _obscureConfirm = !_obscureConfirm),
                                  ),
                                ),
                                validator: (v) {
                                  if (v == null || v.isEmpty) {
                                    return 'Please confirm your password';
                                  }
                                  if (v != _passCtrl.text) {
                                    return 'Passwords do not match';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 28),

                              // Update button
                              GestureDetector(
                                onTap: _isLoading ? null : _resetPassword,
                                child: Container(
                                  height: 52,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: _isLoading
                                          ? [
                                              AppColors.primary
                                                  .withValues(alpha: 0.5),
                                              AppColors.primaryLight
                                                  .withValues(alpha: 0.5),
                                            ]
                                          : const [
                                              AppColors.primary,
                                              AppColors.primaryLight,
                                            ],
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: _isLoading ? null : [
                                      BoxShadow(
                                        color: AppColors.primary
                                            .withValues(alpha: 0.3),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  alignment: Alignment.center,
                                  child: _isLoading
                                      ? const SizedBox(
                                          width: 22, height: 22,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2.5,
                                          ),
                                        )
                                      : const Text(
                                          'Update Password',
                                          style: TextStyle(
                                            color: Colors.white, fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                ),
                              ),

                              const SizedBox(height: 18),

                              GestureDetector(
                                onTap: () => context.go('/auth/login'),
                                child: const Center(
                                  child: Text(
                                    'Back to Sign In',
                                    style: TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );

                  return isWide
                      ? Center(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.symmetric(vertical: 40),
                            child: SizedBox(width: 460, child: content),
                          ),
                        )
                      : SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 24),
                          child: content,
                        );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
