import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/services/shop_settings_service.dart';
import '../../../../core/services/subscription_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../navigation/presentation/pages/main_navigation_screen.dart';
import 'login_screen.dart';
import 'onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await ShopSettingsService.instance.initialize();
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    // 1️⃣ Utilisateur déjà connecté → Dashboard direct
    if (AuthService.instance.isAuthenticated) {
      await SubscriptionService.instance.refreshSubscription();

      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => const MainNavigationScreen(),
        ),
      );
      return;
    }

    // 2️⃣ Onboarding déjà vu → Login direct
    final hasSeenOnboarding = await OnboardingScreen.hasBeenSeen();

    if (!mounted) return;

    if (hasSeenOnboarding) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    } else {
      // 3️⃣ Première fois → Onboarding

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const OnboardingScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            AppAssets.splashBackground,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              color: Colors.white,
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                const Spacer(flex: 2),
                Image.asset(
                  AppAssets.logo,
                  width: 180,
                  height: 180,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => _buildDefaultLogo(),
                ),
                const SizedBox(height: 24),
                const Text(
                  'MA BOUTIQUE',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Gérez votre boutique en toute simplicité',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
                const Spacer(flex: 2),
                const CircularProgressIndicator(
                  color: AppColors.primary,
                  strokeWidth: 3,
                ),
                const SizedBox(height: 60),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultLogo() {
    return Container(
      width: 180,
      height: 180,
      decoration: BoxDecoration(
        color: AppColors.accent,
        borderRadius: BorderRadius.circular(24),
      ),
      child: const Icon(
        Icons.storefront,
        size: 100,
        color: AppColors.primary,
      ),
    );
  }
}
