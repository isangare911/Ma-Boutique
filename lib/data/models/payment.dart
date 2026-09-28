class Payment {
  final String id;
  final String paymentCode;
  final String plan;
  final String planName;
  final double amount;
  final String method;
  final String methodName;
  final String status;
  final String? transactionId;
  final String? payerPhone;
  final int durationDays;
  final DateTime createdAt;
  final DateTime? approvedAt;
  final String? rejectionReason;
  final int? approvedBy;

  Payment({
    required this.id,
    required this.paymentCode,
    required this.plan,
    required this.planName,
    required this.amount,
    required this.method,
    required this.methodName,
    required this.status,
    this.transactionId,
    this.payerPhone,
    required this.durationDays,
    required this.createdAt,
    this.approvedAt,
    this.rejectionReason,
    this.approvedBy,
  });

  // ═══════════════════════════════════════════════════════════
  // ÉTATS DU PAIEMENT
  // ═══════════════════════════════════════════════════════════

  bool get isPending => status == 'PENDING';
  bool get isPendingReview => status == 'PENDING_REVIEW';
  bool get isApproved => status == 'APPROVED';
  bool get isRejected => status == 'REJECTED';
  bool get isCancelled => status == 'CANCELLED';
  bool get isSuccess => status == 'SUCCESS';

  bool get isFinalized => isApproved || isRejected || isCancelled;
  bool get isInProgress => isPending || isPendingReview;

  factory Payment.fromJson(Map<String, dynamic> json) {
    return Payment(
      id: json['id'] as String,
      paymentCode: json['payment_code'] as String? ?? '',
      plan: json['plan'] as String,
      planName: json['plan_name'] as String? ?? json['plan'] as String,
      amount: _parseAmount(json['amount']),
      method: json['method'] as String,
      methodName: json['method_name'] as String? ?? json['method'] as String,
      status: json['status'] as String,
      transactionId: json['transaction_id'] as String?,
      payerPhone: json['payer_phone'] as String?,
      durationDays: json['duration_days'] as int? ?? 30,
      createdAt: DateTime.parse(json['created_at'] as String),
      approvedAt: json['approved_at'] != null
          ? DateTime.parse(json['approved_at'] as String)
          : (json['paid_at'] != null
              ? DateTime.parse(json['paid_at'] as String)
              : null),
      rejectionReason: json['rejection_reason'] as String?,
      approvedBy: json['approved_by'] as int?,
    );
  }

  static double _parseAmount(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  /// Libellé long du statut
  String get statusLabel {
    switch (status) {
      case 'PENDING':
        return 'En attente de paiement';
      case 'PENDING_REVIEW':
        return 'En cours de validation';
      case 'APPROVED':
        return 'Approuvé';
      case 'REJECTED':
        return 'Rejeté';
      case 'CANCELLED':
        return 'Annulé';
      case 'SUCCESS':
        return 'Payé';
      default:
        return status;
    }
  }

  /// ⚡ Libellé court du statut (pour badges)
  String get statusName {
    switch (status) {
      case 'PENDING':
        return 'En attente';
      case 'PENDING_REVIEW':
        return 'À valider';
      case 'APPROVED':
        return 'Approuvé';
      case 'REJECTED':
        return 'Rejeté';
      case 'CANCELLED':
        return 'Annulé';
      case 'SUCCESS':
        return 'Payé';
      default:
        return status;
    }
  }
}

// ═══════════════════════════════════════════════════════════
// INSTRUCTIONS DE PAIEMENT
// ═══════════════════════════════════════════════════════════
class PaymentInstructions {
  final String paymentId;
  final String paymentCode;
  final int amount;
  final String method;
  final String methodName;
  final String merchantNumber;
  final String reference;
  final List<String> steps;
  final String warning;

  PaymentInstructions({
    required this.paymentId,
    required this.paymentCode,
    required this.amount,
    required this.method,
    required this.methodName,
    required this.merchantNumber,
    required this.reference,
    required this.steps,
    required this.warning,
  });

  factory PaymentInstructions.fromJson(Map<String, dynamic> json) {
    return PaymentInstructions(
      paymentId: json['payment_id'] as String,
      paymentCode: json['payment_code'] as String? ??
          json['reference'] as String? ??
          json['payment_id'] as String,
      amount: _parseInt(json['amount']),
      method: json['method'] as String,
      methodName: json['method_name'] as String,
      merchantNumber: json['merchant_number'] as String,
      reference: json['reference'] as String,
      steps: List<String>.from(json['steps'] as List),
      warning: json['warning'] as String? ?? '',
    );
  }

  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
}
