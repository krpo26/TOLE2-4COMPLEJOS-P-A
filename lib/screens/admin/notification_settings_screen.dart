import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../../models/complex.dart';
import '../../providers/settings_provider.dart' show kColorOptions;
import '../../services/notification_prefs_service.dart';
import '../../services/notification_service.dart';
import '../../services/sync_service.dart';

/// Pantalla del administrador: cómo se VEN (barra de notificaciones)
/// y cómo SUENAN las alertas, y cada cuánto sale el sonido. Cada
/// cambio se guarda solo y llega a los demás celulares al sincronizar.
class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  NotificationPrefs? _p;
  bool _hasAudio = false;
  AudioPlayer? _player;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _player?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final p = await NotificationPrefsService.instance.load();
    final audio = await NotificationPrefsService.instance.customAudio();
    if (!mounted) return;
    setState(() {
      _p = p;
      _hasAudio = audio != null;
    });
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _update(NotificationPrefs next) async {
    final saved = await NotificationPrefsService.instance.save(next);
    if (!mounted) return;
    setState(() => _p = saved);
    unawaited(SyncService.instance.pushNotificationPrefs());
  }

  Future<void> _pickAudio() async {
    try {
      final name = await NotificationPrefsService.instance.pickAudio();
      if (name == null) return;
      _hasAudio = true;
      await _update(_p!.copyWith(audioName: name));
      _snack('Audio cargado: $name');
    } catch (e) {
      _snack(e.toString());
    }
  }

  Future<void> _removeAudio() async {
    await NotificationPrefsService.instance.removeAudio();
    _hasAudio = false;
    await _update(_p!.copyWith(clearAudio: true));
    _snack('Se usará el sonido de la app.');
  }

  Future<void> _listen() async {
    final f = await NotificationPrefsService.instance.customAudio();
    if (f == null) return;
    _player ??= AudioPlayer();
    try {
      await _player!.stop();
      await _player!.play(DeviceFileSource(f.path));
    } catch (_) {
      _snack('No se pudo reproducir el audio.');
    }
  }

  String _intervalLabel(int m) {
    if (m == 0) return 'Sin sonido';
    if (m < 60) return '$m min';
    if (m == 60) return '1 hora';
    if (m < 1440) return '${m ~/ 60} horas';
    return '1 día';
  }

  @override
  Widget build(BuildContext context) {
    final p = _p;
    return Scaffold(
      appBar: AppBar(title: const Text('Notificaciones')),
      body: p == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ---------------- ASPECTO ----------------
                const Text('Cómo se ve',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                const Text(
                  'Lo que aparece en la barra de notificaciones del celular.',
                  style: TextStyle(color: Colors.grey),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Banner emergente sobre la app'),
                  subtitle: const Text(
                      'La alerta se muestra arriba aunque se esté usando la app.'),
                  value: p.banner,
                  onChanged: (v) => _update(p.copyWith(banner: v)),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Logo del complejo'),
                  subtitle: const Text(
                      'Muestra el logo del complejo (si tiene) junto a la alerta.'),
                  value: p.useLogo,
                  onChanged: (v) => _update(p.copyWith(useLogo: v)),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Nombre del complejo en el título'),
                  value: p.showComplexName,
                  onChanged: (v) => _update(p.copyWith(showComplexName: v)),
                ),
                const SizedBox(height: 8),
                const Text('Estilo del texto'),
                const SizedBox(height: 6),
                SegmentedButton<String>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: 'compact', label: Text('Compacto')),
                    ButtonSegment(
                        value: 'expanded', label: Text('Texto completo')),
                  ],
                  selected: {p.style},
                  onSelectionChanged: (s) =>
                      _update(p.copyWith(style: s.first)),
                ),
                const SizedBox(height: 16),
                const Text('Color de la notificación'),
                const SizedBox(height: 6),
                SegmentedButton<String>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                        value: 'complex', label: Text('Color del complejo')),
                    ButtonSegment(value: 'fixed', label: Text('Color fijo')),
                  ],
                  selected: {p.colorMode},
                  onSelectionChanged: (s) =>
                      _update(p.copyWith(colorMode: s.first)),
                ),
                if (p.colorMode == 'fixed') ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: List.generate(kColorOptions.length, (i) {
                      final selected = p.fixedColorIndex == i;
                      return GestureDetector(
                        onTap: () => _update(p.copyWith(fixedColorIndex: i)),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: kColorOptions[i].color,
                            shape: BoxShape.circle,
                            border: selected
                                ? Border.all(color: Colors.black, width: 3)
                                : null,
                          ),
                          child: selected
                              ? const Icon(Icons.check, color: Colors.white)
                              : null,
                        ),
                      );
                    }),
                  ),
                ],
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: p.lockVisibility,
                  decoration: const InputDecoration(
                    labelText: 'Con la pantalla bloqueada',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                        value: 'public', child: Text('Mostrar todo')),
                    DropdownMenuItem(
                        value: 'private',
                        child: Text('Ocultar el contenido')),
                    DropdownMenuItem(
                        value: 'secret', child: Text('No mostrar nada')),
                  ],
                  onChanged: (v) {
                    if (v != null) _update(p.copyWith(lockVisibility: v));
                  },
                ),
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 12),

                // ---------------- SONIDO ----------------
                const Text('Cómo suena',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.music_note_outlined),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _hasAudio
                                    ? (p.audioName ?? 'Audio propio')
                                    : 'Sonido de la app (por defecto)',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: [
                            OutlinedButton.icon(
                              onPressed: _pickAudio,
                              icon: const Icon(Icons.upload_file),
                              label: const Text('Cargar audio'),
                            ),
                            if (_hasAudio)
                              OutlinedButton.icon(
                                onPressed: _listen,
                                icon: const Icon(Icons.play_arrow),
                                label: const Text('Escuchar'),
                              ),
                            if (_hasAudio)
                              TextButton.icon(
                                onPressed: _removeAudio,
                                icon: const Icon(Icons.delete_outline),
                                label: const Text('Quitar'),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Formatos: mp3, wav, ogg, m4a. Máximo 450 KB '
                          '(unos 20-30 segundos). El audio lo reproduce la '
                          'app cuando sale la alerta.',
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Cada cuánto suena la alerta auditiva'),
                const SizedBox(height: 4),
                const Text(
                  'Entre un sonido y el siguiente las notificaciones salen '
                  'en silencio (solo la parte visual).',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: NotificationPrefsService.kSoundIntervalOptions
                      .map((m) => ChoiceChip(
                            label: Text(_intervalLabel(m)),
                            selected: p.soundIntervalMinutes == m,
                            onSelected: (_) =>
                                _update(p.copyWith(soundIntervalMinutes: m)),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 12),

                // ---------------- PRUEBA ----------------
                const Text('Probar',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                const Text(
                  'Envía una notificación de ejemplo (con sonido) para ver '
                  'y escuchar cómo queda en cada complejo.',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: kComplexes
                      .map((c) => ActionChip(
                            avatar: Icon(c.icon, size: 18, color: c.color),
                            label: Text(c.shortName),
                            onPressed: () async {
                              await NotificationService.instance
                                  .showTest(c.id);
                              _snack('Notificación de prueba enviada.');
                            },
                          ))
                      .toList(),
                ),
                const SizedBox(height: 24),
              ],
            ),
    );
  }
}
