import 'package:flutter/material.dart';

import '../../../../core/services/admin_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../data/models/admin_models.dart';

class AdminShopsScreen extends StatefulWidget {
  const AdminShopsScreen({super.key});

  @override
  State<AdminShopsScreen> createState() => _AdminShopsScreenState();
}

class _AdminShopsScreenState extends State<AdminShopsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  List<AdminShop> _allShops = [];
  List<AdminShop> _filteredShops = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) _applyFilter();
    });
    _loadShops();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadShops() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final shops = await AdminService.instance.getShops();

    if (!mounted) return;

    setState(() {
      _allShops = shops;
      _isLoading = false;
      if (shops.isEmpty) {
        _error = 'Aucune boutique trouvée';
      }
    });
    _applyFilter();
  }

  void _applyFilter() {
    final query = _searchController.text.toLowerCase();

    setState(() {
      _filteredShops = _allShops.where((shop) {
        // Filtre par onglet
        bool matchesTab = true;
        switch (_tabController.index) {
          case 1:
            matchesTab = shop.status == 'ACTIVE';
            break;
          case 2:
            matchesTab = shop.status == 'TRIAL';
            break;
          case 3:
            matchesTab = shop.status == 'GRACE_PERIOD';
            break;
          case 4:
            matchesTab = shop.status == 'EXPIRED';
            break;
        }

        // Filtre par recherche
        bool matchesSearch = query.isEmpty ||
            shop.name.toLowerCase().contains(query) ||
            shop.ownerName.toLowerCase().contains(query) ||
            shop.phone.toLowerCase().contains(query);

        return matchesTab && matchesSearch;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar: AppBar(
        title: const Text('Boutiques'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadShops,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: AppColors.green(context),
          unselectedLabelColor: AppColors.textSec(context),
          indicatorColor: AppColors.green(context),
          indicatorWeight: 3,
          tabs: const [
            Tab(text: 'Toutes'),
            Tab(text: 'Actives'),
            Tab(text: 'Essai'),
            Tab(text: 'Grâce'),
            Tab(text: 'Expirées'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Barre de recherche
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => _applyFilter(),
              style: TextStyle(color: AppColors.text(context)),
              decoration: InputDecoration(
                hintText: 'Rechercher par nom, propriétaire, téléphone...',
                hintStyle: TextStyle(color: AppColors.textSec(context)),
                prefixIcon: Icon(
                  Icons.search,
                  color: AppColors.textSec(context),
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _applyFilter();
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppColors.card(context),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // Liste
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      color: AppColors.green(context),
                    ),
                  )
                : _filteredShops.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _loadShops,
                        color: AppColors.green(context),
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _filteredShops.length,
                          itemBuilder: (context, index) {
                            return _buildShopTile(_filteredShops[index]);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.storefront_outlined,
            size: 80,
            color: AppColors.textSec(context).withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'Aucune boutique trouvée',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textSec(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShopTile(AdminShop shop) {
    final statusColor = _getStatusColor(shop.status);

    return GestureDetector(
      onTap: () => _showShopDetails(shop),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border(context)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Ligne 1 : Nom + Statut
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.greenLight(context),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      shop.name.substring(0, 1).toUpperCase(),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.green(context),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        shop.name,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.text(context),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            Icons.person_outline,
                            size: 12,
                            color: AppColors.textSec(context),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              shop.ownerName,
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSec(context),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    shop.statusName,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            Divider(height: 1, color: AppColors.border(context)),
            const SizedBox(height: 12),

            // Ligne 2 : Plan, Jours, Total payé
            Row(
              children: [
                Expanded(
                  child: _buildInfoItem(
                    icon: Icons.workspace_premium,
                    label: 'Plan',
                    value: shop.planName,
                    color: _getPlanColor(shop.plan),
                  ),
                ),
                Expanded(
                  child: _buildInfoItem(
                    icon: Icons.schedule,
                    label: 'Jours',
                    value: '${shop.daysRemaining}',
                    color: shop.daysRemaining <= 7
                        ? AppColors.dangerTheme(context)
                        : AppColors.text(context),
                  ),
                ),
                Expanded(
                  child: _buildInfoItem(
                    icon: Icons.monetization_on,
                    label: 'Total payé',
                    value: AppFormatters.formatCurrency(shop.totalPaid),
                    color: AppColors.green(context),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 11, color: AppColors.textSec(context)),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: AppColors.textSec(context),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: color,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'ACTIVE':
        return AppColors.successTheme(context);
      case 'TRIAL':
        return Colors.blue;
      case 'GRACE_PERIOD':
        return AppColors.warningTheme(context);
      case 'EXPIRED':
        return AppColors.dangerTheme(context);
      default:
        return AppColors.textSec(context);
    }
  }

  Color _getPlanColor(String plan) {
    switch (plan) {
      case 'ESSENTIEL':
        return Colors.blue;
      case 'PRO':
        return AppColors.green(context);
      case 'BUSINESS':
        return Colors.purple;
      default:
        return AppColors.textSec(context);
    }
  }

  // ═══════════════════════════════════════════════════════════
  // MODAL DÉTAIL BOUTIQUE
  // ═══════════════════════════════════════════════════════════
  void _showShopDetails(AdminShop shop) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: AppColors.bg(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(24),
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

            // Titre
            Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: AppColors.greenLight(context),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(
                      shop.name.substring(0, 1).toUpperCase(),
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.green(context),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        shop.name,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.text(context),
                        ),
                      ),
                      Text(
                        shop.id,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSec(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Informations
            _buildDetailRow('Propriétaire', shop.ownerName),
            _buildDetailRow('Téléphone', shop.phone),
            _buildDetailRow('Plan', shop.planName),
            _buildDetailRow('Statut', shop.statusName),
            _buildDetailRow('Jours restants', '${shop.daysRemaining} jours'),
            _buildDetailRow(
              'Total payé',
              AppFormatters.formatCurrency(shop.totalPaid),
            ),
            _buildDetailRow('Paiements', '${shop.paymentCount}'),
            if (shop.startDate != null)
              _buildDetailRow(
                'Début abonnement',
                AppFormatters.formatDate(shop.startDate!),
              ),
            if (shop.endDate != null)
              _buildDetailRow(
                'Fin abonnement',
                AppFormatters.formatDate(shop.endDate!),
              ),
            if (shop.lastPaymentDate != null)
              _buildDetailRow(
                'Dernier paiement',
                AppFormatters.formatDate(shop.lastPaymentDate!),
              ),
            _buildDetailRow(
              'Créée le',
              AppFormatters.formatDate(shop.createdAt),
            ),

            const SizedBox(height: 24),

            // Actions
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    label: const Text('Fermer'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 50),
                      side: BorderSide(color: AppColors.textSec(context)),
                      foregroundColor: AppColors.text(context),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Prolonger — Bientôt disponible'),
                        ),
                      );
                    },
                    icon: const Icon(Icons.add_circle_outline),
                    label: const Text('Prolonger'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.green(context),
                      foregroundColor: AppColors.onGreen(context),
                      minimumSize: const Size(0, 50),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSec(context),
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.text(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
