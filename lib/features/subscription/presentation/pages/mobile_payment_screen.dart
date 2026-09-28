import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/services/subscription_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../data/models/payment.dart';

class MobilePaymentScreen extends StatefulWidget {
  final String plan;
  final String planName;
  final int amount;

  const MobilePaymentScreen({
    super.key,
    required this.plan,
    required this.planName,
    required this.amount,
  });

  @override
  State<MobilePaymentScreen> createState() => _MobilePaymentScreenState();
}

class _MobilePaymentScreenState extends State<MobilePaymentScreen> {
  int _currentStep = 0; // 0=choix méthode, 1=instructions, 2=en attente
  String? _selectedMethod;
  Payment? _payment;
  PaymentInstructions? _instructions;
  bool _isLoading = false;
  bool _isConfirming = false;
  String? _errorMessage;

  // ⚡ Polling pour vérifier la validation
  Timer? _pollingTimer;
  int _pollingCount = 0;

  final TextEditingController _transactionController = TextEditingController();

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _transactionController.dispose();
    super.dispose();
  }

  final List<Map<String, dynamic>> _methods = [
    {
      'code': 'ORANGE_MONEY',
      'name': 'Orange Money',
      'icon': Icons.phone_android,
      'color': const Color(0xFFFF6600),
      'description': 'Composez #144#',
    },
    {
      'code': 'WAVE',
      'name': 'Wave',
      'icon': Icons.waves,
      'color': const Color(0xFF1DC8FF),
      'description': 'Via l\'application Wave',
    },
    {
      'code': 'MOOV_MONEY',
      'name': 'Moov Money',
      'icon': Icons.phone_android,
      'color': const Color(0xFF0066B3),
      'description': 'Composez #155#',
    },
  ];

  // ═══════════════════════════════════════════════════════════
  // CRÉER LE PAIEMENT
  // ═══════════════════════════════════════════════════════════
  Future<void> _createPayment(String methodCode) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _selectedMethod = methodCode;
    });

    final result = await SubscriptionService.instance.createPayment(
      plan: widget.plan,
      method: methodCode,
    );

    if (!mounted) return;

    if (result == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Erreur lors de la création du paiement';
      });
      return;
    }

    setState(() {
      _payment = result['payment'] as Payment;
      _instructions = result['instructions'] as PaymentInstructions;
      _isLoading = false;
      _currentStep = 1;
    });
  }

  // ═══════════════════════════════════════════════════════════
  // SOUMETTRE LA PREUVE
  // ═══════════════════════════════════════════════════════════
  Future<void> _submitProof() async {
    final transactionId = _transactionController.text.trim();

    if (transactionId.isEmpty) {
      setState(() {
        _errorMessage = 'Veuillez entrer le code de transaction';
      });
      return;
    }

    if (transactionId.length < 4) {
      setState(() {
        _errorMessage = 'Le code doit contenir au moins 4 caractères';
      });
      return;
    }

    setState(() {
      _isConfirming = true;
      _errorMessage = null;
    });

    final success = await SubscriptionService.instance.submitPaymentProof(
      paymentId: _payment!.id,
      transactionId: transactionId,
    );

    if (!mounted) return;

    if (!success) {
      setState(() {
        _isConfirming = false;
        _errorMessage =
            'Erreur lors de la soumission. Vérifiez le code de transaction.';
      });
      return;
    }

    // ✅ Passer à l'écran d'attente
    setState(() {
      _isConfirming = false;
      _currentStep = 2;
    });

    // ⚡ Démarrer le polling (vérifie toutes les 10s)
    _startPolling();
  }

  // ═══════════════════════════════════════════════════════════
  // POLLING : vérifie si le paiement est approuvé
  // ═══════════════════════════════════════════════════════════
  void _startPolling() {
    _pollingCount = 0;
    _pollingTimer?.cancel();

    _pollingTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      _pollingCount++;

      // Arrêter après 30 tentatives (5 minutes)
      if (_pollingCount > 30) {
        timer.cancel();
        return;
      }

      if (!mounted) {
        timer.cancel();
        return;
      }

      // ⚡ Recharger le statut de l'abonnement
      await SubscriptionService.instance.refreshSubscription();

      if (!mounted) {
        timer.cancel();
        return;
      }

      // Vérifier si l'abonnement est activé
      final sub = SubscriptionService.instance.subscription;
      if (sub != null && sub.isActiveStatus) {
        timer.cancel();
        if (mounted) {
          Navigator.pop(context, true);
        }
      }
    });
  }

  // ═══════════════════════════════════════════════════════════
  // COPIER LE CODE UNIQUE
  // ═══════════════════════════════════════════════════════════
  Future<void> _copyCode() async {
    if (_instructions == null) return;
    await Clipboard.setData(
      ClipboardData(text: _instructions!.paymentCode),
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✓ Code copié'),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  Future<void> _copyMerchantNumber() async {
    if (_instructions == null) return;
    await Clipboard.setData(
      ClipboardData(text: _instructions!.merchantNumber),
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✓ Numéro copié'),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar: AppBar(
        title: const Text('Paiement'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_currentStep == 2) {
              // En attente : empêcher le retour
              _showCancelDialog();
            } else if (_currentStep == 1) {
              _showCancelDialog();
            } else {
              Navigator.pop(context);
            }
          },
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    switch (_currentStep) {
      case 0:
        return _buildMethodSelection();
      case 1:
        return _buildPaymentInstructions();
      case 2:
        return _buildWaitingValidation();
      default:
        return _buildMethodSelection();
    }
  }

  // ═══════════════════════════════════════════════════════════
  // ÉTAPE 0 : SÉLECTION DE LA MÉTHODE
  // ═══════════════════════════════════════════════════════════
  Widget _buildMethodSelection() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Récapitulatif du plan
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
                  'Plan ${widget.planName}',
                  style: TextStyle(
                    color: AppColors.onGreenSec(context),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${AppFormatters.formatCurrency(widget.amount.toDouble())}/mois',
                  style: TextStyle(
                    color: AppColors.onGreen(context),
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          Text(
            'Choisissez votre mode de paiement',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.text(context),
            ),
          ),
          const SizedBox(height: 16),

          ..._methods.map((method) => _buildMethodCard(method)),

          if (_errorMessage != null) ...[
            const SizedBox(height: 16),
            _buildErrorBox(_errorMessage!),
          ],

          const SizedBox(height: 24),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.greenLight(context),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline,
                    color: AppColors.green(context), size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Vous recevrez un code unique. Mentionnez-le lors du '
                    'transfert pour accélérer la validation.',
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
    );
  }

  Widget _buildMethodCard(Map<String, dynamic> method) {
    final isSelected = _selectedMethod == method['code'];
    final isLoading = _isLoading && isSelected;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: _isLoading ? null : () => _createPayment(method['code']),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? method['color'] as Color
                    : AppColors.border(context),
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: (method['color'] as Color).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    method['icon'] as IconData,
                    color: method['color'] as Color,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        method['name'] as String,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.text(context),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        method['description'] as String,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSec(context),
                        ),
                      ),
                    ],
                  ),
                ),
                if (isLoading)
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: method['color'] as Color,
                    ),
                  )
                else
                  Icon(
                    Icons.chevron_right,
                    color: AppColors.textSec(context),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // ÉTAPE 1 : INSTRUCTIONS
  // ═══════════════════════════════════════════════════════════
  Widget _buildPaymentInstructions() {
    if (_instructions == null || _payment == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ⚡ CODE UNIQUE EN GRAND
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.green(context),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppColors.green(context).withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                Icon(
                  Icons.qr_code_2,
                  color: AppColors.onGreen(context),
                  size: 40,
                ),
                const SizedBox(height: 12),
                Text(
                  'VOTRE CODE DE PAIEMENT',
                  style: TextStyle(
                    color: AppColors.onGreenSec(context),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _instructions!.paymentCode,
                  style: TextStyle(
                    color: AppColors.onGreen(context),
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton.icon(
                      onPressed: _copyCode,
                      icon: Icon(Icons.copy,
                          color: AppColors.onGreen(context), size: 18),
                      label: Text(
                        'Copier',
                        style: TextStyle(color: AppColors.onGreen(context)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ⚡ AVERTISSEMENT CRITIQUE
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.warningTheme(context).withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.warningTheme(context).withOpacity(0.4),
                width: 2,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.priority_high,
                    color: AppColors.warningTheme(context), size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'IMPORTANT',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.warningTheme(context),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Mentionnez ce code dans le MOTIF du transfert.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.text(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Montant à envoyer
          Text(
            'Montant à envoyer',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.text(context),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.card(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border(context)),
            ),
            child: Text(
              AppFormatters.formatCurrency(_instructions!.amount.toDouble()),
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.green(context),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Numéro marchand
          Text(
            'Numéro marchand',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.text(context),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.card(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border(context)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _instructions!.merchantNumber,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.text(context),
                      letterSpacing: 1,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _copyMerchantNumber,
                  icon: Icon(Icons.copy, color: AppColors.green(context)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Étapes
          Text(
            'Étapes à suivre',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.text(context),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.card(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border(context)),
            ),
            child: Column(
              children: _instructions!.steps
                  .asMap()
                  .entries
                  .map((entry) => _buildStep(entry.key + 1, entry.value))
                  .toList(),
            ),
          ),
          const SizedBox(height: 24),

          // Code de transaction
          Text(
            'Code de transaction reçu par SMS',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.text(context),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _transactionController,
            decoration: InputDecoration(
              hintText: 'Ex: MP240924.1234.A5B8C2',
              prefixIcon: const Icon(Icons.receipt_long),
              filled: true,
              fillColor: AppColors.card(context),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.border(context)),
              ),
            ),
            style: TextStyle(color: AppColors.text(context)),
          ),

          if (_errorMessage != null) ...[
            const SizedBox(height: 16),
            _buildErrorBox(_errorMessage!),
          ],
          const SizedBox(height: 24),

          // Bouton confirmer
          ElevatedButton.icon(
            onPressed: _isConfirming ? null : _submitProof,
            icon: _isConfirming
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.onGreen(context),
                    ),
                  )
                : const Icon(Icons.check_circle_outline),
            label: Text(
              _isConfirming ? 'Envoi...' : 'J\'ai effectué le paiement',
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.green(context),
              foregroundColor: AppColors.onGreen(context),
              minimumSize: const Size(double.infinity, 50),
            ),
          ),
          const SizedBox(height: 12),

          OutlinedButton.icon(
            onPressed: _isConfirming ? null : _showCancelDialog,
            icon: const Icon(Icons.close),
            label: const Text('Annuler'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
              side: BorderSide(color: AppColors.dangerTheme(context)),
              foregroundColor: AppColors.dangerTheme(context),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildStep(int number, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: AppColors.greenLight(context),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$number',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.green(context),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.text(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // ÉTAPE 2 : EN ATTENTE DE VALIDATION
  // ═══════════════════════════════════════════════════════════
  Widget _buildWaitingValidation() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppColors.warningTheme(context).withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: CircularProgressIndicator(
                  color: AppColors.warningTheme(context),
                  strokeWidth: 4,
                ),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Validation en cours...',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.text(context),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Votre paiement est en cours de vérification.\n'
              'Cela prend généralement moins de 5 minutes.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSec(context),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.card(context),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border(context)),
              ),
              child: Column(
                children: [
                  _buildInfoRow('Code de paiement', _instructions!.paymentCode),
                  const SizedBox(height: 8),
                  _buildInfoRow(
                    'Montant',
                    AppFormatters.formatCurrency(
                        _instructions!.amount.toDouble()),
                  ),
                  const SizedBox(height: 8),
                  _buildInfoRow('Transaction', _payment?.transactionId ?? '—'),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Vous serez notifié automatiquement dès validation.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSec(context),
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 32),
            OutlinedButton.icon(
              onPressed: () async {
                await SubscriptionService.instance.refreshSubscription();
                final sub = SubscriptionService.instance.subscription;
                if (sub != null && sub.isActiveStatus && mounted) {
                  Navigator.pop(context, true);
                } else if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Toujours en attente de validation...'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Vérifier maintenant'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                side: BorderSide(color: AppColors.green(context)),
                foregroundColor: AppColors.green(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textSec(context),
          ),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.text(context),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorBox(String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.dangerTheme(context).withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.dangerTheme(context).withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline,
              color: AppColors.dangerTheme(context), size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: AppColors.dangerTheme(context),
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // DIALOG ANNULATION
  // ═══════════════════════════════════════════════════════════
  Future<void> _showCancelDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Annuler le paiement ?'),
        content: const Text(
          'Si vous annulez, votre demande de paiement sera supprimée. '
          'Vous pourrez en créer une nouvelle à tout moment.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Continuer'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.dangerTheme(context),
            ),
            child: const Text('Annuler le paiement'),
          ),
        ],
      ),
    );

    if (confirmed == true && _payment != null) {
      _pollingTimer?.cancel();
      await SubscriptionService.instance.cancelPayment(_payment!.id);
      if (mounted) Navigator.pop(context);
    }
  }
}
