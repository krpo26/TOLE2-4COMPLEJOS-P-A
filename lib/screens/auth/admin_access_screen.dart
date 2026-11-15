import '../../widgets/app_logo.dart';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../main.dart';
import '../../providers/auth_provider.dart';
import '../../services/auth_service.dart';
import '../complex_home_screen.dart';
import 'setup_screen.dart';

/// Se accede desde un botón aparte en la pantalla de login. Los usuarios
/// comunes ingresan con usuario y contraseña directamente en el login
/// normal; para entrar como administrador (modo god) primero hay que
/// cargar este código de activación, que no se muestra en pantalla.
///
/// SEGURIDAD: el código NUNCA se guarda como texto plano en el código
/// fuente (lo que lo haría visible con solo descompilar/abrir el APK
/// con cualquier herramienta de análisis de strings). En su lugar se
/// guarda el HASH SHA-256 del código, igual que se hace con las
/// contraseñas: se hashea lo que la persona escribe y se compara el
/// resultado, nunca el código en sí.
///
/// Además, para dificultar un ataque de fuerza bruta (probar códigos
/// al azar una y otra vez), después de 3 intentos fallidos la pantalla
/// se bloquea 60 segundos antes de dejar probar de nuevo. Este bloqueo
/// se guarda en el dispositivo, así que reiniciar la app no lo evita.
class AdminAccessScreen extends StatefulWidget {
  const AdminAccessScreen({super.key});

  @override
  State<AdminAccessScreen> createState() => _AdminAccessScreenState();
}

class _AdminAccessScreenState extends State<AdminAccessScreen> {
  // Hash SHA-256 del código de activación. El código en sí no aparece
  // en ningún lado del código fuente ni del APK compilado.
  static const _kActivationCodeHash =
      'd8f00f7508ea5a4d3df8d64ed52d56f5937612658ea3bda163088fd15e06276c';
  static const _kMaxAttempts = 3;
  static const _kLockoutSeconds = 60;
  static const _kAttemptsKey = 'admin_access_failed_attempts';
  static const _kLockoutUntilKey = 'admin_access_lockout_until';

  final _codeFormKey = GlobalKey<FormState>();
  final _codeCtrl = TextEditingController();
  bool _activated = false;
  bool _checkingSetup = false;
  int _remainingLockSeconds = 0;

