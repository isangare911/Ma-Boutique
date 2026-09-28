import 'package:flutter/material.dart';

import '../../../../core/services/data_refresh_notifier.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../data/models/cash_movement.dart';
import '../../../../data/models/cash_session.dart';
import '../../../../data/repositories/cash_repository.dart';
import 'add_expense_screen.dart';
import 'close_cash_screen.dart';
import 'open_cash_screen.dart';

class CashScreen extends StatefulWidget {
  const CashScreen({super.key});

  @override
  State<CashScreen> createState() => _CashScreenState();
}

class _CashScreenState extends State<CashScreen> {
  final CashRepository _repository = CashRepository();

  CashSession? _currentSession;
  List<CashMovement> _movements = [];
  Map<String, double> _summary = {
    'totalIn': 0,
    'totalOut': 0,
    'theoretical': 0,
  };
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
    super.dispose();
  }

  void _onDataChanged() {
    if (mounted) _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final session = await _repository.getCurrentSession();
      if (session != null) {
        final movements = await _repository.getMovementsBySession(session.id);
        final summary = await _repository.getSessionSummary(session.id);

        if (!mounted) return;
        setState(() {
          _currentSession = session;
          _movements = movements;
          _summary = summary;
          _isLoading = false;
        });
      } else {
        setState(() {
          _currentSession = null;
          _movements = [];
          _isLoading = false;
        });
      }
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
        title: const Text('Caisse'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: AppColors.green(context),
              ),
            )
          : _currentSession == null
              ? _buildNoSessionState(context)
              : _buildSessionView(context),
    );
  }

  Widget _buildNoSessionState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.point_of_sale_outlined,
              size: 100,
              color: AppColors.textSec(context).withOpacity(0.5),
            ),
            const SizedBox(height: 24),
            Text(
              'Caisse fermée',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.text(context),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Ouvrez la caisse pour commencer à enregistrer les mouvements',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSec(context)),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const OpenCashScreen()),
                );
                DataRefreshNotifier.instance.notifyProductsChanged();
                await _loadData();
              },
              icon: const Icon(Icons.lock_open),
              label: const Text('Ouvrir la caisse'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionView(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppColors.green(context),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Carte solde
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.green(context),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Solde en caisse',
                    style: TextStyle(
                      color: AppColors.onGreenSec(context),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AppFormatters.formatCurrency(_summary['theoretical'] ?? 0),
                    style: TextStyle(
                      color: AppColors.onGreen(context),
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Ouverte à ${AppFormatters.formatDateTime(_currentSession!.openedAt)}',
                    style: TextStyle(
                      color: AppColors.onGreenSec(context),
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Divider(color: AppColors.onGreen(context).withOpacity(0.2)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildMiniStat(
                          context,
                          'Entrées',
                          AppFormatters.formatCurrency(
                              _summary['totalIn'] ?? 0),
                          Icons.arrow_downward,
                        ),
                      ),
                      Expanded(
                        child: _buildMiniStat(
                          context,
                          'Sorties',
                          AppFormatters.formatCurrency(
                              _summary['totalOut'] ?? 0),
                          Icons.arrow_upward,
                        ),
                      ),
                      Expanded(
                        child: _buildMiniStat(
                          context,
                          'Initial',
                          AppFormatters.formatCurrency(
                              _currentSession!.openingBalance),
                          Icons.lock_open,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Actions rapides
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AddExpenseScreen(
                            sessionId: _currentSession!.id,
                            type: 'OUT',
                          ),
                        ),
                      );
                      DataRefreshNotifier.instance.notifyProductsChanged();
                      await _loadData();
                    },
                    icon: const Icon(Icons.remove_circle_outline),
                    label: const Text('Dépense'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.dangerTheme(context),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AddExpenseScreen(
                            sessionId: _currentSession!.id,
                            type: 'IN',
                          ),
                        ),
                      );
                      DataRefreshNotifier.instance.notifyProductsChanged();
                      await _loadData();
                    },
                    icon: const Icon(Icons.add_circle_outline),
                    label: const Text('Entrée'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.successTheme(context),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            Text(
              'Mouvements du jour',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.text(context),
              ),
            ),
            const SizedBox(height: 12),

            if (_movements.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Text(
                    'Aucun mouvement enregistré',
                    style: TextStyle(color: AppColors.textSec(context)),
                  ),
                ),
              )
            else
              ..._movements.map((m) => _buildMovementTile(context, m)),

            const SizedBox(height: 24),

            OutlinedButton.icon(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CloseCashScreen(
                      session: _currentSession!,
                      theoreticalBalance: _summary['theoretical'] ?? 0,
                    ),
                  ),
                );
                DataRefreshNotifier.instance.notifyProductsChanged();
                await _loadData();
              },
              icon: const Icon(Icons.lock_outline),
              label: const Text('Fermer la caisse'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                side: BorderSide(color: AppColors.dangerTheme(context)),
                foregroundColor: AppColors.dangerTheme(context),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniStat(
      BuildContext context, String label, String value, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: AppColors.onGreen(context), size: 14),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: AppColors.onGreenSec(context),
                fontSize: 11,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: AppColors.onGreen(context),
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildMovementTile(BuildContext context, CashMovement movement) {
    final isIn = movement.isIn;
    final color =
        isIn ? AppColors.successTheme(context) : AppColors.dangerTheme(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isIn ? Icons.arrow_downward : Icons.arrow_upward,
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  movement.category,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text(context),
                  ),
                ),
                if (movement.description != null)
                  Text(
                    movement.description!,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSec(context),
                    ),
                  ),
                Text(
                  AppFormatters.formatDateTime(movement.createdAt),
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSec(context),
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${isIn ? "+" : "-"} ${AppFormatters.formatCurrency(movement.amount)}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
