import '../../core/services/current_shop.dart';
import '../datasources/local/cash_dao.dart';
import '../models/cash_movement.dart';
import '../models/cash_session.dart';

class CashRepository {
  final CashDao _dao = CashDao();

  Future<String> openSession(CashSession session) {
    final shopId = CurrentShop.shopId;
    if (shopId == null) {
      throw StateError('Aucun shop connecté');
    }
    return _dao.openSession(session, shopId);
  }

  Future<CashSession?> getCurrentSession() => _dao.getCurrentSession();

  Future<List<CashSession>> getAllSessions() => _dao.getAllSessions();

  Future<void> closeSession(String sessionId, double closingBalance) =>
      _dao.closeSession(sessionId, closingBalance);

  Future<String> addMovement(CashMovement movement) =>
      _dao.addMovement(movement);

  Future<List<CashMovement>> getMovementsBySession(String sessionId) =>
      _dao.getMovementsBySession(sessionId);

  Future<void> deleteMovement(String id) => _dao.deleteMovement(id);

  Future<double> getTheoreticalBalance(String sessionId) =>
      _dao.getTheoreticalBalance(sessionId);

  Future<Map<String, double>> getSessionSummary(String sessionId) =>
      _dao.getSessionSummary(sessionId);
}
