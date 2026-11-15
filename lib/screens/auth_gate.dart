import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/legal_terms_service.dart';
import 'auth/login_screen.dart';
import 'complex_home_screen.dart';
import 'legal_terms_screen.dart';

/// Punto de entrada de navegación: decide qué pantalla mostrar según
/// el estado de autenticación (login / términos / dashboard).
///
/// La app siempre arranca en el login normal (usuario y contraseña),
/// incluso en el primer uso cuando todavía no existe el usuario god:
/// para crearlo hay que entrar por el botón "Acceso administrador" de
/// la pantalla de login, que pide el código de activación.
///
/// Una vez logueado, si el usuario todavía no aceptó los Términos de
/// Uso y Confidencialidad vigentes, se le muestra esa pantalla antes
/// de dejarlo entrar al dashboard — no se puede saltear.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool? _needsLegalAcceptance;

  Future<bool> _resolveLoggedIn(BuildContext context) async {
    await context.read<AuthProvider>().refresh();
    return context.read<AuthProvider>().isLoggedIn;
  }

  Future<void> _checkLegalAcceptance(String username) async {
    final accepted = await LegalTermsService.instance.hasAccepted(username);
    if (!mounted) return;
    setState(() => _needsLegalAcceptance = !accepted);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _resolveLoggedIn(context),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (!snapshot.data!) {
          _needsLegalAcceptance = null;
          return const LoginScreen();
        }

        final username =
            context.read<AuthProvider>().currentUser?.username ?? '';

        if (_needsLegalAcceptance == null) {
          _checkLegalAcceptance(username);
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (_needsLegalAcceptance == true) {
          return LegalTermsScreen(
            username: username,
            onAccepted: () => setState(() => _needsLegalAcceptance = false),
          );
        }

        return const ComplexHomeScreen();
      },
    );
  }
}
