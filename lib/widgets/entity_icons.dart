import 'package:flutter/material.dart';

/// Íconos que se pueden elegir para representar un vehículo en las
/// listas y formularios. Se guardan como una clave de texto (`icon_key`)
/// en la base de datos, así se puede cambiar el ícono sin tocar
/// ningún otro dato ya cargado.
const Map<String, IconData> kVehicleIconChoices = {
  'truck': Icons.local_shipping,
  'car': Icons.directions_car,
  'pickup': Icons.local_taxi,
  'van': Icons.airport_shuttle,
  'motorcycle': Icons.two_wheeler,
  'bus': Icons.directions_bus,
  'tractor': Icons.agriculture,
  'other': Icons.directions_car_filled,
};

/// Íconos que se pueden elegir para representar a un chofer.
const Map<String, IconData> kDriverIconChoices = {
  'person': Icons.person,
  'person_outline': Icons.person_outline,
  'face': Icons.face_outlined,
  'badge': Icons.badge_outlined,
  'engineering': Icons.engineering_outlined,
  'support_agent': Icons.support_agent_outlined,
  'assignment_ind': Icons.assignment_ind_outlined,
  'star': Icons.star_outline,
};

/// Íconos que se pueden elegir para las secciones principales del
/// dashboard (Vehículos, Choferes). Solo el administrador (god) puede
/// cambiarlos, tocando el lápiz que aparece sobre el ícono.
const Map<String, IconData> kSectionIconChoices = {
  'local_shipping': Icons.local_shipping,
  'directions_car': Icons.directions_car,
  'person': Icons.person,
  'groups': Icons.groups_outlined,
  'badge': Icons.badge_outlined,
  'local_gas_station': Icons.local_gas_station_outlined,
  'build': Icons.build_outlined,
  'fact_check': Icons.fact_check_outlined,
  'assignment': Icons.assignment_outlined,
  'warehouse': Icons.warehouse_outlined,
  'garage': Icons.garage_outlined,
  'admin_panel_settings': Icons.admin_panel_settings_outlined,
};

/// Abre el mismo diálogo de grilla de íconos que usa [IconPickerTile],
/// pero como función suelta — para poder disparerla desde cualquier
/// lado (por ejemplo, desde el lápiz de una [StatCard] del dashboard)
/// sin necesidad de envolver todo en la tarjeta de [IconPickerTile].
Future<String?> pickIconDialog(
  BuildContext context, {
  required String title,
  required Map<String, IconData> choices,
  required String? current,
  required Color color,
}) {
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: 320,
        child: GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          mainAxisSpacing: 4,
          crossAxisSpacing: 4,
          children: choices.entries.map((e) {
            final selected = e.key == current;
            return InkWell(
              borderRadius: BorderRadius.circular(28),
              onTap: () => Navigator.pop(context, e.key),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: CircleAvatar(
                  backgroundColor:
                      selected ? color.withOpacity(0.3) : Colors.grey.shade200,
                  child: Icon(e.value, color: color),
                ),
              ),
            );
          }).toList(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
      ],
    ),
  );
}

IconData resolveEntityIcon(
  Map<String, IconData> choices,
  String? key,
  IconData fallback,
) {
  if (key == null) return fallback;
  return choices[key] ?? fallback;
}

/// Tarjeta con el ícono actual y un botón para elegir uno nuevo de una
/// grilla. Se usa tanto para vehículos como para choferes.
class IconPickerTile extends StatelessWidget {
  final String label;
  final String? iconKey;
  final Map<String, IconData> choices;
  final IconData fallbackIcon;
  final Color color;
  final bool readOnly;
  final void Function(String key) onPicked;

  const IconPickerTile({
    super.key,
    required this.label,
    required this.iconKey,
    required this.choices,
    required this.fallbackIcon,
    required this.color,
    required this.readOnly,
    required this.onPicked,
  });

  IconData get _current => resolveEntityIcon(choices, iconKey, fallbackIcon);

  Future<void> _choose(BuildContext context) async {
    final selected = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(label),
        content: SizedBox(
          width: 320,
          child: GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
            children: choices.entries.map((e) {
              final selected = e.key == iconKey;
              return InkWell(
                borderRadius: BorderRadius.circular(28),
                onTap: () => Navigator.pop(context, e.key),
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: CircleAvatar(
                    backgroundColor:
                        selected ? color.withOpacity(0.3) : Colors.grey.shade200,
                    child: Icon(e.value, color: color),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
    if (selected != null) onPicked(selected);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: readOnly ? null : () => _choose(context),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: color.withOpacity(0.15),
                child: Icon(_current, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(label,
                    style: const TextStyle(fontWeight: FontWeight.w500)),
              ),
              if (!readOnly)
                Icon(Icons.edit_outlined,
                    color: Theme.of(context).colorScheme.primary),
            ],
          ),
        ),
      ),
    );
  }
}
