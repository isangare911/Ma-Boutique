import 'package:flutter/material.dart';

import '../../../../core/services/data_refresh_notifier.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../data/models/sale.dart';
import '../../../../data/repositories/sale_repository.dart';
import 'new_sale_screen.dart';

class SalesListScreen extends StatefulWidget {
  const SalesListScreen({super.key});

  @override
  State<SalesListScreen> createState() => _SalesListScreenState();
}

class _SalesListScreenState extends State<SalesListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final SaleRepository _repository = SaleRepository();

  List<Sale> _allSales = [];
  List<Sale> _filteredSales = [];
  bool _isLoading = true;

  double _todayRevenue = 0;
  double _todayProfit = 0;
  int _todayCount = 0;

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
    setState(() => _isLoading = true);
    try {
      final sales = await _repository.getAllSales();
      final revenue = await _repository.getTodayRevenue();
      final profit = await _repository.getTodayProfit();
      final count = await _repository.getTodaySalesCount();

      if (!mounted) return;

      setState(() {
        _allSales = sales;
        _todayRevenue = revenue;
        _todayProfit = profit;
        _todayCount = count;
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

    setState(() {
      switch (_tabController.index) {
        case 1:
          _filteredSales =
              _allSales.where((s) => s.createdAt.isAfter(today)).toList();
          break;
        case 2:
          _filteredSales =
              _allSales.where((s) => s.createdAt.isAfter(weekAgo)).toList();
          break;
        default:
          _filteredSales = _allSales;
      }
    });
  }

  Future<void> _cancelSale(Sale sale) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Annuler la vente'),
        content: Text(
          'Voulez-vous annuler la vente ${sale.id} ?\n\n'
          'Le stock sera automatiquement restauré.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Non'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.dangerTheme(context),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Oui, annuler'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _repository.cancelSale(sale.id);
        DataRefreshNotifier.instance.notifySalesChanged();
        await _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Vente annulée et stock restauré'),
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

  Future<void> _showSaleDetail(Sale sale) async {
    final fullSale = await _repository.getSaleById(sale.id);
    if (fullSale == null || !mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildSaleDetailSheet(context, fullSale),
    );
  }

  Widget _buildSaleDetailSheet(BuildContext context, Sale sale) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bg(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border(context),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sale.id,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.green(context),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    AppFormatters.formatDateTime(sale.createdAt),
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSec(context),
                    ),
                  ),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (sale.status == 'COMPLETED'
                          ? AppColors.successTheme(context)
                          : AppColors.dangerTheme(context))
                      .withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  sale.status == 'COMPLETED' ? 'Complétée' : 'Annulée',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: sale.status == 'COMPLETED'
                        ? AppColors.successTheme(context)
                        : AppColors.dangerTheme(context),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: AppColors.border(context)),
          Text(
            'Articles',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.text(context),
            ),
          ),
          const SizedBox(height: 8),
          ...sale.items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.productName,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.text(context),
                            ),
                          ),
                          Text(
                            '${item.quantity} x ${AppFormatters.formatCurrency(item.unitPrice)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSec(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      AppFormatters.formatCurrency(item.subtotal),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text(context),
                      ),
                    ),
                  ],
                ),
              )),
          Divider(color: AppColors.border(context)),
          _buildDetailRow(context, 'Mode de paiement', sale.paymentMethod),
          const SizedBox(height: 8),
          _buildDetailRow(
            context,
            'Total',
            AppFormatters.formatCurrency(sale.totalAmount),
            isBold: true,
            color: AppColors.green(context),
          ),
          const SizedBox(height: 24),
          if (sale.status == 'COMPLETED')
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _cancelSale(sale);
              },
              icon: const Icon(Icons.cancel_outlined),
              label: const Text('Annuler la vente'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.dangerTheme(context),
                foregroundColor: Colors.white,
              ),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildDetailRow(
    BuildContext context,
    String label,
    String value, {
    bool isBold = false,
    Color? color,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: AppColors.textSec(context),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isBold ? 16 : 13,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: color ?? AppColors.text(context),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar: AppBar(
        title: const Text('Ventes'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Rafraîchir',
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
            Tab(text: "Aujourd'hui"),
            Tab(text: '7 jours'),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildTodaySummary(context),
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      color: AppColors.green(context),
                    ),
                  )
                : _filteredSales.isEmpty
                    ? _buildEmptyState(context)
                    : RefreshIndicator(
                        onRefresh: _loadData,
                        color: AppColors.green(context),
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredSales.length,
                          itemBuilder: (context, index) {
                            return _buildSaleTile(
                                context, _filteredSales[index]);
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'sales_fab',
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const NewSaleScreen()),
          );
          DataRefreshNotifier.instance.notifySalesChanged();
          await _loadData();
        },
        backgroundColor: AppColors.green(context),
        foregroundColor: AppColors.onGreen(context),
        icon: Icon(Icons.add, color: AppColors.onGreen(context)),
        label: Text(
          'Nouvelle vente',
          style: TextStyle(color: AppColors.onGreen(context)),
        ),
      ),
    );
  }

  Widget _buildTodaySummary(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.green(context),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Chiffre d'affaires (aujourd'hui)",
            style: TextStyle(
              color: AppColors.onGreenSec(context),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AppFormatters.formatCurrency(_todayRevenue),
            style: TextStyle(
              color: AppColors.onGreen(context),
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildSummaryItem(context, 'Ventes', '$_todayCount'),
              const SizedBox(width: 32),
              _buildSummaryItem(
                context,
                'Bénéfice',
                AppFormatters.formatCurrency(_todayProfit),
              ),
            ],
          ),
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
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: AppColors.onGreen(context),
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildSaleTile(BuildContext context, Sale sale) {
    final isCancelled = sale.status == 'CANCELLED';
    return GestureDetector(
      onTap: () => _showSaleDetail(sale),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.card(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isCancelled
                ? AppColors.dangerTheme(context).withOpacity(0.3)
                : AppColors.border(context),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: (isCancelled
                        ? AppColors.dangerTheme(context)
                        : AppColors.successTheme(context))
                    .withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isCancelled
                    ? Icons.cancel_outlined
                    : Icons.check_circle_outline,
                color: isCancelled
                    ? AppColors.dangerTheme(context)
                    : AppColors.successTheme(context),
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sale.id,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text(context),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${AppFormatters.formatDateTime(sale.createdAt)} • ${sale.paymentMethod}',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSec(context),
                    ),
                  ),
                ],
              ),
            ),
            Text(
              AppFormatters.formatCurrency(sale.totalAmount),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isCancelled
                    ? AppColors.textSec(context)
                    : AppColors.green(context),
                decoration: isCancelled ? TextDecoration.lineThrough : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 80,
            color: AppColors.textSec(context).withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'Aucune vente',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textSec(context),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Appuyez sur + pour enregistrer une vente',
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
