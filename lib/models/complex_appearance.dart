/// Apariencia propia de un complejo, definida por el administrador:
/// logo, tema (modo claro/oscuro), color y letra. Cada campo en null
/// significa "usar lo general de la app".
class ComplexAppearance {
  final String complexId;

  /// 'light', 'dark' o 'system'. null = igual que la app.
  final String? themeMode;

  /// Posición en la lista de colores de la app. null = igual que la app.
  final int? colorIndex;

  /// Nombre de la letra (ver AppFont). null = igual que la app.
  final String? fontKey;

  /// Logo propio, como imagen chica codificada en base64. null = logo
  /// general de la app.
  final String? logoBase64;

  final DateTime updatedAt;

  ComplexAppearance({
    required this.complexId,
    this.themeMode,
    this.colorIndex,
    this.fontKey,
    this.logoBase64,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'complex_id': complexId,
        'theme_mode': themeMode,
        'color_index': colorIndex,
        'font_key': fontKey,
        'logo_b64': logoBase64,
        'updated_at': updatedAt.toIso8601String(),
      };

  factory ComplexAppearance.fromMap(Map<String, dynamic> map) {
    return ComplexAppearance(
      complexId: map['complex_id'] as String,
      themeMode: map['theme_mode'] as String?,
      colorIndex: (map['color_index'] as num?)?.toInt(),
      fontKey: map['font_key'] as String?,
      logoBase64: map['logo_b64'] as String?,
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
