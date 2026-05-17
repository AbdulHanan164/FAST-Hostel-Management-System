import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;

import '../../config/theme.dart';
import '../../config/app_keys.dart';
import '../../services/otp_service.dart';

// ---------------------------------------------------------------------------
// Data carrier passed via GoRouter `extra`
// ---------------------------------------------------------------------------
class ForgotPasswordOtpData {
  final String email;
  final String otp;
  const ForgotPasswordOtpData({required this.email, required this.otp});
}

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------
class ForgotPasswordOtpScreen extends StatefulWidget {
  final ForgotPasswordOtpData data;
  const ForgotPasswordOtpScreen({super.key, required this.data});

  @override
  State<ForgotPasswordOtpScreen> createState() =>
      _ForgotPasswordOtpScreenState();
}

class _ForgotPasswordOtpScreenState extends State<ForgotPasswordOtpScreen>
    with SingleTickerProviderStateMixin {
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  bool _isVerifying = false;
  bool _isResending = false;
  int  _secondsLeft = 600;
  Timer? _timer;
  late String _currentOtp;

  late AnimationController _animController;
  late Animation<double>   _fadeAnim;
  late Animation<Offset>   _slideAnim;

  @override
  void initState() {
    super.initState();
    _currentOtp = widget.data.otp;
    _startTimer();

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
    _timer?.cancel();
    for (final c in _controllers) { c.dispose(); }
    for (final f in _focusNodes)  { f.dispose(); }
    _animController.dispose();
    super.dispose();
  }

  // ── Timer ─────────────────────────────────────────────────────────────────
  void _startTimer() {
    _secondsLeft = 600;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        if (_secondsLeft > 0) {
          _secondsLeft--;
        } else {
          t.cancel();
        }
      });
    });
  }

  String get _timerLabel {
    final m = _secondsLeft ~/ 60;
    final s = _secondsLeft % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  bool get _canResend => _secondsLeft == 0;
  String get _enteredOtp => _controllers.map((c) => c.text).join();

  void _clearOtp() {
    for (final c in _controllers) { c.clear(); }
    _focusNodes.first.requestFocus();
  }

  void _onDigitChanged(int index, String value) {
    if (value.length == 1 && index < 5) _focusNodes[index + 1].requestFocus();
    if (_enteredOtp.length == 6) _verifyOtp();
  }

  void _onKeyEvent(int index, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        _controllers[index].text.isEmpty &&
        index > 0) {
      _focusNodes[index - 1].requestFocus();
      _controllers[index - 1].clear();
    }
  }

  // ── Verify ────────────────────────────────────────────────────────────────
  Future<void> _verifyOtp() async {
    if (_isVerifying) return;
    final entered = _enteredOtp;
    if (entered.length < 6) {
      AppKeys.scaffoldMessengerKey.currentState?.showSnackBar(const SnackBar(
        content: Text('Please enter all 6 digits.'),
        backgroundColor: AppTheme.errorColor,
      ));
      return;
    }
    if (entered != _currentOtp) {
      AppKeys.scaffoldMessengerKey.currentState?.showSnackBar(const SnackBar(
        content: Text('Incorrect code. Please check your email and try again.'),
        backgroundColor: AppTheme.errorColor,
        duration: Duration(seconds: 4),
      ));
      _clearOtp();
      return;
    }

    // OTP correct — go to reset password screen
    context.push('/auth/reset-password', extra: widget.data.email);
  }

  // ── Resend ────────────────────────────────────────────────────────────────
  Future<void> _resendOtp() async {
    if (!_canResend || _isResending) return;
    setState(() => _isResending = true);
    try {
      final newOtp = OtpService.generateOtp();

      final response = await http.post(
        Uri.parse('http://localhost:8000/check-email'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email':    widget.data.email,
          'otp_code': newOtp,
          'to_name':  'Student',
        }),
      ).timeout(const Duration(seconds: 15));

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200 && body['success'] == true) {
        _currentOtp = newOtp;
        _clearOtp();
        _startTimer();
        AppKeys.scaffoldMessengerKey.currentState?.showSnackBar(const SnackBar(
          content: Text('A new reset code has been sent to your email.'),
          backgroundColor: AppTheme.successColor,
        ));
      } else {
        AppKeys.scaffoldMessengerKey.currentState?.showSnackBar(SnackBar(
          content: Text(body['message']?.toString() ?? 'Failed to resend code.'),
          backgroundColor: AppTheme.errorColor,
        ));
      }
    } catch (e) {
      AppKeys.scaffoldMessengerKey.currentState?.showSnackBar(SnackBar(
        content: Text(e.toString().replaceFirst('Exception: ', '')),
        backgroundColor: AppTheme.errorColor,
      ));
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────
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
                  final isWide = constraints.maxWidth >= 600;
                  final cardPadding = isWide ? 40.0 : 28.0;

                  Widget content = Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(children: [
                        IconButton(
                          onPressed: () => context.pop(),
                          icon: const Icon(Icons.arrow_back_ios,
                              color: Colors.white, size: 20),
                        ),
                        const Spacer(),
                      ]),
                      const SizedBox(height: 8),

                      Container(
                        width: 80, height: 80,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.mark_email_read_outlined,
                            size: 40, color: Colors.white),
                      ),
                      const SizedBox(height: 20),

                      const Text(
                        'Check Your Email',
                        style: TextStyle(
                          color: Colors.white, fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Enter the 6-digit reset code sent to',
                        style: TextStyle(
                          color: Colors.white70, fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.data.email,
                        style: const TextStyle(
                          color: AppColors.accent, fontSize: 14,
                          fontWeight: FontWeight.w700,
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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // 6 OTP boxes
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: List.generate(6, (i) => _OtpBox(
                                controller: _controllers[i],
                                focusNode:  _focusNodes[i],
                                onChanged:  (v) => _onDigitChanged(i, v),
                                onKeyEvent: (e) => _onKeyEvent(i, e),
                              )),
                            ),

                            const SizedBox(height: 24),

                            // Timer
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.timer_outlined, size: 16,
                                    color: _secondsLeft <= 60
                                        ? AppColors.error
                                        : AppColors.textSecondary),
                                const SizedBox(width: 6),
                                Text(
                                  _secondsLeft > 0
                                      ? 'Code expires in $_timerLabel'
                                      : 'Code expired',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: _secondsLeft <= 60
                                        ? AppColors.error
                                        : AppColors.textSecondary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 24),

                            // Verify button
                            GestureDetector(
                              onTap: _isVerifying ? null : _verifyOtp,
                              child: Container(
                                height: 52,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: _isVerifying
                                        ? [
                                            AppColors.primary.withValues(alpha: 0.5),
                                            AppColors.primaryLight.withValues(alpha: 0.5),
                                          ]
                                        : const [AppColors.primary, AppColors.primaryLight],
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: _isVerifying ? null : [
                                    BoxShadow(
                                      color: AppColors.primary.withValues(alpha: 0.3),
                                      blurRadius: 12, offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                alignment: Alignment.center,
                                child: _isVerifying
                                    ? const SizedBox(
                                        width: 22, height: 22,
                                        child: CircularProgressIndicator(
                                          color: Colors.white, strokeWidth: 2.5,
                                        ),
                                      )
                                    : const Text(
                                        'Verify Code',
                                        style: TextStyle(
                                          color: Colors.white, fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                              ),
                            ),

                            const SizedBox(height: 16),

                            // Resend row
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text(
                                  "Didn't receive it? ",
                                  style: TextStyle(
                                    color: AppColors.textSecondary, fontSize: 13,
                                  ),
                                ),
                                GestureDetector(
                                  onTap: _canResend && !_isResending
                                      ? _resendOtp
                                      : null,
                                  child: _isResending
                                      ? const SizedBox(
                                          width: 14, height: 14,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: AppColors.primary,
                                          ),
                                        )
                                      : Text(
                                          _canResend
                                              ? 'Resend Code'
                                              : 'Resend in $_timerLabel',
                                          style: TextStyle(
                                            color: _canResend
                                                ? AppColors.primary
                                                : AppColors.textSecondary,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                ),
                              ],
                            ),
                          ],
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

// ---------------------------------------------------------------------------
// Single OTP digit box (same as signup OTP screen)
// ---------------------------------------------------------------------------
class _OtpBox extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final ValueChanged<KeyEvent> onKeyEvent;

  const _OtpBox({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onKeyEvent,
  });

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: FocusNode(),
      onKeyEvent: onKeyEvent,
      child: SizedBox(
        width: 46, height: 56,
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          maxLength: 1,
          style: const TextStyle(
            fontSize: 22, fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
          decoration: InputDecoration(
            counterText: '',
            contentPadding: EdgeInsets.zero,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.border, width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primary, width: 2),
            ),
            filled: true,
            fillColor: AppColors.surfaceAlt,
          ),
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: onChanged,
        ),
      ),
    );
  }
}
