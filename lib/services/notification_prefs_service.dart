import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Cómo se ven y suenan las notificaciones de la app. Lo define el
/// administrador y viaja a todos los celulares por la nube.
class NotificationPrefs {
  /// Banner emergente que aparece sobre la app (importancia alta).
  final bool banner;

  /// Muestra el logo del complejo como imagen de la notificación.
  final bool useLogo;

  /// Antepone el nombre del complejo al título.
  final bool showComplexName;

  /// 'compact' = una línea; 'expanded' = texto completo desplegable.
  final String style;

  /// 'complex' = color del complejo; 'fixed' = [fixedColorIndex].
  final String colorMode;
  final int fixedColorIndex;

  /// Qué se ve en la pantalla bloqueada: 'public' (todo), 'private'
  /// (sin el contenido) o 'secret' (nada).
  final String lockVisibility;

  /// Cada cuántos minutos puede sonar la alerta auditiva. 0 = nunca
  /// suena (las notificaciones salen en silencio).
  final int soundIntervalMinutes;

  /// Nombre del audio propio cargado (null = sonido de la app).
  final String? audioName;

  final DateTime updatedAt;

  NotificationPrefs({
    this.banner = true,
    this.useLogo = true,
    this.showComplexName = true,
    this.style = 'expanded',
    this.colorMode = 'complex',
    this.fixedColorIndex = 0,
    this.lockVisibility = 'public',
    this.soundIntervalMinutes = 60,
    this.audioName,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);

  NotificationPrefs copyWith({
    bool? banner,
    bool? useLogo,
    bool? showComplexName,
    String? style,
    String? colorMode,
    int? fixedColorIndex,
    String? lockVisibility,
    int? soundIntervalMinutes,
    String? audioName,
    bool clearAudio = false,
    DateTime? updatedAt,
  }) {
    return NotificationPrefs(
      banner: banner ?? this.banner,
      useLogo: useLogo ?? this.useLogo,
      showComplexName: showComplexName ?? this.showComplexName,
      style: style ?? this.style,
      colorMode: colorMode ?? this.colorMode,
      fixedColorIndex: fixedColorIndex ?? this.fixedColorIndex,
      lockVisibility: lockVisibility ?? this.lockVisibility,
      soundIntervalMinutes: soundIntervalMinutes ?? this.soundIntervalMinutes,
      audioName: clearAudio ? null : (audioName ?? this.audioName),
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'banner': banner,
        'use_logo': useLogo,
        'show_complex_name': showComplexName,
        'style': style,
        'color_mode': colorMode,
        'fixed_color_index': fixedColorIndex,
        'lock_visibility': lockVisibility,
        'sound_interval_minutes': soundIntervalMinutes,
        'audio_name': audioName,
        'updated_at': updatedAt.toIso8601String(),
      };

  factory NotificationPrefs.fromJson(Map<String, dynamic> m,
      {int defaultSoundInterval = 60}) {
    return NotificationPrefs(
      banner: m['banner'] as bool? ?? true,
      useLogo: m['use_logo'] as bool? ?? true,
      showComplexName: m['show_complex_name'] as bool? ?? true,
      style: m['style'] as String? ?? 'expanded',
      colorMode: m['color_mode'] as String? ?? 'complex',
      fixedColorIndex: (m['fixed_color_index'] as num?)?.toInt() ?? 0,
      lockVisibility: m['lock_visibility'] as String? ?? 'public',
      soundIntervalMinutes:
          (m['sound_interval_minutes'] as num?)?.toInt() ?? defaultSoundInterval,
      audioName: m['audio_name'] as String?,
      updatedAt: m['updated_at'] != null
          ? (DateTime.tryParse(m['updated_at'] as String) ??
              DateTime.fromMillisecondsSinceEpoch(0))
          : DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

/// Guarda las preferencias de notificación (en el celular y en la
/// nube) y el audio propio de la alerta.
class NotificationPrefsService {
  NotificationPrefsService._internal();
  static final NotificationPrefsService instance =
      NotificationPrefsService._internal();

  static const _kPrefsKey = 'notif_prefs_v1';
  static const _kLegacyIntervalKey = 'alert_sound_interval_minutes';
  static const _kAudioFileName = 'alert_custom_audio.bin';

  /// Tamaño máximo del audio: tiene que entrar en la nube (Firestore
  /// admite 1 MB por documento).
  static const int kMaxAudioBytes = 450 * 1024;

  /// Opciones de "cada cuánto suena" (en minutos). 0 = sin sonido.
  static const List<int> kSoundIntervalOptions = [
    0, 1, 5, 15, 30, 60, 120, 180, 360, 720, 1440,
  ];

  Future<NotificationPrefs> load() async {
    final sp = await SharedPreferences.getInstance();
    // Si todavía no se configuró, el sonido sigue el intervalo que ya
    // tenía el admin (o 60 minutos).
    final legacy = sp.getInt(_kLegacyIntervalKey) ?? 60;
    final raw = sp.getString(_kPrefsKey);
    if (raw == null) return NotificationPrefs(soundIntervalMinutes: legacy);
    try {
      return NotificationPrefs.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
        defaultSoundInterval: legacy,
      );
    } catch (_) {
      return NotificationPrefs(soundIntervalMinutes: legacy);
    }
  }

  Future<void> _saveLocal(NotificationPrefs p) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kPrefsKey, jsonEncode(p.toJson()));
  }

  /// Guarda un cambio hecho por el administrador (queda con la fecha
  /// de ahora, así gana sobre lo que haya en la nube).
  Future<NotificationPrefs> save(NotificationPrefs p) async {
    final stamped = p.copyWith(updatedAt: DateTime.now());
    await _saveLocal(stamped);
    return stamped;
  }

  // ---------------- AUDIO PROPIO ----------------

  Future<File> _audioFile() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/$_kAudioFileName');
  }

  /// El archivo del audio propio, o null si no hay ninguno cargado.
  Future<File?> customAudio() async {
    final f = await _audioFile();
    return await f.exists() ? f : null;
  }

  /// Deja elegir un audio del celular. Devuelve el nombre, o null si
  /// se canceló. Lanza un texto de error si no sirve.
  Future<String?> pickAudio() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;
    final f = result.files.first;
    final bytes = f.bytes ?? await File(f.path!).readAsBytes();
    if (bytes.length > kMaxAudioBytes) {
      throw 'El audio pesa ${(bytes.length / 1024).round()} KB. '
          'El máximo es ${kMaxAudioBytes ~/ 1024} KB (unos 20-30 segundos).';
    }
    await (await _audioFile()).writeAsBytes(bytes, flush: true);
    return f.name;
  }

