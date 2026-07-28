import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/auth/providers/auth_providers.dart';
import '../models/user_model.dart';
import '../features/auth/screens/splash_screen.dart';
import '../features/auth/screens/onboarding_screen.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/register_screen.dart';
import '../features/auth/screens/forgot_password_screen.dart';
import '../features/auth/screens/profile_settings_screen.dart';
import '../features/shared/screens/notifications_screen.dart';
import '../features/student/screens/student_dashboard_screen.dart';
import '../features/student/screens/grade_entry_screen.dart';
import '../features/student/screens/grade_summary_screen.dart';
import '../features/student/screens/ai_job_match_screen.dart';
import '../features/student/screens/job_role_detail_screen.dart';
import '../features/student/screens/skill_gap_roadmap_screen.dart';
import '../features/student/screens/desired_role_selector_screen.dart';
import '../features/student/screens/certification_library_screen.dart';
import '../features/student/screens/roadmap_pdf_export_screen.dart';
import '../features/student/screens/progress_tracker_screen.dart';
import '../features/student/screens/feedback_screen.dart';
import '../features/recruiter/screens/recruiter_dashboard_screen.dart';
import '../features/recruiter/screens/job_search_screen.dart';
import '../features/recruiter/screens/candidate_shortlist_screen.dart';
import '../features/recruiter/screens/student_profile_view_screen.dart';
import '../features/recruiter/screens/pipeline_board_screen.dart';
import '../features/recruiter/screens/export_report_screen.dart';
import '../features/recruiter/screens/job_request_log_screen.dart';
import '../features/admin/screens/admin_dashboard_screen.dart';
import '../features/admin/screens/user_management_screen.dart';
import '../features/admin/screens/jd_library_screen.dart';
import '../features/admin/screens/ai_weighting_config_screen.dart';
import '../features/admin/screens/course_master_screen.dart';
import '../features/admin/screens/broadcast_notification_screen.dart';
import '../features/admin/screens/system_error_log_screen.dart';
import '../features/admin/screens/data_export_archive_screen.dart';
import '../features/admin/screens/monthly_analytics_screen.dart';
import 'go_router_refresh_stream.dart';

const _authRoutes = ['/login', '/register', '/forgot-password'];

String _dashboardRouteFor(UserRole role) {
  switch (role) {
    case UserRole.recruiter:
      return '/recruiter';
    case UserRole.admin:
      return '/admin';
    case UserRole.student:
      return '/student';
  }
}

