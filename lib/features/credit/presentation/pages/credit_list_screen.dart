import 'package:flutter/material.dart';

import '../../../../core/services/data_refresh_notifier.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../data/models/credit.dart';
import '../../../../data/repositories/credit_repository.dart';
import '../widgets/customer_credit_tile.dart';
import 'credit_detail_screen.dart';
import 'new_credit_screen.dart';
import 'payment_history_screen.dart';

class CreditListScreen extends StatefulWidget {
  const CreditListScreen({super.key});

  @override
  State<CreditListScreen> createState() => _CreditListScreenState();
}

class _CreditListScreenState extends State<CreditListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final CreditRepository _repository = CreditRepository();

  List<Credit> _allCredits = [];
  List<Credit> _filteredCredits = [];
  bool _isLoading = true;

  double _totalCredit = 0;
  double _totalRemaining = 0;
  int _overdueCount = 0;

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
      final credits = await _repository.getAllCredits();
      final total = await _repository.getTotalCreditAmount();
      final remaining = await _repository.getTotalRemainingAmount();
      final overdue = await _repository.getOverdueCount();

      if (!mounted) return;

      setState(() {
        _allCredits = credits;
        _totalCredit = total;
        _totalRemaining = remaining;
        _overdueCount = overdue;
        _isLoading = false;
      });
      _applyFilter();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  void _applyFilter() {
    setState(() {
      switch (_tabController.index) {
        case 1:
          _filteredCredits = _allCredits.where((c) => !c.isPaid).toList();
          break;
        case 2:
          _filteredCredits = _allCredits.where((c) => c.isOverdue).toList();
          break;
        default:
          _filteredCredits = _allCredits;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar: AppBar(
        title: const Text('Cahier de crédit'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Historique des paiements',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const PaymentHistoryScreen(),
                ),
              ).then((_) => _loadData());
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Rafraîchir',
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
            Tab(text: 'Tous'),
            Tab(text: 'En cours'),
            Tab(text: 'En retard'),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildSummaryCard(context),
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      color: AppColors.green(context),
                    ),
                  )
                : _filteredCredits.isEmpty
                    ? _buildEmptyState(context)
                    : RefreshIndicator(
                        onRefresh: _loadData,
                        color: AppColors.green(context),
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredCredits.length,
                          itemBuilder: (context, index) {
                            final credit = _filteredCredits[index];
                            return CustomerCreditTile(
                              credit: credit,
                              onTap: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        CreditDetailScreen(credit: credit),
                                  ),
                                );
                                DataRefreshNotifier.instance
                                    .notifyCreditsChanged();
                                await _loadData();
                              },
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'credit_fab',
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const NewCreditScreen()),
          );
          DataRefreshNotifier.instance.notifyCreditsChanged();
          await _loadData();
        },
        backgroundColor: AppColors.green(context),
        foregroundColor: AppColors.onGreen(context),
        icon: Icon(Icons.add, color: AppColors.onGreen(context)),
        label: Text(
          'Nouveau crédit',
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
        color: AppColors.green(context),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSummaryItem(
                context,
                'Total crédits',
                AppFormatters.formatCurrency(_totalCredit),
              ),
              _buildSummaryItem(
                context,
                'À recouvrer',
                AppFormatters.formatCurrency(_totalRemaining),
              ),
            ],
          ),
          if (_overdueCount > 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.dangerTheme(context).withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: AppColors.onGreen(context),
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$_overdueCount crédit${_overdueCount > 1 ? "s" : ""} en retard',
                    style: TextStyle(
                      color: AppColors.onGreen(context),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryItem(BuildContext context, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppColors.onGreenSec(context),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: AppColors.onGreen(context),
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.credit_card_outlined,
            size: 80,
            color: AppColors.textSec(context).withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'Aucun crédit',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textSec(context),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Appuyez sur + pour créer un crédit',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSec(context),
            ),
          ),
        ],
      ),
    );
  }
}
