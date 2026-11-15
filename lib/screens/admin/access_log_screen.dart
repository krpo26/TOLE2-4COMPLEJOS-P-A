import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/audit_log.dart';
import '../../providers/auth_provider.dart';
import '../../services/database_helper.dart';

/// Últimos ingresos de cada usuario a la app. Sale del historial de
/// movimientos (que se sincroniza entre celulares), así que el
/// administrador ve los ingresos hechos desde cualquier dispositivo.
class AccessLogScreen extends StatefulWidget {
  const AccessLogScreen({super.key});

  @override
  State<AccessLogScreen> createState() => _AccessLogScreenState();
}

class _AccessLogScreenState extends State<AccessLogScreen> {
  late Future<Map<String, List<AuditLog>>> _future;
  final _fmt = DateFormat('dd/MM/yyyy HH:mm');

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Map<String, List<AuditLog>>> _load() async {
    final logs = await DatabaseHelper.instance.getAuditLogs(limit: 10000);
    final byUser = <String, List<AuditLog>>{};
    for (final l in logs.where((l) => l.entityType == kAccessEntityType)) {
      byUser.putIfAbsent(l.username, () => []).add(l);
    }
    for (final list in byUser.values) {
      list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    }
    return byUser;
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Últimos ingresos')),
      body: FutureBuilder<Map<String, List<AuditLog>>>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final byUser = snapshot.data!;
          if (byUser.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Todavía no hay ingresos registrados. Se empiezan a '
                  'anotar desde que se instala esta versión de la app.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            );
          }
          final users = byUser.keys.toList()
            ..sort((a, b) => byUser[b]!.first.timestamp
                .compareTo(byUser[a]!.first.timestamp));
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(12),
              itemCount: users.length,
              itemBuilder: (context, i) {
                final name = users[i];
                final list = byUser[name]!;
                return Card(
                  child: ExpansionTile(
                    leading: const CircleAvatar(child: Icon(Icons.person)),
                    title: Text(name,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                        'Último ingreso: ${_fmt.format(list.first.timestamp)}'),
                    children: [
                      for (final l in list.take(15))
                        ListTile(
                          dense: true,
                          leading: const Icon(Icons.login, size: 18),
                          title: Text(_fmt.format(l.timestamp)),
                        ),
                      if (list.length > 15)
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(
                            'y ${list.length - 15} ingresos anteriores',
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
