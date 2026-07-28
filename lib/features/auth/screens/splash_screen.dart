import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../app/app_constants.dart';

/// S01 — Splash Screen.
/// "Animated logo, app name, version number, auto-navigate after 2 seconds."
///
/// After the 2-second timer, this hands off to `/login`. The router's
/// auth guard (app_router.dart redirect) then takes over: it sends signed-
/// out users to `/onboarding` (first run) or `/login`, and signed-in users
/// straight to their role dashboard (FR-03).
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) context.go('/login');
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.primaryBlue,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 🔶 Replace with the real app logo (assets/images/)
            Icon(Icons.school, size: 72, color: Colors.white),
            SizedBox(height: 16),
            Text(
              'Talent Tracker AI',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text('v0.2.0', style: TextStyle(color: Colors.white70)),
          ],
        ),
      ),
    );
  }
}
