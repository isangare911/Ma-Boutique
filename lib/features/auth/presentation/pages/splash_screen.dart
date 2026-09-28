import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../core/services/shop_settings_service.dart';
import '../../../../core/theme/app_theme.dart';
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
    await Future.delayed(const Duration(seconds: 3));

    if (mounted) {
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
          // ═══════════════════════════════════════════════════
          // COUCHE 1 : IMAGE DE FOND (splash_background.png)
          // ═══════════════════════════════════════════════════
          Image.asset(
            AppAssets.splashBackground,
            fit: BoxFit.cover, // ⚡ Remplit tout l'écran
            errorBuilder: (_, __, ___) => Container(
              color: Colors.white,
            ),
          ),

          // ═══════════════════════════════════════════════════
          // COUCHE 2 : CONTENU (logo + texte + loader)
          // ═══════════════════════════════════════════════════
          SafeArea(
            child: Column(
              children: [
                // Espace flexible en haut
                const Spacer(flex: 2),

                // ⚡ LOGO CENTRÉ
                Image.asset(
                  AppAssets.logo,
                  width: 180,
                  height: 180,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => _buildDefaultLogo(),
                ),

                const SizedBox(height: 24),

                // Nom fixe "MA BOUTIQUE"
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

                // Espace flexible
                const Spacer(flex: 2),

                // Loader en bas
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
