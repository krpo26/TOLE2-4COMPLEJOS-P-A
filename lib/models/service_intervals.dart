/// Intervalo de kilómetros entre service, por marca y modelo. Se usa
/// para calcular AUTOMÁTICAMENTE el próximo kilometraje de service
/// cada vez que se carga un evento tipo "Service" en el historial de
/// un vehículo (ver maintenance_record_form_screen.dart):
///
///   próximo service = kilometraje del service recién cargado
///                      + intervalo de esta tabla
///
/// Si la combinación marca/modelo del vehículo no está acá, no se
/// autocompleta nada — el campo "Próximo service" del vehículo sigue
/// siendo 100% editable a mano, como antes. El admin puede agregar
/// más marcas/modelos a esta lista cuando haga falta.
const Map<String, int> kServiceIntervalsKm = {
  'HONDA TORNADO': 3000,
  'RENAULT DUSTER': 10000,
  'TOYOTA HILUX': 10000,
  'MERCEDES BENZ': 12000,
  'CITROEN JUMPER': 20000, // cubre también "Citroën" (ver _normalize)
};

String _normalize(String s) => s
    .trim()
    .toUpperCase()
    .replaceAll('Ë', 'E')
    .replaceAll('É', 'E')
    .replaceAll('Á', 'A')
    .replaceAll('Í', 'I')
    .replaceAll('Ó', 'O')
    .replaceAll('Ú', 'U')
    .replaceAll(RegExp(r'\s+'), ' ');

/// Devuelve el intervalo de service (en km) para esta marca+modelo,
/// o null si esa combinación no está cargada en [kServiceIntervalsKm].
/// La comparación ignora mayúsculas/acentos y no exige coincidencia
/// exacta: "Renault Duster Oroch" también matchea "RENAULT DUSTER".
int? serviceIntervalKmFor(String brand, String model) {
  final haystack = _normalize('$brand $model');
  for (final entry in kServiceIntervalsKm.entries) {
    if (haystack.contains(entry.key)) return entry.value;
  }
  return null;
}
