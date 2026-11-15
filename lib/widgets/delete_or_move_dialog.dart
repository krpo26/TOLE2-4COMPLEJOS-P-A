import 'package:flutter/material.dart';

import '../models/complex.dart';

/// Resultado del diálogo: o se elimina definitivamente, o se mueve a
/// otro complejo ([targetComplexId]).
class DeleteOrMoveResult {
  final bool delete;
  final String? targetComplexId;
  const DeleteOrMoveResult.delete()
      : delete = true,
        targetComplexId = null;
  const DeleteOrMoveResult.move(String this.targetComplexId) : delete = false;
}

/// Pregunta qué hacer con un vehículo / chofer: eliminarlo
/// definitivamente (desaparece de todos los dispositivos) o pasarlo
/// a otro de los complejos. Devuelve null si se cancela.
Future<DeleteOrMoveResult?> showDeleteOrMoveDialog(
  BuildContext context, {
  required String itemLabel,
  required String currentComplexId,
  String deleteWarning = 'No se puede deshacer.',
}) {
  final others = kComplexes.where((c) => c.id != currentComplexId).toList();
  return showDialog<DeleteOrMoveResult>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('¿Qué hacer con "$itemLabel"?'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Pasarlo a otro complejo:',
                style: TextStyle(fontWeight: FontWeight.w600)),
            ...others.map(
              (c) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(c.icon, color: c.color),
                title: Text(c.name, style: const TextStyle(fontSize: 13)),
                onTap: () => Navigator.pop(ctx, DeleteOrMoveResult.move(c.id)),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar')),
        TextButton(
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          onPressed: () async {
            final sure = await showDialog<bool>(
              context: ctx,
              builder: (c2) => AlertDialog(
                title: const Text('Eliminar definitivamente'),
                content: Text(
                    'Se borra "$itemLabel" de todos los dispositivos. $deleteWarning'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(c2, false),
                      child: const Text('Cancelar')),
                  TextButton(
                      style:
                          TextButton.styleFrom(foregroundColor: Colors.red),
                      onPressed: () => Navigator.pop(c2, true),
                      child: const Text('Eliminar para siempre')),
                ],
              ),
            );
            if (sure == true && ctx.mounted) {
              Navigator.pop(ctx, const DeleteOrMoveResult.delete());
            }
          },
          child: const Text('Eliminar definitivamente'),
        ),
      ],
    ),
  );
}
