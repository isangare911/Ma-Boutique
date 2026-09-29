import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/services/shop_user_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/models/shop_user.dart';

class AddUserScreen extends StatefulWidget {
  const AddUserScreen({super.key});

  @override
  State<AddUserScreen> createState() => _AddUserScreenState();
}

class _AddUserScreenState extends State<AddUserScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _passwordController = TextEditingController();

  String _selectedRole = ShopUserRole.seller;
  bool _obscurePassword = true;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void dispose() {
    _phoneController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════
  // SAUVEGARDER
  // ═══════════════════════════════════════════════════════════
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    final result = await ShopUserService.instance.addUser(
      phone: _phoneController.text.trim(),
      role: _selectedRole,
      firstName: _firstNameController.text.trim(),
      lastName: _lastNameController.text.trim(),
      password:
          _passwordController.text.isEmpty ? null : _passwordController.text,
    );

    if (!mounted) return;

    if (result['success'] == true) {
      final generatedPassword = result['generated_password'] as String?;

      if (generatedPassword != null) {
        // ⚡ Afficher le mot de passe généré dans un dialog
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                Icon(
                  Icons.check_circle,
                  color: AppColors.successTheme(context),
                ),
                const SizedBox(width: 8),
                const Text('Utilisateur créé'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_firstNameController.text.trim()} a été ajouté comme ${ShopUserRole.getLabel(_selectedRole)}.',
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.warningTheme(context).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.warningTheme(context).withOpacity(0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '⚠️ Mot de passe temporaire',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.warningTheme(context),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Ce mot de passe ne sera plus jamais affiché. '
                        'Transmettez-le maintenant à l\'employé.',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.text(context),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.card(context),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.border(context)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: SelectableText(
                                generatedPassword,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'monospace',
                                  color: AppColors.text(context),
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.copy, size: 18),
                              tooltip: 'Copier',
                              onPressed: () {
                                Clipboard.setData(
                                  ClipboardData(text: generatedPassword),
                                );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('✓ Mot de passe copié'),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('J\'ai noté le mot de passe'),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✓ ${_firstNameController.text.trim()} ajouté comme ${ShopUserRole.getLabel(_selectedRole)}',
            ),
            backgroundColor: AppColors.successTheme(context),
          ),
        );
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } else {
      setState(() {
        _isSaving = false;
        _errorMessage = result['error'] as String? ?? 'Erreur lors de l\'ajout';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar: AppBar(
        title: const Text('Ajouter un utilisateur'),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ═══════════════════════════════════════════════════
              // INFO CARD
              // ═══════════════════════════════════════════════════
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.greenLight(context),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: AppColors.green(context),
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'L\'utilisateur se connectera avec son propre numéro de téléphone. '
                        'Un mot de passe temporaire lui sera attribué s\'il n\'a pas de compte.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.text(context),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ═══════════════════════════════════════════════════
              // SECTION 1 : INFORMATIONS
              // ═══════════════════════════════════════════════════
              _buildSectionTitle('Informations personnelles'),
              const SizedBox(height: 12),

              // Prénom
              _buildTextField(
                controller: _firstNameController,
                label: 'Prénom *',
                hint: 'Ex: Moussa',
                icon: Icons.person_outline,
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Champ obligatoire' : null,
              ),
              const SizedBox(height: 12),

              // Nom
              _buildTextField(
                controller: _lastNameController,
                label: 'Nom',
                hint: 'Ex: Diarra',
                icon: Icons.person_outline,
              ),
              const SizedBox(height: 12),

              // Téléphone
              _buildTextField(
                controller: _phoneController,
                label: 'Téléphone *',
                hint: '+223 70 12 34 56',
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Champ obligatoire';
                  }
                  if (!v.trim().startsWith('+')) {
                    return 'Le numéro doit commencer par +';
                  }
                  if (v.trim().length < 10) {
                    return 'Numéro trop court';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // ═══════════════════════════════════════════════════
              // SECTION 2 : RÔLE
              // ═══════════════════════════════════════════════════
              _buildSectionTitle('Rôle dans la boutique'),
              const SizedBox(height: 12),

              // Cartes de rôle
              ...ShopUserRole.assignable.map((role) {
                final isSelected = _selectedRole == role;
                final roleColor = _getRoleColor(role);

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedRole = role;
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? roleColor.withOpacity(0.1)
                          : AppColors.card(context),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color:
                            isSelected ? roleColor : AppColors.border(context),
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: roleColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            _getRoleIcon(role),
                            color: roleColor,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                ShopUserRole.getLabel(role),
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.text(context),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                ShopUserRole.getDescription(role),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSec(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          isSelected
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                          color: isSelected
                              ? roleColor
                              : AppColors.textSec(context),
                          size: 22,
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),

              const SizedBox(height: 12),

              // ═══════════════════════════════════════════════════
              // SECTION 3 : MOT DE PASSE (optionnel)
              // ═══════════════════════════════════════════════════
              _buildSectionTitle('Mot de passe (optionnel)'),
              const SizedBox(height: 8),
              Text(
                'Laissez vide pour générer un mot de passe temporaire',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSec(context),
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 12),

              _buildTextField(
                controller: _passwordController,
                label: 'Mot de passe',
                hint: '••••••••',
                icon: Icons.lock_outline,
                isPassword: _obscurePassword,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                    color: AppColors.textSec(context),
                  ),
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                ),
                validator: (v) {
                  if (v != null && v.isNotEmpty && v.length < 6) {
                    return 'Minimum 6 caractères';
                  }
                  return null;
                },
              ),

              // ═══════════════════════════════════════════════════
              // ERREUR
              // ═══════════════════════════════════════════════════
              if (_errorMessage != null) ...[
                const SizedBox(height: 20),
                Container(
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
                      Icon(
                        Icons.error_outline,
                        color: AppColors.dangerTheme(context),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(
                            color: AppColors.dangerTheme(context),
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 32),

              // ═══════════════════════════════════════════════════
              // BOUTON SAUVEGARDER
              // ═══════════════════════════════════════════════════
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
                    : const Icon(Icons.person_add),
                label: Text(
                  _isSaving ? 'Ajout en cours...' : 'Ajouter l\'utilisateur',
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // WIDGETS
  // ═══════════════════════════════════════════════════════════
  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 15,
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
    bool isPassword = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: isPassword,
      style: TextStyle(color: AppColors.text(context)),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
        suffixIcon: suffixIcon,
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
      validator: validator,
    );
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case ShopUserRole.manager:
        return Colors.blue;
      case ShopUserRole.seller:
        return Colors.orange;
      case ShopUserRole.accountant:
        return Colors.purple;
      default:
        return AppColors.green(context);
    }
  }

  IconData _getRoleIcon(String role) {
    switch (role) {
      case ShopUserRole.manager:
        return Icons.manage_accounts;
      case ShopUserRole.seller:
        return Icons.point_of_sale;
      case ShopUserRole.accountant:
        return Icons.calculate;
      default:
        return Icons.person;
    }
  }
}
