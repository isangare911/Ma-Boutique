import 'package:flutter/material.dart';

/// ⚡ OTP désactivé — cette fonctionnalité n'est plus utilisée.
/// Conservé pour éviter les erreurs d'import dans le code existant.
class OtpScreen extends StatelessWidget {
  final String phoneNumber;
  const OtpScreen({super.key, required this.phoneNumber});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Vérification')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Cette fonctionnalité est désactivée.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
