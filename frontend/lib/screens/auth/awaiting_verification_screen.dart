import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/auth_provider.dart';
import '../../config/theme.dart';

class AwaitingVerificationScreen extends ConsumerStatefulWidget {
  const AwaitingVerificationScreen({super.key});

  @override
  ConsumerState<AwaitingVerificationScreen> createState() => _AwaitingVerificationScreenState();
}

class _AwaitingVerificationScreenState extends ConsumerState<AwaitingVerificationScreen>
    with TickerProviderStateMixin {
  Timer? _pollTimer;
  bool _isSending = false;
  bool _checking = false;

  late AnimationController _fadeController;
  late AnimationController _pulseController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);

    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOut));
    _pulseAnim = Tween<double>(begin: 0.92, end: 1.08)
        .animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));

    _fadeController.forward();

    _pollTimer = Timer.periodic(const Duration(seconds: 6), (_) => _checkVerified());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _fadeController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _checkVerified() async {
    if (_checking || !mounted) return;
    setState(() => _checking = true);
    try {
      if (!mounted) return;
      final authService = ref.read(authServiceProvider);
      final verified = await authService.isEmailVerified();
      if (!mounted) return;

      if (verified) {
        final current = ref.read(currentUserProvider).when(
          data: (u) => u,
          loading: () => null,
          error: (_, __) => null,
        );

        if (current != null && mounted) {
          try {
            final userModel = await ref.read(authServiceProvider).getUser(current.uid);
            _pollTimer?.cancel();
            if (mounted) {
              if (userModel != null && userModel.email.contains('admin')) {
                context.go('/admin/dashboard');
              } else {
                context.go('/student/dashboard');
              }
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Email verified — welcome!')),
              );
            }
          } catch (_) {
            _pollTimer?.cancel();
            if (mounted) context.go('/auth/login');
          }
        } else {
          _pollTimer?.cancel();
          if (mounted) context.go('/auth/login');
        }
      }
    } catch (e) {
      // ignore errors during polling
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _resend() async {
    setState(() => _isSending = true);
    try {
      final authService = ref.read(authServiceProvider);
      await authService.sendEmailVerification();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Verification email resent')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to resend: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).asData?.value;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.primaryDark, AppColors.primary, AppColors.primaryLight],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: SlideTransition(
              position: _slideAnim,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    const SizedBox(height: 48),

                    // ── Pulsing envelope ───────────────────────────────────
                    ScaleTransition(
                      scale: _pulseAnim,
                      child: Container(
                        width: 110,
                        height: 110,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2),
                        ),
                        child: const Center(
                          child: Text('✉️', style: TextStyle(fontSize: 52)),
                        ),
                      ),
                    ),

                    const SizedBox(height: 28),

                    const Text(
                      'Verify Your Email',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'One last step! Check your inbox.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.80),
                        fontSize: 15,
                      ),
                    ),

                    const SizedBox(height: 32),

                    // ── Instructions card ──────────────────────────────────
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryDark.withValues(alpha: 0.25),
                            blurRadius: 32,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (user != null) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceAlt,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppColors.divider),
                              ),
                              child: Row(
                                children: [
                                  const Text('📧', style: TextStyle(fontSize: 18)),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      user.email,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textPrimary,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],

                          const Text(
                            'Steps to verify:',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 12),

                          _Step(number: '1', text: 'Open your university email inbox'),
                          const SizedBox(height: 8),
                          _Step(number: '2', text: 'Click the verification link in the email'),
                          const SizedBox(height: 8),
                          _Step(number: '3', text: 'Come back here — we\'ll detect it automatically'),

                          const SizedBox(height: 24),

                          // Resend button
                          GestureDetector(
                            onTap: _isSending ? null : _resend,
                            child: Container(
                              height: 54,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: _isSending
                                      ? [AppColors.primary.withValues(alpha: 0.5), AppColors.primaryLight.withValues(alpha: 0.5)]
                                      : const [AppColors.primary, AppColors.primaryLight],
                                ),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: _isSending
                                    ? null
                                    : [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))],
                              ),
                              alignment: Alignment.center,
                              child: _isSending
                                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                                  : const Text(
                                      '📤 Resend Verification Email',
                                      style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
                                    ),
                            ),
                          ),

                          const SizedBox(height: 12),

                          // I have verified button
                          GestureDetector(
                            onTap: _checking ? null : _checkVerified,
                            child: Container(
                              height: 54,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _checking ? AppColors.primary.withValues(alpha: 0.4) : AppColors.primary,
                                  width: 1.5,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: _checking
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2.5),
                                    )
                                  : const Text(
                                      '✅ I have verified',
                                      style: TextStyle(
                                        color: AppColors.primary,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                            ),
                          ),

                          const SizedBox(height: 16),

                          GestureDetector(
                            onTap: () async {
                              final authService = ref.read(authServiceProvider);
                              try {
                                await authService.signOut();
                              } catch (_) {}
                              if (mounted) context.go('/auth/login');
                            },
                            child: const Center(
                              child: Text(
                                '← Back to Login',
                                style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w600, fontSize: 14),
                              ),
                            ),
                          ),

                          const SizedBox(height: 16),

                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceAlt,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                const Text('🔄', style: TextStyle(fontSize: 14)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'We automatically check verification every 6 seconds.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.number, required this.text});
  final String number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [AppColors.primary, AppColors.primaryLight]),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            number,
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              text,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, height: 1.4),
            ),
          ),
        ),
      ],
    );
  }
}
