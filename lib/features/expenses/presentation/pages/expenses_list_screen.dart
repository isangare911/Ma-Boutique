import 'package:flutter/material.dart';

import '../../../../core/services/data_refresh_notifier.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../data/models/expense.dart';
import '../../../../data/repositories/expense_repository.dart';
import 'add_expense_screen.dart';

class ExpensesListScreen extends StatefulWidget {
  const ExpensesListScreen({super.key});

  @override
  State<ExpensesListScreen> createState() => _ExpensesListScreenState();
}

class _ExpensesListScreenState extends State<ExpensesListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ExpenseRepository _repository = ExpenseRepository();

  List<Expense> _allExpenses = [];
  List<Expense> _filteredExpenses = [];
  List<Map<String, dynamic>> _byCategory = [];
  bool _isLoading = true;

  double _todayTotal = 0;
  double _monthTotal = 0;
  double _yearTotal = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) _applyFilter();
    });
    DataRefreshNotifier.instance.addListener(_onDataChanged);
    _loadData();
  }

  @override
  void dispose() {
    DataRefreshNotifier.instance.removeListener(_onDataChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onDataChanged() {
    if (mounted) _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final expenses = await _repository.getAllExpenses();
      final today = await _repository.getTodayTotal();
      final month = await _repository.getMonthTotal();
      final year = await _repository.getYearTotal();
      final categories = await _repository.getTotalByCategory();

      if (!mounted) return;

      setState(() {
        _allExpenses = expenses;
        _todayTotal = today;
        _monthTotal = month;
        _yearTotal = year;
        _byCategory = categories;
        _isLoading = false;
      });
      _applyFilter();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  void _applyFilter() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekAgo = today.subtract(const Duration(days: 7));
    final monthStart = DateTime(now.year, now.month, 1);

    setState(() {
      switch (_tabController.index) {
        case 1:
          _filteredExpenses = _allExpenses
              .where((e) => e.expenseDate.isAfter(monthStart))
              .toList();
          break;
        case 2:
          _filteredExpenses = _allExpenses
              .where((e) => e.expenseDate.isAfter(weekAgo))
              .toList();
          break;
        default:
          _filteredExpenses = _allExpenses;
      }
    });
  }

  Future<void> _deleteExpense(Expense expense) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer la dépense'),
        content: Text(
          'Voulez-vous supprimer cette dépense de ${AppFormatters.formatCurrency(expense.amount)} ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.dangerTheme(context),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _repository.deleteExpense(expense.id);
        DataRefreshNotifier.instance.notifyProductsChanged();
        await _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Dépense supprimée'),
              backgroundColor: AppColors.successTheme(context),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur: $e'),
              backgroundColor: AppColors.dangerTheme(context),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar: AppBar(
        title: const Text('Dépenses'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.green(context),
          unselectedLabelColor: AppColors.textSec(context),
          indicatorColor: AppColors.green(context),
          indicatorWeight: 3,
          tabs: const [
            Tab(text: 'Toutes'),
            Tab(text: 'Ce mois'),
            Tab(text: '7 jours'),
          ],
        ),
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: AppColors.green(context),
              ),
            )
          : Column(
              children: [
                _buildSummaryCard(context),
                Expanded(
                  child: _filteredExpenses.isEmpty &&
                          (_byCategory.isEmpty || _tabController.index != 0)
                      ? _buildEmptyState(context)
                      : RefreshIndicator(
                          onRefresh: _loadData,
                          color: AppColors.green(context),
                          child: ListView(
                            padding: const EdgeInsets.all(16),
                            children: [
                              if (_byCategory.isNotEmpty &&
                                  _tabController.index == 0) ...[
                                Text(
                                  'Dépenses par catégorie',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.text(context),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                ..._byCategory.map(
                                  (cat) => _buildCategorySummary(context, cat),
                                ),
                                const SizedBox(height: 24),
                              ],
                              if (_filteredExpenses.isNotEmpty) ...[
                                Text(
                                  _tabController.index == 0
                                      ? 'Historique des dépenses'
                                      : 'Dépenses filtrées',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.text(context),
                                  ),
                                ),
                                const SizedBox(height: 12),
                              ],
                              ..._filteredExpenses.map(
                                (expense) =>
                                    _buildExpenseTile(context, expense),
                              ),
                              if (_filteredExpenses.isEmpty &&
                                  _tabController.index != 0)
                                Padding(
                                  padding: const EdgeInsets.only(top: 40),
                                  child: Center(
                                    child: Column(
                                      children: [
                                        Icon(
                                          Icons.filter_alt_off,
                                          size: 60,
                                          color: AppColors.textSec(context)
                                              .withOpacity(0.4),
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          'Aucune dépense sur cette période',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: AppColors.textSec(context),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'expenses_fab',
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const AddExpenseScreen(),
            ),
          );
          DataRefreshNotifier.instance.notifyProductsChanged();
          await _loadData();
        },
        backgroundColor: AppColors.green(context),
        foregroundColor: AppColors.onGreen(context),
        icon: Icon(Icons.add, color: AppColors.onGreen(context)),
        label: Text(
          'Nouvelle dépense',
          style: TextStyle(color: AppColors.onGreen(context)),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.dangerTheme(context),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Total des dépenses (cette année)',
            style: TextStyle(
              color: Colors.white.withOpacity(0.85),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AppFormatters.formatCurrency(_yearTotal),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Divider(color: Colors.white.withOpacity(0.2)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildMiniStat(context, 'Aujourd\'hui', _todayTotal),
              ),
              Expanded(
                child: _buildMiniStat(context, 'Ce mois', _monthTotal),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(BuildContext context, String label, double value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.85),
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          AppFormatters.formatCurrency(value),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildCategorySummary(
      BuildContext context, Map<String, dynamic> category) {
    final total = _byCategory.fold<double>(
      0,
      (sum, c) => sum + (c['total'] as double),
    );
    final ratio = total > 0 ? (category['total'] as double) / total : 0.0;
    final color = _getCategoryColor(context, category['category'] as String);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _getCategoryIcon(category['category'] as String),
                  color: color,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category['category'] as String,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text(context),
                      ),
                    ),
                    Text(
                      '${category['count']} dépense${(category['count'] as int) > 1 ? "s" : ""}',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSec(context),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                AppFormatters.formatCurrency(category['total'] as double),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 4,
              backgroundColor: AppColors.border(context),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpenseTile(BuildContext context, Expense expense) {
    final color = _getCategoryColor(context, expense.category);

    return Dismissible(
      key: Key(expense.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: AppColors.dangerTheme(context),
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.centerRight,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        await _deleteExpense(expense);
        return false;
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.card(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border(context)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                _getCategoryIcon(expense.category),
                color: color,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    expense.category,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text(context),
                    ),
                  ),
                  if (expense.description != null &&
                      expense.description!.isNotEmpty)
                    Text(
                      expense.description!,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSec(context),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  Text(
                    AppFormatters.formatDate(expense.expenseDate),
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSec(context),
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '- ${AppFormatters.formatCurrency(expense.amount)}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.dangerTheme(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getCategoryColor(BuildContext context, String category) {
    // Couleurs fixes pour la cohérence des catégories
    switch (category) {
      case 'Transport':
        return Colors.blue;
      case 'Électricité':
        return Colors.orange;
      case 'Loyer':
        return Colors.purple;
      case 'Salaire':
        return Colors.teal;
      case 'Achat marchandise':
        return AppColors.green(context);
      case 'Achat matériel':
        return Colors.indigo;
      case 'Réparation':
        return Colors.brown;
      case 'Eau':
        return Colors.cyan;
      case 'Internet':
        return Colors.deepPurple;
      default:
        return AppColors.textSec(context);
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Transport':
        return Icons.local_shipping_outlined;
      case 'Électricité':
        return Icons.bolt;
      case 'Loyer':
        return Icons.home_outlined;
      case 'Salaire':
        return Icons.people_outline;
      case 'Achat marchandise':
        return Icons.shopping_cart_outlined;
      case 'Achat matériel':
        return Icons.build_outlined;
      case 'Réparation':
        return Icons.handyman_outlined;
      case 'Eau':
        return Icons.water_drop_outlined;
      case 'Internet':
        return Icons.wifi;
      default:
        return Icons.receipt_long_outlined;
    }
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.money_off,
            size: 80,
            color: AppColors.textSec(context).withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'Aucune dépense',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textSec(context),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Appuyez sur + pour enregistrer une dépense',
            style: TextStyle(fontSize: 13, color: AppColors.textSec(context)),
          ),
        ],
      ),
    );
  }
}
