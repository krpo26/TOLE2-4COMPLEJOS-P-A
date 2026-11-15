import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/audit_log.dart';
import '../../services/database_helper.dart';

/// Historial de quién hizo qué cambio y cuándo (altas, ediciones,
/// archivados, bajas definitivas de vehículos, choferes y usuarios).
/// Solo lo ve el usuario god. Es de solo lectura: no se puede editar
/// ni borrar nada de acá.
class AuditLogScreen extends StatefulWidget {
  const AuditLogScreen({super.key});

  @override
  State<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends State<AuditLogScreen> {
  late Future<List<AuditLog>> _future;

  @override
  void initState() {
    super.initState();
    _future = DatabaseHelper.instance.getAuditLogs();
  }

  IconData _iconFor(String entityType) {
    switch (entityType) {
      case 'Vehículo':
        return Icons.local_shipping_outlined;
      case 'Chofer':
        return Icons.person_outline;
      case 'Usuario':
        return Icons.manage_accounts_outlined;
      default:
        return Icons.history;
    }
  }

  Color _colorFor(String action) {
    if (action.contains('eliminó')) return Colors.red;
    if (action.contains('archivó')) return Colors.orange;
    if (action.contains('creó')) return Colors.green;
    return Colors.blueGrey;
  }

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('dd/MM/yyyy HH:mm');
    return Scaffold(
      appBar: AppBar(title: const Text('Auditoría')),
      body: FutureBuilder<List<AuditLog>>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final logs = snapshot.data!;
          if (logs.isEmpty) {
            return const Center(
                child: Text('Todavía no hay movimientos registrados.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: logs.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final log = logs[index];
              return ListTile(
                leading: Icon(_iconFor(log.entityType),
                    color: _colorFor(log.action)),
                title: Text.rich(TextSpan(children: [
                  TextSpan(
                      text: log.username,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  TextSpan(text: ' ${log.action} '),
                  TextSpan(
                      text: '${log.entityType.toLowerCase()} "${log.entityLabel}"'),
                ])),
                subtitle: Text(dateFmt.format(log.timestamp)),
              );
            },
          );
        },
      ),
    );
  }
}
