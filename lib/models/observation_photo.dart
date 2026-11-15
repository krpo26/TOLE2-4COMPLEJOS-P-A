/// Foto suelta adjunta como "observación" de un vehículo (por ejemplo,
/// una foto de un golpe, un desperfecto o cualquier detalle visual que
/// no encaja en los campos de documentación fijos como cédula/VTV).
/// Un vehículo puede tener cero o muchas.
class ObservationPhoto {
  final String id;
  final String vehicleId;
  final String photoPath;
  final DateTime createdAt;

  ObservationPhoto({
    required this.id,
    required this.vehicleId,
    required this.photoPath,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'vehicle_id': vehicleId,
      'photo_path': photoPath,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory ObservationPhoto.fromMap(Map<String, dynamic> map) {
    return ObservationPhoto(
      id: map['id'] as String,
      vehicleId: map['vehicle_id'] as String,
      photoPath: map['photo_path'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
