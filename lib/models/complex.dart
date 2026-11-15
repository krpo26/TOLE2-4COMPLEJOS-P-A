import 'package:flutter/material.dart';

/// Complejo penitenciario. Cada uno tiene su propia sección dentro de
/// la app, con sus propios vehículos (móviles) y choferes.
class Complex {
  final String id;
  final String name;
  final String shortName;
  final IconData icon;
  final Color color;

  const Complex({
    required this.id,
    required this.name,
    required this.shortName,
    required this.icon,
    required this.color,
  });
}

/// Complejo al que pertenecen los datos cargados ANTES de existir las
/// 4 secciones (todo lo que ya estaba en la app era de Benjamín Paz).
const String kDefaultComplexId = 'benjamin_paz';

const List<Complex> kComplexes = [
  Complex(
    id: 'benjamin_paz',
    name: 'COMPLEJO PENITENCIARIO BENJAMIN PAZ',
    shortName: 'BENJAMIN PAZ',
    icon: Icons.shield_outlined,
    color: Color(0xFF1565C0),
  ),
  Complex(
    id: 'villa_urquiza',
    name: 'COMPLEJO PENITENCIARIO VILLA URQUIZA',
    shortName: 'VILLA URQUIZA',
    icon: Icons.account_balance_outlined,
    color: Color(0xFF2E7D32),
  ),
  Complex(
    id: 'delfin_gallo',
    name: 'COMPLEJO PENITENCIARIO DELFIN GALLO',
    shortName: 'DELFIN GALLO',
    icon: Icons.security_outlined,
    color: Color(0xFFEF6C00),
  ),
  Complex(
    id: 'concepcion',
    name: 'COMPLEJO PENITENCIARIO CONCEPCION',
    shortName: 'CONCEPCION',
    icon: Icons.apartment_outlined,
    color: Color(0xFF6A1B9A),
  ),
];

Complex complexById(String id) => kComplexes.firstWhere(
      (c) => c.id == id,
      orElse: () => kComplexes.first,
    );
