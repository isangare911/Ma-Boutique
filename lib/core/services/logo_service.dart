import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

class LogoService {
  static final LogoService instance = LogoService._();
  LogoService._();

  final ImagePicker _picker = ImagePicker();

  /// Choisir une image depuis la galerie
  Future<String?> pickImageFromGallery() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      if (pickedFile == null) return null;
      return await _saveImageLocally(pickedFile);
    } catch (e) {
      debugPrint('Erreur pickImageFromGallery: $e');
      return null;
    }
  }

  /// Prendre une photo depuis la caméra
  Future<String?> pickImageFromCamera() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      if (pickedFile == null) return null;
      return await _saveImageLocally(pickedFile);
    } catch (e) {
      debugPrint('Erreur pickImageFromCamera: $e');
      return null;
    }
  }

  /// Copier l'image dans le stockage permanent de l'app
  Future<String> _saveImageLocally(XFile file) async {
    final directory = await getApplicationDocumentsDirectory();
    final fileName = 'shop_logo_${DateTime.now().millisecondsSinceEpoch}.png';
    final savedImage = File('${directory.path}/$fileName');
    await File(file.path).copy(savedImage.path);
    debugPrint('✓ Logo sauvegardé: ${savedImage.path}');
    return savedImage.path;
  }

  /// ⚡ NOUVEAU : Supprimer un ancien logo
  Future<void> deleteLogo(String? path) async {
    if (path == null || path.isEmpty) return;
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
        debugPrint('✓ Ancien logo supprimé: $path');
      }
    } catch (e) {
      debugPrint('Erreur suppression logo: $e');
    }
  }
}
