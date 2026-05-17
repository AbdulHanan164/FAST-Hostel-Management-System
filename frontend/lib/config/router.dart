import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:firebase_auth/firebase_auth.dart';
import '../providers/auth_provider.dart';
import '../widgets/auth_gate.dart';
import '../screens/splash_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/signup_screen.dart';
import '../screens/auth/forgot_password_screen.dart';
import '../screens/auth/awaiting_verification_screen.dart';
import '../screens/auth/otp_verification_screen.dart';
import '../screens/auth/forgot_password_otp_screen.dart';
import '../screens/auth/reset_password_screen.dart';
import '../screens/student/student_dashboard.dart';
import '../screens/student/hostel_allotment/hostel_application_screen.dart';
import '../screens/student/hostel_allotment/room_selection_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/notifications_screen.dart';
import '../screens/mess_screen.dart';
import '../screens/student/complaint_box_screen.dart';
import '../screens/student/gym_registration_screen.dart';
import '../screens/student/mess_attendance_screen.dart';
import '../screens/student/room_swap_screen.dart';
import '../screens/student/hostel_browse_screen.dart';
import '../screens/payments_screen.dart';
import '../screens/admin/admin_dashboard.dart';
import '../screens/admin/applications_management_screen.dart';
import '../screens/admin/complaints_management_screen.dart';
import '../screens/admin/fee_payments_screen.dart';
import '../screens/admin/bank_settings_screen.dart';
import '../screens/admin/gym_management_screen.dart';
import '../screens/admin/hall_management_screen.dart';
import '../screens/admin/hostel_management_screen.dart';
import '../screens/admin/mess_attendance_management_screen.dart';
import '../screens/admin/mess_management_screen.dart';
import '../screens/admin/mess_billing_screen.dart'; // Import Mess Billing Screen
import '../screens/admin/room_requests_screen.dart';
import '../screens/admin/hall_detail_screen.dart';
import '../screens/admin/notice_board_management_screen.dart';
import '../screens/admin/clear_data_screen.dart';
import '../screens/admin/student_status_screen.dart';
import '../screens/notice_board_screen.dart';
import '../screens/chat/chat_list_screen.dart';
import '../screens/chat/chat_room_screen.dart';
import '../utils/admin_utils.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final currentUser = ref.watch(currentUserProvider);
  final authReady = ref.watch(authReadyProvider);

  return GoRouter(
    initialLocation: '/auth/login',
    redirect: (context, state) {
      final location = state.uri.toString();
      final isAwaitingVerification =
          location.startsWith('/auth/awaiting-verification');

      // Allow awaiting verification screen regardless of auth state
      if (isAwaitingVerification) {
        return null;
      }

      // Wait for auth to be ready before making routing decisions
      // This is critical on Web where auth persistence causes delays
      final isAuthReady = authReady.when(
        data: (ready) => ready,
        loading: () => false, // Wait for auth to be ready
        error: (_, __) => true, // On error, proceed (router will handle it)
      );

      // If auth is not ready yet, don't redirect (stay on current route)
      // The AuthGate will show loading until auth is ready
      if (!isAuthReady) {
        return null;
      }

      // Check Firebase Auth directly as fallback if provider is in error state
      final firebaseUser = FirebaseAuth.instance.currentUser;
      final hasFirebaseAuth = firebaseUser != null;

      // Check provider state for Firestore user data
      final userModel = currentUser.when(
        data: (user) => user,
        loading: () => null,
        error: (_, __) => null, // Don't block navigation on Firestore errors
      );

      final hasProviderUser = userModel != null;
      final isLoggedIn = hasFirebaseAuth || hasProviderUser;
      final isAdmin = AdminUtils.isAdmin(userModel);

      // If not logged in and trying to access protected routes
      if (!isLoggedIn && !location.startsWith('/auth')) {
        return '/auth/login';
      }

      // Role-based redirection when logged in
      if (isLoggedIn &&
          location.startsWith('/auth') &&
          !isAwaitingVerification) {
        // Redirect to appropriate dashboard based on role
        if (isAdmin) {
          return '/admin/dashboard';
        } else {
          return '/student/dashboard';
        }
      }

      // Role-based redirection on splash screen
      if (isLoggedIn && location == '/splash') {
        if (isAdmin) {
          return '/admin/dashboard';
        } else {
          return '/student/dashboard';
        }
      }

      // Protect admin routes - only admins can access
      if (isLoggedIn && location.startsWith('/admin') && !isAdmin) {
        return '/student/dashboard'; // Redirect non-admins to student dashboard
      }

      // Protect student routes - redirect admins to admin dashboard
      if (isLoggedIn && location.startsWith('/student') && isAdmin) {
        return '/admin/dashboard'; // Redirect admins to admin dashboard
      }

      // If not logged in and on splash screen, redirect to login
      if (!isLoggedIn && location == '/splash') {
        return '/auth/login';
      }

      return null;
    },
    routes: [
      // Root redirect for web and direct '/' visits
      GoRoute(
        path: '/',
        redirect: (context, state) => '/splash',
      ),
      // Friendly alias used in some deployments
      GoRoute(
        path: '/fast',
        redirect: (context, state) => '/splash',
      ),
      // Splash Screen
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),

      // Authentication Routes
      GoRoute(
        path: '/auth/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/auth/signup',
        builder: (context, state) => const SignupScreen(),
      ),
      GoRoute(
        path: '/auth/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/auth/awaiting-verification',
        builder: (context, state) => const AwaitingVerificationScreen(),
      ),
      GoRoute(
        path: '/auth/verify-otp',
        builder: (context, state) {
          final data = state.extra as OtpSignupData;
          return OtpVerificationScreen(data: data);
        },
      ),
      GoRoute(
        path: '/auth/forgot-password-otp',
        builder: (context, state) {
          final data = state.extra as ForgotPasswordOtpData;
          return ForgotPasswordOtpScreen(data: data);
        },
      ),
      GoRoute(
        path: '/auth/reset-password',
        builder: (context, state) {
          final email = state.extra as String;
          return ResetPasswordScreen(email: email);
        },
      ),

      // Student Routes
      GoRoute(
        path: '/student/dashboard',
        builder: (context, state) => const StudentDashboard(),
        routes: [
          GoRoute(
            path: 'hostel-application',
            builder: (context, state) => const HostelApplicationScreen(),
          ),
          GoRoute(
            path: 'room-selection',
            builder: (context, state) => const RoomSelectionScreen(),
          ),
          GoRoute(
            path: 'profile',
            builder: (context, state) => const ProfileScreen(),
          ),
          GoRoute(
            path: 'notifications',
            builder: (context, state) => const NotificationsScreen(),
          ),
          GoRoute(
            path: 'notice-board',
            builder: (context, state) => const NoticeBoardScreen(),
          ),
          GoRoute(
            path: 'mess',
            builder: (context, state) => const MessScreen(),
          ),
          GoRoute(
            path: 'mess-attendance',
            builder: (context, state) => const MessAttendanceScreen(),
          ),
          GoRoute(
            path: 'gym-registration',
            builder: (context, state) => const GymRegistrationScreen(),
          ),
          GoRoute(
            path: 'complaint-box',
            builder: (context, state) => const ComplaintBoxScreen(),
          ),
          GoRoute(
            path: 'room-swap',
            builder: (context, state) => const RoomSwapScreen(),
          ),
          GoRoute(
            path: 'payments',
            builder: (context, state) => const PaymentsScreen(),
          ),
          GoRoute(
            path: 'browse-hostels',
            builder: (context, state) => const HostelBrowseScreen(),
          ),
          GoRoute(
            path: 'chat',
            builder: (context, state) => const ChatListScreen(),
          ),
          GoRoute(
            path: 'chat/:chatId',
            builder: (context, state) {
              final room = state.extra as dynamic;
              return ChatRoomScreen(room: room);
            },
          ),
        ],
      ),

      // Admin Routes
      GoRoute(
        path: '/admin/dashboard',
        builder: (context, state) => const AdminDashboard(),
        routes: [
          GoRoute(
            path: 'hostel-management',
            builder: (context, state) => const HostelManagementScreen(),
          ),
          GoRoute(
            path: 'applications',
            builder: (context, state) => const ApplicationsManagementScreen(),
          ),
          GoRoute(
            path: 'room-requests',
            builder: (context, state) => const RoomRequestsScreen(),
          ),
          GoRoute(
            path: 'fee-payments',
            builder: (context, state) => const FeePaymentsScreen(),
          ),
          GoRoute(
            path: 'bank-settings',
            builder: (context, state) => const BankSettingsScreen(),
          ),
          GoRoute(
            path: 'halls',
            builder: (context, state) => const HallManagementScreen(),
          ),
          GoRoute(
            path: 'halls/:hallId',
            builder: (context, state) {
              final hallId = state.pathParameters['hallId']!;
              return HallDetailScreen(hallId: hallId);
            },
          ),
          GoRoute(
            path: 'mess-management',
            builder: (context, state) => const MessManagementScreen(),
          ),
          GoRoute(
            path: 'mess-attendance',
            builder: (context, state) => const MessAttendanceManagementScreen(),
          ),
          GoRoute(
            path: 'mess-billing',
            builder: (context, state) => const MessBillingScreen(),
          ),
          GoRoute(
            path: 'gym-management',
            builder: (context, state) => const GymManagementScreen(),
          ),
          GoRoute(
            path: 'complaints',
            builder: (context, state) => const ComplaintsManagementScreen(),
          ),
          GoRoute(
            path: 'notice-board',
            builder: (context, state) => const NoticeBoardManagementScreen(),
          ),
          GoRoute(
            path: 'db-management',
            builder: (context, state) => const ClearDataScreen(),
          ),
          GoRoute(
            path: 'student-status',
            builder: (context, state) => const StudentStatusScreen(),
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('Page not found: ${state.uri.toString()}'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.go('/splash'),
              child: const Text('Go to Home'),
            ),
          ],
        ),
      ),
    ),
  );
});

class AppRouter {
  static final router = routerProvider;
}
