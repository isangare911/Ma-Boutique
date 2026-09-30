import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../core/permissions/permission_guard.dart';
import '../../../../core/permissions/permissions.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/services/data_refresh_notifier.dart';
import '../../../../core/services/shop_settings_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/subscription_banner.dart';
import '../../../../core/widgets/subscription_guard.dart';
import '../../../../data/repositories/product_repository.dart';
import '../../../../data/repositories/sale_repository.dart';
import '../../../navigation/presentation/pages/main_navigation_screen.dart';
import '../../../reports/presentation/pages/reports_screen.dart';
import '../../../sales/presentation/pages/new_sale_screen.dart';
import '../../../settings/presentation/pages/shop_settings_screen.dart';
import 'widgets/alert_item.dart';
import 'widgets/quick_action_button.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final ProductRepository _productRepo = ProductRepository();
  final SaleRepository _saleRepo = SaleRepository();

  double _todayRevenue = 0;
  double _todayProfit = 0;
  int _todaySalesCount = 0;
  int _outOfStockCount = 0;
  int _totalProducts = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    DataRefreshNotifier.instance.addListener(_onDataChanged);
    ShopSettingsService.instance.addListener(_onSettingsChanged);
    _loadStats();
  }

  @override
  void dispose() {
    DataRefreshNotifier.instance.removeListener(_onDataChanged);
    ShopSettingsService.instance.removeListener(_onSettingsChanged);
    super.dispose();
  }

  void _onDataChanged() {
    if (mounted) _loadStats();
  }

  void _onSettingsChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadStats() async {
    try {
      final revenue = await _saleRepo.getTodayRevenue();
      final profit = await _saleRepo.getTodayProfit();
      final salesCount = await _saleRepo.getTodaySalesCount();
      final outOfStock = await _productRepo.getOutOfStockCount();
      final totalProducts = await _productRepo.getTotalProducts();

      if (!mounted) return;

      setState(() {
        _todayRevenue = revenue;
        _todayProfit = profit;
        _todaySalesCount = salesCount;
        _outOfStockCount = outOfStock;
        _totalProducts = totalProducts;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _goToTab(int index) {
    MainNavigationScreen.tabNotifier.value = index;
  }

  Widget _buildAvatar(BuildContext context) {
    final logoPath = ShopSettingsService.instance.shopLogoPath;
    final hasLogo = logoPath != null && logoPath.isNotEmpty;

    return GestureDetector(
      onTap: Permissions.can(Permission.viewSettings)
          ? () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ShopSettingsScreen()),
              );
            }
          : null,
      child: Container(
        width: 45,
        height: 45,
        decoration: BoxDecoration(
          color: AppColors.greenLight(context),
          shape: BoxShape.circle,
          border: Border.all(
            color: AppColors.green(context).withOpacity(0.3),
            width: 2,
          ),
        ),
        child: ClipOval(
          child: hasLogo
              ? Image.file(
                  File(logoPath),
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Icon(
                    Icons.person,
                    color: AppColors.green(context),
                  ),
                )
              : Icon(
                  Icons.person,
                  color: AppColors.green(context),
                ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ⚡ Lire le nom de la boutique depuis le user connecté
    final user = AuthService.instance.user;
    final shopName = user?['shop']?['name'] as String? ?? 'Ma Boutique';

    // ⚡ Fallback : si pas de user, prendre depuis ShopSettingsService
    final displayName =
        shopName.isNotEmpty ? shopName : ShopSettingsService.instance.shopName;

    return Container(
      color: AppColors.bg(context),
      child: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadStats,
          color: AppColors.green(context),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ⚡ Bannière d'abonnement
                const SubscriptionBanner(),

                // EN-TÊTE
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Bonjour, $displayName 👋',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppColors.text(context),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Voici le résumé de votre boutique',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.textSec(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    _buildAvatar(context),
                  ],
                ),
                const SizedBox(height: 24),

                // CARTE PRINCIPALE (CA)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.green(context),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.green(context).withOpacity(0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Chiffre d'affaires (aujourd'hui)",
                        style: TextStyle(
                          color: AppColors.onGreenSec(context),
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        AppFormatters.formatCurrency(_todayRevenue),
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
                            'Ventes',
                            '$_todaySalesCount',
                          ),
                          const SizedBox(width: 24),
                          PermissionGuardAny(
                            permissions: [
                              Permission.editSales,
                              Permission.viewReports,
                            ],
                            child: _buildMiniStat(
                              context,
                              'Bénéfice',
                              AppFormatters.formatCurrency(_todayProfit),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ACTIONS RAPIDES
                Text(
                  'Actions rapides',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.text(context),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    PermissionGuard(
                      permission: Permission.editSales,
                      child: QuickActionButton(
                        label: 'Nouvelle\nvente',
                        icon: Icons.add_shopping_cart,
                        onTap: () async {
                          final canProceed =
                              await SubscriptionGuard.canPerformAction(
                            context,
                            actionName: 'Nouvelle vente',
                          );
                          if (!canProceed) return;

                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const NewSaleScreen(),
                            ),
                          );
                          DataRefreshNotifier.instance.notifySalesChanged();
                          await _loadStats();
                        },
                      ),
                    ),
                    PermissionGuard(
                      permission: Permission.viewStock,
                      child: QuickActionButton(
                        label: 'Stock',
                        icon: Icons.inventory_2_outlined,
                        onTap: () => _goToTab(2),
                      ),
                    ),
                    PermissionGuard(
                      permission: Permission.viewCredits,
                      child: QuickActionButton(
                        label: 'Crédit',
                        icon: Icons.credit_card,
                        onTap: () => _goToTab(3),
                      ),
                    ),
                    PermissionGuard(
                      permission: Permission.viewReports,
                      child: QuickActionButton(
                        label: 'Rapports',
                        icon: Icons.bar_chart,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ReportsScreen(),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // ALERTES
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Alertes',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.text(context),
                      ),
                    ),
                    PermissionGuard(
                      permission: Permission.viewStock,
                      child: TextButton(
                        onPressed: () => _goToTab(2),
                        child: Text(
                          'Voir tout',
                          style: TextStyle(color: AppColors.green(context)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                if (_isLoading)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: CircularProgressIndicator(
                        color: AppColors.green(context),
                      ),
                    ),
                  )
                else ...[
                  PermissionGuard(
                    permission: Permission.viewStock,
                    child: _outOfStockCount > 0
                        ? AlertItem(
                            title:
                                '$_outOfStockCount produit${_outOfStockCount > 1 ? "s" : ""} en rupture de stock',
                            subtitle: 'Appuyez pour voir les détails',
                            icon: Icons.warning_amber_rounded,
                            color: AppColors.dangerTheme(context),
                          )
                        : const SizedBox.shrink(),
                  ),
                  PermissionGuard(
                    permission: Permission.viewStock,
                    child: AlertItem(
                      title: '$_totalProducts produits au total',
                      subtitle: 'Gérez votre inventaire',
                      icon: Icons.inventory_2_outlined,
                      color: AppColors.green(context),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
              ],
            ),
          ),
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
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: AppColors.onGreen(context),
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
