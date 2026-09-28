import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  static final ConnectivityService instance = ConnectivityService._();
  ConnectivityService._();

  final Connectivity _connectivity = Connectivity();
  final StreamController<bool> _connectionController =
      StreamController<bool>.broadcast();

  Stream<bool> get connectionStream => _connectionController.stream;

  bool _isConnected = false;
  bool get isConnected => _isConnected;

  /// Initialise le service et démarre l'écoute
  Future<void> initialize() async {
    // Vérifier l'état initial
    final result = await _connectivity.checkConnectivity();
    _isConnected = _hasConnection(result);
    _connectionController.add(_isConnected);

    // Écouter les changements
    _connectivity.onConnectivityChanged.listen((result) {
      final connected = _hasConnection(result);
      if (connected != _isConnected) {
        _isConnected = connected;
        _connectionController.add(connected);
      }
    });
  }

  bool _hasConnection(List<ConnectivityResult> results) {
    return results.any((r) =>
        r == ConnectivityResult.wifi ||
        r == ConnectivityResult.mobile ||
        r == ConnectivityResult.ethernet);
  }

  /// Vérifie manuellement la connexion
  Future<bool> checkConnection() async {
    final result = await _connectivity.checkConnectivity();
    _isConnected = _hasConnection(result);
    return _isConnected;
  }

  void dispose() {
    _connectionController.close();
  }
}