  Future<void> removeAudio() async {
    final f = await _audioFile();
    if (await f.exists()) await f.delete();
  }

  // ---------------- NUBE ----------------

  DocumentReference<Map<String, dynamic>> _doc(FirebaseFirestore fs) =>
      fs.collection('app_settings').doc('notifications');

  Future<void> pushToCloud(FirebaseFirestore fs) async {
    final p = await load();
    final f = await customAudio();
    await _doc(fs).set({
      'prefs': p.toJson(),
      'updated_at': p.updatedAt.toIso8601String(),
      'audio_b64': f == null ? null : base64Encode(await f.readAsBytes()),
    });
  }

  /// Gana la versión más nueva (por fecha) entre este celular y la nube.
  Future<void> syncWithCloud(FirebaseFirestore fs) async {
    final local = await load();
    final snap = await _doc(fs).get();
    DateTime remoteAt = DateTime.fromMillisecondsSinceEpoch(0);
    if (snap.exists) {
      final d = snap.data()!;
      remoteAt = DateTime.tryParse((d['updated_at'] as String?) ?? '') ??
          remoteAt;
      if (remoteAt.isAfter(local.updatedAt)) {
        final remote = NotificationPrefs.fromJson(
            Map<String, dynamic>.from(d['prefs'] as Map));
        await _saveLocal(remote);
        final b64 = d['audio_b64'] as String?;
        if (b64 != null && b64.isNotEmpty) {
          await (await _audioFile()).writeAsBytes(base64Decode(b64), flush: true);
        } else {
          await removeAudio();
        }
        return;
      }
    }
    if (!snap.exists || local.updatedAt.isAfter(remoteAt)) {
      await pushToCloud(fs);
    }
  }
}
