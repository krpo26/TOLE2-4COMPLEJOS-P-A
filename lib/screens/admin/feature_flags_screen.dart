import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/feature_flag.dart';
import '../../providers/feature_flags_provider.dart';

/// Pantalla desde la que el admin (god) decide qué pestañas/secciones
/// y qué datos puntuales puede ver un usuario común. El admin siempre
/// ve todo, sin importar estos interruptores — solo afectan a los
/// usuarios comunes.
class FeatureFlagsScreen extends StatelessWidget {
  const FeatureFlagsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FeatureFlagsProvider>();

    // Agrupa las definiciones por categoría, respetando el orden en
    // que aparecen en kFeatureFlagDefs.
    final categories = <String, List<FeatureFlagDef>>{};
    for (final def in kFeatureFlagDefs) {
      categories.putIfAbsent(def.category, () => []).add(def);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Qué ven los usuarios')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Elegí qué secciones y qué datos puede ver un usuario común. '
            'Vos, como administrador, siempre vas a seguir viendo todo — '
            'esto solo afecta lo que ven los demás usuarios.',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 20),
          for (final entry in categories.entries) ...[
            Text(entry.key,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 8),
            ...entry.value.map((def) => Card(
                  child: SwitchListTile(
                    title: Text(def.label,
                        style:
                            const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(def.description),
                    value: provider.isEnabled(def.key),
                    onChanged: (value) =>
                        provider.setEnabled(def.key, value),
                  ),
                )),
            const SizedBox(height: 20),
          ],
        ],
      ),
    );
  }
}
