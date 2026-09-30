import '../../core/services/current_shop.dart';
import '../datasources/local/expense_dao.dart';
import '../models/expense.dart';

class ExpenseRepository {
  final ExpenseDao _dao = ExpenseDao();

  Future<List<Expense>> getAllExpenses() => _dao.getAllExpenses();

  Future<List<Expense>> getExpensesByDateRange(DateTime start, DateTime end) =>
      _dao.getExpensesByDateRange(start, end);

  Future<List<Expense>> getExpensesByCategory(String category) =>
      _dao.getExpensesByCategory(category);

  Future<Expense?> getExpenseById(String id) => _dao.getExpenseById(id);

  Future<String> addExpense(Expense expense) {
    final shopId = CurrentShop.shopId;
    if (shopId == null) {
      throw StateError('Aucun shop connecté');
    }
    return _dao.insertExpense(expense, shopId);
  }

  Future<void> updateExpense(Expense expense) {
    final shopId = CurrentShop.shopId;
    if (shopId == null) {
      throw StateError('Aucun shop connecté');
    }
    return _dao.updateExpense(expense, shopId);
  }

  Future<void> deleteExpense(String id) => _dao.deleteExpense(id);

  Future<double> getTodayTotal() => _dao.getTodayTotal();
  Future<double> getMonthTotal() => _dao.getMonthTotal();
  Future<double> getYearTotal() => _dao.getYearTotal();

  Future<List<Map<String, dynamic>>> getTotalByCategory({
    DateTime? start,
    DateTime? end,
  }) =>
      _dao.getTotalByCategory(start: start, end: end);
}
