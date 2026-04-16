class Usuario {
  final String id;       // UUID string
  final String nombreCompleto;
  final String correo;
  final String? telefono;
  final String rol;      // extraído de rol.nombre
  final bool activo;
  final DateTime creadoEn;

  const Usuario({
    required this.id,
    required this.nombreCompleto,
    required this.correo,
    this.telefono,
    required this.rol,
    required this.activo,
    required this.creadoEn,
  });

  factory Usuario.fromJson(Map<String, dynamic> json) {
    // rol viene como objeto: {"id": "...", "nombre": "cliente"}
    final rolRaw = json['rol'];
    final String rolNombre = rolRaw is Map
        ? (rolRaw['nombre'] as String? ?? 'cliente')
        : (rolRaw as String? ?? 'cliente');

    return Usuario(
      id: json['id'].toString(),
      nombreCompleto: json['nombre_completo'] as String,
      correo: json['correo'] as String,
      telefono: json['telefono'] as String?,
      rol: rolNombre,
      activo: json['activo'] as bool? ?? true,
      creadoEn: json['creado_en'] != null
          ? DateTime.parse(json['creado_en'].toString())
          : DateTime.now(),
    );
  }

  Usuario copyWith({
    String? nombreCompleto,
    String? telefono,
  }) =>
      Usuario(
        id: id,
        nombreCompleto: nombreCompleto ?? this.nombreCompleto,
        correo: correo,
        telefono: telefono ?? this.telefono,
        rol: rol,
        activo: activo,
        creadoEn: creadoEn,
      );
}
