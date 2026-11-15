import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

import '../models/audit_log.dart';
import '../models/user_account.dart';
import 'audit_service.dart';
import 'database_helper.dart';
import 'sync_service.dart';

/// Maneja la autenticación y el ciclo de vida de los usuarios.
///
/// Hay UN SOLO usuario "god" (se crea una única vez en el primer uso
/// de la app) con permiso total. El usuario god puede crear, editar y
/// eliminar usuarios "comunes", que solo pueden iniciar sesión y ver
/// información (sin crear/editar/eliminar vehículos ni choferes).
///
/// Las contraseñas se guardan siempre hasheadas (SHA-256) en SQLite.
/// La sesión activa (qué usuario quedó logueado) se guarda por
/// separado en el almacenamiento seguro del sistema.
///
/// Los usuarios comunes se sincronizan con la nube (ver
/// [SyncService]) para poder iniciar sesión desde cualquier
/// dispositivo, no solo desde el que los creó. El usuario god NUNCA
/// se sincroniza: queda siempre local al dispositivo donde se creó.
class AuthService {
  AuthService._internal();
  static final AuthService instance = AuthService._internal();

  final _storage = const FlutterSecureStorage();
  static const _kSessionUserIdKey = 'session_user_id';

  String _hash(String value) => sha256.convert(utf8.encode(value)).toString();

  /// true si todavía no existe el usuario god (primer uso de la app).
  Future<bool> needsSetup() async {
    final god = await DatabaseHelper.instance.getGodUser();
    return god == null;
  }

  /// Crea el usuario god. Solo debe poder llamarse una vez, en el
  /// setup inicial (needsSetup() == true).
  Future<void> createGodUser(String username, String password) async {
    final user = UserAccount(
      id: const Uuid().v4(),
      username: username.trim(),
      passwordHash: _hash(password),
      role: UserRole.god,
    );
    await DatabaseHelper.instance.insertUser(user);
    await _storage.write(key: _kSessionUserIdKey, value: user.id);
  }

  Future<bool> login(String username, String password) async {
    final trimmedUsername = username.trim();
    var user =
        await DatabaseHelper.instance.getUserByUsername(trimmedUsername);

    if (user == null) {
      // No está en este dispositivo todavía: puede ser un usuario
      // común creado desde otro celular que aún no se sincronizó acá.
      // Se busca directamente en la nube como respaldo.
      final cloudUser =
          await SyncService.instance.findCommonUserByUsername(trimmedUsername);
      if (cloudUser == null) return false;
      await DatabaseHelper.instance.insertUser(cloudUser);
      user = cloudUser;
    }

    if (user.passwordHash != _hash(password)) return false;

    await _storage.write(key: _kSessionUserIdKey, value: user.id);
    // Se anota el ingreso (lo ve el admin en "Últimos ingresos").
    unawaited(AuditService.log(
      action: 'ingresó',
      entityType: kAccessEntityType,
      entityLabel: user.username,
    ));
    return true;
  }

  Future<UserAccount?> currentUser() async {
    final id = await _storage.read(key: _kSessionUserIdKey);
    if (id == null) return null;
    return DatabaseHelper.instance.getUserById(id);
  }

  Future<bool> isLoggedIn() async => (await currentUser()) != null;

  Future<void> logout() async {
    await _storage.delete(key: _kSessionUserIdKey);
  }

  Future<bool> changePassword(
      String currentPassword, String newPassword) async {
    final user = await currentUser();
    if (user == null || user.passwordHash != _hash(currentPassword)) {
      return false;
    }
    await DatabaseHelper.instance
        .updateUser(user.copyWith(passwordHash: _hash(newPassword)));
    return true;
  }

  // ---------------- Administración de usuarios comunes (solo god) ----------------

  Future<List<UserAccount>> listCommonUsers() =>
      DatabaseHelper.instance.getCommonUsers();

  /// Devuelve null si se creó bien, o un mensaje de error si el
  /// usuario ya existe.
  Future<String?> createCommonUser(String username, String password,
      {List<String> complexIds = const []}) async {
    final existing =
        await DatabaseHelper.instance.getUserByUsername(username.trim());
    if (existing != null) return 'Ese usuario ya existe';

    final user = UserAccount(
      id: const Uuid().v4(),
      username: username.trim(),
      passwordHash: _hash(password),
      role: UserRole.common,
      complexIds: complexIds,
    );
    await DatabaseHelper.instance.insertUser(user);
    unawaited(SyncService.instance.pushUser(user));
    unawaited(AuditService.log(
      action: 'creó', entityType: 'Usuario', entityLabel: user.username,
    ));
    return null;
  }

  /// Actualiza usuario y/o contraseña de un usuario común existente.
  /// Si [newPassword] es null o vacío, no se modifica la contraseña.
  Future<String?> updateCommonUser(
    UserAccount user, {
    required String newUsername,
    String? newPassword,
    List<String>? complexIds,
  }) async {
    if (newUsername.trim() != user.username) {
      final existing =
          await DatabaseHelper.instance.getUserByUsername(newUsername.trim());
      if (existing != null) return 'Ese usuario ya existe';
    }
    final updated = user.copyWith(
      username: newUsername.trim(),
      passwordHash: (newPassword != null && newPassword.isNotEmpty)
          ? _hash(newPassword)
          : null,
      complexIds: complexIds,
    );
    await DatabaseHelper.instance.updateUser(updated);
    unawaited(SyncService.instance.pushUser(updated));
    unawaited(AuditService.log(
      action: 'editó', entityType: 'Usuario', entityLabel: updated.username,
    ));
    return null;
  }

  Future<void> deleteCommonUser(UserAccount user) async {
    await DatabaseHelper.instance.deleteUser(user.id);
    await DatabaseHelper.instance.insertTombstone('user', user.id);
    unawaited(SyncService.instance.deleteUserRemote(user.id));
    unawaited(SyncService.instance.pushTombstone('user', user.id));
    unawaited(AuditService.log(
      action: 'eliminó definitivamente',
      entityType: 'Usuario',
      entityLabel: user.username,
    ));
  }
}
