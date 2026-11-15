/// Registro de que un usuario leyó y aceptó los Términos de Uso y
/// Confidencialidad de la app, y con qué versión del texto. Si el
/// texto cambia (nueva versión), a ese usuario se le vuelve a pedir
/// aceptar, aunque ya lo hubiera hecho con una versión anterior.
class LegalAcceptance {
  final String username;
  final String version;
  final DateTime acceptedAt;

  LegalAcceptance({
    required this.username,
    required this.version,
    required this.acceptedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'username': username,
      'version': version,
      'accepted_at': acceptedAt.toIso8601String(),
    };
  }

  factory LegalAcceptance.fromMap(Map<String, dynamic> map) {
    return LegalAcceptance(
      username: map['username'] as String,
      version: map['version'] as String,
      acceptedAt: DateTime.parse(map['accepted_at'] as String),
    );
  }
}
