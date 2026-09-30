import 'package:flutter/material.dart';

import '../../../../core/services/auth_service.dart';
import '../../../../core/services/shop_settings_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../navigation/presentation/pages/main_navigation_screen.dart';

class ChangePasswordScreen extends StatefulWidget {
  /// Si true, c'est un changement obligatoire (après login avec MDP temporaire).
  /// L'ancien mot de passe ne sera PAS demandé.
  final bool isForced;

  const ChangePasswordScreen({super.key, this.isForced = false});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscureOld = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void dispose() {
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    final result = await AuthService.instance.changePassword(
      oldPassword: widget.isForced ? null : _oldPasswordController.text.trim(),
      newPassword: _newPasswordController.text,
    );

    if (!mounted) return;

    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('✓ Mot de passe modifié avec succès'),
          backgroundColor: AppColors.successTheme(context),
        ),
      );

      // ⚡ Recharger les settings après changement de mot de passe
      await ShopSettingsService.instance.reload();

      // ⚡ Si c'était forcé → aller au Dashboard
      if (widget.isForced) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => const MainNavigationScreen(),
          ),
          (route) => false,
        );
      } else {
        Navigator.pop(context, true);
      }
    } else {
      setState(() {
        _isSaving = false;
        _errorMessage = result['error'] as String? ?? 'Erreur inconnue';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar: AppBar(
        title: Text(
          widget.isForced
              ? 'Changer votre mot de passe'
              : 'Modifier le mot de passe',
        ),
        automaticallyImplyLeading: !widget.isForced,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ⚡ Bandeau info si forcé
              if (widget.isForced) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.warningTheme(context).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.warningTheme(context).withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: AppColors.warningTheme(context),
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Votre mot de passe est temporaire. '
                          'Pour des raisons de sécurité, vous devez le changer '
                          'avant de continuer.',
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
              ],

              // Champ ancien mot de passe (seulement si NON forcé)
              if (!widget.isForced) ...[
                _buildLabel('Ancien mot de passe'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _oldPasswordController,
                  obscureText: _obscureOld,
                  style: TextStyle(color: AppColors.text(context)),
                  decoration: _buildInputDecoration(
                    hint: '••••••••',
                    icon: Icons.lock_outline,
                    suffix: IconButton(
                      icon: Icon(
                        _obscureOld ? Icons.visibility_off : Icons.visibility,
                        color: AppColors.textSec(context),
                      ),
                      onPressed: () =>
                          setState(() => _obscureOld = !_obscureOld),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Champ obligatoire';
                    return null;
                  },
                ),
                const SizedBox(height: 20),
              ],

              // Nouveau mot de passe
              _buildLabel('Nouveau mot de passe'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _newPasswordController,
                obscureText: _obscureNew,
                style: TextStyle(color: AppColors.text(context)),
                decoration: _buildInputDecoration(
                  hint: 'Minimum 6 caractères',
                  icon: Icons.lock_reset,
                  suffix: IconButton(
                    icon: Icon(
                      _obscureNew ? Icons.visibility_off : Icons.visibility,
                      color: AppColors.textSec(context),
                    ),
                    onPressed: () => setState(() => _obscureNew = !_obscureNew),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Champ obligatoire';
                  if (v.length < 6) return 'Minimum 6 caractères';
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Confirmation
              _buildLabel('Confirmer le nouveau mot de passe'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _confirmPasswordController,
                obscureText: _obscureConfirm,
                style: TextStyle(color: AppColors.text(context)),
                decoration: _buildInputDecoration(
                  hint: '••••••••',
                  icon: Icons.lock_outline,
                  suffix: IconButton(
                    icon: Icon(
                      _obscureConfirm ? Icons.visibility_off : Icons.visibility,
                      color: AppColors.textSec(context),
                    ),
                    onPressed: () =>
                        setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Champ obligatoire';
                  if (v != _newPasswordController.text) {
                    return 'Les mots de passe ne correspondent pas';
                  }
                  return null;
                },
              ),

              // Erreur
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

              // Bouton
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
                    : const Icon(Icons.check),
                label: Text(
                  _isSaving ? 'Enregistrement...' : 'Valider',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.text(context),
      ),
    );
  }

  InputDecoration _buildInputDecoration({
    required String hint,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon),
      suffixIcon: suffix,
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
    );
  }
}
