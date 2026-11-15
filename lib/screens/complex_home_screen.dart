import '../widgets/app_logo.dart';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/complex.dart';
import '../models/driver.dart';
import '../models/vehicle.dart';
import '../providers/appearance_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/tramite_provider.dart';
import '../providers/driver_provider.dart';
import '../providers/sync_provider.dart';
import '../providers/vehicle_provider.dart';
import '../services/database_helper.dart';
import '../services/notification_service.dart';
import 'admin/admin_panel_screen.dart';
import 'admin/complex_appearance_screen.dart';
import 'admin/manage_records_screen.dart';
import 'auth/login_screen.dart';
import 'dashboard_screen.dart';
import 'settings_screen.dart';
import 'users/user_management_screen.dart';

/// Pantalla principal: las 4 secciones (una por complejo
/// penitenciario). Cada una abre el mismo panel de trabajo
/// (vehículos, choferes, alertas) pero con los datos de ese
/// complejo solamente.
///
/// El administrador (god) entra a los 4. Un usuario común solo a los
/// que el admin le habilitó (los demás se ven con candado).
class ComplexHomeScreen extends StatefulWidget {
  const ComplexHomeScreen({super.key});

  @override
  State<ComplexHomeScreen> createState() => _ComplexHomeScreenState();
}

class _ComplexHomeScreenState extends State<ComplexHomeScreen> {
  // Cantidad de alertas críticas (service / carnet) de cada complejo.
  Map<String, int> _alertCounts = {};
  DateTime? _lastSeenSync;

  @override
  void initState() {
    super.initState();
    _loadCounts();
    // Al entrar se revisan las alertas de los complejos habilitados
    // para este usuario y salen las notificaciones de cada uno.
    NotificationService.instance.checkForCurrentUser();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Si terminó una sincronización con la nube, se refrescan los
    // contadores con lo que llegó.
    final synced = context.read<SyncProvider>().lastSyncedAt;
    if (synced != _lastSeenSync) {
      _lastSeenSync = synced;
      _loadCounts();
    }
  }

  Future<void> _loadCounts() async {
    final db = DatabaseHelper.instance;
    final vehicles = await db.getVehicles();
    final drivers = await db.getDrivers();
    final counts = <String, int>{};
    for (final v in vehicles) {
      if (v.maintenanceStatus != MaintenanceStatus.ok) {
        counts[v.complexId] = (counts[v.complexId] ?? 0) + 1;
      }
    }
    for (final d in drivers) {
      if (d.licenseStatus != LicenseStatus.ok) {
        counts[d.complexId] = (counts[d.complexId] ?? 0) + 1;
      }
    }
    if (!mounted) return;
    setState(() => _alertCounts = counts);
  }

  /// Color de la tarjeta: el que el admin eligió para ese complejo, o
  /// el original.
  Color _accentFor(AppearanceProvider appearance, Complex c) {
    final idx = appearance.of(c.id)?.colorIndex;
    if (idx != null && idx < kColorOptions.length) {
      return kColorOptions[idx].color;
    }
    return c.color;
  }

  Future<void> _open(BuildContext context, Complex complex) async {
    final auth = context.read<AuthProvider>();
    if (!auth.canAccess(complex.id)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'No tenés acceso a este complejo. Pedile al administrador que te habilite.'),
        ),
      );
      return;
    }
    final vehicles = context.read<VehicleProvider>();
    final drivers = context.read<DriverProvider>();
    final appearance = context.read<AppearanceProvider>();
    final tramites = context.read<TramiteProvider>();
    await Future.wait([
      tramites.setComplex(complex.id),
      vehicles.setComplex(complex.id),
      drivers.setComplex(complex.id),
    ]);
    if (!context.mounted) return;
    // Adentro del complejo se usa su apariencia (logo, tema, letra).
    appearance.setActive(complex.id);
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => DashboardScreen(complex: complex)),
    );
    appearance.setActive(null);
    _loadCounts();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final sync = context.watch<SyncProvider>();
    final isGod = auth.isGod;
    final appearance = context.watch<AppearanceProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('PARQUE AUTOMOTOR',
            style: TextStyle(fontSize: 16)),
        actions: [
          IconButton(
            tooltip: 'Apariencia',
            icon: const Icon(Icons.palette_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
          if (sync.isCloudEnabled)
            IconButton(
              tooltip: 'Sincronizar ahora',
              icon: sync.isSyncing
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.sync),
              onPressed: sync.isSyncing ? null : () => sync.syncNow(),
            ),
          if (isGod)
            IconButton(
              tooltip: 'Mover, descargar o borrar',
              icon: const Icon(Icons.drive_file_move_outline),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ManageRecordsScreen()),
              ),
            ),
          if (isGod)
            IconButton(
              tooltip: 'Administrar usuarios',
              icon: const Icon(Icons.manage_accounts_outlined),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const UserManagementScreen()),
              ),
            ),
          if (isGod)
            IconButton(
              tooltip: 'Panel de administración',
              icon: const Icon(Icons.settings_suggest_outlined),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AdminPanelScreen()),
              ),
            ),
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await context.read<AuthProvider>().logout();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: const AppLogo(height: 90),
          ),
          const SizedBox(height: 8),
          Text(
            'Servicio Penitenciario de Tucumán',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Theme.of(context).hintColor, fontSize: 12),
          ),
          const SizedBox(height: 16),
          Text(
            isGod
                ? 'Elegí el complejo con el que querés trabajar'
                : 'Elegí tu complejo',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          ...kComplexes.map(
            (c) => _ComplexCard(
              complex: c,
              enabled: auth.canAccess(c.id),
              logo: appearance.logoOf(c.id),
              accent: _accentFor(appearance, c),
              onEditAppearance: isGod
                  ? () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                ComplexAppearanceScreen(complex: c)),
                      )
                  : null,
              alerts: auth.canAccess(c.id) ? (_alertCounts[c.id] ?? 0) : 0,
              onTap: () => _open(context, c),
            ),
          ),
        ],
      ),
    );
  }
}

class _ComplexCard extends StatelessWidget {
  final Complex complex;
  final bool enabled;
  final int alerts;
  final Uint8List? logo;
  final Color accent;
  final VoidCallback? onEditAppearance;
  final VoidCallback onTap;

  const _ComplexCard({
    required this.complex,
    required this.enabled,
    required this.alerts,
    required this.logo,
    required this.accent,
    required this.onEditAppearance,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = enabled ? accent : Colors.grey;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
            child: Row(
              children: [
                if (logo != null)
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: Colors.white,
                    backgroundImage: MemoryImage(logo!),
                  )
                else
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: color,
                    child: Icon(complex.icon, color: Colors.white, size: 28),
                  ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    complex.name,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: enabled ? null : Colors.grey,
                    ),
                  ),
                ),
                if (alerts > 0) ...[
                  Badge(
                    label: Text('$alerts'),
                    backgroundColor: Colors.red,
                    child: const Icon(Icons.notifications_active_outlined,
                        color: Colors.red),
                  ),
                  const SizedBox(width: 12),
                ],
                if (onEditAppearance != null)
                  IconButton(
                    tooltip: 'Logo, tema y letra de este complejo',
                    icon: Icon(Icons.palette_outlined, color: color),
                    onPressed: onEditAppearance,
                  ),
                Icon(enabled ? Icons.chevron_right : Icons.lock_outline,
                    color: color),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
