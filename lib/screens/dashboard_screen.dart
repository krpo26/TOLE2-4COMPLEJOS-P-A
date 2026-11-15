import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/complex.dart';
import '../models/fuel_station.dart';
import '../services/fuel_station_service.dart';
import '../providers/appearance_provider.dart';
import '../models/driver.dart';
import '../models/vehicle.dart';
import '../providers/auth_provider.dart';
import '../providers/driver_provider.dart';
import '../providers/feature_flags_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/sync_provider.dart';
import '../providers/vehicle_provider.dart';
import '../services/pdf_report_service.dart';
import '../services/sync_service.dart';
import '../widgets/entity_icons.dart';
import '../widgets/stat_card.dart';
import '../widgets/status_badge.dart';
import 'drivers/driver_list_screen.dart';
import 'settings_screen.dart';
import '../providers/tramite_provider.dart';
import 'admin/manage_records_screen.dart';
import 'tramites/tramites_screen.dart';
import 'vehicles/fuel_stations_screen.dart';
import 'vehicles/vehicle_list_screen.dart';

class DashboardScreen extends StatelessWidget {
  final Complex complex;
  const DashboardScreen({super.key, required this.complex});

  @override
  Widget build(BuildContext context) {
    final vehicleProvider = context.watch<VehicleProvider>();
    final driverProvider = context.watch<DriverProvider>();
    final authProvider = context.watch<AuthProvider>();
    final syncProvider = context.watch<SyncProvider>();
    final settingsProvider = context.watch<SettingsProvider>();
    final flags = context.watch<FeatureFlagsProvider>();
    final isGod = authProvider.isGod;
    // El admin siempre ve todo; a los usuarios comunes se les respeta
    // lo que el admin haya configurado en "Pestañas visibles".
    bool canSee(String key) => isGod || flags.isEnabled(key);

    final criticalVehicles =
        canSee('tab_vehicles') ? vehicleProvider.criticalVehicles : <Vehicle>[];
    final criticalDrivers =
        canSee('tab_drivers') ? driverProvider.criticalDrivers : <Driver>[];
    final totalCritical = criticalVehicles.length + criticalDrivers.length;

    return Scaffold(
      appBar: AppBar(
        title: Builder(builder: (ctx) {
          final logo = ctx.watch<AppearanceProvider>().logoOf(complex.id);
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (logo != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child:
                      Image.memory(logo, height: 30, width: 30, fit: BoxFit.cover),
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(complex.name,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14)),
              ),
            ],
          );
        }),
        actions: [
          IconButton(
            tooltip: 'Apariencia',
            icon: const Icon(Icons.palette_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
          if (syncProvider.isCloudEnabled)
            IconButton(
              tooltip: 'Sincronizar ahora',
              icon: syncProvider.isSyncing
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.sync),
              onPressed:
                  syncProvider.isSyncing ? null : () => syncProvider.syncNow(),
            ),
          if (isGod)
            IconButton(
              tooltip: 'Mover, descargar o borrar',
              icon: const Icon(Icons.drive_file_move_outline),
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        ManageRecordsScreen(initialComplexId: complex.id),
                  ),
                );
                await vehicleProvider.load();
                await driverProvider.load();
                if (context.mounted) {
                  await context.read<TramiteProvider>().load();
                }
              },
            ),
          if (canSee('export_pdf'))
            IconButton(
              tooltip: 'Exportar reporte PDF',
              icon: const Icon(Icons.picture_as_pdf_outlined),
              onPressed: () => PdfReportService.generateAndShare(
                vehicles: vehicleProvider.vehicles,
                drivers: driverProvider.drivers,
                complexName: complex.name,
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await vehicleProvider.load();
          await driverProvider.load();
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _SyncStatusBanner(syncProvider: syncProvider),
            const SizedBox(height: 12),
            Row(
              children: [
                if (canSee('tab_vehicles'))
                  Expanded(
                    child: StatCard(
                      title: 'Vehículos',
                      value: '${vehicleProvider.vehicles.length}',
                      icon: resolveEntityIcon(kSectionIconChoices,
                          settingsProvider.vehiclesSectionIconKey,
                          Icons.local_shipping),
                      color: Colors.blue,
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const VehicleListScreen())),
                      onEditIcon: !isGod
                          ? null
                          : () async {
                              final picked = await pickIconDialog(
                                context,
                                title: 'Ícono de Vehículos',
                                choices: kSectionIconChoices,
                                current: settingsProvider.vehiclesSectionIconKey,
                                color: Colors.blue,
                              );
                              if (picked != null) {
                                settingsProvider.setVehiclesSectionIcon(picked);
                              }
                            },
                    ),
                  ),
                if (canSee('tab_vehicles') && canSee('tab_drivers'))
                  const SizedBox(width: 12),
                if (canSee('tab_drivers'))
                  Expanded(
                    child: StatCard(
                      title: 'Choferes',
                      value: '${driverProvider.drivers.length}',
                      icon: resolveEntityIcon(kSectionIconChoices,
                          settingsProvider.driversSectionIconKey, Icons.person),
                      color: Colors.indigo,
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const DriverListScreen())),
                      onEditIcon: !isGod
                          ? null
                          : () async {
                              final picked = await pickIconDialog(
                                context,
                                title: 'Ícono de Choferes',
                                choices: kSectionIconChoices,
                                current: settingsProvider.driversSectionIconKey,
                                color: Colors.indigo,
                              );
                              if (picked != null) {
                                settingsProvider.setDriversSectionIcon(picked);
                              }
                            },
                    ),
                  ),
              ],
            ),
            if (canSee('tab_tramites')) ...[
              const SizedBox(height: 12),
              Builder(builder: (ctx) {
                final tramiteProvider = ctx.watch<TramiteProvider>();
                return StatCard(
                  title: 'Trámites en curso',
                  value: '${tramiteProvider.openCount}',
                  icon: Icons.assignment_outlined,
                  color: Colors.deepPurple,
                  onTap: () => Navigator.push(
                    ctx,
                    MaterialPageRoute(
                        builder: (_) => TramitesScreen(complex: complex)),
                  ),
                );
              }),
            ],
            if (canSee('tab_stations')) ...[
              const SizedBox(height: 12),
              FutureBuilder<List<FuelStation>>(
                future: FuelStationService.instance.loadAll(),
                builder: (context, snap) {
                  final count = (snap.data ?? const <FuelStation>[])
                      .where((s) => s.province == 'TUCUMAN')
                      .length;
                  return StatCard(
                    title: 'Estaciones de servicio',
                    value: snap.hasData ? '$count' : '…',
                    icon: Icons.local_gas_station_outlined,
                    color: Colors.teal,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const FuelStationsScreen()),
                    ),
                  );
                },
              ),
            ],
            const SizedBox(height: 12),
            StatCard(
              title: 'Alertas críticas',
              value: '$totalCritical',
              icon: Icons.warning_amber_rounded,
              color: totalCritical > 0 ? Colors.red : Colors.green,
            ),
            const SizedBox(height: 24),
            const Text('Alertas críticas',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (totalCritical == 0)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text('Sin alertas. Todo en orden ✅',
                      style: TextStyle(color: Colors.grey)),
                ),
              )
            else ...[
              ...criticalVehicles.map((v) => _VehicleAlertTile(vehicle: v)),
              ...criticalDrivers.map((d) => _DriverAlertTile(driver: d)),
            ],
          ],
        ),
      ),
    );
  }
}

