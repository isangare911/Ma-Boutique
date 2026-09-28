import 'package:flutter/material.dart';

import '../../../../core/services/auth_service.dart';
import '../../../../core/services/subscription_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../admin/presentation/pages/admin_dashboard_screen.dart';
import '../../../auth/presentation/pages/login_screen.dart';
import '../../../cash/presentation/pages/cash_screen.dart';
import '../../../expenses/presentation/pages/expenses_list_screen.dart';
import '../../../reports/presentation/pages/reports_screen.dart';
import '../../../settings/presentation/pages/shop_settings_screen.dart';
import '../../../settings/presentation/pages/sync_status_screen.dart';
import '../../../subscription/presentation/pages/subscription_screen.dart';
import '../../../suppliers/presentation/pages/suppliers_list_screen.dart';
import '../../../users/presentation/pages/users_list_screen.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  // ═══════════════════════════════════════════════════════════
  // VÉRIFIER SI L'UTILISATEUR EST SUPERUSER
  // ═══════════════════════════════════════════════════════════
  bool _isSuperuser() {
    final user = AuthService.instance.user;
    if (user == null) return false;
    return user['is_superuser'] == true;
  }

  // ═══════════════════════════════════════════════════════════
  // VÉRIFIER SI L'UTILISATEUR PEUT GÉRER LES UTILISATEURS
  // ═══════════════════════════════════════════════════════════
  bool _canManageUsers() {
    final user = AuthService.instance.user;
    if (user == null) return false;

    final role = user['role'] as String?;
    final isSuperuser = user['is_superuser'] == true;

    // OWNER, MANAGER ou superuser peuvent gérer les utilisateurs
    return isSuperuser || role == 'OWNER' || role == 'MANAGER';
  }

  // ═══════════════════════════════════════════════════════════
  // DÉCONNEXION
  // ═══════════════════════════════════════════════════════════
  Future<void> _handleLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Se déconnecter ?'),
        content: const Text(
          'Voulez-vous vraiment vous déconnecter ?\n\n'
          'Vos données restent sauvegardées localement et sur le Cloud. '
          'Vous n\'aurez pas besoin de refaire l\'OTP à la prochaine connexion.',
        ),
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
    await SubscriptionService.instance.clearCache();

    if (!context.mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSuperuser = _isSuperuser();
    final canManageUsers = _canManageUsers();

    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar: AppBar(
        title: const Text('Plus'),
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ═══════════════════════════════════════════════════
          // SECTION ADMIN (visible uniquement pour le superuser)
          // ═══════════════════════════════════════════════════
          if (isSuperuser) ...[
            _buildMenuItem(
              context,
              icon: Icons.admin_panel_settings,
              title: 'Dashboard Admin',
              subtitle: 'Gérer les abonnés et paiements',
              color: Colors.deepPurple,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AdminDashboardScreen(),
                  ),
                );
              },
            ),
            Divider(color: AppColors.border(context)),
          ],

          // ═══════════════════════════════════════════════════
          // MENU PRINCIPAL
          // ═══════════════════════════════════════════════════

          // ⚡ Utilisateurs (visible pour OWNER/MANAGER)
          if (canManageUsers)
            _buildMenuItem(
              context,
              icon: Icons.group_outlined,
              title: 'Utilisateurs',
              subtitle: 'Gérer les utilisateurs de la boutique',
              color: Colors.indigo,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const UsersListScreen(),
                  ),
                );
              },
            ),

          _buildMenuItem(
            context,
            icon: Icons.people_outline,
            title: 'Clients',
            subtitle: 'Gérer vos clients',
            color: Colors.blue,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Clients — Bientôt disponible')),
              );
            },
          ),
          _buildMenuItem(
            context,
            icon: Icons.local_shipping_outlined,
            title: 'Fournisseurs',
            subtitle: 'Gérer vos fournisseurs',
            color: Colors.orange,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SuppliersListScreen()),
              );
            },
          ),
          _buildMenuItem(
            context,
            icon: Icons.point_of_sale_outlined,
            title: 'Caisse',
            subtitle: 'Ouvrir et fermer la caisse',
            color: Colors.green,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CashScreen()),
              );
            },
          ),
          _buildMenuItem(
            context,
            icon: Icons.bar_chart,
            title: 'Rapports',
            subtitle: 'Voir vos statistiques',
            color: Colors.purple,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ReportsScreen()),
              );
            },
          ),
          _buildMenuItem(
            context,
            icon: Icons.money_off,
            title: 'Dépenses',
            subtitle: 'Enregistrer vos dépenses',
            color: Colors.red,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ExpensesListScreen()),
              );
            },
          ),

          Divider(color: AppColors.border(context)),

          _buildMenuItem(
            context,
            icon: Icons.sync,
            title: 'Synchronisation',
            subtitle: 'Gérer la sync avec le Cloud',
            color: AppColors.green(context),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SyncStatusScreen()),
              );
            },
          ),
          _buildMenuItem(
            context,
            icon: Icons.settings_outlined,
            title: 'Paramètres',
            subtitle: 'Configurer votre boutique',
            color: AppColors.textSec(context),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ShopSettingsScreen()),
              );
            },
          ),
          _buildMenuItem(
            context,
            icon: Icons.workspace_premium_outlined,
            title: 'Abonnement',
            subtitle: SubscriptionService.instance.isTrial
                ? '${SubscriptionService.instance.daysRemaining} jours d\'essai restants'
                : SubscriptionService.instance.statusName,
            color: AppColors.green(context),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const SubscriptionScreen(),
                ),
              );
            },
          ),
          _buildMenuItem(
            context,
            icon: Icons.support_agent,
            title: 'Support',
            subtitle: 'Besoin d\'aide ?',
            color: Colors.teal,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Support — Bientôt disponible')),
              );
            },
          ),

          const SizedBox(height: 16),

          // ═══════════════════════════════════════════════════
          // BOUTON DÉCONNEXION
          // ═══════════════════════════════════════════════════
          Card(
            elevation: 0,
            color: AppColors.dangerTheme(context).withOpacity(0.1),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              leading: Icon(
                Icons.logout,
                color: AppColors.dangerTheme(context),
              ),
              title: Text(
                'Se déconnecter',
                style: TextStyle(
                  color: AppColors.dangerTheme(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
              trailing: Icon(
                Icons.chevron_right,
                color: AppColors.dangerTheme(context),
              ),
              onTap: () => _handleLogout(context),
            ),
          ),

          const SizedBox(height: 16),

          Center(
            child: Text(
              'Version 1.0.0',
              style: TextStyle(
                color: AppColors.textSec(context).withOpacity(0.6),
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    VoidCallback? onTap,
  }) {
    return Card(
      elevation: 0,
      color: AppColors.card(context),
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.text(context),
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textSec(context),
          ),
        ),
        trailing: Icon(
          Icons.chevron_right,
          color: AppColors.textSec(context),
        ),
        onTap: onTap ??
            () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('$title - Bientôt disponible')),
              );
            },
      ),
    );
  }
}
