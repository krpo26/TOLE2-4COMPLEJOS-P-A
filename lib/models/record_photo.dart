/// Foto adjunta a un registro puntual del historial de mantenimiento
/// (arreglo, avería, service u otro), por ejemplo una foto de la
/// pieza rota o del trabajo realizado. Un registro puede tener cero
/// o muchas.
class RecordPhoto {
  final String id;
  final String recordId;
  final String photoPath;
  final DateTime createdAt;

  RecordPhoto({
    required this.id,
    required this.recordId,
    required this.photoPath,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'record_id': recordId,
      'photo_path': photoPath,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory RecordPhoto.fromMap(Map<String, dynamic> map) {
    return RecordPhoto(
      id: map['id'] as String,
      recordId: map['record_id'] as String,
      photoPath: map['photo_path'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
