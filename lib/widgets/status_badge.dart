import 'package:flutter/material.dart';

import '../models/driver.dart';
import '../models/vehicle.dart';

/// Badge de color reutilizable: verde = OK, amarillo = próximo,
/// rojo = vencido/superado. Sirve tanto para vehículos como choferes.
class StatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const StatusBadge({super.key, required this.label, required this.color});

  factory StatusBadge.forMaintenance(MaintenanceStatus status) {
    switch (status) {
      case MaintenanceStatus.ok:
        return StatusBadge(label: 'OK', color: Colors.green);
      case MaintenanceStatus.warning:
        return StatusBadge(label: 'Próximo', color: Colors.amber.shade800);
      case MaintenanceStatus.overdue:
        return StatusBadge(label: 'Vencido', color: Colors.red);
    }
  }

  factory StatusBadge.forLicense(LicenseStatus status) {
    switch (status) {
      case LicenseStatus.ok:
        return StatusBadge(label: 'OK', color: Colors.green);
      case LicenseStatus.warning:
        return StatusBadge(label: 'Por vencer', color: Colors.amber.shade800);
      case LicenseStatus.expired:
        return StatusBadge(label: 'Vencido', color: Colors.red);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color, width: 1.2),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
}
