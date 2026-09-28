import 'package:flutter/material.dart';

import 'permissions.dart';

/// Cache complètement le [child] si la permission n'est pas accordée.
/// Utilise [fallback] pour afficher autre chose (par défaut : rien).
class PermissionGuard extends StatelessWidget {
  final Permission permission;
  final Widget child;
  final Widget? fallback;

  const PermissionGuard({
    super.key,
    required this.permission,
    required this.child,
    this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    if (!Permissions.can(permission)) {
      return fallback ?? const SizedBox.shrink();
    }
    return child;
  }
}

/// Vérifie plusieurs permissions (toutes requises).
class PermissionGuardAll extends StatelessWidget {
  final List<Permission> permissions;
  final Widget child;
  final Widget? fallback;

  const PermissionGuardAll({
    super.key,
    required this.permissions,
    required this.child,
    this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    if (!Permissions.canAll(permissions)) {
      return fallback ?? const SizedBox.shrink();
    }
    return child;
  }
}

/// Vérifie au moins une permission.
class PermissionGuardAny extends StatelessWidget {
  final List<Permission> permissions;
  final Widget child;
  final Widget? fallback;

  const PermissionGuardAny({
    super.key,
    required this.permissions,
    required this.child,
    this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    if (!Permissions.canAny(permissions)) {
      return fallback ?? const SizedBox.shrink();
    }
    return child;
  }
}
