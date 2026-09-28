// ═══════════════════════════════════════════════════════════
// STATISTIQUES GLOBALES (Dashboard Admin)
// ═══════════════════════════════════════════════════════════
class AdminStats {
  final double totalRevenue;
  final double monthlyRevenue;
  final double weeklyRevenue;
  final double mrr;
  final int totalPayments;
  final int pendingReview;
  final int rejectedPayments;
  final int totalShops;
  final int activeShops;
  final int trialShops;
  final int graceShops;
  final int expiredShops;
  final int newShopsThisMonth;
  final int newShopsThisWeek;
  final double renewalRate;
  final List<RevenueByPlan> revenueByPlan;
  final List<RevenueByMethod> revenueByMethod;

  AdminStats({
    required this.totalRevenue,
    required this.monthlyRevenue,
    required this.weeklyRevenue,
    required this.mrr,
    required this.totalPayments,
    required this.pendingReview,
    required this.rejectedPayments,
    required this.totalShops,
    required this.activeShops,
    required this.trialShops,
    required this.graceShops,
    required this.expiredShops,
    required this.newShopsThisMonth,
    required this.newShopsThisWeek,
    required this.renewalRate,
    required this.revenueByPlan,
    required this.revenueByMethod,
  });

  factory AdminStats.fromJson(Map<String, dynamic> json) {
    return AdminStats(
      totalRevenue: _toDouble(json['total_revenue']),
      monthlyRevenue: _toDouble(json['monthly_revenue']),
      weeklyRevenue: _toDouble(json['weekly_revenue']),
      mrr: _toDouble(json['mrr']),
      totalPayments: json['total_payments'] as int? ?? 0,
      pendingReview: json['pending_review'] as int? ?? 0,
      rejectedPayments: json['rejected_payments'] as int? ?? 0,
      totalShops: json['total_shops'] as int? ?? 0,
      activeShops: json['active_shops'] as int? ?? 0,
      trialShops: json['trial_shops'] as int? ?? 0,
      graceShops: json['grace_shops'] as int? ?? 0,
      expiredShops: json['expired_shops'] as int? ?? 0,
      newShopsThisMonth: json['new_shops_this_month'] as int? ?? 0,
      newShopsThisWeek: json['new_shops_this_week'] as int? ?? 0,
      renewalRate: _toDouble(json['renewal_rate']),
      revenueByPlan: (json['revenue_by_plan'] as List? ?? [])
          .map((e) => RevenueByPlan.fromJson(e as Map<String, dynamic>))
          .toList(),
      revenueByMethod: (json['revenue_by_method'] as List? ?? [])
          .map((e) => RevenueByMethod.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  static double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }
}

class RevenueByPlan {
  final String plan;
  final double total;
  final int count;

  RevenueByPlan({
    required this.plan,
    required this.total,
    required this.count,
  });

  factory RevenueByPlan.fromJson(Map<String, dynamic> json) {
    return RevenueByPlan(
      plan: json['plan'] as String,
      total: AdminStats._toDouble(json['total']),
      count: json['count'] as int? ?? 0,
    );
  }

  String get planName {
    switch (plan) {
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
}

class RevenueByMethod {
  final String method;
  final double total;
  final int count;

  RevenueByMethod({
    required this.method,
    required this.total,
    required this.count,
  });

  factory RevenueByMethod.fromJson(Map<String, dynamic> json) {
    return RevenueByMethod(
      method: json['method'] as String,
      total: AdminStats._toDouble(json['total']),
      count: json['count'] as int? ?? 0,
    );
  }

  String get methodName {
    switch (method) {
      case 'ORANGE_MONEY':
        return 'Orange Money';
      case 'WAVE':
        return 'Wave';
      case 'MOOV_MONEY':
        return 'Moov Money';
      case 'CASH':
        return 'Espèces';
      default:
        return method;
    }
  }
}

// ═══════════════════════════════════════════════════════════
// BOUTIQUE (avec stats pour l'admin)
// ═══════════════════════════════════════════════════════════
class AdminShop {
  final String id;
  final String name;
  final String ownerName;
  final String phone;
  final String currency;
  final String plan;
  final String status;
  final int daysRemaining;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool isActive;
  final DateTime createdAt;
  final double totalPaid;
  final int paymentCount;
  final DateTime? lastPaymentDate;

  AdminShop({
    required this.id,
    required this.name,
    required this.ownerName,
    required this.phone,
    required this.currency,
    required this.plan,
    required this.status,
    required this.daysRemaining,
    this.startDate,
    this.endDate,
    required this.isActive,
    required this.createdAt,
    required this.totalPaid,
    required this.paymentCount,
    this.lastPaymentDate,
  });

  factory AdminShop.fromJson(Map<String, dynamic> json) {
    return AdminShop(
      id: json['id'] as String,
      name: json['name'] as String,
      ownerName: json['owner_name'] as String? ?? '—',
      phone: json['phone'] as String? ?? '—',
      currency: json['currency'] as String? ?? 'FCFA',
      plan: json['plan'] as String,
      status: json['status'] as String,
      daysRemaining: json['days_remaining'] as int? ?? 0,
      startDate: json['start_date'] != null
          ? DateTime.parse(json['start_date'] as String)
          : null,
      endDate: json['end_date'] != null
          ? DateTime.parse(json['end_date'] as String)
          : null,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      totalPaid: AdminStats._toDouble(json['total_paid']),
      paymentCount: json['payment_count'] as int? ?? 0,
      lastPaymentDate: json['last_payment_date'] != null
          ? DateTime.parse(json['last_payment_date'] as String)
          : null,
    );
  }

  String get planName {
    switch (plan) {
      case 'TRIAL':
        return 'Essai';
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

  String get statusName {
    switch (status) {
      case 'TRIAL':
        return 'Essai';
      case 'ACTIVE':
        return 'Actif';
      case 'GRACE_PERIOD':
        return 'Grâce';
      case 'EXPIRED':
        return 'Expiré';
      default:
        return status;
    }
  }
}