/// Auth-aware navigation matching Section 6 — App Navigation Flow.
///
/// - `/splash` (S01) handles its own 2-second timer, then navigates to
///   `/login`. This redirect callback intentionally ignores `/splash` so
///   the splash animation always gets to show.
/// - If signed out and onboarding hasn't been seen yet -> `/onboarding`.
/// - If signed out and onboarding has been seen -> only `/login`,
///   `/register`, `/forgot-password` are reachable; anything else bounces
///   back to `/login`.
/// - If signed in -> `/login`, `/register`, `/forgot-password`, and
///   `/onboarding` all redirect to the user's role dashboard
///   (`/student`, `/recruiter`, or `/admin`) per FR-03.
/// - FR-05 — if the signed-in user's Firestore profile has
///   `isActive == false`, they are signed out and sent back to `/login`.
final goRouterProvider = Provider<GoRouter>((ref) {
  final authRepo = ref.watch(authRepositoryProvider);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: GoRouterRefreshStream(authRepo.authStateChanges),
    redirect: (context, state) async {
      final loc = state.matchedLocation;

      // Let the splash screen run its own timer + redirect.
      if (loc == '/splash') return null;

      final user = authRepo.currentUser;

      if (user == null) {
        // Section 6: Onboarding is shown once, before Login.
        if (loc == '/onboarding') return null;

        final prefs = await SharedPreferences.getInstance();
        final seenOnboarding = prefs.getBool('onboarding_seen') ?? false;
        if (!seenOnboarding) return '/onboarding';

        if (_authRoutes.contains(loc)) return null;
        return '/login'; // trying to reach a protected route while signed out
      }

      // Signed in — look up the role for routing (FR-03).
      final userModel = await authRepo.getUserModel(user.uid);
      if (userModel == null) {
        // Profile doc not written yet (e.g. mid-registration) — wait here.
        return null;
      }

      // FR-05 — Admin-deactivated accounts are signed out immediately.
      if (!userModel.isActive) {
        await authRepo.signOut();
        return '/login';
      }

      final dashboard = _dashboardRouteFor(userModel.role);
      if (loc == '/onboarding' || _authRoutes.contains(loc)) return dashboard;
      return null; // already inside the right area — allow
    },
    routes: [
      GoRoute(path: '/splash', builder: (context, state) => const SplashScreen()),
      GoRoute(path: '/onboarding', builder: (context, state) => const OnboardingScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/register', builder: (context, state) => const RegisterScreen()),
      GoRoute(path: '/forgot-password', builder: (context, state) => const ForgotPasswordScreen()),

      // S-06 / S-07 — shared across all 3 roles (Section 5.1), so these
      // live at the top level rather than nested under any one
      // dashboard's /student, /recruiter, or /admin route.
      GoRoute(path: '/profile', builder: (context, state) => const ProfileSettingsScreen()),
      GoRoute(path: '/notifications', builder: (context, state) => const NotificationsScreen()),

      // Role dashboards — entry points for each portal (Phase 4/5 build these out)
      GoRoute(
        path: '/student',
        builder: (context, state) => const StudentDashboardScreen(),
        routes: [
          // S-09 — Grade Entry
          GoRoute(path: 'grades', builder: (context, state) => const GradeEntryScreen()),
          // S-10 — Grade Summary
          GoRoute(path: 'grades-summary', builder: (context, state) => const GradeSummaryScreen()),
          // S-11 — AI Job Match (top 3 recommendations, FR-08)
          GoRoute(path: 'matches', builder: (context, state) => const AiJobMatchScreen()),
          // S-12 — Job Role Detail, by JD ID
          GoRoute(
            path: 'matches/:jdId',
            builder: (context, state) => JobRoleDetailScreen(jdId: state.pathParameters['jdId']!),
          ),
          // S-13 — Skill Gap Roadmap (Gantt chart)
          GoRoute(
            path: 'roadmap',
            builder: (context, state) => const SkillGapRoadmapScreen(),
            routes: [
              // S-16 — Roadmap PDF Export (FR-14), nested so the "back" button
              // returns to the roadmap that was being exported.
              GoRoute(path: 'export', builder: (context, state) => const RoadmapPdfExportScreen()),
            ],
          ),
          // S-14 — Desired Role Selector (FR-12)
          GoRoute(path: 'roles', builder: (context, state) => const DesiredRoleSelectorScreen()),
          // S-15 — Certification Library
          GoRoute(path: 'certifications', builder: (context, state) => const CertificationLibraryScreen()),
          // S-17 — Progress Tracker (FR-38)
          GoRoute(path: 'progress', builder: (context, state) => const ProgressTrackerScreen()),
          // S-33 — Feedback (FR-39)
          GoRoute(path: 'feedback', builder: (context, state) => const FeedbackScreen()),
        ],
      ),
      GoRoute(
        path: '/recruiter',
        builder: (context, state) => const RecruiterDashboardScreen(),
        routes: [
          // S-19 — Job Search
          GoRoute(path: 'search', builder: (context, state) => const JobSearchScreen()),
          // S-20 — Candidate Shortlist (ranked results for the current scan)
          GoRoute(path: 'shortlist', builder: (context, state) => const CandidateShortlistScreen()),
          // S-21 — Student Profile View (Recruiter), by student UID
          GoRoute(
            path: 'profile/:studentUid',
            builder: (context, state) =>
                StudentProfileViewScreen(studentUid: state.pathParameters['studentUid']!),
          ),
          // S-22 — Pipeline Board (Kanban)
          GoRoute(path: 'pipeline', builder: (context, state) => const PipelineBoardScreen()),
          // S-23 — Export Report (FR-19)
          GoRoute(path: 'export', builder: (context, state) => const ExportReportScreen()),
          // S-24 — Job Request Log
          GoRoute(path: 'request-log', builder: (context, state) => const JobRequestLogScreen()),
        ],
      ),
      GoRoute(
        path: '/admin',
        builder: (context, state) => const AdminDashboardScreen(),
        routes: [
          // S-26 — User Management
          GoRoute(path: 'users', builder: (context, state) => const UserManagementScreen()),
          // S-28 — JD Library
          GoRoute(path: 'jds', builder: (context, state) => const JDLibraryScreen()),
          // S-29 — AI Weighting Config, by JD ID
          GoRoute(
            path: 'jds/:jdId/weights',
            builder: (context, state) => AiWeightingConfigScreen(jdId: state.pathParameters['jdId']!),
          ),
          // S-27 — Course Master
          GoRoute(path: 'courses', builder: (context, state) => const CourseMasterScreen()),
          // S-30 — Broadcast Notification
          GoRoute(path: 'broadcast', builder: (context, state) => const BroadcastNotificationScreen()),
          // S-31 — System Error Log
          GoRoute(path: 'error-log', builder: (context, state) => const SystemErrorLogScreen()),
          // S-32 — Data Export & Archive (FR-27)
          GoRoute(path: 'export-archive', builder: (context, state) => const DataExportArchiveScreen()),
          // S-34 — Monthly Analytics
          GoRoute(path: 'analytics', builder: (context, state) => const MonthlyAnalyticsScreen()),
        ],
      ),
    ],
  );
});