  @override
  void initState() {
    super.initState();
    _checkLockoutState();
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  String _hashOf(String value) => sha256.convert(utf8.encode(value)).toString();

  Future<void> _checkLockoutState() async {
    final prefs = await SharedPreferences.getInstance();
    final lockoutUntil = prefs.getInt(_kLockoutUntilKey) ?? 0;
    final remaining =
        lockoutUntil - DateTime.now().millisecondsSinceEpoch ~/ 1000;
    if (remaining > 0) {
      setState(() => _remainingLockSeconds = remaining);
      _tickLockout();
    }
  }

  void _tickLockout() {
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      if (_remainingLockSeconds <= 1) {
        setState(() => _remainingLockSeconds = 0);
      } else {
        setState(() => _remainingLockSeconds -= 1);
        _tickLockout();
      }
    });
  }

  Future<void> _registerFailedAttempt() async {
    final prefs = await SharedPreferences.getInstance();
    final attempts = (prefs.getInt(_kAttemptsKey) ?? 0) + 1;
    await prefs.setInt(_kAttemptsKey, attempts);
    if (attempts >= _kMaxAttempts) {
      final until = DateTime.now().millisecondsSinceEpoch ~/ 1000 +
          _kLockoutSeconds;
      await prefs.setInt(_kLockoutUntilKey, until);
      await prefs.setInt(_kAttemptsKey, 0);
      if (!mounted) return;
      setState(() => _remainingLockSeconds = _kLockoutSeconds);
      _tickLockout();
    }
  }

  Future<void> _clearAttempts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kAttemptsKey, 0);
    await prefs.remove(_kLockoutUntilKey);
  }

  Future<void> _validateCode() async {
    if (_remainingLockSeconds > 0) return;
    if (!_codeFormKey.currentState!.validate()) return;

    final entered = _hashOf(_codeCtrl.text.trim());
    if (entered != _kActivationCodeHash) {
      await _registerFailedAttempt();
      if (!mounted) return;
      _codeCtrl.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Código de activación incorrecto')),
      );
      return;
    }

    await _clearAttempts();
    setState(() => _checkingSetup = true);
    final needsSetup = await AuthService.instance.needsSetup();
    if (!mounted) return;

    if (needsSetup) {
      // Todavía no existe el usuario god: se crea acá mismo.
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const SetupScreen()),
      );
    } else {
      setState(() {
        _activated = true;
        _checkingSetup = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Acceso administrador')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: _activated ? const _GodLoginForm() : _buildCodeStep(),
          ),
        ),
      ),
    );
  }

  Widget _buildCodeStep() {
    final locked = _remainingLockSeconds > 0;
    return Form(
      key: _codeFormKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.admin_panel_settings_outlined, size: 64),
          const SizedBox(height: 12),
          const Text(
            'Ingresá el código de activación para acceder como '
            'administrador (modo god).',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _codeCtrl,
            enabled: !locked,
            obscureText: true,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
                labelText: 'Código de activación',
                border: OutlineInputBorder()),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Campo obligatorio' : null,
            onFieldSubmitted: (_) => _validateCode(),
          ),
          const SizedBox(height: 8),
          CheckboxListTile(
            value: _activated,
            onChanged: null,
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            title: const Text('Casillero de activación'),
            subtitle: const Text('Se marca al validar el código correcto'),
          ),
          if (locked) ...[
            const SizedBox(height: 8),
            Text(
              'Demasiados intentos fallidos. Probá de nuevo en '
              '$_remainingLockSeconds s.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: (_checkingSetup || locked) ? null : _validateCode,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: _checkingSetup
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Validar código'),
            ),
          ),
        ],
      ),
    );
  }
}

class _GodLoginForm extends StatefulWidget {
  const _GodLoginForm();

  @override
  State<_GodLoginForm> createState() => _GodLoginFormState();
}

class _GodLoginFormState extends State<_GodLoginForm> {
  final _formKey = GlobalKey<FormState>();
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  String? _error;
  bool _obscure = true;

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    final auth = context.read<AuthProvider>();
    final ok = await auth.login(_userCtrl.text.trim(), _passCtrl.text);

    if (!mounted) return;

    if (ok && auth.isGod) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const ComplexHomeScreen()),
        (route) => false,
      );
    } else {
      if (ok) {
        // Las credenciales son válidas pero no son del usuario god:
        // se cierra la sesión para no dejarlo logueado por esta vía.
        await auth.logout();
      }
      setState(() {
        _loading = false;
        _error = 'Usuario o contraseña de administrador incorrectos';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AppLogo(height: 90),
          const SizedBox(height: 12),
          const Text(
            kAppTitle,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            'Ingreso administrador',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
          const SizedBox(height: 28),
          TextFormField(
            controller: _userCtrl,
            decoration: const InputDecoration(
                labelText: 'Usuario administrador',
                prefixIcon: Icon(Icons.admin_panel_settings_outlined),
                border: OutlineInputBorder()),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Campo obligatorio' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _passCtrl,
            obscureText: _obscure,
            decoration: InputDecoration(
              labelText: 'Contraseña',
              prefixIcon: const Icon(Icons.lock_outline),
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(_obscure
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            validator: (v) =>
                (v == null || v.isEmpty) ? 'Campo obligatorio' : null,
            onFieldSubmitted: (_) => _login(),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!,
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _loading ? null : _login,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Ingresar como administrador'),
            ),
          ),
        ],
      ),
    );
  }
}
