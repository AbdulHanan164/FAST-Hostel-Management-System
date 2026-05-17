import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/auth_provider.dart';
import '../../config/theme.dart';
import '../../config/app_keys.dart';
import '../../services/admin_service.dart';
import 'loading_auth_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _passwordEdited = false;
  bool _fieldsInitialized = false;
  String? _emailDomainError;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(_handlePasswordChanged);
    _emailController.addListener(_validateEmailDomain);

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
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_fieldsInitialized) {
      _resetInputFields(clearEmail: true);
      _fieldsInitialized = true;
    }
  }

  void _handlePasswordChanged() {
    if (!_passwordEdited && _passwordController.text.isNotEmpty) {
      _passwordEdited = true;
    }
  }

  void _resetInputFields({bool clearEmail = false}) {
    if (!mounted) return;
    if (clearEmail && _emailController.hasListeners) {
      _emailController.clear();
    }
    if (_passwordController.hasListeners) {
      _passwordController.clear();
    }
    _passwordEdited = false;
  }

  @override
  void dispose() {
    _passwordController.removeListener(_handlePasswordChanged);
    _emailController.removeListener(_validateEmailDomain);
    _emailController.dispose();
    _passwordController.dispose();
    _animController.dispose();
    super.dispose();
  }

  void _validateEmailDomain() {
    final value = _emailController.text.trim().toLowerCase();
    if (value.isEmpty) {
      if (_emailDomainError != null) setState(() => _emailDomainError = null);
      return;
    }
    if (!value.contains('@')) {
      if (_emailDomainError != null) setState(() => _emailDomainError = null);
      return;
    }
    final isValidDomain = value.endsWith('@cfd.nu.edu.pk') ||
        AdminService.isApprovedAdminEmail(_emailController.text.trim());
    final newError = isValidDomain
        ? null
        : 'Use your @cfd.nu.edu.pk email or an admin email';
    if (newError != _emailDomainError) {
      setState(() => _emailDomainError = newError);
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    final messenger = AppKeys.scaffoldMessengerKey.currentState;

    if (!_passwordEdited || _passwordController.text.trim().isEmpty) {
      messenger?.showSnackBar(
        const SnackBar(
          content: Text('Please enter your password to continue.'),
          backgroundColor: AppTheme.errorColor,
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    if (mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => const LoadingAuthScreen(message: 'Signing in...'),
          fullscreenDialog: true,
        ),
      );
    }

    try {
      debugPrint('Starting login process...');
      final authNotifier = ref.read(currentUserProvider.notifier);

      debugPrint('Calling authNotifier.signIn...');
      await authNotifier.signIn(
        _emailController.text.trim(),
        _passwordController.text,
      );
      debugPrint('authNotifier.signIn completed');

      if (!mounted) {
        debugPrint('Login screen disposed after signIn; aborting post-login flow.');
        return;
      }

      debugPrint('Checking Firebase Auth state...');

      final authService = ref.read(authServiceProvider);
      var authUser = authService.currentUser;

      if (authUser != null) {
        try {
          await authUser.reload();
          authUser = authService.currentUser;
        } catch (e) {
          debugPrint('Warning: Failed to reload user: $e');
        }
      }

      if (authUser == null) {
        debugPrint('Error: Firebase Auth user is null after login');
        if (mounted) Navigator.of(context).pop();
        messenger?.showSnackBar(
          const SnackBar(
            content: Text('Login failed. Please check your credentials and try again.'),
            backgroundColor: AppTheme.errorColor,
            duration: Duration(seconds: 5),
          ),
        );
        return;
      }

      if (!mounted) return;

      final currentUserAsync = ref.read(currentUserProvider);
      final userModel = currentUserAsync.value;

      if (userModel == null) {
        if (mounted) Navigator.of(context).pop();
        messenger?.showSnackBar(
          const SnackBar(
            content: Text('Login successful! Some profile features may be limited.'),
            backgroundColor: AppTheme.successColor,
            duration: Duration(seconds: 3),
          ),
        );
      } else {
        messenger?.showSnackBar(
          const SnackBar(
            content: Text('Login successful! Welcome back.'),
            backgroundColor: AppTheme.successColor,
            duration: Duration(seconds: 3),
          ),
        );
      }

      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        final currentRoute = ModalRoute.of(context)?.settings.name;
        if (currentRoute == '/auth/login' || currentRoute == null) {
          Navigator.of(context).pop();
        }
      }
    } catch (e, stackTrace) {
      debugPrint('Login error caught: $e');
      debugPrint('Stack trace: $stackTrace');

      if (mounted) Navigator.of(context).pop();

      String errorMessage = e.toString().replaceFirst('Exception: ', '');
      String errorCode = '';

      if (errorMessage.contains('Sign in failed:')) {
        final match = RegExp(r'Sign in failed:\s*(.+)').firstMatch(errorMessage);
        if (match != null) {
          errorCode = match.group(1)!.trim();
        }
      }

      if (errorCode == 'user-not-found' || errorMessage.contains('user-not-found') || errorMessage.contains('User not found')) {
        errorMessage = 'No account found with this email. Please sign up first.';
      } else if (errorCode == 'wrong-password' || errorCode == 'invalid-credential' ||
          errorMessage.contains('wrong-password') || errorMessage.contains('invalid-credential')) {
        errorMessage = 'Incorrect email or password. Please try again.';
      } else if (errorCode == 'invalid-email' || errorMessage.contains('invalid-email')) {
        errorMessage = 'Invalid email address. Please check your email format.';
      } else if (errorCode == 'user-disabled' || errorMessage.contains('user-disabled')) {
        errorMessage = 'This account has been disabled. Please contact support.';
      } else if (errorCode == 'too-many-requests' || errorMessage.contains('too-many-requests')) {
        errorMessage = 'Too many failed attempts. Please try again later.';
      } else if (errorCode == 'network-request-failed' || errorMessage.contains('network') || errorMessage.contains('unavailable')) {
        errorMessage = 'Network error. Please check your internet connection and try again.';
      } else if (errorMessage.contains('Please use a valid university email')) {
        errorMessage = 'Please use a valid university email (@cfd.nu.edu.pk)';
      } else {
        errorMessage = errorCode.isNotEmpty
            ? 'Login failed: $errorCode'
            : 'Login failed. Please check your credentials and try again.';
      }

      messenger?.showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: AppTheme.errorColor,
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        _resetInputFields();
      }
    }
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
                  final logoSize = isWide ? 88.0 : 72.0;
                  final titleSize = isWide ? 24.0 : 20.0;
                  final vertPadding = isWide ? 48.0 : 32.0;

                  Widget content = Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ── Hero ──────────────────────────────────────────
                      Image.asset(
                        'assets/images/fast_logo-removebg-preview.png',
                        width: logoSize,
                        height: logoSize,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'FAST Hostel System',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: titleSize,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Welcome back!',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.80),
                          fontSize: 14,
                        ),
                      ),
                      SizedBox(height: isWide ? 32 : 24),

                      // ── White card form ───────────────────────────────
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
                              Text(
                                'Sign In',
                                style: TextStyle(
                                  fontSize: isWide ? 22 : 20,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Enter your credentials to continue',
                                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                              ),
                              const SizedBox(height: 22),

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
                                  final lower = value.trim().toLowerCase();
                                  if (AdminService.isApprovedAdminEmail(value) || lower.endsWith('@cfd.nu.edu.pk')) return null;
                                  return 'Use your @cfd.nu.edu.pk email or admin email';
                                },
                              ),

                              if (_emailDomainError != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 6, left: 12),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.info_outline, size: 13, color: AppColors.error),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(_emailDomainError!,
                                            style: const TextStyle(fontSize: 12, color: AppColors.error)),
                                      ),
                                    ],
                                  ),
                                )
                              else
                                const Padding(
                                  padding: EdgeInsets.only(top: 6, left: 12),
                                  child: Text(
                                    'Use your @cfd.nu.edu.pk university email',
                                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                  ),
                                ),

                              const SizedBox(height: 16),

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
                                  if (value == null || value.isEmpty) return 'Please enter your password';
                                  if (value.length < 6) return 'Password must be at least 6 characters';
                                  return null;
                                },
                              ),

                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: () => context.push('/auth/forgot-password'),
                                  style: TextButton.styleFrom(
                                    foregroundColor: AppColors.accent,
                                    padding: EdgeInsets.zero,
                                  ),
                                  child: const Text('Forgot Password?',
                                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                ),
                              ),

                              const SizedBox(height: 18),
                              GestureDetector(
                                onTap: _isLoading ? null : _login,
                                child: Container(
                                  height: isWide ? 52 : 48,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: _isLoading
                                          ? [AppColors.primary.withValues(alpha: 0.5), AppColors.primaryLight.withValues(alpha: 0.5)]
                                          : const [AppColors.primary, AppColors.primaryLight],
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: _isLoading ? null : [
                                      BoxShadow(
                                        color: AppColors.primary.withValues(alpha: 0.3),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  alignment: Alignment.center,
                                  child: _isLoading
                                      ? const SizedBox(width: 22, height: 22,
                                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                                      : const Text('Sign In',
                                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // ── Register link ─────────────────────────────────
                      Padding(
                        padding: const EdgeInsets.only(top: 20),
                        child: GestureDetector(
                          onTap: () => context.push('/auth/signup'),
                          child: RichText(
                            text: const TextSpan(
                              text: 'New student? ',
                              style: TextStyle(color: Colors.white70, fontSize: 14),
                              children: [
                                TextSpan(
                                  text: 'Register',
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

                  // On wide screens: center with max-width constraint
                  // On mobile: full width with edge padding
                  return isWide
                      ? Center(
                          child: SingleChildScrollView(
                            padding: EdgeInsets.symmetric(vertical: vertPadding),
                            child: SizedBox(
                              width: 460,
                              child: content,
                            ),
                          ),
                        )
                      : SingleChildScrollView(
                          padding: EdgeInsets.symmetric(horizontal: 20, vertical: vertPadding),
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
