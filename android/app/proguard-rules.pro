# ═══════════════════════════════════════════════════════════
# Règles ProGuard pour Flutter
# ═══════════════════════════════════════════════════════════

# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Firebase Auth
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }

# Sqflite
-keep class com.tekartik.sqflite.** { *; }

# flutter_secure_storage
-keep class com.it_nomads.fluttersecurestorage.** { *; }

# flutter_local_notifications
-keep class com.dexterous.** { *; }

# Modèles JSON (si tu as des toJson/fromJson manuels)
-keep class com.example.boutique.** { *; }

# Ne pas obfusquer les classes avec des SerializedNames GSON
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes InnerClasses
-keepattributes EnclosingMethod

# Éviter les warnings sur les libs optionnelles
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn retrofit2.**
-dontwarn javax.annotation.**