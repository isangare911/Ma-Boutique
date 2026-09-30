import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../core/services/auth_service.dart';
import '../../../../core/services/logo_service.dart';
import '../../../../core/services/notification_cheker.dart';
import '../../../../core/services/shop_settings_service.dart';
import '../../../../core/services/theme_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/models/shop_settings.dart';

class ShopSettingsScreen extends StatefulWidget {
  const ShopSettingsScreen({super.key});

  @override
  State<ShopSettingsScreen> createState() => _ShopSettingsScreenState();
}

class _ShopSettingsScreenState extends State<ShopSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;
  late TextEditingController _ownerController;
  String _currency = 'FCFA';
  String? _logoPath;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();

    // ⚡ Lire les settings actuels (déjà chargés par le service)
    final settings = ShopSettingsService.instance.settings;
    final user = AuthService.instance.user;
    final shopData = user?['shop'] as Map<String, dynamic>?;

    // ⚡ Priorité : settings locaux > données serveur
    _nameController = TextEditingController(
      text: settings.shopName.isNotEmpty
          ? settings.shopName
          : (shopData?['name'] as String? ?? ''),
    );
    _phoneController = TextEditingController(
      text: settings.phone ?? (shopData?['phone'] as String?) ?? '',
    );
    _addressController = TextEditingController(
      text: settings.address ?? (shopData?['address'] as String?) ?? '',
    );
    _ownerController = TextEditingController(
      text: settings.ownerName ?? (shopData?['owner_name'] as String?) ?? '',
    );
    _currency = settings.currency;
    _logoPath = settings.shopLogoPath;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _ownerController.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════
  // CHOISIR UN LOGO
  // ═══════════════════════════════════════════════════════════
  Future<void> _changeLogo() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: AppColors.card(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border(context),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Changer le logo',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.text(context),
              ),
            ),
            const SizedBox(height: 20),
            _buildLogoOption(
              icon: Icons.photo_library_outlined,
              label: 'Choisir depuis la galerie',
              onTap: () => Navigator.pop(context, 'gallery'),
            ),
            _buildLogoOption(
              icon: Icons.camera_alt_outlined,
              label: 'Prendre une photo',
              onTap: () => Navigator.pop(context, 'camera'),
            ),
            if (_logoPath != null && _logoPath!.isNotEmpty)
              _buildLogoOption(
                icon: Icons.delete_outline,
                label: 'Supprimer le logo',
                color: AppColors.dangerTheme(context),
                onTap: () => Navigator.pop(context, 'delete'),
              ),
          ],
        ),
      ),
    );

    if (action == null) return;

    if (action == 'delete') {
      await LogoService.instance.deleteLogo(_logoPath);
      if (mounted) setState(() => _logoPath = null);
      return;
    }

    String? newPath;
    if (action == 'gallery') {
      newPath = await LogoService.instance.pickImageFromGallery();
    } else if (action == 'camera') {
      newPath = await LogoService.instance.pickImageFromCamera();
    }

    if (newPath != null && mounted) {
      if (_logoPath != null && _logoPath != newPath) {
        await LogoService.instance.deleteLogo(_logoPath);
      }
      setState(() => _logoPath = newPath);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Logo sélectionné — Cliquez sur Enregistrer'),
          backgroundColor: AppColors.successTheme(context),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Widget _buildLogoOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    final c = color ?? AppColors.primary;
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: c.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: c),
      ),
      title: Text(label, style: TextStyle(color: color)),
      onTap: onTap,
    );
  }

  // ═══════════════════════════════════════════════════════════
  // TESTER LES NOTIFICATIONS
  // ═══════════════════════════════════════════════════════════
  Future<void> _testNotifications() async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Vérification des alertes en cours...'),
        backgroundColor: AppColors.primary,
        duration: const Duration(seconds: 1),
      ),
    );

    await NotificationChecker.instance.checkAll();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('✓ Alertes vérifiées'),
          backgroundColor: AppColors.successTheme(context),
        ),
      );
    }
  }

  // ═══════════════════════════════════════════════════════════
  // SAUVEGARDER
  // ═══════════════════════════════════════════════════════════
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final current = ShopSettingsService.instance.settings;
      final updated = current.copyWith(
        // ⚡ Plus de ShopSettings.defaultId — l'id est déjà dans current
        shopName: _nameController.text.trim(),
        phone: _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim(),
        address: _addressController.text.trim().isEmpty
            ? null
            : _addressController.text.trim(),
        ownerName: _ownerController.text.trim().isEmpty
            ? null
            : _ownerController.text.trim(),
        currency: _currency,
        shopLogoPath: _logoPath,
        updatedAt: DateTime.now(),
      );

      await ShopSettingsService.instance.updateSettings(updated);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Paramètres enregistrés'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar: AppBar(title: const Text('Paramètres boutique')),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ═══════════════════════════════════════════════
              // APERÇU DU LOGO
              // ═══════════════════════════════════════════════
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: AppColors.greenLight(context),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.green(context).withOpacity(0.2),
                          width: 3,
                        ),
                      ),
                      child: ClipOval(
                        child: (_logoPath != null && _logoPath!.isNotEmpty)
                            ? Image.file(
                                File(_logoPath!),
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Icon(
                                  Icons.storefront,
                                  size: 60,
                                  color: AppColors.green(context),
                                ),
                              )
                            : Icon(
                                Icons.storefront,
                                size: 60,
                                color: AppColors.green(context),
                              ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: _changeLogo,
                      icon: const Icon(Icons.image_outlined),
                      label: Text(
                        (_logoPath != null && _logoPath!.isNotEmpty)
                            ? 'Changer le logo'
                            : 'Ajouter un logo',
                        style: TextStyle(color: AppColors.green(context)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              _buildSectionTitle(context, 'Informations générales'),
              const SizedBox(height: 12),

              _buildTextField(
                controller: _nameController,
                label: 'Nom de la boutique *',
                hint: 'Ex: Boutique Moussa',
                icon: Icons.storefront,
                validator: (v) =>
                    v == null || v.isEmpty ? 'Champ obligatoire' : null,
              ),
              const SizedBox(height: 12),

              _buildTextField(
                controller: _ownerController,
                label: 'Nom du propriétaire',
                hint: 'Ex: Moussa Diarra',
                icon: Icons.person_outline,
              ),
              const SizedBox(height: 12),

              _buildTextField(
                controller: _phoneController,
                label: 'Téléphone',
                hint: '+223 70 12 34 56',
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),

              _buildTextField(
                controller: _addressController,
                label: 'Adresse',
                hint: 'Ex: Bamako, Mali',
                icon: Icons.location_on_outlined,
              ),
              const SizedBox(height: 24),

              _buildSectionTitle(context, 'Devise'),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: AppColors.card(context),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border(context)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _currency,
                    isExpanded: true,
                    dropdownColor: AppColors.card(context),
                    style: TextStyle(color: AppColors.text(context)),
                    items: ShopSettings.availableCurrencies.map((c) {
                      return DropdownMenuItem(
                        value: c['code'],
                        child: Text(c['label']!),
                      );
                    }).toList(),
                    onChanged: (v) => setState(() => _currency = v!),
                  ),
                ),
              ),
              const SizedBox(height: 24),

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
                        'Aperçu : 15 000 $_currency',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.green(context),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              _buildSectionTitle(context, 'Apparence'),
              const SizedBox(height: 12),

              ListenableBuilder(
                listenable: ThemeService.instance,
                builder: (context, _) {
                  return Container(
                    decoration: BoxDecoration(
                      color: AppColors.card(context),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border(context)),
                    ),
                    child: SwitchListTile(
                      value: ThemeService.instance.isDarkMode,
                      onChanged: (value) async {
                        await ThemeService.instance.toggleDarkMode(value);
                      },
                      title: Row(
                        children: [
                          Icon(
                            ThemeService.instance.isDarkMode
                                ? Icons.dark_mode
                                : Icons.light_mode,
                            color: AppColors.green(context),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Mode sombre',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppColors.text(context),
                            ),
                          ),
                        ],
                      ),
                      subtitle: Text(
                        ThemeService.instance.isDarkMode
                            ? 'Activé'
                            : 'Désactivé',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSec(context),
                        ),
                      ),
                      activeColor: AppColors.green(context),
                    ),
                  );
                },
              ),
              const SizedBox(height: 32),

              ElevatedButton.icon(
                onPressed: _isSaving ? null : _save,
                icon: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(_isSaving ? 'Enregistrement...' : 'Enregistrer'),
              ),
              const SizedBox(height: 12),

              OutlinedButton.icon(
                onPressed: _testNotifications,
                icon: const Icon(Icons.notifications_active),
                label: const Text('Tester les notifications'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  side: BorderSide(color: AppColors.green(context)),
                  foregroundColor: AppColors.green(context),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
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

  Widget _buildTextField({
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
      ),
    );
  }
}
