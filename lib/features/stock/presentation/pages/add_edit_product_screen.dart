import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../data/models/product.dart';
import '../../../../data/repositories/product_repository.dart';

class AddEditProductScreen extends StatefulWidget {
  final Product? product;

  const AddEditProductScreen({super.key, this.product});

  @override
  State<AddEditProductScreen> createState() => _AddEditProductScreenState();
}

class _AddEditProductScreenState extends State<AddEditProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final ProductRepository _repository = ProductRepository();

  late TextEditingController _nameController;
  late TextEditingController _referenceController;
  late TextEditingController _categoryController;
  late TextEditingController _purchasePriceController;
  late TextEditingController _sellingPriceController;
  late TextEditingController _quantityController;
  late TextEditingController _alertThresholdController;
  late TextEditingController _unitController;

  bool _isLoading = false;
  bool get isEditing => widget.product != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.product?.name ?? '');
    _referenceController =
        TextEditingController(text: widget.product?.reference ?? '');
    _categoryController =
        TextEditingController(text: widget.product?.category ?? '');
    _purchasePriceController = TextEditingController(
        text: widget.product?.purchasePrice.toStringAsFixed(0) ?? '');
    _sellingPriceController = TextEditingController(
        text: widget.product?.sellingPrice.toStringAsFixed(0) ?? '');
    _quantityController =
        TextEditingController(text: widget.product?.quantity.toString() ?? '');
    _alertThresholdController = TextEditingController(
        text: widget.product?.alertThreshold.toString() ?? '5');
    _unitController = TextEditingController(text: widget.product?.unit ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _referenceController.dispose();
    _categoryController.dispose();
    _purchasePriceController.dispose();
    _sellingPriceController.dispose();
    _quantityController.dispose();
    _alertThresholdController.dispose();
    _unitController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final product = Product(
        id: widget.product?.id ?? Product.generateId(),
        name: _nameController.text.trim(),
        reference: _referenceController.text.trim().isEmpty
            ? null
            : _referenceController.text.trim(),
        category: _categoryController.text.trim().isEmpty
            ? null
            : _categoryController.text.trim(),
        purchasePrice: double.tryParse(_purchasePriceController.text) ?? 0,
        sellingPrice: double.tryParse(_sellingPriceController.text) ?? 0,
        quantity: int.tryParse(_quantityController.text) ?? 0,
        alertThreshold: int.tryParse(_alertThresholdController.text) ?? 5,
        unit: _unitController.text.trim().isEmpty
            ? null
            : _unitController.text.trim(),
      );

      if (isEditing) {
        await _repository.updateProduct(product);
      } else {
        await _repository.addProduct(product);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isEditing ? 'Produit modifié avec succès' : 'Produit ajouté',
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
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer le produit'),
        content: const Text(
            'Êtes-vous sûr de vouloir supprimer ce produit ? Cette action est irréversible.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.dangerTheme(context),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirmed == true && widget.product != null) {
      try {
        await _repository.deleteProduct(widget.product!.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Produit supprimé'),
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
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar: AppBar(
        title: Text(isEditing ? 'Modifier le produit' : 'Ajouter un produit'),
        actions: [
          if (isEditing)
            IconButton(
              icon: Icon(
                Icons.delete_outline,
                color: AppColors.dangerTheme(context),
              ),
              onPressed: _isLoading ? null : _confirmDelete,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle(context, 'Informations du produit'),
              const SizedBox(height: 12),
              _buildTextField(
                context,
                controller: _nameController,
                label: 'Nom du produit *',
                hint: 'Ex: Riz 25kg',
                icon: Icons.inventory_2_outlined,
                validator: (v) =>
                    v == null || v.isEmpty ? 'Champ obligatoire' : null,
              ),
              const SizedBox(height: 12),
              _buildTextField(
                context,
                controller: _referenceController,
                label: 'Référence',
                hint: 'Ex: RIZ-001',
                icon: Icons.qr_code,
              ),
              const SizedBox(height: 12),
              _buildTextField(
                context,
                controller: _categoryController,
                label: 'Catégorie',
                hint: 'Ex: Alimentation',
                icon: Icons.category_outlined,
              ),
              const SizedBox(height: 12),
              _buildTextField(
                context,
                controller: _unitController,
                label: 'Unité',
                hint: 'Ex: sac, bouteille, pièce',
                icon: Icons.straighten,
              ),
              const SizedBox(height: 24),
              _buildSectionTitle(context, 'Prix'),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      context,
                      controller: _purchasePriceController,
                      label: "Prix d'achat",
                      hint: '15000',
                      icon: Icons.shopping_cart_outlined,
                      keyboardType: TextInputType.number,
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Obligatoire' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTextField(
                      context,
                      controller: _sellingPriceController,
                      label: 'Prix de vente',
                      hint: '18000',
                      icon: Icons.sell_outlined,
                      keyboardType: TextInputType.number,
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Obligatoire' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildSectionTitle(context, 'Stock'),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      context,
                      controller: _quantityController,
                      label: 'Quantité',
                      hint: '10',
                      icon: Icons.numbers,
                      keyboardType: TextInputType.number,
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Obligatoire' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTextField(
                      context,
                      controller: _alertThresholdController,
                      label: "Seuil d'alerte",
                      hint: '5',
                      icon: Icons.warning_amber_rounded,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _save,
                icon: _isLoading
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
                  _isLoading
                      ? 'Enregistrement...'
                      : (isEditing ? 'Enregistrer' : 'Ajouter le produit'),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: AppColors.text(context),
      ),
    );
  }

  Widget _buildTextField(
    BuildContext context, {
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      style: TextStyle(color: AppColors.text(context)),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
        labelStyle: TextStyle(color: AppColors.textSec(context)),
        hintStyle: TextStyle(color: AppColors.textSec(context)),
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
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.green(context), width: 2),
        ),
      ),
    );
  }
}
