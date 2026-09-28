import '../datasources/local/credit_dao.dart';
import '../models/credit.dart';
import '../models/credit_payment.dart';

class CreditRepository {
  final CreditDao _dao = CreditDao();
  static const String _defaultShopId = 'SHOP-00001';

  Future<List<Credit>> getAllCredits() => _dao.getAllCredits();
  Future<Credit?> getCreditById(String id) => _dao.getCreditById(id);
  Future<List<Credit>> getCreditsByCustomer(String customerId) =>
      _dao.getCreditsByCustomer(customerId);
  Future<String> addCredit(Credit credit) =>
      _dao.insertCredit(credit, _defaultShopId);
  Future<void> addPayment(CreditPayment payment) =>
      _dao.addPayment(payment, _defaultShopId);
  Future<List<CreditPayment>> getPaymentsByCredit(String creditId) =>
      _dao.getPaymentsByCredit(creditId);
  Future<List<CreditPayment>> getAllPayments() => _dao.getAllPayments();

  // Statistiques
  Future<double> getTotalCreditAmount() => _dao.getTotalCreditAmount();
  Future<double> getTotalRemainingAmount() => _dao.getTotalRemainingAmount();
  Future<int> getOverdueCount() => _dao.getOverdueCount();
  Future<double> getTotalPaymentsReceived() => _dao.getTotalPaymentsReceived();
}
