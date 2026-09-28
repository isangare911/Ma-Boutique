import '../../data/models/shop_user.dart';
import '../services/auth_service.dart';

// ═══════════════════════════════════════════════════════════
// PERMISSIONS DISPONIBLES
// ═══════════════════════════════════════════════════════════

enum Permission {
  // Dashboard
  viewDashboard,

  // Ventes
  viewSales,
  editSales,

  // Stock
  viewStock,
  editStock,

  // Crédits
  viewCredits,
  editCredits,
  collectCreditPayment,

  // Clients
  viewCustomers,
  editCustomers,

  // Caisse
  viewCash,
  editCash,

  // Dépenses
  viewExpenses,
  editExpenses,

  // Fournisseurs
  viewSuppliers,
  editSuppliers,

  // Rapports
  viewReports,

  // Utilisateurs
  viewUsers,
  editUsers,

  // Paramètres
  viewSettings,
  editSettings,

  // Sync
  viewSync,
  editSync,

  // Abonnement
  viewSubscription,
  editSubscription,

  // Admin
  viewAdminDashboard,
}

// ═══════════════════════════════════════════════════════════
// MATRICE DES PERMISSIONS PAR RÔLE
// ═══════════════════════════════════════════════════════════

class RolePermissions {
  /// Toutes les permissions (OWNER)
  static const Set<Permission> _owner = {
    Permission.viewDashboard,
    Permission.viewSales,
    Permission.editSales,
    Permission.viewStock,
    Permission.editStock,
    Permission.viewCredits,
    Permission.editCredits,
    Permission.collectCreditPayment,
    Permission.viewCustomers,
    Permission.editCustomers,
    Permission.viewCash,
    Permission.editCash,
    Permission.viewExpenses,
    Permission.editExpenses,
    Permission.viewSuppliers,
    Permission.editSuppliers,
    Permission.viewReports,
    Permission.viewUsers,
    Permission.editUsers,
    Permission.viewSettings,
    Permission.editSettings,
    Permission.viewSync,
    Permission.editSync,
    Permission.viewSubscription,
    Permission.editSubscription,
  };

  /// Gérant — tout sauf la gestion des utilisateurs
  static const Set<Permission> _manager = {
    Permission.viewDashboard,
    Permission.viewSales,
    Permission.editSales,
    Permission.viewStock,
    Permission.editStock,
    Permission.viewCredits,
    Permission.editCredits,
    Permission.collectCreditPayment,
    Permission.viewCustomers,
    Permission.editCustomers,
    Permission.viewCash,
    Permission.editCash,
    Permission.viewExpenses,
    Permission.editExpenses,
    Permission.viewSuppliers,
    Permission.editSuppliers,
    Permission.viewReports,
    Permission.viewSettings,
    Permission.editSettings,
    Permission.viewSync,
    Permission.editSync,
    Permission.viewSubscription, // lecture seule
    // ❌ viewUsers, editUsers
    // ❌ editSubscription
  };

  /// Vendeur — ventes + clients + stock en lecture
  static const Set<Permission> _seller = {
    Permission.viewDashboard,
    Permission.viewSales,
    Permission.editSales,
    Permission.viewStock, // 👁️ lecture seule
    // ❌ editStock
    Permission.viewCredits,
    Permission.editCredits,
    Permission.collectCreditPayment,
    Permission.viewCustomers,
    Permission.editCustomers,
    // ❌ cash, expenses, suppliers, reports
    // ❌ users, settings, sync, subscription
  };

  /// Comptable — caisse, dépenses, rapports, crédits
  static const Set<Permission> _accountant = {
    Permission.viewDashboard,
    // ❌ ventes, stock
    Permission.viewCredits,
    Permission.editCredits,
    Permission.collectCreditPayment,
    Permission.viewCustomers, // 👁️ lecture seule
    Permission.viewCash,
    Permission.editCash,
    Permission.viewExpenses,
    Permission.editExpenses,
    Permission.viewReports,
    // ❌ suppliers, users, settings, sync, subscription
  };

  static Set<Permission> forRole(String role) {
    switch (role) {
      case ShopUserRole.owner:
        return _owner;
      case ShopUserRole.manager:
        return _manager;
      case ShopUserRole.seller:
        return _seller;
      case ShopUserRole.accountant:
        return _accountant;
      default:
        return {};
    }
  }
}

// ═══════════════════════════════════════════════════════════
// HELPER GLOBAL : Permissions.can(...)
// ═══════════════════════════════════════════════════════════

class Permissions {
  Permissions._();

  /// Rôle de l'utilisateur connecté
  static String? get _role {
    final user = AuthService.instance.user;
    if (user == null) return null;
    return user['role'] as String?;
  }

  /// Flag superuser (indépendant du rôle boutique)
  static bool get isSuperuser {
    final user = AuthService.instance.user;
    if (user == null) return false;
    return user['is_superuser'] == true;
  }

  /// Vérifie une permission donnée
  static bool can(Permission permission) {
    // Le superuser (admin SaaS) a tous les droits sauf ce qui est réservé OWNER
    if (isSuperuser && permission == Permission.viewAdminDashboard) {
      return true;
    }

    final role = _role;
    if (role == null) return false;

    final perms = RolePermissions.forRole(role);
    return perms.contains(permission);
  }

  /// Vérifie plusieurs permissions (toutes requises)
  static bool canAll(List<Permission> permissions) {
    return permissions.every(can);
  }

  /// Vérifie au moins une permission
  static bool canAny(List<Permission> permissions) {
    return permissions.any(can);
  }

  /// Peut-on accéder au dashboard admin SaaS ?
  static bool get canViewAdminDashboard => isSuperuser;
}
