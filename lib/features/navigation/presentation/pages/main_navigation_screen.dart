import 'package:flutter/material.dart';

import '../../../../core/permissions/permissions.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../credit/presentation/pages/credit_list_screen.dart';
import '../../../dashboard/presentation/pages/dashboard_screen.dart';
import '../../../sales/presentation/pages/sales_list_screen.dart';
import '../../../settings/presentation/pages/more_screen.dart';
import '../../../stock/presentation/pages/stock_list_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  static final ValueNotifier<int> tabNotifier = ValueNotifier<int>(0);

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  // ═══════════════════════════════════════════════════════════
  // CONSTRUCTION DYNAMIQUE DES ONGLETS SELON LE RÔLE
  // ═══════════════════════════════════════════════════════════
  List<_NavTab> _buildTabs() {
    final tabs = <_NavTab>[];

    // Accueil — toujours visible
    tabs.add(_NavTab(
      icon: Icons.home_outlined,
      activeIcon: Icons.home,
      label: 'Accueil',
      screen: const DashboardScreen(),
      permission: Permission.viewDashboard,
    ));

    // Ventes
    if (Permissions.can(Permission.viewSales)) {
      tabs.add(_NavTab(
        icon: Icons.receipt_long_outlined,
        activeIcon: Icons.receipt_long,
        label: 'Ventes',
        screen: const SalesListScreen(),
        permission: Permission.viewSales,
      ));
    }

    // Stock
    if (Permissions.can(Permission.viewStock)) {
      tabs.add(_NavTab(
        icon: Icons.inventory_2_outlined,
        activeIcon: Icons.inventory_2,
        label: 'Stock',
        screen: const StockListScreen(),
        permission: Permission.viewStock,
      ));
    }

    // Crédits
    if (Permissions.can(Permission.viewCredits)) {
      tabs.add(_NavTab(
        icon: Icons.credit_card_outlined,
        activeIcon: Icons.credit_card,
        label: 'Crédits',
        screen: const CreditListScreen(),
        permission: Permission.viewCredits,
      ));
    }

    // Plus — toujours visible
    tabs.add(_NavTab(
      icon: Icons.menu,
      activeIcon: Icons.menu,
      label: 'Plus',
      screen: const MoreScreen(),
      permission: Permission.viewDashboard, // toujours autorisé
    ));

    return tabs;
  }

  @override
  void initState() {
    super.initState();
    MainNavigationScreen.tabNotifier.addListener(_onTabChanged);
  }

  @override
  void dispose() {
    MainNavigationScreen.tabNotifier.removeListener(_onTabChanged);
    super.dispose();
  }

  void _onTabChanged() {
    if (mounted && _currentIndex != MainNavigationScreen.tabNotifier.value) {
      setState(() => _currentIndex = MainNavigationScreen.tabNotifier.value);
    }
  }

  void _onWillPop(bool didPop, Object? result) {
    if (didPop) return;

    if (_currentIndex != 0) {
      setState(() => _currentIndex = 0);
      MainNavigationScreen.tabNotifier.value = 0;
    } else {
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final tabs = _buildTabs();

    // Sécurité : si l'index courant dépasse le nombre d'onglets, revenir à 0
    if (_currentIndex >= tabs.length) {
      _currentIndex = 0;
    }

    return PopScope(
      canPop: _currentIndex == 0,
      onPopInvokedWithResult: _onWillPop,
      child: Scaffold(
        backgroundColor: AppColors.bg(context),
        body: IndexedStack(
          index: _currentIndex,
          children: tabs.map((t) => t.screen).toList(),
        ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: AppColors.card(context),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) {
              setState(() => _currentIndex = index);
            },
            type: BottomNavigationBarType.fixed,
            backgroundColor: AppColors.card(context),
            selectedItemColor: AppColors.green(context),
            unselectedItemColor: AppColors.textSec(context),
            selectedFontSize: 12,
            unselectedFontSize: 11,
            selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
            elevation: 0,
            items: tabs
                .map((t) => BottomNavigationBarItem(
                      icon: Icon(t.icon),
                      activeIcon: Icon(t.activeIcon),
                      label: t.label,
                    ))
                .toList(),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// MODÈLE INTERNE
// ═══════════════════════════════════════════════════════════

class _NavTab {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final Widget screen;
  final Permission permission;

  _NavTab({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.screen,
    required this.permission,
  });
}
