import 'package:flutter/material.dart';

import '../../../../core/services/auth_service.dart';
import '../../../../core/services/shop_user_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/models/shop_user.dart';
import 'add_user_screen.dart';

class UsersListScreen extends StatefulWidget {
  const UsersListScreen({super.key});

  @override
  State<UsersListScreen> createState() => _UsersListScreenState();
}

class _UsersListScreenState extends State<UsersListScreen> {
  List<ShopUser> _users = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final users = await ShopUserService.instance.getUsers();

      if (!mounted) return;

      setState(() {
        _users = users;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Erreur de chargement';
      });
    }
  }

  // ═══════════════════════════════════════════════════════════
  // SUPPRIMER UN UTILISATEUR
  // ═══════════════════════════════════════════════════════════
  Future<void> _deleteUser(ShopUser user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer cet utilisateur ?'),
        content: Text(
          '${user.fullName} n\'aura plus accès à la boutique.\n\n'
          'Ses données personnelles restent intactes.',
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
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final success = await ShopUserService.instance.deleteUser(user.id);

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${user.fullName} supprimé'),
          backgroundColor: AppColors.successTheme(context),
        ),
      );
      await _loadUsers();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Erreur lors de la suppression'),
          backgroundColor: AppColors.dangerTheme(context),
        ),
      );
    }
  }

  // ═══════════════════════════════════════════════════════════
  // ACTIVER / DÉSACTIVER UN UTILISATEUR
  // ═══════════════════════════════════════════════════════════
  Future<void> _toggleActive(ShopUser user) async {
    final newStatus = !user.isActive;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          newStatus
              ? 'Activer cet utilisateur ?'
              : 'Désactiver cet utilisateur ?',
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              newStatus
                  ? '${user.fullName} pourra à nouveau se connecter et accéder à la boutique.'
                  : '${user.fullName} ne pourra plus se connecter, mais ses données sont conservées.',
            ),
            if (!newStatus) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.warningTheme(context).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: AppColors.warningTheme(context),
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Vous pourrez le réactiver à tout moment.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.warningTheme(context),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: newStatus
                  ? AppColors.successTheme(context)
                  : AppColors.warningTheme(context),
            ),
            child: Text(newStatus ? 'Activer' : 'Désactiver'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final success = await ShopUserService.instance.updateUser(
      memberId: user.id,
      isActive: newStatus,
    );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newStatus
                ? '${user.fullName} activé'
                : '${user.fullName} désactivé',
          ),
          backgroundColor: newStatus
              ? AppColors.successTheme(context)
              : AppColors.warningTheme(context),
        ),
      );
      await _loadUsers();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Erreur lors de la modification'),
          backgroundColor: AppColors.dangerTheme(context),
        ),
      );
    }
  }

  // ═══════════════════════════════════════════════════════════
  // MODIFIER LE RÔLE
  // ═══════════════════════════════════════════════════════════
  Future<void> _changeRole(ShopUser user) async {
    final newRole = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: AppColors.card(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border(context),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Changer le rôle de ${user.fullName}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.text(context),
              ),
            ),
            const SizedBox(height: 20),
            ...ShopUserRole.assignable.map((role) {
              final isCurrent = user.role == role;
              return ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _getRoleColor(role).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _getRoleIcon(role),
                    color: _getRoleColor(role),
                    size: 22,
                  ),
                ),
                title: Text(
                  ShopUserRole.getLabel(role),
                  style: TextStyle(
                    fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                    color: AppColors.text(context),
                  ),
                ),
                subtitle: Text(
                  ShopUserRole.getDescription(role),
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSec(context),
                  ),
                ),
                trailing: isCurrent
                    ? Icon(
                        Icons.check_circle,
                        color: AppColors.green(context),
                      )
                    : null,
                onTap: () => Navigator.pop(context, role),
              );
            }).toList(),
          ],
        ),
      ),
    );

    if (newRole == null || newRole == user.role) return;

    final success = await ShopUserService.instance.updateUser(
      memberId: user.id,
      role: newRole,
    );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Rôle modifié : ${ShopUserRole.getLabel(newRole)}',
          ),
          backgroundColor: AppColors.successTheme(context),
        ),
      );
      await _loadUsers();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Erreur lors de la modification'),
          backgroundColor: AppColors.dangerTheme(context),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar: AppBar(
        title: const Text('Utilisateurs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadUsers,
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: AppColors.green(context),
              ),
            )
          : _error != null
              ? _buildError()
              : _users.isEmpty
                  ? _buildEmptyState()
                  : RefreshIndicator(
                      onRefresh: _loadUsers,
                      color: AppColors.green(context),
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          _buildInfoCard(),
                          const SizedBox(height: 16),
                          ..._users.map((user) => _buildUserCard(user)),
                        ],
                      ),
                    ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const AddUserScreen(),
            ),
          );
          await _loadUsers();
        },
        backgroundColor: AppColors.green(context),
        foregroundColor: AppColors.onGreen(context),
        icon: Icon(Icons.person_add, color: AppColors.onGreen(context)),
        label: Text(
          'Ajouter',
          style: TextStyle(color: AppColors.onGreen(context)),
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 60,
              color: AppColors.dangerTheme(context),
            ),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: TextStyle(
                fontSize: 15,
                color: AppColors.text(context),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadUsers,
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.group_outlined,
            size: 80,
            color: AppColors.textSec(context).withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'Aucun utilisateur',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textSec(context),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Appuyez sur + pour ajouter un utilisateur',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSec(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.greenLight(context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: AppColors.green(context), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Ajoutez des vendeurs, gérants ou comptables pour vous aider à gérer votre boutique. '
              'Chaque utilisateur se connecte avec son propre numéro de téléphone.',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.text(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(ShopUser user) {
    final roleColor = _getRoleColor(user.role);
    final isCurrentUser = user.userId == AuthService.instance.user?['id'];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: !user.isActive
              ? AppColors.dangerTheme(context).withOpacity(0.4)
              : isCurrentUser
                  ? AppColors.green(context).withOpacity(0.3)
                  : AppColors.border(context),
          width: isCurrentUser ? 2 : 1,
        ),
      ),
      child: Opacity(
        opacity: user.isActive ? 1.0 : 0.6,
        child: Row(
          children: [
            // Avatar
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: roleColor.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  user.initial,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: roleColor,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Infos
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          user.fullName,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.text(context),
                            decoration: user.isActive
                                ? null
                                : TextDecoration.lineThrough,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isCurrentUser)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.greenLight(context),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Vous',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: AppColors.green(context),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.phone_outlined,
                        size: 12,
                        color: AppColors.textSec(context),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        user.phone,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSec(context),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: roleColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _getRoleIcon(user.role),
                              size: 11,
                              color: roleColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              user.roleName,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: roleColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!user.isActive) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.dangerTheme(context)
                                .withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Désactivé',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppColors.dangerTheme(context),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // Menu actions
            if (!user.isOwner && !isCurrentUser)
              PopupMenuButton<String>(
                icon: Icon(
                  Icons.more_vert,
                  color: AppColors.textSec(context),
                ),
                onSelected: (value) {
                  switch (value) {
                    case 'role':
                      _changeRole(user);
                      break;
                    case 'toggle':
                      _toggleActive(user);
                      break;
                    case 'delete':
                      _deleteUser(user);
                      break;
                  }
                },
                itemBuilder: (context) => [
                  // Changer rôle
                  const PopupMenuItem(
                    value: 'role',
                    child: Row(
                      children: [
                        Icon(Icons.swap_horiz, size: 18),
                        SizedBox(width: 8),
                        Text('Changer le rôle'),
                      ],
                    ),
                  ),

                  // Activer / Désactiver
                  PopupMenuItem(
                    value: 'toggle',
                    child: Row(
                      children: [
                        Icon(
                          user.isActive
                              ? Icons.block
                              : Icons.check_circle_outline,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          user.isActive ? 'Désactiver' : 'Activer',
                        ),
                      ],
                    ),
                  ),

                  // Supprimer
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(
                          Icons.delete_outline,
                          size: 18,
                          color: AppColors.dangerTheme(context),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Supprimer',
                          style: TextStyle(
                            color: AppColors.dangerTheme(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'OWNER':
        return AppColors.green(context);
      case 'MANAGER':
        return Colors.blue;
      case 'SELLER':
        return Colors.orange;
      case 'ACCOUNTANT':
        return Colors.purple;
      default:
        return AppColors.textSec(context);
    }
  }

  IconData _getRoleIcon(String role) {
    switch (role) {
      case 'OWNER':
        return Icons.workspace_premium;
      case 'MANAGER':
        return Icons.manage_accounts;
      case 'SELLER':
        return Icons.point_of_sale;
      case 'ACCOUNTANT':
        return Icons.calculate;
      default:
        return Icons.person;
    }
  }
}
