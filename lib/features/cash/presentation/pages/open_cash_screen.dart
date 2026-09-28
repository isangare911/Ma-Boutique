import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../data/models/cash_session.dart';
import '../../../../data/repositories/cash_repository.dart';

class OpenCashScreen extends StatefulWidget {
  const OpenCashScreen({super.key});

  @override
  State<OpenCashScreen> createState() => _OpenCashScreenState();
}

class _OpenCashScreenState extends State<OpenCashScreen> {
  final _formKey = GlobalKey<FormState>();
  final _balanceController = TextEditingController();
  final CashRepository _repository = CashRepository();
  bool _isSaving = false;

  @override
  void dispose() {
    _balanceController.dispose();
    super.dispose();
  }

  Future<void> _open() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final session = CashSession(
        id: CashSession.generateId(),
        openingBalance: double.parse(_balanceController.text),
        openedAt: DateTime.now(),
      );

      await _repository.openSession(session);

      if (mounted) {
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
      appBar: AppBar(title: const Text('Ouverture de caisse')),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.greenLight(context),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: AppColors.green(context)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Comptez l\'argent en caisse avant d\'ouvrir.',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.text(context),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Solde initial (FCFA)',
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
                  hintText: 'Ex: 50000',
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
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _isSaving ? null : _open,
                icon: _isSaving
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.onGreen(context),
                        ),
                      )
                    : const Icon(Icons.lock_open),
                label: Text(_isSaving ? 'Ouverture...' : 'Ouvrir la caisse'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
