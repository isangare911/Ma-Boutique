import '../../core/services/current_shop.dart';
import '../datasources/local/credit_dao.dart';
import '../models/credit.dart';
import '../models/credit_payment.dart';

class CreditRepository {
  final CreditDao _dao = CreditDao();

  Future<List<Credit>> getAllCredits() => _dao.getAllCredits();

  Future<Credit?> getCreditById(String id) => _dao.getCreditById(id);

  Future<List<Credit>> getCreditsByCustomer(String customerId) =>
      _dao.getCreditsByCustomer(customerId);

  Future<String> addCredit(Credit credit) {
    final shopId = CurrentShop.shopId;
    if (shopId == null) {
      throw StateError('Aucun shop connecté');
    }
    return _dao.insertCredit(credit, shopId);
  }

  Future<void> addPayment(CreditPayment payment) {
    final shopId = CurrentShop.shopId;
    if (shopId == null) {
      throw StateError('Aucun shop connecté');
    }
    return _dao.addPayment(payment, shopId);
  }

  Future<List<CreditPayment>> getPaymentsByCredit(String creditId) =>
      _dao.getPaymentsByCredit(creditId);

  Future<List<CreditPayment>> getAllPayments() => _dao.getAllPayments();

  Future<double> getTotalCreditAmount() => _dao.getTotalCreditAmount();
  Future<double> getTotalRemainingAmount() => _dao.getTotalRemainingAmount();
  Future<int> getOverdueCount() => _dao.getOverdueCount();
  Future<double> getTotalPaymentsReceived() => _dao.getTotalPaymentsReceived();
}
