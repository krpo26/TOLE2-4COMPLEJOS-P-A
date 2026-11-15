import 'package:flutter/material.dart';

/// Tipo de trámite que se inicia para un móvil.
enum TramiteType { service, compras, arreglo, otro }

extension TramiteTypeX on TramiteType {
  String get label {
    switch (this) {
      case TramiteType.service:
        return 'PEDIDO DE SERVICE';
      case TramiteType.compras:
        return 'PEDIDO DE COMPRAS';
      case TramiteType.arreglo:
        return 'PEDIDO DE ARREGLO';
      case TramiteType.otro:
        return 'OTRO';
    }
  }

  IconData get icon {
    switch (this) {
      case TramiteType.service:
        return Icons.build_circle_outlined;
      case TramiteType.compras:
        return Icons.shopping_cart_outlined;
      case TramiteType.arreglo:
        return Icons.car_repair;
      case TramiteType.otro:
        return Icons.description_outlined;
    }
  }
}

/// Estado en el que está el trámite.
enum TramiteStatus { iniciado, enTramite, finalizado, rechazado }

extension TramiteStatusX on TramiteStatus {
  String get label {
    switch (this) {
      case TramiteStatus.iniciado:
        return 'Iniciado';
      case TramiteStatus.enTramite:
        return 'En trámite';
      case TramiteStatus.finalizado:
        return 'Finalizado';
      case TramiteStatus.rechazado:
        return 'Rechazado';
    }
  }

  Color get color {
    switch (this) {
      case TramiteStatus.iniciado:
        return Colors.blue;
      case TramiteStatus.enTramite:
        return Colors.orange;
      case TramiteStatus.finalizado:
        return Colors.green;
      case TramiteStatus.rechazado:
        return Colors.red;
    }
  }

  /// Sigue en curso (todavía no se resolvió).
  bool get isOpen =>
      this == TramiteStatus.iniciado || this == TramiteStatus.enTramite;
}

/// Un trámite (pedido de service, de compras, de arreglo u otro) de
/// un móvil. El complejo se deduce del móvil: si el móvil se pasa a
/// otro complejo, el trámite lo acompaña.
class Tramite {
  final String id;
  final String vehicleId;
  final TramiteType type;
  final DateTime startDate;
  final TramiteStatus status;
  final String fileNumber; // N° de expediente
  final String detail; // detalle opcional (útil para "OTRO")
  final DateTime updatedAt;

  Tramite({
    required this.id,
    required this.vehicleId,
    required this.type,
    required this.startDate,
    required this.status,
    required this.fileNumber,
    this.detail = '',
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();

  Tramite copyWith({
    String? vehicleId,
    TramiteType? type,
    DateTime? startDate,
    TramiteStatus? status,
    String? fileNumber,
    String? detail,
  }) {
    return Tramite(
      id: id,
      vehicleId: vehicleId ?? this.vehicleId,
      type: type ?? this.type,
      startDate: startDate ?? this.startDate,
      status: status ?? this.status,
      fileNumber: fileNumber ?? this.fileNumber,
      detail: detail ?? this.detail,
      updatedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'vehicle_id': vehicleId,
        'type': type.name,
        'start_date': startDate.toIso8601String(),
        'status': status.name,
        'file_number': fileNumber,
        'detail': detail,
        'updated_at': updatedAt.toIso8601String(),
      };

  factory Tramite.fromMap(Map<String, dynamic> map) {
    return Tramite(
      id: map['id'] as String,
      vehicleId: map['vehicle_id'] as String,
      type: TramiteType.values.firstWhere(
        (t) => t.name == map['type'],
        orElse: () => TramiteType.otro,
      ),
      startDate: DateTime.parse(map['start_date'] as String),
      status: TramiteStatus.values.firstWhere(
        (s) => s.name == map['status'],
        orElse: () => TramiteStatus.iniciado,
      ),
      fileNumber: (map['file_number'] ?? '') as String,
      detail: (map['detail'] ?? '') as String,
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
