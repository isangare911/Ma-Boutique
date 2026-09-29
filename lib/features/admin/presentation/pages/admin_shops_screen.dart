import 'package:flutter/material.dart';

import '../../../../core/services/admin_service.dart';
import '../../../../core/services/whatsapp_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../data/models/admin_models.dart';
import '../../../../data/models/payment.dart';

class AdminShopsScreen extends StatefulWidget {
  final int initialTab;
  final String? initialSort;

  const AdminShopsScreen({
    super.key,
    this.initialTab = 0,
    this.initialSort,
  });

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

  String _sortBy = 'name';
  String? _planFilter;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 7,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 6),
    );
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) _applyFilter();
    });

    if (widget.initialSort != null) {
      _sortBy = widget.initialSort!;
    }

    _loadShops();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadShops() async {
    setState(() => _isLoading = true);

    final shops = await AdminService.instance.getShops();

    if (!mounted) return;

    setState(() {
      _allShops = shops;
      _isLoading = false;
    });
    _applyFilter();
  }

  void _applyFilter() {
    final query = _searchController.text.toLowerCase();

    var result = _allShops.where((shop) {
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
        case 5:
          matchesTab = shop.status == 'PENDING_VALIDATION';
          break;
        case 6:
          matchesTab = shop.status == 'CANCELLED';
          break;
      }

      bool matchesSearch = query.isEmpty ||
          shop.name.toLowerCase().contains(query) ||
          shop.ownerName.toLowerCase().contains(query) ||
          shop.phone.toLowerCase().contains(query);

      bool matchesPlan = _planFilter == null || shop.plan == _planFilter;

      return matchesTab && matchesSearch && matchesPlan;
    }).toList();

    switch (_sortBy) {
      case 'name':
        result.sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        break;
      case 'revenue':
        result.sort((a, b) => b.totalPaid.compareTo(a.totalPaid));
        break;
      case 'date':
        result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case 'days_asc':
        result.sort((a, b) => a.daysRemaining.compareTo(b.daysRemaining));
        break;
      case 'days_desc':
        result.sort((a, b) => b.daysRemaining.compareTo(a.daysRemaining));
        break;
    }

    setState(() {
      _filteredShops = result;
    });
  }

  void _showSortSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bg(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Trier par',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.text(context),
              ),
            ),
            const SizedBox(height: 12),
            _buildSortOption('name', 'Nom (A-Z)', Icons.sort_by_alpha),
            _buildSortOption(
                'revenue', 'Revenus (élevé → faible)', Icons.trending_down),
            _buildSortOption(
                'date', 'Date d\'inscription (récent)', Icons.calendar_today),
            _buildSortOption(
                'days_asc', 'Jours restants (urgent)', Icons.schedule),
            _buildSortOption(
                'days_desc', 'Jours restants (long)', Icons.schedule),
          ],
        ),
      ),
    );
  }

  Widget _buildSortOption(String value, String label, IconData icon) {
    final isSelected = _sortBy == value;
    return ListTile(
      leading: Icon(
        icon,
        color:
            isSelected ? AppColors.green(context) : AppColors.textSec(context),
      ),
      title: Text(
        label,
        style: TextStyle(
          color: AppColors.text(context),
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      trailing: isSelected
          ? Icon(Icons.check, color: AppColors.green(context))
          : null,
      onTap: () {
        Navigator.pop(context);
        setState(() => _sortBy = value);
        _applyFilter();
      },
    );
  }

  void _showPlanFilterSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bg(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Filtrer par plan',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.text(context),
              ),
            ),
            const SizedBox(height: 12),
            _buildPlanOption(null, 'Tous les plans'),
            _buildPlanOption('ESSENTIEL', 'Essentiel'),
            _buildPlanOption('PRO', 'Pro'),
            _buildPlanOption('BUSINESS', 'Business'),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanOption(String? value, String label) {
    final isSelected = _planFilter == value;
    return ListTile(
      title: Text(
        label,
        style: TextStyle(
          color: AppColors.text(context),
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      trailing: isSelected
          ? Icon(Icons.check, color: AppColors.green(context))
          : null,
      onTap: () {
        Navigator.pop(context);
        setState(() => _planFilter = value);
        _applyFilter();
      },
    );
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
            Tab(text: 'En attente'),
            Tab(text: 'Annulées'),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => _applyFilter(),
              style: TextStyle(color: AppColors.text(context)),
              decoration: InputDecoration(
                hintText: 'Rechercher par nom, propriétaire...',
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _buildFilterChip(
                  icon: Icons.sort,
                  label: _getSortLabel(),
                  isActive: _sortBy != 'name',
                  onTap: _showSortSheet,
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  icon: Icons.filter_list,
                  label: _planFilter ?? 'Tous les plans',
                  isActive: _planFilter != null,
                  onTap: _showPlanFilterSheet,
                ),
                const Spacer(),
                Text(
                  '${_filteredShops.length}',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSec(context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
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

  String _getSortLabel() {
    switch (_sortBy) {
      case 'name':
        return 'Nom';
      case 'revenue':
        return 'Revenus';
      case 'date':
        return 'Récents';
      case 'days_asc':
        return 'Urgents';
      case 'days_desc':
        return 'Longs';
      default:
        return 'Trier';
    }
  }

  Widget _buildFilterChip({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.green(context).withOpacity(0.15)
              : AppColors.card(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive
                ? AppColors.green(context).withOpacity(0.5)
                : AppColors.border(context),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isActive
                  ? AppColors.green(context)
                  : AppColors.textSec(context),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isActive
                    ? AppColors.green(context)
                    : AppColors.text(context),
              ),
            ),
          ],
        ),
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
    final isExpiringSoon = shop.status != 'EXPIRED' &&
        shop.status != 'CANCELLED' &&
        shop.status != 'PENDING_VALIDATION' &&
        shop.daysRemaining > 0 &&
        shop.daysRemaining <= 7;

    final isPending = shop.status == 'PENDING_VALIDATION';
    final isCancelled = shop.status == 'CANCELLED';

    return GestureDetector(
      onTap: () => _showShopDetails(shop),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isPending
                ? AppColors.warningTheme(context).withOpacity(0.5)
                : isCancelled
                    ? AppColors.dangerTheme(context).withOpacity(0.5)
                    : isExpiringSoon
                        ? AppColors.dangerTheme(context).withOpacity(0.4)
                        : AppColors.border(context),
            width: (isPending || isCancelled || isExpiringSoon) ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              shop.name,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppColors.text(context),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isExpiringSoon) ...[
                            const SizedBox(width: 4),
                            Icon(
                              Icons.warning_amber_rounded,
                              size: 16,
                              color: AppColors.dangerTheme(context),
                            ),
                          ],
                          if (isPending) ...[
                            const SizedBox(width: 4),
                            Icon(
                              Icons.hourglass_top,
                              size: 16,
                              color: AppColors.warningTheme(context),
                            ),
                          ],
                        ],
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
      case 'PENDING_VALIDATION':
        return AppColors.warningTheme(context);
      case 'CANCELLED':
        return AppColors.textSec(context);
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
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: AppColors.bg(context),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border(context),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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

                      _buildSectionTitle('Informations'),
                      _buildDetailRow('Propriétaire', shop.ownerName),
                      _buildDetailRow('Téléphone', shop.phone),
                      _buildDetailRow('Plan', shop.planName),
                      _buildDetailRow('Statut', shop.statusName),
                      _buildDetailRow(
                          'Jours restants', '${shop.daysRemaining} jours'),
                      if (shop.startDate != null)
                        _buildDetailRow('Début abonnement',
                            AppFormatters.formatDate(shop.startDate!)),
                      if (shop.endDate != null)
                        _buildDetailRow('Fin abonnement',
                            AppFormatters.formatDate(shop.endDate!)),
                      _buildDetailRow(
                          'Créée le', AppFormatters.formatDate(shop.createdAt)),

                      // ⚡ Section annulation
                      if (shop.status == 'CANCELLED') ...[
                        const SizedBox(height: 20),
                        _buildSectionTitle('Annulation'),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color:
                                AppColors.dangerTheme(context).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppColors.dangerTheme(context)
                                  .withOpacity(0.3),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.cancel,
                                    size: 16,
                                    color: AppColors.dangerTheme(context),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Abonnement annulé',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.dangerTheme(context),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 20),

                      _buildSectionTitle('Paiements (${shop.paymentCount})'),
                      _buildDetailRow('Total payé',
                          AppFormatters.formatCurrency(shop.totalPaid)),
                      if (shop.lastPaymentDate != null)
                        _buildDetailRow('Dernier paiement',
                            AppFormatters.formatDate(shop.lastPaymentDate!)),

                      const SizedBox(height: 12),

                      _buildPaymentsHistory(shop.id),

                      const SizedBox(height: 24),

                      // ⚡ Actions secondaires
                      _buildAdminActions(shop),
                    ],
                  ),
                ),
              ),

              // Actions principales fixes
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.card(context),
                  border: Border(
                    top: BorderSide(color: AppColors.border(context)),
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: Row(
                    children: [
                      if (shop.phone.isNotEmpty && shop.phone != '—')
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _contactWhatsApp(shop),
                            icon: const Icon(
                              Icons.chat,
                              color: Color(0xFF25D366),
                              size: 18,
                            ),
                            label: const Text('Contacter'),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 48),
                              side: const BorderSide(color: Color(0xFF25D366)),
                              foregroundColor: const Color(0xFF25D366),
                            ),
                          ),
                        ),
                      if (shop.phone.isNotEmpty && shop.phone != '—')
                        const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _extendSubscription(shop),
                          icon: const Icon(Icons.add_circle_outline, size: 18),
                          label: const Text('Prolonger'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.green(context),
                            foregroundColor: AppColors.onGreen(context),
                            minimumSize: const Size(0, 48),
                          ),
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
    );
  }

  // ═══════════════════════════════════════════════════════════
  // ACTIONS ADMIN (essai gratuit, annuler, réactiver)
  // ═══════════════════════════════════════════════════════════
  Widget _buildAdminActions(AdminShop shop) {
    final isPending = shop.status == 'PENDING_VALIDATION';
    final isCancelled = shop.status == 'CANCELLED';
    final isExpired = shop.status == 'EXPIRED';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Actions administrateur'),
        const SizedBox(height: 8),

        // ⚡ Accorder un essai gratuit
        if (isPending || isExpired)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _grantTrial(shop),
              icon: const Icon(Icons.card_giftcard, size: 18),
              label: const Text('Accorder un essai gratuit'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
          ),

        if (isPending || isExpired) const SizedBox(height: 8),

        // ⚡ Annuler l'abonnement
        if (!isCancelled && !isPending)
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _cancelSubscription(shop),
              icon: const Icon(Icons.cancel_outlined, size: 18),
              label: const Text('Annuler l\'abonnement'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                side: BorderSide(color: AppColors.dangerTheme(context)),
                foregroundColor: AppColors.dangerTheme(context),
              ),
            ),
          ),

        // ⚡ Réactiver
        if (isCancelled || isExpired)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _reactivateShop(shop),
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Réactiver la boutique'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.green(context),
                foregroundColor: AppColors.onGreen(context),
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
          ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  // ACCORDER UN ESSAI GRATUIT
  // ═══════════════════════════════════════════════════════════
  Future<void> _grantTrial(AdminShop shop) async {
    int selectedDays = 15;
    String selectedPlan = 'ESSENTIEL';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Accorder un essai gratuit'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Boutique : ${shop.name}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              // Durée
              const Text('Durée de l\'essai', style: TextStyle(fontSize: 13)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [7, 15, 30, 60].map((d) {
                  return ChoiceChip(
                    label: Text('$d jours'),
                    selected: selectedDays == d,
                    onSelected: (_) => setDialogState(() => selectedDays = d),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // Plan
              const Text('Plan accordé', style: TextStyle(fontSize: 13)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: ['ESSENTIEL', 'PRO', 'BUSINESS'].map((p) {
                  return ChoiceChip(
                    label: Text(p),
                    selected: selectedPlan == p,
                    onSelected: (_) => setDialogState(() => selectedPlan = p),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Accorder'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;
    if (!mounted) return;

    final result = await AdminService.instance.grantTrial(
      shopId: shop.id,
      days: selectedDays,
      plan: selectedPlan,
    );

    if (!mounted) return;

    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] as String? ?? '✓ Essai accordé'),
          backgroundColor: AppColors.successTheme(context),
        ),
      );
      Navigator.pop(context);
      _loadShops();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['error'] as String? ?? 'Erreur'),
          backgroundColor: AppColors.dangerTheme(context),
        ),
      );
    }
  }

  // ═══════════════════════════════════════════════════════════
  // ANNULER L'ABONNEMENT
  // ═══════════════════════════════════════════════════════════
  Future<void> _cancelSubscription(AdminShop shop) async {
    final controller = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Annuler l\'abonnement ?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Boutique : ${shop.name}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.dangerTheme(context).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '⚠️ Cette action va immédiatement bloquer l\'accès à la boutique.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.dangerTheme(context),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Raison de l\'annulation *',
                hintText: 'Ex: Paiement non reçu',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.dangerTheme(context),
            ),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final reason = controller.text.trim();
    if (reason.length < 5) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Raison trop courte (min 5 caractères)')),
        );
      }
      return;
    }

    if (!mounted) return;

    final result = await AdminService.instance.cancelSubscription(
      shopId: shop.id,
      reason: reason,
    );

    if (!mounted) return;

    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] as String? ?? '✓ Abonnement annulé'),
          backgroundColor: AppColors.successTheme(context),
        ),
      );
      Navigator.pop(context);
      _loadShops();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['error'] as String? ?? 'Erreur'),
          backgroundColor: AppColors.dangerTheme(context),
        ),
      );
    }
  }

  // ═══════════════════════════════════════════════════════════
  // RÉACTIVER
  // ═══════════════════════════════════════════════════════════
  Future<void> _reactivateShop(AdminShop shop) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Réactiver la boutique ?'),
        content: Text(
          'Réactiver "${shop.name}" pour 30 jours ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Réactiver'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!mounted) return;

    final result = await AdminService.instance.reactivateShop(
      shopId: shop.id,
      days: 30,
    );

    if (!mounted) return;

    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] as String? ?? '✓ Boutique réactivée'),
          backgroundColor: AppColors.successTheme(context),
        ),
      );
      Navigator.pop(context);
      _loadShops();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['error'] as String? ?? 'Erreur'),
          backgroundColor: AppColors.dangerTheme(context),
        ),
      );
    }
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: AppColors.text(context),
        ),
      ),
    );
  }

  Widget _buildPaymentsHistory(String shopId) {
    return FutureBuilder<List<Payment>>(
      future: AdminService.instance.getShopPayments(shopId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.green(context),
                ),
              ),
            ),
          );
        }

        final payments = snapshot.data ?? [];

        if (payments.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.card(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border(context)),
            ),
            child: Center(
              child: Text(
                'Aucun paiement enregistré',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSec(context),
                ),
              ),
            ),
          );
        }

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.card(context),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border(context)),
          ),
          child: Column(
            children: payments.take(5).map((p) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Icon(
                      _getPaymentStatusIcon(p.status),
                      size: 16,
                      color: _getPaymentStatusColor(p.status),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.paymentCode,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.text(context),
                            ),
                          ),
                          Text(
                            AppFormatters.formatDate(p.createdAt),
                            style: TextStyle(
                              fontSize: 10,
                              color: AppColors.textSec(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          AppFormatters.formatCurrency(p.amount),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.green(context),
                          ),
                        ),
                        Text(
                          p.statusName,
                          style: TextStyle(
                            fontSize: 10,
                            color: _getPaymentStatusColor(p.status),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  IconData _getPaymentStatusIcon(String status) {
    switch (status) {
      case 'APPROVED':
        return Icons.check_circle;
      case 'PENDING_REVIEW':
        return Icons.hourglass_bottom;
      case 'REJECTED':
        return Icons.cancel;
      default:
        return Icons.payment;
    }
  }

  Color _getPaymentStatusColor(String status) {
    switch (status) {
      case 'APPROVED':
        return AppColors.successTheme(context);
      case 'PENDING_REVIEW':
        return AppColors.warningTheme(context);
      case 'REJECTED':
        return AppColors.dangerTheme(context);
      default:
        return AppColors.textSec(context);
    }
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 13, color: AppColors.textSec(context)),
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

  Future<void> _contactWhatsApp(AdminShop shop) async {
    final message = 'Bonjour ${shop.ownerName},\n\n'
        'Nous vous contactons au sujet de votre boutique "${shop.name}" '
        'sur Ma Boutique.';

    await WhatsAppService.instance.sendMessage(
      phone: shop.phone,
      message: message,
    );
  }

  Future<void> _extendSubscription(AdminShop shop) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Prolonger l\'abonnement ?'),
        content: Text(
          'Prolonger "${shop.name}" de 30 jours ?\n\n'
          '⚠️ Cette action est manuelle et ne génère pas de paiement.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Prolonger'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Prolongation manuelle — à implémenter côté backend'),
        ),
      );
    }
  }
}
