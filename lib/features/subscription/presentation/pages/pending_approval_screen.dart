import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/services/auth_service.dart';
import '../../../../core/services/shop_settings_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/pages/login_screen.dart';

class PendingApprovalScreen extends StatefulWidget {
  const PendingApprovalScreen({super.key});

  @override
  State<PendingApprovalScreen> createState() => _PendingApprovalScreenState();
}

class _PendingApprovalScreenState extends State<PendingApprovalScreen> {
  bool _isChecking = false;

  Future<void> _checkStatus() async {
    setState(() => _isChecking = true);

    // Rafraîchir le user pour voir si le statut a changé
    await AuthService.instance.initialize();

    if (!mounted) return;

    setState(() => _isChecking = false);

    final user = AuthService.instance.user;
    final status = user?['shop']?['subscription_status'];

    // Si le statut n'est plus PENDING_VALIDATION → redirection
    if (status != 'PENDING_VALIDATION') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('✅ Votre abonnement a été activé !'),
          backgroundColor: AppColors.successTheme(context),
        ),
      );

      // Retourner à l'écran de login pour se reconnecter proprement
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Votre demande est toujours en attente de validation.',
          ),
          backgroundColor: AppColors.warningTheme(context),
        ),
      );
    }
  }

  Future<void> _contactWhatsApp() async {
    final shopName = ShopSettingsService.instance.shopName;
    final user = AuthService.instance.user;
    final phone = user?['phone'] ?? '';

    final message = 'Bonjour, je suis $phone, propriétaire de "$shopName". '
        'Je viens de m\'inscrire sur Ma Boutique et je souhaite activer mon abonnement.';

    // ⚡ Numéro WhatsApp du support (à remplacer par le tien)
    const supportNumber = '+22384099944';

    final url = Uri.parse(
      'https://wa.me/$supportNumber?text=${Uri.encodeComponent(message)}',
    );

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('WhatsApp n\'est pas installé')),
        );
      }
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Se déconnecter ?'),
        content: const Text('Voulez-vous vraiment vous déconnecter ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.dangerTheme(context),
            ),
            child: const Text('Se déconnecter'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await AuthService.instance.logout();

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final shopName = ShopSettingsService.instance.shopName;
    final user = AuthService.instance.user;
    final phone = user?['phone'] ?? '';

    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar: AppBar(
        title: const Text('En attente de validation'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Se déconnecter',
            onPressed: _logout,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _checkStatus,
        color: AppColors.green(context),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),

              // ⚡ Icône animée
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: AppColors.warningTheme(context).withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.hourglass_top,
                  size: 60,
                  color: AppColors.warningTheme(context),
                ),
              ),

              const SizedBox(height: 32),

              Text(
                'Demande envoyée',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: AppColors.text(context),
                ),
              ),

              const SizedBox(height: 16),

              Text(
                'Votre demande d\'activation pour "$shopName" a bien été enregistrée.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: AppColors.textSec(context),
                  height: 1.5,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                'Vous serez notifié dès que votre compte sera activé.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSec(context),
                  fontStyle: FontStyle.italic,
                ),
              ),

              const SizedBox(height: 32),

              // ⚡ Info card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.card(context),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border(context)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: AppColors.green(context),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Prochaines étapes',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.text(context),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildStep('1', 'Vous recevrez une confirmation'),
                    const SizedBox(height: 8),
                    _buildStep(
                        '2', 'Reconnectez-vous pour accéder à votre boutique'),
                    const SizedBox(height: 8),
                    _buildStep(
                        '3', 'Configurez votre stock et commencez à vendre'),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // ⚡ Bouton "Vérifier maintenant"
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isChecking ? null : _checkStatus,
                  icon: _isChecking
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.onGreen(context),
                          ),
                        )
                      : const Icon(Icons.refresh),
                  label: Text(
                    _isChecking ? 'Vérification...' : 'Vérifier mon statut',
                  ),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // ⚡ Bouton WhatsApp
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _contactWhatsApp,
                  icon: const Icon(
                    Icons.chat,
                    color: Color(0xFF25D366),
                    size: 20,
                  ),
                  label: const Text('Contacter le support'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    side: const BorderSide(color: Color(0xFF25D366)),
                    foregroundColor: const Color(0xFF25D366),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              Text(
                'Votre numéro : $phone',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSec(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep(String number, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: AppColors.green(context).withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppColors.green(context),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.text(context),
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}
