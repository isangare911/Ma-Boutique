import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../data/models/cash_session.dart';
import '../../../../data/repositories/cash_repository.dart';

class CloseCashScreen extends StatefulWidget {
  final CashSession session;
  final double theoreticalBalance;

  const CloseCashScreen({
    super.key,
    required this.session,
    required this.theoreticalBalance,
  });

  @override
  State<CloseCashScreen> createState() => _CloseCashScreenState();
}

class _CloseCashScreenState extends State<CloseCashScreen> {
  final _formKey = GlobalKey<FormState>();
  final _balanceController = TextEditingController();
  final CashRepository _repository = CashRepository();
  bool _isSaving = false;

  double get _realBalance => double.tryParse(_balanceController.text) ?? 0;

  double get _difference => _realBalance - widget.theoreticalBalance;

  @override
  void initState() {
    super.initState();
    _balanceController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _balanceController.dispose();
    super.dispose();
  }

  Future<void> _close() async {
    if (!_formKey.currentState!.validate()) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmer la fermeture'),
        content: Text(
          'Solde théorique: ${AppFormatters.formatCurrency(widget.theoreticalBalance)}\n'
          'Solde réel: ${AppFormatters.formatCurrency(_realBalance)}\n'
          'Écart: ${AppFormatters.formatCurrency(_difference)}\n\n'
          'Voulez-vous vraiment fermer la caisse ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isSaving = true);

    try {
      await _repository.closeSession(widget.session.id, _realBalance);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Caisse fermée avec succès'),
            backgroundColor: AppColors.successTheme(context),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: AppColors.dangerTheme(context),
          ),
        );
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar: AppBar(title: const Text('Fermeture de caisse')),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.card(context),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border(context)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Solde théorique',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSec(context),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      AppFormatters.formatCurrency(widget.theoreticalBalance),
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.green(context),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Solde réel compté (FCFA)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text(context),
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _balanceController,
                keyboardType: TextInputType.number,
                autofocus: true,
                style: TextStyle(color: AppColors.text(context)),
                decoration: InputDecoration(
                  hintText: 'Comptez et entrez le montant',
                  prefixIcon: const Icon(Icons.money),
                  filled: true,
                  fillColor: AppColors.card(context),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.border(context)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.border(context)),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Champ obligatoire';
                  if (double.tryParse(v) == null) return 'Montant invalide';
                  return null;
                },
              ),
              const SizedBox(height: 24),
              if (_balanceController.text.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: (_difference == 0
                            ? AppColors.successTheme(context)
                            : _difference > 0
                                ? AppColors.warningTheme(context)
                                : AppColors.dangerTheme(context))
                        .withOpacity(0.15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: (_difference == 0
                              ? AppColors.successTheme(context)
                              : _difference > 0
                                  ? AppColors.warningTheme(context)
                                  : AppColors.dangerTheme(context))
                          .withOpacity(0.3),
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        _difference == 0
                            ? 'Caisse équilibrée ✓'
                            : _difference > 0
                                ? 'Excédent de caisse'
                                : 'Manquant de caisse',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _difference == 0
                              ? AppColors.successTheme(context)
                              : _difference > 0
                                  ? AppColors.warningTheme(context)
                                  : AppColors.dangerTheme(context),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        AppFormatters.formatCurrency(_difference.abs()),
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: _difference == 0
                              ? AppColors.successTheme(context)
                              : _difference > 0
                                  ? AppColors.warningTheme(context)
                                  : AppColors.dangerTheme(context),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _isSaving ? null : _close,
                icon: _isSaving
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.lock_outline),
                label: Text(_isSaving ? 'Fermeture...' : 'Fermer la caisse'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.dangerTheme(context),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
