import 'package:flutter/material.dart';

import '../../../../core/services/data_refresh_notifier.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/subscription_guard.dart';
import '../../../../data/models/cart_item.dart';
import '../../../../data/models/product.dart';
import '../../../../data/repositories/product_repository.dart';
import '../widgets/product_card.dart';
import 'cart_screen.dart';

class NewSaleScreen extends StatefulWidget {
  const NewSaleScreen({super.key});

  @override
  State<NewSaleScreen> createState() => _NewSaleScreenState();
}

class _NewSaleScreenState extends State<NewSaleScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ProductRepository _repository = ProductRepository();
  final List<CartItem> _cart = [];

  List<Product> _allProducts = [];
  List<Product> _filteredProducts = [];
  bool _isLoading = true;
  bool _isAuthorized = false;

  @override
  void initState() {
    super.initState();
    _checkSubscription();
  }

  /// ⚡ Vérifie l'abonnement avant d'autoriser la vente
  Future<void> _checkSubscription() async {
    await Future.delayed(const Duration(milliseconds: 100));
    if (!mounted) return;

    final canProceed = await SubscriptionGuard.canPerformAction(
      context,
      actionName: 'Nouvelle vente',
    );

    if (!canProceed) {
      if (mounted) Navigator.pop(context);
      return;
    }

    setState(() => _isAuthorized = true);
    await _loadProducts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final products = await _repository.getAllProducts();
      if (!mounted) return;
      setState(() {
        _allProducts = products;
        _filteredProducts = products;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: $e'),
          backgroundColor: AppColors.dangerTheme(context),
        ),
      );
    }
  }

  void _filterProducts(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredProducts = _allProducts;
      } else {
        _filteredProducts = _allProducts
            .where((p) =>
                p.name.toLowerCase().contains(query.toLowerCase()) ||
                (p.category?.toLowerCase().contains(query.toLowerCase()) ??
                    false))
            .toList();
      }
    });
  }

  void _addToCart(Product product) {
    setState(() {
      final existingIndex =
          _cart.indexWhere((item) => item.product.id == product.id);
      if (existingIndex >= 0) {
        _cart[existingIndex].quantity++;
      } else {
        _cart.add(CartItem(product: product));
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${product.name} ajouté au panier'),
        duration: const Duration(seconds: 1),
        backgroundColor: AppColors.green(context),
      ),
    );
  }

  double get _cartTotal => _cart.fold(0, (sum, item) => sum + item.subtotal);

  @override
  Widget build(BuildContext context) {
    // ⚡ Tant que la vérification n'est pas faite, on affiche un loader
    if (!_isAuthorized) {
      return Scaffold(
        backgroundColor: AppColors.bg(context),
        appBar: AppBar(title: const Text('Nouvelle vente')),
        body: Center(
          child: CircularProgressIndicator(color: AppColors.green(context)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar: AppBar(
        title: const Text('Nouvelle vente'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              onChanged: _filterProducts,
              style: TextStyle(color: AppColors.text(context)),
              decoration: InputDecoration(
                hintText: 'Rechercher un produit...',
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
                : _filteredProducts.isEmpty
                    ? Center(
                        child: Text(
                          'Aucun produit trouvé',
                          style: TextStyle(color: AppColors.textSec(context)),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _filteredProducts.length,
                        itemBuilder: (context, index) {
                          return ProductCard(
                            product: _filteredProducts[index],
                            onAdd: () => _addToCart(_filteredProducts[index]),
                          );
                        },
                      ),
          ),
        ],
      ),
      bottomNavigationBar: _cart.isEmpty
          ? null
          : Container(
              padding: const EdgeInsets.all(16),
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
              child: SafeArea(
                child: ElevatedButton(
                  onPressed: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CartScreen(cart: _cart),
                      ),
                    );
                    if (result == true) {
                      DataRefreshNotifier.instance.notifySalesChanged();
                      setState(() => _cart.clear());
                      await _loadProducts();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.green(context),
                    foregroundColor: AppColors.onGreen(context),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color:
                                  AppColors.onGreen(context).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${_cart.fold(0, (sum, item) => sum + item.quantity)}',
                              style: TextStyle(
                                color: AppColors.onGreen(context),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Voir le panier',
                            style: TextStyle(
                              color: AppColors.onGreen(context),
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '${_cartTotal.toStringAsFixed(0)} FCFA',
                        style: TextStyle(
                          color: AppColors.onGreen(context),
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
