import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final NotificationService instance = NotificationService._();
  NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  // ═══════════════════════════════════════════════════════════
  // INITIALISATION
  // ═══════════════════════════════════════════════════════════
  Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // ⚡ Demander la permission (Android 13+)
    await _requestPermissions();

    _initialized = true;
    debugPrint('✓ NotificationService initialisé');
  }

  Future<void> _requestPermissions() async {
    final androidImpl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidImpl != null) {
      await androidImpl.requestNotificationsPermission();
    }
  }

  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('Notification tapée: ${response.payload}');
    // TODO: Naviguer vers l'écran correspondant
  }

  // ═══════════════════════════════════════════════════════════
  // AFFICHER UNE NOTIFICATION
  // ═══════════════════════════════════════════════════════════
  Future<void> show({
    required int id,
    required String title,
    required String body,
    String? payload,
    Importance importance = Importance.high, // ⚡ Type natif
  }) async {
    if (!_initialized) await initialize();

    final androidDetails = AndroidNotificationDetails(
      'ma_boutique_channel',
      'Ma Boutique',
      channelDescription: 'Notifications de gestion de boutique',
      importance: importance,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails();

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _plugin.show(id, title, body, details, payload: payload);
  }

  // ═══════════════════════════════════════════════════════════
  // NOTIFICATIONS SPÉCIFIQUES
  // ═══════════════════════════════════════════════════════════
  Future<void> showCreditDueSoon({
    required String customerName,
    required double amount,
    required int daysLeft,
    required String currency,
  }) async {
    final daysText = daysLeft == 0
        ? "aujourd'hui"
        : daysLeft == 1
            ? 'demain'
            : 'dans $daysLeft jours';

    await show(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: '⏰ Crédit à échéance',
      body: '$customerName doit $amount $currency (échéance $daysText)',
      payload: 'credit_due:$customerName',
    );
  }

  Future<void> showCreditOverdue({
    required String customerName,
    required double amount,
    required int daysLate,
    required String currency,
  }) async {
    await show(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: '🚨 Crédit en retard',
      body:
          '$customerName a $daysLate jour${daysLate > 1 ? "s" : ""} de retard ($amount $currency)',
      payload: 'credit_overdue:$customerName',
    );
  }

  Future<void> showLowStock({
    required String productName,
    required int quantity,
    required String unit,
  }) async {
    await show(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: '📦 Stock faible',
      body: '$productName : $quantity $unit restant',
      payload: 'low_stock:$productName',
    );
  }

  Future<void> showOutOfStock({
    required String productName,
  }) async {
    await show(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: '❌ Rupture de stock',
      body: '$productName est épuisé',
      payload: 'out_of_stock:$productName',
    );
  }

  /// Annuler toutes les notifications
  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }
}
