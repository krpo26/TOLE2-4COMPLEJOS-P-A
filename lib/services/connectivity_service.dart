import 'package:connectivity_plus/connectivity_plus.dart';

/// Detecta si el dispositivo tiene conexión a internet, para decidir
/// cuándo intentar sincronizar con la nube. La app NUNCA depende de
/// esto para funcionar: SQLite local cubre el 100% de las funciones
/// sin conexión.
class ConnectivityService {
  ConnectivityService._internal();
  static final ConnectivityService instance = ConnectivityService._internal();

  final _connectivity = Connectivity();

  bool _hasConnection(List<ConnectivityResult> results) =>
      results.any((r) => r != ConnectivityResult.none);

  Future<bool> get isOnline async {
    final result = await _connectivity.checkConnectivity();
    return _hasConnection(result);
  }

  Stream<bool> get onStatusChange =>
      _connectivity.onConnectivityChanged.map(_hasConnection);
}
