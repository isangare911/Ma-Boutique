import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'core/services/auth_service.dart';
import 'core/services/notification_cheker.dart';
import 'core/services/notification_service.dart';
import 'core/services/shop_settings_service.dart';
import 'core/services/subscription_service.dart';
import 'core/services/sync_service.dart';
import 'core/services/theme_service.dart';
import 'core/theme/app_theme.dart';
import 'data/datasources/local/database_helper.dart';
import 'features/auth/presentation/pages/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp();
    debugPrint('✓ Firebase initialisé');
  } catch (e) {
    debugPrint('⚠ Erreur Firebase');
  }

  await DatabaseHelper.instance.database;

  // ⚡ Plus de données de démo — chaque boutique démarre vide

  await ShopSettingsService.instance.initialize();
  await NotificationService.instance.initialize();
  await AuthService.instance.initialize();
  await SyncService.instance.initialize();
  await ThemeService.instance.initialize();
  await SubscriptionService.instance.initializeFromCache();

  NotificationChecker.instance.checkAll();

  SubscriptionCheckerService.instance.start();

  runApp(const MaBoutiqueApp());
}

class MaBoutiqueApp extends StatelessWidget {
  const MaBoutiqueApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeService.instance,
      builder: (context, _) {
        return MaterialApp(
          title: 'Ma Boutique',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeService.instance.themeMode,
          home: const SplashScreen(),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════
// SERVICE DE VÉRIFICATION PÉRIODIQUE
// ═══════════════════════════════════════════════════════════
class SubscriptionCheckerService {
  static final SubscriptionCheckerService instance =
      SubscriptionCheckerService._();
  SubscriptionCheckerService._();

  Timer? _timer;

  void start() {
    _timer = Timer.periodic(const Duration(hours: 1), (_) => _check());
    Timer(const Duration(seconds: 30), _check);
  }

  Future<void> _check() async {
    if (!AuthService.instance.isAuthenticated) return;

    final manipulated = await SubscriptionService.instance.isDateManipulated();
    if (manipulated) {
      debugPrint('🚨 Manipulation détectée → déconnexion forcée');
      await AuthService.instance.logout();
      return;
    }

    final needsRefresh = await SubscriptionService.instance.needsRefresh();
    if (needsRefresh) {
      debugPrint('🔄 Refresh abonnement (> 24h)');
      await SubscriptionService.instance.refreshSubscription();
    }
  }

  void stop() {
    _timer?.cancel();
  }
}
