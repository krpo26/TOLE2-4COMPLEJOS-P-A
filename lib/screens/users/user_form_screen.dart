import 'package:flutter/material.dart';

import '../../models/complex.dart';
import '../../models/user_account.dart';
import '../../services/auth_service.dart';

class UserFormScreen extends StatefulWidget {
  final UserAccount? user; // null = alta de usuario común nuevo

  const UserFormScreen({super.key, this.user});

  @override
  State<UserFormScreen> createState() => _UserFormScreenState();
}

class _UserFormScreenState extends State<UserFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _userCtrl;
  final _passCtrl = TextEditingController();
  final _passConfirmCtrl = TextEditingController();
  late final Set<String> _complexIds;
  bool _saving = false;
  String? _error;

  bool get _isEditing => widget.user != null;

  @override
  void initState() {
    super.initState();
    _userCtrl = TextEditingController(text: widget.user?.username ?? '');
    _complexIds = {...?widget.user?.complexIds};
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });

    String? error;
    if (_isEditing) {
      error = await AuthService.instance.updateCommonUser(
        widget.user!,
        newUsername: _userCtrl.text.trim(),
        newPassword: _passCtrl.text.isEmpty ? null : _passCtrl.text,
        complexIds: _complexIds.toList(),
      );
    } else {
      error = await AuthService.instance
          .createCommonUser(_userCtrl.text.trim(), _passCtrl.text,
              complexIds: _complexIds.toList());
    }

    if (!mounted) return;

    if (error != null) {
      setState(() {
        _saving = false;
        _error = error;
      });
      return;
    }

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar usuario' : 'Nuevo usuario común'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (!_isEditing)
              const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: Text(
                  'Este usuario solo podrá iniciar sesión y ver la '
                  'información de vehículos y choferes. No podrá crear, '
                  'editar ni eliminar nada.',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            TextFormField(
              controller: _userCtrl,
              decoration: const InputDecoration(
                  labelText: 'Usuario', border: OutlineInputBorder()),
              validator: (v) => (v == null || v.trim().length < 3)
                  ? 'Mínimo 3 caracteres'
                  : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passCtrl,
              obscureText: true,
              decoration: InputDecoration(
                labelText:
                    _isEditing ? 'Nueva contraseña (opcional)' : 'Contraseña',
                border: const OutlineInputBorder(),
              ),
              validator: (v) {
                if (_isEditing && (v == null || v.isEmpty)) return null;
                if (v == null || v.length < 6) return 'Mínimo 6 caracteres';
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passConfirmCtrl,
              obscureText: true,
              decoration: InputDecoration(
                labelText: _isEditing
                    ? 'Confirmar nueva contraseña'
                    : 'Confirmar contraseña',
                border: const OutlineInputBorder(),
              ),
              validator: (v) {
                if (_isEditing && _passCtrl.text.isEmpty) return null;
                return v != _passCtrl.text
                    ? 'Las contraseñas no coinciden'
                    : null;
              },
            ),
            const SizedBox(height: 24),
            const Text('Complejos habilitados',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text(
              'El usuario solo podrá entrar a los complejos tildados.',
              style: TextStyle(color: Colors.grey),
            ),
            ...kComplexes.map(
              (c) => CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _complexIds.contains(c.id),
                title: Text(c.name, style: const TextStyle(fontSize: 13)),
                onChanged: (v) => setState(() {
                  if (v == true) {
                    _complexIds.add(c.id);
                  } else {
                    _complexIds.remove(c.id);
                  }
                }),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(_isEditing ? 'Guardar cambios' : 'Crear usuario'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
