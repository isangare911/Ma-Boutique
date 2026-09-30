import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/services/auth_service.dart';
import '../../../../core/services/shop_settings_service.dart';
import '../../../../core/services/subscription_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../navigation/presentation/pages/main_navigation_screen.dart';

class OtpScreen extends StatefulWidget {
  final String phoneNumber;
  const OtpScreen({super.key, required this.phoneNumber});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  static const int _otpLength = 6;
  final List<TextEditingController> _controllers =
      List.generate(_otpLength, (_) => TextEditingController());
  final List<FocusNode> _focusNodes =
      List.generate(_otpLength, (_) => FocusNode());

  String? _verificationId;
  bool _isSending = false;
  bool _isVerifying = false;
  String? _errorMessage;
  int _resendCountdown = 45;
  bool _canResend = false;

  @override
  void initState() {
    super.initState();
    _sendOTP();
    _startCountdown();
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════
  // ENVOYER L'OTP VIA FIREBASE
  // ═══════════════════════════════════════════════════════════
  Future<void> _sendOTP() async {
    setState(() {
      _isSending = true;
      _errorMessage = null;
    });

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: widget.phoneNumber,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (PhoneAuthCredential credential) async {
          debugPrint('✓ Auto-vérification Firebase');
          await _signInWithCredential(credential);
        },
        verificationFailed: (FirebaseAuthException e) {
          // ⚡ Ne pas logger e.message (peut contenir des infos)
          debugPrint('❌ Erreur Firebase auth');
          if (mounted) {
            setState(() {
              _isSending = false;
              _errorMessage = _translateError(e.code);
            });
          }
        },
        codeSent: (String verificationId, int? resendToken) {
          // ⚡ Ne pas logger verificationId
          debugPrint('✓ OTP envoyé');
          if (mounted) {
            setState(() {
              _verificationId = verificationId;
              _isSending = false;
            });
          }
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          debugPrint('⏱ Auto-retrieval timeout');
          _verificationId = verificationId;
        },
      );
    } catch (e) {
      // ⚡ Logger l'exception générique sans le contenu
      debugPrint('❌ Exception envoi OTP');
      if (mounted) {
        setState(() {
          _isSending = false;
          _errorMessage = 'Erreur d\'envoi du code';
        });
      }
    }
  }

  String _translateError(String code) {
    switch (code) {
      case 'invalid-phone-number':
        return 'Numéro de téléphone invalide';
      case 'too-many-requests':
        return 'Trop de tentatives. Réessayez plus tard.';
      case 'quota-exceeded':
        return 'Quota SMS dépassé';
      case 'app-not-authorized':
        return 'Application non autorisée';
      default:
        return 'Erreur: $code';
    }
  }

  // ═══════════════════════════════════════════════════════════
  // VÉRIFIER LE CODE
  // ═══════════════════════════════════════════════════════════
  Future<void> _verifyOTP() async {
    final code = _controllers.map((c) => c.text).join();

    if (code.length != _otpLength) {
      setState(() => _errorMessage = 'Entrez les 6 chiffres');
      return;
    }

    if (_verificationId == null) {
      setState(() => _errorMessage = 'Veuillez renvoyer le code');
      return;
    }

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: code,
      );

      await _signInWithCredential(credential);
    } catch (e) {
      debugPrint('❌ Erreur vérification OTP');
      if (mounted) {
        setState(() {
          _isVerifying = false;
          _errorMessage = 'Code incorrect. Réessayez.';
        });
      }
    }
  }

  Future<void> _signInWithCredential(PhoneAuthCredential credential) async {
    try {
      final userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);

      debugPrint('✓ Firebase auth OK');
      await ShopSettingsService.instance.reload();

      await AuthService.instance.markDeviceAsVerified(widget.phoneNumber);

      await SubscriptionService.instance.refreshSubscription();

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => const MainNavigationScreen(),
          ),
          (route) => false,
        );
      }
    } catch (e) {
      debugPrint('❌ Erreur signInWithCredential');
      if (mounted) {
        setState(() {
          _isVerifying = false;
          _errorMessage = 'Erreur d\'authentification';
        });
      }
    }
  }

  // ═══════════════════════════════════════════════════════════
  // COMPTE À REBOURS POUR RENVOYER
  // ═══════════════════════════════════════════════════════════
  void _startCountdown() {
    _resendCountdown = 45;
    _canResend = false;

    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() {
        _resendCountdown--;
        if (_resendCountdown <= 0) {
          _canResend = true;
        }
      });
      return _resendCountdown > 0;
    });
  }

  Future<void> _resendOTP() async {
    if (!_canResend) return;

    for (var c in _controllers) {
      c.clear();
    }

    await _sendOTP();
    _startCountdown();
  }

  // ═══════════════════════════════════════════════════════════
  // GESTION DES CHAMPS OTP
  // ═══════════════════════════════════════════════════════════
  void _onChanged(String value, int index) {
    if (value.length == 1 && index < _otpLength - 1) {
      _focusNodes[index + 1].requestFocus();
    }
    if (_controllers.every((c) => c.text.isNotEmpty)) {
      _verifyOTP();
    }
  }

  void _onKeyEvent(KeyEvent event, int index) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        _controllers[index].text.isEmpty &&
        index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.text(context)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              Text(
                'Vérification',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.text(context),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Entrez le code envoyé au ${widget.phoneNumber}',
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.textSec(context),
                ),
              ),
              const SizedBox(height: 32),
              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
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
              if (_isSending)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        CircularProgressIndicator(
                          color: AppColors.green(context),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Envoi du code...',
                          style: TextStyle(
                            color: AppColors.textSec(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(
                    _otpLength,
                    (index) => SizedBox(
                      width: 48,
                      height: 56,
                      child: KeyboardListener(
                        focusNode: FocusNode(),
                        onKeyEvent: (event) => _onKeyEvent(event, index),
                        child: TextFormField(
                          controller: _controllers[index],
                          focusNode: _focusNodes[index],
                          textAlign: TextAlign.center,
                          keyboardType: TextInputType.number,
                          maxLength: 1,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: AppColors.text(context),
                          ),
                          decoration: InputDecoration(
                            counterText: '',
                            filled: true,
                            fillColor: AppColors.card(context),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: AppColors.border(context),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: AppColors.green(context),
                                width: 2,
                              ),
                            ),
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          // ⚡ AJOUT : validator simple pour OTP
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return '';
                            }
                            if (!RegExp(r'^\d$').hasMatch(value)) {
                              return '';
                            }
                            return null;
                          },
                          onChanged: (value) => _onChanged(value, index),
                        ),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 32),
              if (!_isSending)
                Center(
                  child: Column(
                    children: [
                      if (_canResend)
                        TextButton.icon(
                          onPressed: _resendOTP,
                          icon: Icon(Icons.refresh,
                              color: AppColors.green(context)),
                          label: Text(
                            'Renvoyer le code',
                            style: TextStyle(color: AppColors.green(context)),
                          ),
                        )
                      else
                        Text(
                          'Renvoyer dans $_resendCountdown s',
                          style: TextStyle(
                            color: AppColors.textSec(context),
                            fontSize: 14,
                          ),
                        ),
                    ],
                  ),
                ),
              const Spacer(),
              if (!_isSending)
                ElevatedButton(
                  onPressed: _isVerifying ? null : _verifyOTP,
                  child: _isVerifying
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.onGreen(context),
                          ),
                        )
                      : const Text('Vérifier'),
                ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
