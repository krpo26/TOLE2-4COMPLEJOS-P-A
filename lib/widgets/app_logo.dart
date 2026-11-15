import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/appearance_provider.dart';
import '../providers/feature_flags_provider.dart';

/// Logo institucional de la app. Si se está dentro de un complejo que
/// tiene logo propio (cargado por el admin) muestra ese; si no, el
/// que haya elegido el admin en el Panel de administración.
class AppLogo extends StatelessWidget {
  final double height;

  /// Complejo cuyo logo mostrar. Si no se indica, se usa el complejo
  /// en el que se está trabajando (si hay uno).
  final String? complexId;

  const AppLogo({super.key, required this.height, this.complexId});

  @override
  Widget build(BuildContext context) {
    final appearance = context.watch<AppearanceProvider>();
    final id = complexId ?? appearance.activeComplexId;
    if (id != null) {
      final bytes = appearance.logoOf(id);
      if (bytes != null) {
        return Image.memory(bytes, height: height, fit: BoxFit.contain);
      }
    }
    final asset = context.watch<FeatureFlagsProvider>().logoAsset;
    return Image.asset(asset, height: height);
  }
}
