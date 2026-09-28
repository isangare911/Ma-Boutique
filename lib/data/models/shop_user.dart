class ShopUser {
  final String id;
  final int userId;
  final String phone;
  final String firstName;
  final String lastName;
  final String role; // OWNER, MANAGER, SELLER, ACCOUNTANT
  final bool isActive;
  final bool isSuperuser;
  final Map<String, dynamic> permissions;
  final DateTime createdAt;

  ShopUser({
    required this.id,
    required this.userId,
    required this.phone,
    required this.firstName,
    required this.lastName,
    required this.role,
    required this.isActive,
    required this.isSuperuser,
    required this.permissions,
    required this.createdAt,
  });

  // ═══════════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════════

  String get fullName {
    final name = '$firstName $lastName'.trim();
    return name.isEmpty ? phone : name;
  }

  String get initial {
    final name = firstName.isNotEmpty ? firstName : phone;
    return name.substring(0, 1).toUpperCase();
  }

  bool get isOwner => role == 'OWNER';
  bool get isManager => role == 'MANAGER';
  bool get isSeller => role == 'SELLER';
  bool get isAccountant => role == 'ACCOUNTANT';

  /// Libellé du rôle
  String get roleName {
    switch (role) {
      case 'OWNER':
        return 'Propriétaire';
      case 'MANAGER':
        return 'Gérant';
      case 'SELLER':
        return 'Vendeur';
      case 'ACCOUNTANT':
        return 'Comptable';
      default:
        return role;
    }
  }

  factory ShopUser.fromJson(Map<String, dynamic> json) {
    return ShopUser(
      id: json['id'] as String,
      userId: json['user_id'] as int? ?? 0,
      phone: json['phone'] as String? ?? '',
      firstName: json['first_name'] as String? ?? '',
      lastName: json['last_name'] as String? ?? '',
      role: json['role'] as String? ?? 'SELLER',
      isActive: json['is_active'] as bool? ?? true,
      isSuperuser: json['is_superuser'] as bool? ?? false,
      permissions: json['permissions'] as Map<String, dynamic>? ?? {},
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// CONSTANTES DES RÔLES
// ═══════════════════════════════════════════════════════════

class ShopUserRole {
  static const String owner = 'OWNER';
  static const String manager = 'MANAGER';
  static const String seller = 'SELLER';
  static const String accountant = 'ACCOUNTANT';

  /// Rôles assignables (exclut OWNER)
  static const List<String> assignable = [
    manager,
    seller,
    accountant,
  ];

  static String getLabel(String role) {
    switch (role) {
      case owner:
        return 'Propriétaire';
      case manager:
        return 'Gérant';
      case seller:
        return 'Vendeur';
      case accountant:
        return 'Comptable';
      default:
        return role;
    }
  }

  static String getDescription(String role) {
    switch (role) {
      case owner:
        return 'Accès complet à toutes les fonctionnalités';
      case manager:
        return 'Gestion quotidienne (ventes, stock, crédits, caisse)';
      case seller:
        return 'Peut effectuer des ventes et gérer les clients';
      case accountant:
        return 'Accès aux rapports, à la caisse et aux dépenses';
      default:
        return '';
    }
  }
}