class _VehicleAlertTile extends StatelessWidget {
  final Vehicle vehicle;
  const _VehicleAlertTile({required this.vehicle});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.build_circle_outlined),
        title: Text('${vehicle.internalNumber} · ${vehicle.plate}'),
        subtitle: Text(vehicle.kmRemaining <= 0
            ? 'Service superado por ${-vehicle.kmRemaining} km'
            : 'Faltan ${vehicle.kmRemaining} km para el service'),
        trailing: StatusBadge.forMaintenance(vehicle.maintenanceStatus),
      ),
    );
  }
}

class _DriverAlertTile extends StatelessWidget {
  final Driver driver;
  const _DriverAlertTile({required this.driver});

  @override
  Widget build(BuildContext context) {
    final days = driver.daysToLicenseExpiration;
    return Card(
      child: ListTile(
        leading: const Icon(Icons.badge_outlined),
        title: Text(driver.fullName),
        subtitle: Text(days < 0
            ? 'Carnet vencido hace ${-days} días'
            : 'Carnet vence en $days días'),
        trailing: StatusBadge.forLicense(driver.licenseStatus),
      ),
    );
  }
}

/// Chip informativo: muestra si la app está online/offline y, si la
/// nube está configurada, cuándo fue la última sincronización. La
/// app funciona igual de bien en cualquiera de los dos estados.
class _SyncStatusBanner extends StatelessWidget {
  final SyncProvider syncProvider;
  const _SyncStatusBanner({required this.syncProvider});

  @override
  Widget build(BuildContext context) {
    if (!syncProvider.isCloudEnabled) {
      final error = SyncService.instance.lastInitError;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.storage, size: 18, color: Colors.grey),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Modo offline (base local). La sincronización en la nube no está configurada.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
              ],
            ),
            if (error != null) ...[
              const SizedBox(height: 4),
              SelectableText(
                'Diagnóstico: $error',
                style: const TextStyle(fontSize: 10, color: Colors.redAccent),
              ),
            ],
          ],
        ),
      );
    }

    final online = syncProvider.isOnline;
    final color = online ? Colors.green : Colors.orange;
    final lastSync = syncProvider.lastSyncedAt;
    final syncText = syncProvider.isSyncing
        ? 'Sincronizando...'
        : (lastSync != null
            ? 'Última sincronización: ${TimeOfDay.fromDateTime(lastSync).format(context)}'
            : 'Sin sincronizar todavía');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(online ? Icons.cloud_done_outlined : Icons.cloud_off_outlined,
              size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${online ? 'En línea' : 'Sin conexión (modo offline)'} · $syncText',
              style: TextStyle(fontSize: 12, color: color),
            ),
          ),
        ],
      ),
    );
  }
}
