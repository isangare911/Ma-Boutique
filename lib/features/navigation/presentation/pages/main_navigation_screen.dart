import 'package:flutter/material.dart';

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

  final List<Widget> _screens = const [
    DashboardScreen(),
    SalesListScreen(),
    StockListScreen(),
    CreditListScreen(),
    MoreScreen(),
  ];

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

  // ═══════════════════════════════════════════════════════════
  // GESTION DU BOUTON RETOUR
  // ═══════════════════════════════════════════════════════════
  /// Intercepte le bouton retour :
  /// - Si on n'est pas sur l'onglet Accueil → aller à Accueil
  /// - Si on est déjà sur Accueil → quitter l'app
  void _onWillPop(bool didPop, Object? result) {
    if (didPop) return;

    if (_currentIndex != 0) {
      // Revenir à l'onglet Accueil
      setState(() => _currentIndex = 0);
      MainNavigationScreen.tabNotifier.value = 0;
    } else {
      // Quitter l'app
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _currentIndex == 0, // ⚡ Autoriser le pop seulement sur Accueil
      onPopInvokedWithResult: _onWillPop,
      child: Scaffold(
        backgroundColor: AppColors.bg(context),
        body: IndexedStack(
          index: _currentIndex,
          children: _screens,
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
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home_outlined),
                activeIcon: Icon(Icons.home),
                label: 'Accueil',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.receipt_long_outlined),
                activeIcon: Icon(Icons.receipt_long),
                label: 'Ventes',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.inventory_2_outlined),
                activeIcon: Icon(Icons.inventory_2),
                label: 'Stock',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.credit_card_outlined),
                activeIcon: Icon(Icons.credit_card),
                label: 'Crédits',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.menu),
                activeIcon: Icon(Icons.menu),
                label: 'Plus',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
