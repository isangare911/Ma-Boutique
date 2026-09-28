import 'package:flutter/foundation.dart';

import '../../data/repositories/credit_repository.dart';
import '../../data/repositories/product_repository.dart';
import 'notification_service.dart';
import 'shop_settings_service.dart';

class NotificationChecker {
  static final NotificationChecker instance = NotificationChecker._();
  NotificationChecker._();

  final CreditRepository _creditRepo = CreditRepository();
  final ProductRepository _productRepo = ProductRepository();

  /// Vérifie tous les rappels et affiche les notifications
  Future<void> checkAll() async {
    try {
      await _checkCreditDueSoon();
      await _checkCreditOverdue();
      await _checkStockAlerts();
    } catch (e) {
      debugPrint('Erreur NotificationChecker: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════
  // CRÉDITS À ÉCHÉANCE (5j, 2j, aujourd'hui)
  // ═══════════════════════════════════════════════════════════
  Future<void> _checkCreditDueSoon() async {
    final credits = await _creditRepo.getAllCredits();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    for (final credit in credits) {
      if (credit.isPaid || credit.isOverdue) continue;

      final dueDay = DateTime(
        credit.dueDate.year,
        credit.dueDate.month,
        credit.dueDate.day,
      );
      final daysLeft = dueDay.difference(today).inDays;

      // Rappel à 5 jours
      if (daysLeft == 5) {
        await NotificationService.instance.showCreditDueSoon(
          customerName: credit.customer.name,
          amount: credit.remainingAmount,
          daysLeft: 5,
          currency: ShopSettingsService.instance.currency,
        );
      }
      // Rappel à 2 jours
      else if (daysLeft == 2) {
        await NotificationService.instance.showCreditDueSoon(
          customerName: credit.customer.name,
          amount: credit.remainingAmount,
          daysLeft: 2,
          currency: ShopSettingsService.instance.currency,
        );
      }
      // Rappel le jour de l'échéance
      else if (daysLeft == 0) {
        await NotificationService.instance.showCreditDueSoon(
          customerName: credit.customer.name,
          amount: credit.remainingAmount,
          daysLeft: 0,
          currency: ShopSettingsService.instance.currency,
        );
      }
    }
  }

  // ═══════════════════════════════════════════════════════════
  // CRÉDITS EN RETARD
  // ═══════════════════════════════════════════════════════════
  Future<void> _checkCreditOverdue() async {
    final credits = await _creditRepo.getAllCredits();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    for (final credit in credits) {
      if (credit.isPaid || !credit.isOverdue) continue;

      final dueDay = DateTime(
        credit.dueDate.year,
        credit.dueDate.month,
        credit.dueDate.day,
      );
      final daysLate = today.difference(dueDay).inDays;

      // Ne notifier qu'une fois tous les 3 jours pour éviter le spam
      if (daysLate % 3 == 0) {
        await NotificationService.instance.showCreditOverdue(
          customerName: credit.customer.name,
          amount: credit.remainingAmount,
          daysLate: daysLate,
          currency: ShopSettingsService.instance.currency,
        );
      }
    }
  }

  // ═══════════════════════════════════════════════════════════
  // STOCK FAIBLE ET RUPTURES
  // ═══════════════════════════════════════════════════════════
  Future<void> _checkStockAlerts() async {
    // Ruptures
    final outOfStock = await _productRepo.getOutOfStockProducts();
    for (final product in outOfStock) {
      await NotificationService.instance.showOutOfStock(
        productName: product.name,
      );
    }

    // Stock faible
    final lowStock = await _productRepo.getLowStockProducts();
    for (final product in lowStock) {
      await NotificationService.instance.showLowStock(
        productName: product.name,
        quantity: product.quantity,
        unit: product.unit ?? 'unité(s)',
      );
    }
  }
}
