import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'notification_settings_screen.dart';
import 'manage_records_screen.dart';
import 'package:intl/intl.dart';

import '../../services/backup_service.dart';
import '../../services/notification_service.dart';
import '../../services/sync_service.dart';
import 'access_log_screen.dart';
import 'audit_log_screen.dart';
import 'feature_flags_screen.dart';

/// Panel de administración avanzada. Solo llega acá el usuario god
/// (el botón que la abre está oculto para usuarios comunes).
///
/// Desde acá se configura:
/// - Cada cuánto se repite la alerta sonora de vencimientos mientras
///   haya algo pendiente (service próximo/vencido, carnet próximo a
///   vencer o vencido).
/// - El respaldo de la base de datos: ver cuándo fue el último
///   (automático, cada 3 horas, corre solo en segundo plano), forzar
///   uno manual ahora mismo, y restaurar desde un archivo guardado.
class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  int _intervalMinutes = NotificationService.kDefaultIntervalMinutes;
  DateTime? _lastBackupAt;
  bool _loading = true;
  bool _exporting = false;
  bool _restoring = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final interval = await NotificationService.instance.getAlertIntervalMinutes();
    final lastBackup = await BackupService.instance.getLastBackupAt();
    if (!mounted) return;
    setState(() {
      _intervalMinutes = interval;
      _lastBackupAt = lastBackup;
      _loading = false;
    });
  }

  String _intervalLabel(int minutes) {
    if (minutes < 60) return '$minutes minutos';
    final hours = minutes / 60;
    if (hours == hours.roundToDouble()) {
      final h = hours.round();
      return h == 1 ? '1 hora' : '$h horas';
    }
    return '${hours.toStringAsFixed(1)} horas';
  }

  Future<void> _setInterval(int minutes) async {
    setState(() => _intervalMinutes = minutes);
    await NotificationService.instance.setAlertIntervalMinutes(minutes);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content:
              Text('Alerta sonora configurada cada ${_intervalLabel(minutes)}')),
    );
  }

  Future<void> _exportNow() async {
    setState(() => _exporting = true);
    try {
      await BackupService.instance.exportAndShare();
      final lastBackup = await BackupService.instance.getLastBackupAt();
      if (!mounted) return;
      setState(() => _lastBackupAt = lastBackup);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _restoreFromFile() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Restaurar respaldo'),
        content: const Text(
          'Se van a cargar los datos del archivo elegido. No borra nada '
          'de lo que ya está cargado: si un vehículo, chofer o carga ya '
          'existe (mismo ID), se actualiza con lo del archivo; si no '
          'existe, se agrega. ¿Continuar?',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Restaurar')),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _restoring = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final bytes = result.files.first.bytes;
      if (bytes == null) return;

      final jsonStr = utf8.decode(bytes);
      await BackupService.instance.restoreFromJsonString(jsonStr);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Respaldo restaurado correctamente')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo restaurar: $e')),
      );
    } finally {
      if (mounted) setState(() => _restoring = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('dd/MM/yyyy HH:mm');
    final cloudEnabled = SyncService.instance.isCloudEnabled;

    return Scaffold(
      appBar: AppBar(title: const Text('Panel de administración')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.notifications_active_outlined),
                  title: const Text('Notificaciones: aspecto y sonido'),
                  subtitle: const Text(
                      'Color, logo, banner, audio propio y cada cuánto suena.'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const NotificationSettingsScreen()),
                  ),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.drive_file_move_outline),
                  title: const Text('Mover, descargar o borrar'),
                  subtitle: const Text(
                      'Vehículos y choferes de cualquiera de los 4 complejos.'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const ManageRecordsScreen()),
                  ),
                ),
                const Divider(),
                const SizedBox(height: 12),
                const Text('Repetición de las alertas',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                const Text(
                  'Mientras haya un service vencido/próximo o un carnet '
                  'vencido/por vencer, el celular repite la notificación '
                  'cada tanto tiempo. Elegí cada cuánto (el sonido se '
                  'regula aparte, en "Notificaciones"):',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: NotificationService.kIntervalOptionsMinutes
                      .map((minutes) => ChoiceChip(
                            label: Text(_intervalLabel(minutes)),
                            selected: _intervalMinutes == minutes,
                            onSelected: (_) => _setInterval(minutes),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 28),
                const Divider(),
                const SizedBox(height: 12),
                const Text('Respaldo de la base de datos',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                  cloudEnabled
                      ? 'Se hace un respaldo automático cada 3 horas en '
                        'segundo plano (se sube también a la nube). '
                        'También podés forzar uno manual ahora mismo.'
                      : 'Se hace un respaldo automático cada 3 horas, '
                        'guardado en este celular (la nube todavía no '
                        'está conectada, ver diagnóstico en el dashboard). '
                        'También podés forzar uno manual ahora mismo.',
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 8),
                Text(
                  _lastBackupAt == null
                      ? 'Todavía no se hizo ningún respaldo.'
                      : 'Último respaldo: ${dateFmt.format(_lastBackupAt!)}',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _exporting ? null : _exportNow,
                  icon: _exporting
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.upload_file_outlined),
                  label: const Text('Exportar respaldo ahora'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _restoring ? null : _restoreFromFile,
                  icon: _restoring
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.download_outlined),
                  label: const Text('Restaurar desde un archivo'),
                ),
                const SizedBox(height: 8),
                Text(
                  'El respaldo incluye vehículos, choferes, usuarios comunes, '
                  'mantenimiento, combustible y fichas técnicas. No incluye '
                  'las fotos en sí (quedan solo en el celular donde se '
                  'tomaron, salvo que la nube esté conectada). El usuario '
                  'god nunca se incluye en el respaldo, por seguridad.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 28),
                const Divider(),
                const SizedBox(height: 12),
                const Text('Auditoría',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                const Text(
                  'Quién creó, editó, archivó o eliminó definitivamente '
                  'cada vehículo, chofer o usuario, y cuándo.',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AuditLogScreen()),
                  ),
                  icon: const Icon(Icons.history),
                  label: const Text('Ver historial de movimientos'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AccessLogScreen()),
                  ),
                  icon: const Icon(Icons.login),
                  label: const Text('Últimos ingresos de usuarios'),
                ),
                const SizedBox(height: 28),
                const Divider(),
                const SizedBox(height: 12),
                const Text('Pestañas visibles',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                const Text(
                  'Elegí qué secciones puede ver un usuario común (vos '
                  'siempre las ves todas).',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const FeatureFlagsScreen()),
                  ),
                  icon: const Icon(Icons.visibility_outlined),
                  label: const Text('Configurar pestañas'),
                ),
              ],
            ),
    );
  }
}
