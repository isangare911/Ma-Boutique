import 'package:flutter/material.dart';

import '../../../../core/services/data_refresh_notifier.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../data/models/supplier.dart';
import '../../../../data/repositories/supplier_repository.dart';
import 'add_supplier_screen.dart';
import 'supplier_detail_screen.dart';

class SuppliersListScreen extends StatefulWidget {
  const SuppliersListScreen({super.key});

  @override
  State<SuppliersListScreen> createState() => _SuppliersListScreenState();
}

class _SuppliersListScreenState extends State<SuppliersListScreen> {
  final SupplierRepository _repository = SupplierRepository();
  final TextEditingController _searchController = TextEditingController();

  List<Supplier> _allSuppliers = [];
  List<Supplier> _filteredSuppliers = [];
  Map<String, double> _balances = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    DataRefreshNotifier.instance.addListener(_onDataChanged);
    _loadData();
  }

  @override
  void dispose() {
    DataRefreshNotifier.instance.removeListener(_onDataChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onDataChanged() {
    if (mounted) _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final suppliers = await _repository.getAllSuppliers();
      final balances = await _repository.getAllSuppliersBalances();

      if (!mounted) return;
      setState(() {
        _allSuppliers = suppliers;
        _filteredSuppliers = suppliers;
        _balances = balances;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  void _applyFilter(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredSuppliers = _allSuppliers;
      } else {
        _filteredSuppliers = _allSuppliers.where((s) {
          return s.name.toLowerCase().contains(query.toLowerCase()) ||
              (s.phone?.toLowerCase().contains(query.toLowerCase()) ?? false);
        }).toList();
      }
    });
  }

  double get _totalDebt {
    return _balances.values
        .where((b) => b > 0)
        .fold<double>(0, (sum, b) => sum + b);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar: AppBar(
        title: const Text('Fournisseurs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: Column(
        children: [
          if (_totalDebt > 0)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.warningTheme(context).withOpacity(0.15),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.warningTheme(context).withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.warningTheme(context).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.account_balance_wallet_outlined,
                      color: AppColors.warningTheme(context),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Total dû aux fournisseurs',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text(context),
                      ),
                    ),
                  ),
                  Text(
                    AppFormatters.formatCurrency(_totalDebt),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.warningTheme(context),
                    ),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              onChanged: _applyFilter,
              style: TextStyle(color: AppColors.text(context)),
              decoration: InputDecoration(
                hintText: 'Rechercher un fournisseur...',
                hintStyle: TextStyle(color: AppColors.textSec(context)),
                prefixIcon: Icon(
                  Icons.search,
                  color: AppColors.textSec(context),
                ),
                filled: true,
                fillColor: AppColors.card(context),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      color: AppColors.green(context),
                    ),
                  )
                : _filteredSuppliers.isEmpty
                    ? _buildEmptyState(context)
                    : RefreshIndicator(
                        onRefresh: _loadData,
                        color: AppColors.green(context),
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _filteredSuppliers.length,
                          itemBuilder: (context, index) {
                            final supplier = _filteredSuppliers[index];
                            final balance = _balances[supplier.id] ?? 0.0;
                            return _buildSupplierTile(
                                context, supplier, balance);
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'suppliers_fab',
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddSupplierScreen()),
          );
          DataRefreshNotifier.instance.notifyProductsChanged();
          await _loadData();
        },
        backgroundColor: AppColors.green(context),
        foregroundColor: AppColors.onGreen(context),
        icon: Icon(Icons.add, color: AppColors.onGreen(context)),
        label: Text(
          'Nouveau fournisseur',
          style: TextStyle(color: AppColors.onGreen(context)),
        ),
      ),
    );
  }

  Widget _buildSupplierTile(
      BuildContext context, Supplier supplier, double balance) {
    final hasDebt = balance > 0;
    final hasCredit = balance < 0;

    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SupplierDetailScreen(supplier: supplier),
          ),
        );
        DataRefreshNotifier.instance.notifyProductsChanged();
        await _loadData();
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
            CircleAvatar(
              radius: 24,
              backgroundColor: AppColors.greenLight(context),
              child: Text(
                supplier.name.substring(0, 1).toUpperCase(),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.green(context),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    supplier.name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text(context),
                    ),
                  ),
                  if (supplier.phone != null)
                    Text(
                      supplier.phone!,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSec(context),
                      ),
                    ),
                  if (supplier.productsSupplied != null &&
                      supplier.productsSupplied!.isNotEmpty)
                    Text(
                      supplier.productsSupplied!,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSec(context),
                        fontStyle: FontStyle.italic,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (hasDebt) ...[
                  Text(
                    AppFormatters.formatCurrency(balance),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.dangerTheme(context),
                    ),
                  ),
                  Text(
                    'À payer',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.textSec(context),
                    ),
                  ),
                ] else if (hasCredit) ...[
                  Text(
                    AppFormatters.formatCurrency(balance.abs()),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.successTheme(context),
                    ),
                  ),
                  Text(
                    'Avance',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.textSec(context),
                    ),
                  ),
                ] else
                  Text(
                    'Soldé',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.successTheme(context),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right,
              color: AppColors.textSec(context),
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
            Icons.local_shipping_outlined,
            size: 80,
            color: AppColors.textSec(context).withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'Aucun fournisseur',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textSec(context),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Appuyez sur + pour ajouter un fournisseur',
            style: TextStyle(fontSize: 13, color: AppColors.textSec(context)),
          ),
        ],
      ),
    );
  }
}
