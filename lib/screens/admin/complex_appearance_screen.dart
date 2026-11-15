import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../models/complex.dart';
import '../../models/complex_appearance.dart';
import '../../providers/appearance_provider.dart';
import '../../providers/settings_provider.dart';
import '../../theme/app_theme.dart';

/// Pantalla del administrador: logo, tema, color y letra PROPIOS de un
/// complejo. Lo que se deja en "Igual que la app" toma lo general.
/// Al guardar, el cambio llega a todos los celulares por la nube.
class ComplexAppearanceScreen extends StatefulWidget {
  final Complex complex;
  const ComplexAppearanceScreen({super.key, required this.complex});

  @override
  State<ComplexAppearanceScreen> createState() =>
      _ComplexAppearanceScreenState();
}

class _ComplexAppearanceScreenState extends State<ComplexAppearanceScreen> {
  static const _inherit = 'inherit';

  String? _mode; // null = igual que la app
  int? _color; // null = igual que la app
  String? _font; // null = igual que la app
  String? _logoB64; // null = logo general
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final current = context.read<AppearanceProvider>().of(widget.complex.id);
    _mode = current?.themeMode;
    _color = current?.colorIndex;
    _font = current?.fontKey;
    _logoB64 = current?.logoBase64;
  }

  Uint8List? get _logoBytes {
    final b64 = _logoB64;
    if (b64 == null || b64.isEmpty) return null;
    try {
      return base64Decode(b64);
    } catch (_) {
      return null;
    }
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _pickLogo() async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (bytes.length > 700 * 1024) {
        _snack('La imagen es muy pesada. Elegí una más chica.');
        return;
      }
      setState(() => _logoB64 = base64Encode(bytes));
    } catch (_) {
      _snack('No se pudo abrir la galería.');
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await context.read<AppearanceProvider>().save(
          ComplexAppearance(
            complexId: widget.complex.id,
            themeMode: _mode,
            colorIndex: _color,
            fontKey: _font,
            logoBase64: _logoB64,
          ),
        );
    if (!mounted) return;
    _snack('Apariencia guardada. Llega a los demás celulares al sincronizar.');
    Navigator.pop(context);
  }

  void _reset() {
    setState(() {
      _mode = null;
      _color = null;
      _font = null;
      _logoB64 = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final complex = widget.complex;
    final logo = _logoBytes;

    // Vista previa con lo que se está eligiendo.
    final previewMode = themeModeFromKey(_mode) ?? settings.themeMode;
    final previewDark = previewMode == ThemeMode.dark ||
        (previewMode == ThemeMode.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.dark);
    final previewSeed = (_color != null && _color! < kColorOptions.length)
        ? kColorOptions[_color!].color
        : settings.seedColor;
    final previewFont = fontFromKey(_font) ?? settings.font;

    return Scaffold(
      appBar: AppBar(title: const Text('Apariencia del complejo')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(complex.name,
              textAlign: TextAlign.center,
              style:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text(
            'Lo que dejes en "Igual que la app" usa la apariencia general.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
          const SizedBox(height: 16),

          // ---------- Vista previa ----------
          Theme(
            data: buildAppTheme(
              brightness: previewDark ? Brightness.dark : Brightness.light,
              seed: previewSeed,
              font: previewFont,
            ),
            child: Builder(
              builder: (ctx) => Card(
                color: Theme.of(ctx).colorScheme.surface,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      if (logo != null)
                        Image.memory(logo, height: 64, fit: BoxFit.contain)
                      else
                        Icon(complex.icon,
                            size: 48, color: Theme.of(ctx).colorScheme.primary),
                      const SizedBox(height: 8),
                      Text('Vista previa',
                          style: Theme.of(ctx).textTheme.titleMedium),
                      Text('Así se verá este complejo.',
                          style: Theme.of(ctx).textTheme.bodyMedium),
                      const SizedBox(height: 8),
                      FilledButton(onPressed: () {}, child: const Text('Botón')),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ---------- Logo ----------
          const Text('Logo',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: logo != null
                    ? Padding(
                        padding: const EdgeInsets.all(4),
                        child: Image.memory(logo, fit: BoxFit.contain),
                      )
                    : const Center(
                        child: Text('Logo\ngeneral',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 11, color: Colors.grey)),
                      ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _pickLogo,
                      icon: const Icon(Icons.image_outlined),
                      label: const Text('Elegir imagen'),
                    ),
                    if (logo != null)
                      TextButton.icon(
                        onPressed: () => setState(() => _logoB64 = null),
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Quitar (usar el general)'),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ---------- Tema (modo) ----------
          const Text('Tema',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: _inherit, label: Text('Igual')),
              ButtonSegment(value: 'light', label: Text('Claro')),
              ButtonSegment(value: 'dark', label: Text('Oscuro')),
              ButtonSegment(value: 'system', label: Text('Auto')),
            ],
            selected: {_mode ?? _inherit},
            onSelectionChanged: (s) =>
                setState(() => _mode = s.first == _inherit ? null : s.first),
          ),
          const SizedBox(height: 24),

          // ---------- Color ----------
          const Text('Color',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              GestureDetector(
                onTap: () => setState(() => _color = null),
                child: Column(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: _color == null ? Colors.black : Colors.grey,
                            width: _color == null ? 3 : 1),
                      ),
                      child: const Icon(Icons.sync_alt, color: Colors.grey),
                    ),
                    const SizedBox(height: 4),
                    const Text('Igual', style: TextStyle(fontSize: 11)),
                  ],
                ),
              ),
              ...List.generate(kColorOptions.length, (i) {
                final option = kColorOptions[i];
                final selected = _color == i;
                return GestureDetector(
                  onTap: () => setState(() => _color = i),
                  child: Column(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: option.color,
                          shape: BoxShape.circle,
                          border: selected
                              ? Border.all(color: Colors.black, width: 3)
                              : null,
                        ),
                        child: selected
                            ? const Icon(Icons.check, color: Colors.white)
                            : null,
                      ),
                      const SizedBox(height: 4),
                      Text(option.name, style: const TextStyle(fontSize: 11)),
                    ],
                  ),
                );
              }),
            ],
          ),
          const SizedBox(height: 24),

          // ---------- Letra ----------
          const Text('Letra',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          RadioListTile<String?>(
            contentPadding: EdgeInsets.zero,
            title: const Text('Igual que la app'),
            value: null,
            groupValue: _font,
            onChanged: (v) => setState(() => _font = v),
          ),
          ...AppFont.values.map(
            (f) => RadioListTile<String?>(
              contentPadding: EdgeInsets.zero,
              title: Text(f.label),
              value: f.name,
              groupValue: _font,
              onChanged: (v) => setState(() => _font = v),
            ),
          ),
          const SizedBox(height: 24),

          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _saving ? null : _reset,
                  child: const Text('Restablecer'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Guardar'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
