import 'package:flutter/material.dart';

import '../../models/complex.dart';
import '../../models/user_account.dart';
import '../../services/auth_service.dart';
import 'user_form_screen.dart';

/// Solo llega a esta pantalla el usuario god (el botón que la abre
/// está oculto para usuarios comunes). Permite crear, editar y
/// eliminar usuarios comunes, que únicamente pueden iniciar sesión
/// y ver información — no pueden crear, editar ni eliminar nada.
class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  late Future<List<UserAccount>> _future;

  @override
  void initState() {
    super.initState();
    _future = AuthService.instance.listCommonUsers();
  }

  void _reload() {
    setState(() {
      _future = AuthService.instance.listCommonUsers();
    });
  }

  Future<void> _delete(UserAccount user) async {
    // 'edit' = cambiar los complejos habilitados; 'delete' = borrar.
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('¿Qué hacer con "${user.username}"?'),
        content: const Text(
            'Podés cambiarlo de complejo (editar los complejos habilitados) '
            'o eliminarlo definitivamente: no podrá volver a iniciar sesión '
            'en ningún dispositivo.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, 'edit'),
              child: const Text('Cambiar de complejo')),
          TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () => Navigator.pop(ctx, 'delete'),
              child: const Text('Eliminar definitivamente')),
        ],
      ),
    );
    if (choice == 'edit') {
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => UserFormScreen(user: user)),
      );
      _reload();
    } else if (choice == 'delete') {
      await AuthService.instance.deleteCommonUser(user);
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Administrar usuarios')),
      body: FutureBuilder<List<UserAccount>>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final users = snapshot.data!;
          if (users.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Todavía no creaste usuarios comunes.\n'
                  'Tocá "+" para agregar el primero.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: users.length,
            itemBuilder: (context, index) {
              final u = users[index];
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.person_outline),
                  ),
                  title: Text(u.username),
                  subtitle: Text(u.complexIds.isEmpty
                      ? 'Sin complejos habilitados'
                      : 'Habilitado en: ${u.complexIds.map((id) => complexById(id).shortName).join(', ')}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => UserFormScreen(user: u)),
                          );
                          _reload();
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _delete(u),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Nuevo usuario'),
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const UserFormScreen()),
          );
          _reload();
        },
      ),
    );
  }
}
