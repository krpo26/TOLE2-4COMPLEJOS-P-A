import 'package:uuid/uuid.dart';

import '../models/audit_log.dart';
import 'auth_service.dart';
import 'database_helper.dart';

/// Registra en `audit_log` quién hizo qué cambio y cuándo. Se llama
/// desde los providers después de cada alta/edición/archivado/baja
/// definitiva. Nunca interrumpe la operación principal si falla (por
/// ejemplo, no tener usuario logueado en algún caso raro): la
/// auditoría es un registro adicional, no un requisito para operar.
class AuditService {
  static Future<void> log({
    required String action,
    required String entityType,
    required String entityLabel,
  }) async {
    try {
      final user = await AuthService.instance.currentUser();
      await DatabaseHelper.instance.insertAuditLog(
        AuditLog(
          id: const Uuid().v4(),
          timestamp: DateTime.now(),
          username: user?.username ?? 'desconocido',
          action: action,
          entityType: entityType,
          entityLabel: entityLabel,
        ),
      );
    } catch (_) {
      // Nunca debe romper la operación principal por un fallo acá.
    }
  }
}
