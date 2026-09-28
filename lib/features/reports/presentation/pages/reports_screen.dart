import 'package:flutter/material.dart';

import '../../../../core/services/data_refresh_notifier.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../data/repositories/credit_repository.dart';
import '../../../../data/repositories/product_repository.dart';
import '../../../../data/repositories/sale_repository.dart';
import '../widgets/report_summary_card.dart';
import '../widgets/simple_bar_chart.dart';
import '../widgets/top_product_tile.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final SaleRepository _saleRepo = SaleRepository();
  final ProductRepository _productRepo = ProductRepository();
  final CreditRepository _creditRepo = CreditRepository();

  bool _isLoading = true;

  double _todayRevenue = 0;
  double _weekRevenue = 0;
  double _monthRevenue = 0;
  double _yearRevenue = 0;
  double _todayProfit = 0;
  int _todaySalesCount = 0;

  List<Map<String, dynamic>> _revenueByDay = [];
  List<Map<String, dynamic>> _topProducts = [];
  List<Map<String, dynamic>> _salesByCategory = [];
  List<Map<String, dynamic>> _salesByPayment = [];

  double _totalCredit = 0;
  double _totalRemaining = 0;
  double _totalPaymentsReceived = 0;
  int _overdueCount = 0;

  int _totalProducts = 0;
  int _outOfStockCount = 0;
  double _stockValue = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
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
      final todayRev = await _saleRepo.getRevenueForPeriod('day');
      final weekRev = await _saleRepo.getRevenueForPeriod('week');
      final monthRev = await _saleRepo.getRevenueForPeriod('month');
      final yearRev = await _saleRepo.getRevenueForPeriod('year');
      final profit = await _saleRepo.getTodayProfit();
      final count = await _saleRepo.getTodaySalesCount();

      final byDay = await _saleRepo.getRevenueByDay(7);
      final top = await _saleRepo.getTopProducts(5);
      final byCategory = await _saleRepo.getSalesByCategory();
      final byPayment = await _saleRepo.getSalesByPaymentMethod();

      final totalCredit = await _creditRepo.getTotalCreditAmount();
      final remaining = await _creditRepo.getTotalRemainingAmount();
      final paymentsReceived = await _creditRepo.getTotalPaymentsReceived();
      final overdue = await _creditRepo.getOverdueCount();

      final totalProducts = await _productRepo.getTotalProducts();
      final outOfStock = await _productRepo.getOutOfStockCount();
      final stockValue = await _productRepo.getTotalStockValue();

      if (!mounted) return;

      setState(() {
        _todayRevenue = todayRev;
        _weekRevenue = weekRev;
        _monthRevenue = monthRev;
        _yearRevenue = yearRev;
        _todayProfit = profit;
        _todaySalesCount = count;
        _revenueByDay = byDay;
        _topProducts = top;
        _salesByCategory = byCategory;
        _salesByPayment = byPayment;
        _totalCredit = totalCredit;
        _totalRemaining = remaining;
        _totalPaymentsReceived = paymentsReceived;
        _overdueCount = overdue;
        _totalProducts = totalProducts;
        _outOfStockCount = outOfStock;
        _stockValue = stockValue;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar: AppBar(
        title: const Text('Rapports'),
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
          isScrollable: true,
          tabs: const [
            Tab(text: 'Ventes'),
            Tab(text: 'Produits'),
            Tab(text: 'Crédits'),
            Tab(text: 'Paiements'),
          ],
        ),
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: AppColors.green(context),
              ),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _buildSalesTab(context),
                _buildProductsTab(context),
                _buildCreditsTab(context),
                _buildPaymentsTab(context),
              ],
            ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // ONGLET VENTES
  // ═══════════════════════════════════════════════════════════
  Widget _buildSalesTab(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppColors.green(context),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.green(context),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Chiffre d'affaires total",
                    style: TextStyle(
                      color: AppColors.onGreenSec(context),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AppFormatters.formatCurrency(_yearRevenue),
                    style: TextStyle(
                      color: AppColors.onGreen(context),
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _buildMiniStat(
                        context,
                        'Aujourd\'hui',
                        AppFormatters.formatCurrency(_todayRevenue),
                      ),
                      const SizedBox(width: 20),
                      _buildMiniStat(
                        context,
                        '7 jours',
                        AppFormatters.formatCurrency(_weekRevenue),
                      ),
                      const SizedBox(width: 20),
                      _buildMiniStat(
                        context,
                        'Ce mois',
                        AppFormatters.formatCurrency(_monthRevenue),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ReportSummaryCard(
                    title: 'Ventes aujourd\'hui',
                    value: '$_todaySalesCount',
                    icon: Icons.receipt_long,
                    color: AppColors.green(context),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ReportSummaryCard(
                    title: 'Bénéfice du jour',
                    value: AppFormatters.formatCurrency(_todayProfit),
                    icon: Icons.trending_up,
                    color: AppColors.successTheme(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              'Évolution du CA (7 derniers jours)',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.text(context),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.card(context),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border(context)),
              ),
              child: SimpleBarChart(data: _revenueByDay),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // ONGLET PRODUITS
  // ═══════════════════════════════════════════════════════════
  Widget _buildProductsTab(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppColors.green(context),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: ReportSummaryCard(
                    title: 'Produits',
                    value: '$_totalProducts',
                    icon: Icons.inventory_2_outlined,
                    color: AppColors.green(context),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ReportSummaryCard(
                    title: 'Ruptures',
                    value: '$_outOfStockCount',
                    icon: Icons.warning_amber_rounded,
                    color: AppColors.dangerTheme(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ReportSummaryCard(
              title: 'Valeur totale du stock',
              value: AppFormatters.formatCurrency(_stockValue),
              icon: Icons.account_balance_wallet_outlined,
              color: AppColors.successTheme(context),
            ),
            const SizedBox(height: 24),
            Text(
              'Top 5 des produits vendus',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.text(context),
              ),
            ),
            const SizedBox(height: 12),
            if (_topProducts.isEmpty)
              _buildEmptyMessage(context, 'Aucune vente enregistrée')
            else
              ..._topProducts.asMap().entries.map((entry) {
                final idx = entry.key + 1;
                final product = entry.value;
                return TopProductTile(
                  rank: idx,
                  name: product['name'] as String,
                  quantity: product['quantity'] as int,
                  revenue: product['revenue'] as double,
                );
              }),
            const SizedBox(height: 24),
            if (_salesByCategory.isNotEmpty) ...[
              Text(
                'Ventes par catégorie',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.text(context),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.card(context),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border(context)),
                ),
                child: Column(
                  children: _salesByCategory.map((cat) {
                    final total = _salesByCategory.fold<double>(
                      0,
                      (sum, c) => sum + (c['revenue'] as double),
                    );
                    final ratio =
                        total > 0 ? (cat['revenue'] as double) / total : 0.0;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                cat['category'] as String,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.text(context),
                                ),
                              ),
                              Text(
                                AppFormatters.formatCurrency(
                                    cat['revenue'] as double),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.green(context),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: ratio,
                              minHeight: 6,
                              backgroundColor: AppColors.border(context),
                              valueColor: AlwaysStoppedAnimation(
                                AppColors.green(context),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // ONGLET CRÉDITS
  // ═══════════════════════════════════════════════════════════
  Widget _buildCreditsTab(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppColors.green(context),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.dangerTheme(context),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total à recouvrer',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AppFormatters.formatCurrency(_totalRemaining),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (_overdueCount > 0) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded,
                              color: Colors.white, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            '$_overdueCount crédit${_overdueCount > 1 ? "s" : ""} en retard',
                            style: const TextStyle(
                              color: Colors.white,
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
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ReportSummaryCard(
                    title: 'Crédits accordés',
                    value: AppFormatters.formatCurrency(_totalCredit),
                    icon: Icons.credit_card,
                    color: AppColors.warningTheme(context),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ReportSummaryCard(
                    title: 'Recouvrés',
                    value: AppFormatters.formatCurrency(_totalPaymentsReceived),
                    icon: Icons.check_circle_outline,
                    color: AppColors.successTheme(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (_totalCredit > 0) ...[
              Text(
                'Taux de recouvrement',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.text(context),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.card(context),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border(context)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${((_totalPaymentsReceived / _totalCredit) * 100).toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppColors.successTheme(context),
                          ),
                        ),
                        Text(
                          '${AppFormatters.formatCurrency(_totalPaymentsReceived)} / ${AppFormatters.formatCurrency(_totalCredit)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSec(context),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: _totalCredit > 0
                            ? _totalPaymentsReceived / _totalCredit
                            : 0,
                        minHeight: 8,
                        backgroundColor: AppColors.border(context),
                        valueColor: AlwaysStoppedAnimation(
                          AppColors.successTheme(context),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // ONGLET PAIEMENTS
  // ═══════════════════════════════════════════════════════════
  Widget _buildPaymentsTab(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppColors.green(context),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ventes par moyen de paiement',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.text(context),
              ),
            ),
            const SizedBox(height: 12),
            if (_salesByPayment.isEmpty)
              _buildEmptyMessage(context, 'Aucune vente enregistrée')
            else
              ..._salesByPayment.map((payment) {
                final totalAmount = _salesByPayment.fold<double>(
                  0,
                  (sum, p) => sum + (p['total'] as double),
                );
                final ratio = totalAmount > 0
                    ? (payment['total'] as double) / totalAmount
                    : 0.0;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.card(context),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border(context)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                _getPaymentIcon(payment['method'] as String),
                                color: AppColors.green(context),
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                payment['method'] as String,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.text(context),
                                ),
                              ),
                            ],
                          ),
                          Text(
                            AppFormatters.formatCurrency(
                                payment['total'] as double),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.green(context),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            '${payment['count']} vente${(payment['count'] as int) > 1 ? "s" : ""}',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSec(context),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${(ratio * 100).toStringAsFixed(1)}%',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.green(context),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: ratio,
                          minHeight: 6,
                          backgroundColor: AppColors.border(context),
                          valueColor: AlwaysStoppedAnimation(
                            AppColors.green(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniStat(BuildContext context, String label, String value) {
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
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyMessage(BuildContext context, String message) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.bar_chart_outlined,
              size: 48,
              color: AppColors.textSec(context).withOpacity(0.5),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: TextStyle(color: AppColors.textSec(context)),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getPaymentIcon(String method) {
    switch (method.toLowerCase()) {
      case 'espèces':
        return Icons.money;
      case 'orange money':
        return Icons.phone_android;
      case 'moov money':
        return Icons.phone_android;
      case 'carte bancaire':
        return Icons.credit_card;
      default:
        return Icons.payment;
    }
  }
}
