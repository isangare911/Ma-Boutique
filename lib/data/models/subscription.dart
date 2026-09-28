class Subscription {
  final String shopId;
  final String plan; // TRIAL, ESSENTIEL, PRO, BUSINESS
  final String status; // TRIAL, ACTIVE, GRACE_PERIOD, EXPIRED
  final DateTime start;
  final DateTime? end;
  final int daysRemaining;
  final bool isActive;
  final DateTime? lastPaymentDate;
  final DateTime lastVerifiedAt; // ⚡ Anti-manipulation de date

  Subscription({
    required this.shopId,
    required this.plan,
    required this.status,
    required this.start,
    this.end,
    required this.daysRemaining,
    required this.isActive,
    this.lastPaymentDate,
    required this.lastVerifiedAt,
  });

  // ═══════════════════════════════════════════════════════════
  // ÉTAT DE L'ABONNEMENT
  // ═══════════════════════════════════════════════════════════

  bool get isTrial => status == 'TRIAL';
  bool get isActiveStatus => status == 'ACTIVE';
  bool get isGracePeriod => status == 'GRACE_PERIOD';
  bool get isExpired => status == 'EXPIRED';

  /// Peut-on vendre ? (essai ou actif seulement)
  bool get canSell => isActive || isTrial;

  /// Peut-on consulter les données ?
  bool get canView => true; // Toujours vrai

  /// Nom lisible du plan
  String get planName {
    switch (plan) {
      case 'TRIAL':
        return 'Essai gratuit';
      case 'ESSENTIEL':
        return 'Essentiel';
      case 'PRO':
        return 'Pro';
      case 'BUSINESS':
        return 'Business';
      default:
        return plan;
    }
  }

  /// Nom lisible du statut
  String get statusName {
    switch (status) {
      case 'TRIAL':
        return 'Période d\'essai';
      case 'ACTIVE':
        return 'Actif';
      case 'GRACE_PERIOD':
        return 'Période de grâce';
      case 'EXPIRED':
        return 'Expiré';
      default:
        return status;
    }
  }

  // ═══════════════════════════════════════════════════════════
  // SERIALIZATION
  // ═══════════════════════════════════════════════════════════

  factory Subscription.fromJson(Map<String, dynamic> json) {
    return Subscription(
      shopId: json['id'] as String,
      plan: json['subscription_plan'] as String? ?? 'TRIAL',
      status: json['subscription_status'] as String? ?? 'TRIAL',
      start: DateTime.parse(json['subscription_start'] as String),
      end: json['subscription_end'] != null
          ? DateTime.parse(json['subscription_end'] as String)
          : null,
      daysRemaining: json['days_remaining'] as int? ?? 0,
      isActive: json['is_active'] as bool? ?? false,
      lastPaymentDate: json['last_payment_date'] != null
          ? DateTime.parse(json['last_payment_date'] as String)
          : null,
      lastVerifiedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'shop_id': shopId,
      'plan': plan,
      'status': status,
      'start': start.toIso8601String(),
      'end': end?.toIso8601String(),
      'days_remaining': daysRemaining,
      'is_active': isActive,
      'last_payment_date': lastPaymentDate?.toIso8601String(),
      'last_verified_at': lastVerifiedAt.toIso8601String(),
    };
  }

  Subscription copyWith({
    String? shopId,
    String? plan,
    String? status,
    DateTime? start,
    DateTime? end,
    int? daysRemaining,
    bool? isActive,
    DateTime? lastPaymentDate,
    DateTime? lastVerifiedAt,
  }) {
    return Subscription(
      shopId: shopId ?? this.shopId,
      plan: plan ?? this.plan,
      status: status ?? this.status,
      start: start ?? this.start,
      end: end ?? this.end,
      daysRemaining: daysRemaining ?? this.daysRemaining,
      isActive: isActive ?? this.isActive,
      lastPaymentDate: lastPaymentDate ?? this.lastPaymentDate,
      lastVerifiedAt: lastVerifiedAt ?? this.lastVerifiedAt,
    );
  }
}

// ═══════════════════════════════════════════════════════════
// PLAN D'ABONNEMENT (pour l'écran de choix)
// ═══════════════════════════════════════════════════════════
class SubscriptionPlan {
  final String code;
  final String name;
  final int priceMonthly;
  final int priceYearly;
  final List<String> features;

  SubscriptionPlan({
    required this.code,
    required this.name,
    required this.priceMonthly,
    required this.priceYearly,
    required this.features,
  });

  factory SubscriptionPlan.fromJson(Map<String, dynamic> json) {
    return SubscriptionPlan(
      code: json['code'] as String,
      name: json['name'] as String,
      priceMonthly: json['price_monthly'] as int,
      priceYearly: json['price_yearly'] as int,
      features: List<String>.from(json['features'] as List),
    );
  }
}
