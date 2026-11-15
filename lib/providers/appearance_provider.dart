import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../models/complex_appearance.dart';
import '../services/database_helper.dart';
import '../services/sync_service.dart';

/// Apariencia (logo, tema, color, letra) de cada complejo. La define
/// el administrador y viaja a todos los celulares por la nube.
///
/// [activeComplexId] es el complejo en el que se está trabajando: la
/// app aplica su apariencia mientras se está adentro, y vuelve a la
/// general al volver a la pantalla de los 4 complejos.
class AppearanceProvider extends ChangeNotifier {
  final Map<String, ComplexAppearance> _items = {};
  final Map<String, Uint8List> _logos = {};
  String? activeComplexId;

  ComplexAppearance? of(String complexId) => _items[complexId];
  ComplexAppearance? get active =>
      activeComplexId == null ? null : _items[activeComplexId];
  Uint8List? logoOf(String complexId) => _logos[complexId];

  Future<void> load() async {
    final list = await DatabaseHelper.instance.getComplexAppearances();
    _items.clear();
    _logos.clear();
    for (final a in list) {
      _items[a.complexId] = a;
      _decodeLogo(a);
    }
    notifyListeners();
  }

  void _decodeLogo(ComplexAppearance a) {
    final b64 = a.logoBase64;
    if (b64 == null || b64.isEmpty) {
      _logos.remove(a.complexId);
      return;
    }
    try {
      _logos[a.complexId] = base64Decode(b64);
    } catch (_) {
      _logos.remove(a.complexId);
    }
  }

  void setActive(String? complexId) {
    if (activeComplexId == complexId) return;
    activeComplexId = complexId;
    notifyListeners();
  }

  /// Solo debe llamarse desde la pantalla del administrador (god).
  Future<void> save(ComplexAppearance a) async {
    _items[a.complexId] = a;
    _decodeLogo(a);
    notifyListeners();
    await DatabaseHelper.instance.upsertComplexAppearance(a);
    unawaited(SyncService.instance.pushAppearance(a));
  }
}
