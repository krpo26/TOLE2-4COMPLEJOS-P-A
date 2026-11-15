import 'package:flutter/foundation.dart';

import '../models/user_account.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  UserAccount? _currentUser;

  UserAccount? get currentUser => _currentUser;
  bool get isGod => _currentUser?.role == UserRole.god;
  bool get isLoggedIn => _currentUser != null;

  /// El god entra a los 4 complejos; un usuario común solo a los que
  /// el admin le habilitó.
  bool canAccess(String complexId) => _currentUser?.canAccess(complexId) ?? false;

  Future<void> refresh() async {
    _currentUser = await AuthService.instance.currentUser();
    notifyListeners();
  }

  Future<bool> login(String username, String password) async {
    final ok = await AuthService.instance.login(username, password);
    if (ok) await refresh();
    return ok;
  }

  Future<void> logout() async {
    await AuthService.instance.logout();
    _currentUser = null;
    notifyListeners();
  }
}
