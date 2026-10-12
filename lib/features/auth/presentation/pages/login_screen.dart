import 'package:boutique/features/navigation/presentation/pages/main_navigation_screen.dart';
import 'package:flutter/material.dart';

import '../../../../core/services/auth_service.dart';
import '../../../../core/services/shop_settings_service.dart';
import '../../../../core/services/subscription_service.dart';
import '../../../../core/services/sync_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../subscription/presentation/pages/pending_approval_screen.dart';
import '../../../subscription/presentation/pages/subscription_screen.dart';
import '../widgets/custom_text_field.dart';
import 'change_password_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    final authService = AuthService.instance;
    final result = await authService.login(
      phone: _phoneController.text.trim(),
      password: _passwordController.text,
    );

    if (!mounted) return;

    if (!result.success) {
      String message;
      if (result.isThrottled) {
        message = 'Trop de tentatives. Réessayez dans une minute.';
      } else if (result.isNetworkError) {
        message = 'Pas de connexion. Vérifiez votre réseau.';
      } else {
        message = result.error ?? 'Identifiants invalides.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppColors.dangerTheme(context),
        ),
      );
      return;
    }

    // ⚡ Reloads non-bloquants
    try {
      await ShopSettingsService.instance.reload();
      await SubscriptionService.instance.refreshSubscription();
    } catch (e) {
      debugPrint('Erreur reload après login: $e');
    }

    if (!mounted) return;

    // ⚡ PULL : récupérer les données du serveur après login
    try {
      await SyncService.instance.pullAll();
    } catch (e) {
      debugPrint('⚠ Erreur pull après login: $e');
    }

    // ⚡ Recharger les settings après le pull
    await ShopSettingsService.instance.reload();

    if (!mounted) return;

    // ⚡ 0. SUPERUSER → onglet "Plus" direct
    final user = AuthService.instance.user;
    final isSuperuser = user?['is_superuser'] == true;
    debugPrint('🔍 Login - is_superuser: $isSuperuser');

    if (isSuperuser) {
      MainNavigationScreen.tabNotifier.value = 4;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
        (route) => false,
      );
      return;
    }

    // ⚡ 1. Force le changement de mot de passe
    if (result.mustChangePassword) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => const ChangePasswordScreen(isForced: true),
        ),
        (route) => false,
      );
      return;
    }

    final subStatus = result.subscriptionStatus;

    // ⚡ 2. PENDING_VALIDATION → écran d'attente
    if (subStatus == 'PENDING_VALIDATION') {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const PendingApprovalScreen()),
        (route) => false,
      );
      return;
    }

    // ⚡ 3. CANCELLED ou EXPIRED → écran abonnement
    if (subStatus == 'CANCELLED' || subStatus == 'EXPIRED') {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
        (route) => false,
      );
      return;
    }

    // ⚡ 4. Sinon → Dashboard
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg(context),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 40),
                Text(
                  'Bienvenue !',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.text(context),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Connectez-vous à votre compte',
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.textSec(context),
                  ),
                ),
                const SizedBox(height: 40),
                CustomTextField(
                  label: 'Téléphone',
                  hint: '+223 70 12 34 56',
                  prefixIcon: Icons.phone_outlined,
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Veuillez entrer votre numéro de téléphone';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                CustomTextField(
                  label: 'Mot de passe',
                  hint: '••••••••',
                  prefixIcon: Icons.lock_outline,
                  isPassword: _obscurePassword,
                  controller: _passwordController,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                      color: AppColors.textSec(context),
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Veuillez entrer votre mot de passe';
                    }
                    return null;
                  },
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: null,
                    child: Text(
                      'Mot de passe oublié ?',
                      style: TextStyle(color: AppColors.textSec(context)),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                ListenableBuilder(
                  listenable: AuthService.instance,
                  builder: (context, _) {
                    final isLoading = AuthService.instance.isLoading;
                    return ElevatedButton(
                      onPressed: isLoading ? null : _login,
                      child: isLoading
                          ? SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.onGreen(context),
                              ),
                            )
                          : const Text('Se connecter'),
                    );
                  },
                ),
                const SizedBox(height: 24),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Pas encore de compte ? ',
                      style: TextStyle(color: AppColors.textSec(context)),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const RegisterScreen(),
                          ),
                        );
                      },
                      child: Text(
                        'Inscrivez-vous',
                        style: TextStyle(
                          color: AppColors.green(context),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
