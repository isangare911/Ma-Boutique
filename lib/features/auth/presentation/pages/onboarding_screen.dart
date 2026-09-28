import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../core/theme/app_theme.dart';
import 'login_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  // ⚡ Clé pour savoir si l'onboarding a déjà été vu
  static const String _keyHasSeenOnboarding = 'has_seen_onboarding';

  /// Vérifie si l'utilisateur a déjà vu l'onboarding
  static Future<bool> hasBeenSeen() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyHasSeenOnboarding) ?? false;
  }

  /// Marque l'onboarding comme vu
  static Future<void> markAsSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyHasSeenOnboarding, true);
  }

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, dynamic>> _pages = [
    {
      'image': AppAssets.onboarding1,
      'icon': Icons.storefront,
      'title': 'Gérez votre boutique facilement',
      'description':
          'Ventes, stock, crédits et rapports dans une seule application.',
    },
    {
      'image': AppAssets.onboarding2,
      'icon': Icons.inventory_2_outlined,
      'title': 'Suivez vos stocks en temps réel',
      'description':
          'Soyez alerté des ruptures et ne manquez jamais un produit.',
    },
    {
      'image': AppAssets.onboarding3,
      'icon': Icons.people_outline,
      'title': 'Gérez vos crédits et clients',
      'description':
          'Accordez des crédits, suivez les paiements et fidélisez vos clients.',
    },
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onNext() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _goToLogin();
    }
  }

  Future<void> _goToLogin() async {
    // ⚡ Marquer l'onboarding comme vu avant de naviguer
    await OnboardingScreen.markAsSeen();

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _goToLogin,
                child: const Text(
                  'Passer',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                },
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  return _buildPage(_pages[index]);
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _pages.length,
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  height: 8,
                  width: _currentPage == index ? 24 : 8,
                  decoration: BoxDecoration(
                    color: _currentPage == index
                        ? AppColors.primary
                        : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: ElevatedButton(
                onPressed: _onNext,
                child: Text(
                  _currentPage == _pages.length - 1 ? 'Commencer' : 'Suivant',
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildPage(Map<String, dynamic> page) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.3),
              shape: BoxShape.circle,
            ),
            child: ClipOval(
              child: Image.asset(
                page['image'] as String,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Icon(
                  page['icon'] as IconData,
                  size: 100,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 48),
          Text(
            page['title'] as String,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            page['description'] as String,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
