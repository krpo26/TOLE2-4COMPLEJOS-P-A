import 'dart:async';

import 'package:flutter/foundation.dart';

import '../services/connectivity_service.dart';
import '../services/sync_service.dart';

class SyncProvider extends ChangeNotifier {
  bool isOnline = false;
  bool isSyncing = false;
  StreamSubscription<bool>? _subscription;
  void Function()? _onSynced;

  bool get isCloudEnabled => SyncService.instance.isCloudEnabled;
  DateTime? get lastSyncedAt => SyncService.instance.lastSyncedAt;

  /// [onSynced] se llama después de cada sincronización exitosa, para
  /// que la UI recargue vehículos/choferes con lo que vino de la nube.
  Future<void> start({void Function()? onSynced}) async {
    _onSynced = onSynced;
    isOnline = await ConnectivityService.instance.isOnline;
    notifyListeners();

    if (isOnline) await syncNow();

    _subscription =
        ConnectivityService.instance.onStatusChange.listen((online) async {
      final reconnected = online && !isOnline;
      isOnline = online;
      notifyListeners();
      if (reconnected) await syncNow();
    });
  }

  Future<void> syncNow() async {
    if (!SyncService.instance.isCloudEnabled) return;
    isSyncing = true;
    notifyListeners();

    await SyncService.instance.syncAll();

    isSyncing = false;
    notifyListeners();
    _onSynced?.call();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
