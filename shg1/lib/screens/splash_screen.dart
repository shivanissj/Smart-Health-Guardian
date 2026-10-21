import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'auth_screen.dart';
import 'home/home_shell.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  // TODO: replace with real Firebase Auth check (FirebaseAuth.instance.currentUser != null)
  final bool _userLoggedIn = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 4000), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => _userLoggedIn ? const HomeShell() : const AuthScreen(),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final screenHeight = MediaQuery.of(context).size.height;
    
    return Scaffold(
      backgroundColor: AppColors.black,
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: isMobile ? 80 : 100,
                  height: isMobile ? 80 : 100,
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.teal, width: 2),
                  ),
                  child: Icon(Icons.favorite_rounded, color: AppColors.teal, size: isMobile ? 40 : 48),
                ),
                const SizedBox(height: 28),
                Text(
                  'SMART HEALTH GUARDIAN',
                  style: TextStyle(
                    color: AppColors.white,
                    fontSize: isMobile ? 18 : 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    height: 1.3,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  'Wearable Health Monitoring &\nEmergency Alert System',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.white.withOpacity(0.6),
                    fontSize: isMobile ? 12 : 14,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 40),
                const SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.teal),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
