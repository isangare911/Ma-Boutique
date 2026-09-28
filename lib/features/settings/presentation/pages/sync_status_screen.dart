import 'package:flutter/material.dart';

import '../../../../core/services/connectivity_service.dart';
import '../../../../core/services/sync_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';

class SyncStatusScreen extends StatefulWidget {
  const SyncStatusScreen({super.key});

  @override
  State<SyncStatusScreen> createState() => _SyncStatusScreenState();
}

class _SyncStatusScreenState extends State<SyncStatusScreen> {
  final SyncService _sync = SyncService.instance;

  @override
  void initState() {
    super.initState();
    _sync.addListener(_onSyncChanged);
    _sync.refreshCounters();
  }

  @override
  void dispose() {
    _sync.removeListener(_onSyncChanged);
    super.dispose();
  }

  void _onSyncChanged() {
    if (mounted) setState(() {});
  }

  Color _getStatusColor(BuildContext context) {
    switch (_sync.status) {
      case SyncStatus.success:
        return AppColors.successTheme(context);
      case SyncStatus.syncing:
        return AppColors.green(context);
      case SyncStatus.failed:
        return AppColors.dangerTheme(context);
      case SyncStatus.offline:
        return AppColors.textSec(context);
      default:
        return AppColors.textSec(context);
    }
  }

  IconData _getStatusIcon() {
    switch (_sync.status) {
      case SyncStatus.success:
        return Icons.check_circle_outline;
      case SyncStatus.syncing:
        return Icons.sync;
      case SyncStatus.failed:
        return Icons.error_outline;
      case SyncStatus.offline:
        return Icons.cloud_off;
      default:
        return Icons.cloud_done_outlined;
    }
  }

  String _getStatusText() {
    switch (_sync.status) {
      case SyncStatus.success:
        return 'Synchronisé';
      case SyncStatus.syncing:
        return 'Synchronisation en cours...';
      case SyncStatus.failed:
        return 'Synchronisation échouée';
      case SyncStatus.offline:
        return 'Hors ligne';
      default:
        return 'En attente';
    }
  }

  @override
  Widget build(BuildContext context) {
    final connected = ConnectivityService.instance.isConnected;

    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar: AppBar(
        title: const Text('Synchronisation'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              await _sync.refreshCounters();
              await _sync.syncNow();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // État connexion
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: (connected
                        ? AppColors.successTheme(context)
                        : AppColors.dangerTheme(context))
                    .withOpacity(0.15),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: (connected
                          ? AppColors.successTheme(context)
                          : AppColors.dangerTheme(context))
                      .withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    connected ? Icons.wifi : Icons.wifi_off,
                    color: connected
                        ? AppColors.successTheme(context)
                        : AppColors.dangerTheme(context),
                    size: 32,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          connected ? 'Connecté à Internet' : 'Hors ligne',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: connected
                                ? AppColors.successTheme(context)
                                : AppColors.dangerTheme(context),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          connected
                              ? 'Les données peuvent être synchronisées'
                              : 'Les modifications sont enregistrées localement',
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
            ),
            const SizedBox(height: 24),

            // État sync
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.card(context),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border(context)),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _getStatusColor(context).withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: _sync.isSyncing
                        ? SizedBox(
                            width: 40,
                            height: 40,
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              color: _getStatusColor(context),
                            ),
                          )
                        : Icon(
                            _getStatusIcon(),
                            color: _getStatusColor(context),
                            size: 40,
                          ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _getStatusText(),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _getStatusColor(context),
                    ),
                  ),
                  if (_sync.lastSyncAt != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Dernière sync: ${AppFormatters.formatDateTime(_sync.lastSyncAt!)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSec(context),
                      ),
                    ),
                  ],
                  if (_sync.lastError != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _sync.lastError!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.dangerTheme(context),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Stats
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    context,
                    'En attente',
                    '${_sync.pendingCount}',
                    Icons.schedule,
                    AppColors.warningTheme(context),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    context,
                    'Échouées',
                    '${_sync.failedCount}',
                    Icons.error_outline,
                    AppColors.dangerTheme(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Boutons
            ElevatedButton.icon(
              onPressed: _sync.isSyncing ? null : () => _sync.syncNow(),
              icon: const Icon(Icons.sync),
              label: Text(
                _sync.isSyncing
                    ? 'Synchronisation...'
                    : 'Synchroniser maintenant',
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () async {
                await _sync.retryAllFailed();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer les échecs'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                side: BorderSide(color: AppColors.green(context)),
                foregroundColor: AppColors.green(context),
              ),
            ),
            const SizedBox(height: 24),

            // Info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.greenLight(context),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: AppColors.green(context)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Vos données sont d\'abord enregistrées localement. Elles sont envoyées au Cloud dès que la connexion est disponible.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.text(context),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.text(context),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSec(context),
            ),
          ),
        ],
      ),
    );
  }
}
