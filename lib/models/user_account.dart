import 'complex.dart';

/// Rol del usuario dentro de la app.
/// - god: el único usuario con permiso total (crear/editar/eliminar
///   vehículos, choferes, y además administrar usuarios comunes).
/// - common: usuario creado por el god, solo puede iniciar sesión y
///   VER la información. No puede crear, editar ni eliminar nada.
enum UserRole { god, common }

extension UserRoleX on UserRole {
  String get value => this == UserRole.god ? 'god' : 'common';

  static UserRole fromValue(String value) =>
      value == 'god' ? UserRole.god : UserRole.common;
}

class UserAccount {
  final String id;
  final String username;
  final String passwordHash;
  final UserRole role;
  // Complejos a los que el admin habilitó a este usuario. El god
  // entra a todos sin importar esta lista.
  final List<String> complexIds;

  UserAccount({
    required this.id,
    required this.username,
    required this.passwordHash,
    required this.role,
    this.complexIds = const [],
  });

  bool get isGod => role == UserRole.god;

  bool canAccess(String complexId) => isGod || complexIds.contains(complexId);

  UserAccount copyWith({
    String? username,
    String? passwordHash,
    UserRole? role,
    List<String>? complexIds,
  }) {
    return UserAccount(
      id: id,
      username: username ?? this.username,
      passwordHash: passwordHash ?? this.passwordHash,
      role: role ?? this.role,
      complexIds: complexIds ?? this.complexIds,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'username': username,
      'password_hash': passwordHash,
      'role': role.value,
      'allowed_complexes': complexIds.join(','),
    };
  }

  factory UserAccount.fromMap(Map<String, dynamic> map) {
    return UserAccount(
      id: map['id'] as String,
      username: map['username'] as String,
      passwordHash: map['password_hash'] as String,
      role: UserRoleX.fromValue(map['role'] as String),
      complexIds: _parseComplexIds(map['allowed_complexes']),
    );
  }
}

/// Usuarios creados antes de existir los 4 complejos (columna sin
/// valor) quedan habilitados en Benjamín Paz, para que no pierdan
/// el acceso que ya tenían. Un texto vacío significa "ninguno".
List<String> _parseComplexIds(dynamic raw) {
  if (raw == null) return [kDefaultComplexId];
  final text = raw as String;
  if (text.isEmpty) return [];
  return text.split(',').where((e) => e.isNotEmpty).toList();
}
