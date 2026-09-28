import 'package:flutter/material.dart';

import '../../../../core/services/data_refresh_notifier.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../data/models/credit.dart';
import '../../../../data/models/customer.dart';
import '../../../../data/repositories/credit_repository.dart';
import '../../../../data/repositories/customer_repository.dart';

class NewCreditScreen extends StatefulWidget {
  const NewCreditScreen({super.key});

  @override
  State<NewCreditScreen> createState() => _NewCreditScreenState();
}

class _NewCreditScreenState extends State<NewCreditScreen> {
  final _formKey = GlobalKey<FormState>();
  final CreditRepository _creditRepo = CreditRepository();
  final CustomerRepository _customerRepo = CustomerRepository();

  Customer? _selectedCustomer;
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  DateTime _dueDate = DateTime.now().add(const Duration(days: 30));

  List<Customer> _customers = [];
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadCustomers() async {
    try {
      final customers = await _customerRepo.getAllCustomers();
      if (!mounted) return;
      setState(() {
        _customers = [];
        _customers = customers;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _selectedCustomer == null) {
      if (_selectedCustomer == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Veuillez sélectionner un client'),
            backgroundColor: AppColors.dangerTheme(context),
          ),
        );
      }
      return;
    }

    setState(() => _isSaving = true);

    try {
      final amount = double.parse(_amountController.text);

      final credit = Credit(
        id: Credit.generateId(),
        customer: _selectedCustomer!,
        totalAmount: amount,
        paidAmount: 0,
        createdAt: DateTime.now(),
        dueDate: _dueDate,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      );

      await _creditRepo.addCredit(credit);
      DataRefreshNotifier.instance.notifyCreditsChanged();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Crédit de ${AppFormatters.formatCurrency(amount)} créé pour ${_selectedCustomer!.name}',
            ),
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
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _pickDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _dueDate = picked);
    }
  }

  Future<void> _addNewCustomer() async {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nouveau client'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Nom complet',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Téléphone (optionnel)',
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
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );

    if (result == true && nameController.text.trim().isNotEmpty) {
      try {
        final newCustomer = Customer(
          id: Customer.generateId(),
          name: nameController.text.trim(),
          phone: phoneController.text.trim().isEmpty
              ? null
              : phoneController.text.trim(),
        );
        await _customerRepo.addCustomer(newCustomer);
        await _loadCustomers();
        setState(() {
          _selectedCustomer = newCustomer;
        });
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur: $e'),
              backgroundColor: AppColors.dangerTheme(context),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar: AppBar(
        title: const Text('Nouveau crédit'),
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: AppColors.green(context),
              ),
            )
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Client',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.text(context),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _addNewCustomer,
                          icon: Icon(Icons.person_add,
                              size: 18, color: AppColors.green(context)),
                          label: Text(
                            'Nouveau client',
                            style: TextStyle(color: AppColors.green(context)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: AppColors.card(context),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border(context)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedCustomer?.id,
                          isExpanded: true,
                          hint: Text(
                            'Sélectionner un client',
                            style: TextStyle(color: AppColors.textSec(context)),
                          ),
                          dropdownColor: AppColors.card(context),
                          style: TextStyle(color: AppColors.text(context)),
                          items: _customers.map((c) {
                            return DropdownMenuItem<String>(
                              value: c.id,
                              child: Text(
                                c.name,
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedCustomer =
                                  _customers.firstWhere((c) => c.id == value);
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Montant du crédit (FCFA)',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text(context),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      style: TextStyle(color: AppColors.text(context)),
                      decoration: InputDecoration(
                        hintText: 'Ex: 25000',
                        prefixIcon: const Icon(Icons.money),
                        filled: true,
                        fillColor: AppColors.card(context),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              BorderSide(color: AppColors.border(context)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              BorderSide(color: AppColors.border(context)),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Champ obligatoire';
                        final amount = double.tryParse(v);
                        if (amount == null) return 'Montant invalide';
                        if (amount <= 0) return 'Montant doit être > 0';
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    Text(
                      "Date d'échéance",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text(context),
                      ),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: _pickDueDate,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.card(context),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border(context)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_today,
                                color: AppColors.textSec(context)),
                            const SizedBox(width: 12),
                            Text(
                              AppFormatters.formatDate(_dueDate),
                              style: TextStyle(
                                fontSize: 15,
                                color: AppColors.text(context),
                              ),
                            ),
                            const Spacer(),
                            Icon(Icons.arrow_drop_down,
                                color: AppColors.textSec(context)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Notes (optionnel)',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text(context),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _notesController,
                      maxLines: 3,
                      maxLength: 300,
                      style: TextStyle(color: AppColors.text(context)),
                      decoration: InputDecoration(
                        hintText: 'Ex: Riz 25kg + Huile 1L',
                        filled: true,
                        fillColor: AppColors.card(context),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              BorderSide(color: AppColors.border(context)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              BorderSide(color: AppColors.border(context)),
                        ),
                      ),
                      // ⚡ AJOUT : validator pour éviter les abus
                      validator: (value) {
                        if (value != null && value.length > 300) {
                          return 'Maximum 300 caractères';
                        }
                        // ⚡ Interdire les caractères de contrôle
                        if (value != null &&
                            RegExp(r'[\x00-\x1F\x7F]').hasMatch(value)) {
                          return 'Caractères invalides détectés';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton.icon(
                      onPressed: _isSaving ? null : _save,
                      icon: _isSaving
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.onGreen(context),
                              ),
                            )
                          : const Icon(Icons.save_outlined),
                      label: Text(
                        _isSaving
                            ? 'Enregistrement...'
                            : 'Enregistrer le crédit',
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
