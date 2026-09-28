import 'package:flutter/foundation.dart';

/// Notificateur global pour signaler quand les données changent
/// et forcer le rafraîchissement des écrans concernés.
class DataRefreshNotifier extends ChangeNotifier {
  static final DataRefreshNotifier instance = DataRefreshNotifier._();
  DataRefreshNotifier._();

  // Événements spécifiques
  int _productsVersion = 0;
  int _salesVersion = 0;
  int _creditsVersion = 0;
  int _customersVersion = 0;

  int get productsVersion => _productsVersion;
  int get salesVersion => _salesVersion;
  int get creditsVersion => _creditsVersion;
  int get customersVersion => _customersVersion;

  /// Notifier que les produits ont changé (stock modifié, ajout, suppression)
  void notifyProductsChanged() {
    _productsVersion++;
    notifyListeners();
  }

  /// Notifier qu'une vente a été créée ou annulée
  void notifySalesChanged() {
    _salesVersion++;
    _productsVersion++; // Une vente modifie aussi le stock
    notifyListeners();
  }

  /// Notifier qu'un crédit a changé
  void notifyCreditsChanged() {
    _creditsVersion++;
    notifyListeners();
  }

  /// Notifier qu'un client a changé
  void notifyCustomersChanged() {
    _customersVersion++;
    notifyListeners();
  }
}
