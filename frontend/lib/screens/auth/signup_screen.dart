import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/user_model.dart';
import '../../config/theme.dart';
import '../../config/app_keys.dart';
import '../../services/otp_service.dart';
import 'loading_auth_screen.dart';
import 'otp_verification_screen.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _fathersNameController = TextEditingController();
  final _arnRollController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  static const String _adminEmail = 'fasthostel3@gmail.com';

  Gender _selectedGender = Gender.male;
  bool _agreeToTerms = false;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _animController.forward();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _fathersNameController.dispose();
    _arnRollController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _animController.dispose();
    super.dispose();
  }

  bool _isValidInstitutionEmail(String email) {
    final lower = email.toLowerCase();
    if (lower == _adminEmail) return true;
    return lower.endsWith('@cfd.nu.edu.pk');
  }

  Future<void> _sendOtp() async {
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim();
    final messenger = AppKeys.scaffoldMessengerKey.currentState;

    if (!_agreeToTerms) {
      messenger?.showSnackBar(
        const SnackBar(
          content: Text('You must agree to the Hostel Rules and Regulations.'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    if (!_isValidInstitutionEmail(email)) {
      messenger?.showSnackBar(
        const SnackBar(
          content: Text('Only @cfd.nu.edu.pk emails (or admin email) are allowed to sign up.'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    // Show sending indicator
    if (mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => const LoadingAuthScreen(message: 'Sending verification code...'),
          fullscreenDialog: true,
        ),
      );
    }

    try {
      final otp = OtpService.generateOtp();
      await OtpService.sendOtpEmail(
        email: email,
        otp: otp,
        recipientName: _nameController.text.trim(),
      );

      if (!mounted) return;
      Navigator.of(context).pop(); // close loading screen

      // Navigate to OTP verification screen with all form data
      context.push(
        '/auth/verify-otp',
        extra: OtpSignupData(
          email: email,
          password: _passwordController.text,
          name: _nameController.text.trim(),
          fathersName: _fathersNameController.text.trim(),
          arnRollNumber: _arnRollController.text.trim().toUpperCase(),
          phone: _phoneController.text.trim(),
          gender: _selectedGender,
          agreeToTerms: _agreeToTerms,
          otp: otp,
        ),
      );
    } catch (e) {
      debugPrint('Send OTP failed: $e');
      if (mounted) Navigator.of(context).pop();
      String errorMessage = e.toString().replaceFirst('Exception: ', '');
      if (errorMessage.contains('network') || errorMessage.contains('Network')) {
        errorMessage = 'Network error. Please check your internet connection and try again.';
      }
      messenger?.showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: AppTheme.errorColor,
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _sectionLabel(IconData icon, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 600;
                  final cardPadding = isWide ? 36.0 : 24.0;
                  final hPad = isWide ? 0.0 : 20.0;

                  Widget content = Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                    // ── Hero header ────────────────────────────────────────
                          Row(
                            children: [
                              IconButton(
                                onPressed: () => context.pop(),
                                icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
                              ),
                              const Spacer(),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Image.asset(
                            'assets/images/fast_logo-removebg-preview.png',
                            width: 72,
                            height: 72,
                            fit: BoxFit.contain,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Create Account',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Join FAST Hostel System',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.80),
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 24),

                    // ── White card form ────────────────────────────────────
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(cardPadding),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(isWide ? 24 : 20),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryDark.withValues(alpha: 0.25),
                            blurRadius: 32,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _sectionLabel(Icons.person_outline, 'Personal Information'),

                            TextFormField(
                              controller: _nameController,
                              decoration: const InputDecoration(
                                labelText: 'Full Name',
                                prefixIcon: Icon(Icons.person_outline),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) return 'Please enter your full name';
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),

                            TextFormField(
                              controller: _fathersNameController,
                              decoration: const InputDecoration(
                                labelText: "Father's Name",
                                prefixIcon: Icon(Icons.person_outline),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) return "Please enter your father's name";
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),

                            TextFormField(
                              controller: _arnRollController,
                              decoration: const InputDecoration(
                                labelText: 'Roll Number',
                                hintText: 'e.g., 24A-1234',
                                prefixIcon: Icon(Icons.badge_outlined),
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
                              keyboardType: TextInputType.phone,
                              decoration: const InputDecoration(
                                labelText: 'Phone Number',
                                prefixIcon: Icon(Icons.phone_outlined),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) return 'Please enter your phone number';
                                final cleaned = value.replaceAll(RegExp(r'[\s-]'), '');
                                if (!RegExp(r'^[0-9]{10,15}$').hasMatch(cleaned)) return 'Please enter a valid phone number (10-15 digits)';
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            // Gender toggle chips
                            const Text(
                              'Gender',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => setState(() => _selectedGender = Gender.male),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      decoration: BoxDecoration(
                                        color: _selectedGender == Gender.male
                                            ? AppColors.primary
                                            : AppColors.surfaceAlt,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: _selectedGender == Gender.male
                                              ? AppColors.primary
                                              : AppColors.divider,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.male,
                                            size: 20,
                                            color: _selectedGender == Gender.male ? Colors.white : AppColors.textPrimary,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Male',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              color: _selectedGender == Gender.male
                                                  ? Colors.white
                                                  : AppColors.textPrimary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => setState(() => _selectedGender = Gender.female),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      decoration: BoxDecoration(
                                        color: _selectedGender == Gender.female
                                            ? AppColors.primary
                                            : AppColors.surfaceAlt,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: _selectedGender == Gender.female
                                              ? AppColors.primary
                                              : AppColors.divider,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.female,
                                            size: 20,
                                            color: _selectedGender == Gender.female ? Colors.white : AppColors.textPrimary,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Female',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              color: _selectedGender == Gender.female
                                                  ? Colors.white
                                                  : AppColors.textPrimary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 24),
                            _sectionLabel(Icons.lock_outline, 'Account Information'),

                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: const InputDecoration(
                                labelText: 'University Email',
                                hintText: 'student@cfd.nu.edu.pk',
                                prefixIcon: Icon(Icons.email_outlined),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) return 'Please enter your email';
                                if (!_isValidInstitutionEmail(value.trim())) return 'Use your @cfd.nu.edu.pk email (or admin email) to sign up';
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),

                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              decoration: InputDecoration(
                                labelText: 'Password',
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                    color: AppColors.textSecondary,
                                  ),
                                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) return 'Please enter a password';
                                if (value.length < 8) return 'Password must be at least 8 characters';
                                if (!value.contains(RegExp(r'[A-Z]'))) return 'Password must contain at least one uppercase letter';
                                if (!value.contains(RegExp(r'[a-z]'))) return 'Password must contain at least one lowercase letter';
                                if (!value.contains(RegExp(r'[0-9]'))) return 'Password must contain at least one number';
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),

                            TextFormField(
                              controller: _confirmPasswordController,
                              obscureText: _obscureConfirmPassword,
                              decoration: InputDecoration(
                                labelText: 'Confirm Password',
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscureConfirmPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                    color: AppColors.textSecondary,
                                  ),
                                  onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) return 'Please confirm your password';
                                if (value != _passwordController.text) return 'Passwords do not match';
                                return null;
                              },
                            ),

                            const SizedBox(height: 16),

                            // Terms checkbox
                            GestureDetector(
                              onTap: () => setState(() => _agreeToTerms = !_agreeToTerms),
                              child: Row(
                                children: [
                                  Container(
                                    width: 22,
                                    height: 22,
                                    decoration: BoxDecoration(
                                      color: _agreeToTerms ? AppColors.primary : Colors.white,
                                      borderRadius: BorderRadius.circular(5),
                                      border: Border.all(
                                        color: _agreeToTerms ? AppColors.primary : AppColors.border,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: _agreeToTerms
                                        ? const Icon(Icons.check, size: 14, color: Colors.white)
                                        : null,
                                  ),
                                  const SizedBox(width: 10),
                                  const Expanded(
                                    child: Text(
                                      'I agree with the Hostel Rules and Regulations',
                                      style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 24),

                            // Gradient button
                            GestureDetector(
                              onTap: _isLoading ? null : _sendOtp,
                              child: Container(
                                height: 54,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: _isLoading
                                        ? [
                                            AppColors.primary.withValues(alpha: 0.5),
                                            AppColors.primaryLight.withValues(alpha: 0.5),
                                          ]
                                        : const [AppColors.primary, AppColors.primaryLight],
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: _isLoading
                                      ? null
                                      : [
                                          BoxShadow(
                                            color: AppColors.primary.withValues(alpha: 0.3),
                                            blurRadius: 12,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                ),
                                alignment: Alignment.center,
                                child: _isLoading
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                      )
                                    : const Text(
                                        'Send Verification Code',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // ── Login link ─────────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.only(top: 20),
                      child: GestureDetector(
                        onTap: () => context.push('/auth/login'),
                        child: RichText(
                          text: const TextSpan(
                            text: 'Already have an account? ',
                            style: TextStyle(color: Colors.white70, fontSize: 14),
                            children: [
                              TextSpan(
                                text: 'Sign In',
                                style: TextStyle(
                                  color: AppColors.accent,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    ],
                  );

                  return isWide
                      ? Center(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.symmetric(vertical: 32),
                            child: SizedBox(width: 500, child: content),
                          ),
                        )
                      : SingleChildScrollView(
                          padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 24),
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
