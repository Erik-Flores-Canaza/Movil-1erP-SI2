class Notificacion {
  final String id;
  final String titulo;
  final String mensaje;
  final bool leida;
  final DateTime creadoEn;

  const Notificacion({
    required this.id,
    required this.titulo,
    required this.mensaje,
    required this.leida,
    required this.creadoEn,
  });

  factory Notificacion.fromJson(Map<String, dynamic> json) => Notificacion(
        id: json['id'].toString(),
        titulo: json['titulo'] as String? ?? '',
        mensaje: json['cuerpo'] as String? ?? '',        // backend usa 'cuerpo'
        leida: json['leida'] as bool? ?? false,
        creadoEn: json['enviada_en'] != null             // backend usa 'enviada_en'
            ? _parseUtc(json['enviada_en'].toString())
            : DateTime.now(),
      );

  /// El backend envía ISO-8601 sin 'Z'. Forzamos UTC para que la diferencia
  /// con DateTime.now() (local) sea correcta al convertir con toLocal().
  static DateTime _parseUtc(String s) =>
      DateTime.parse(s.endsWith('Z') || s.contains('+') ? s : '${s}Z');

  Notificacion copyWith({bool? leida}) => Notificacion(
        id: id,
        titulo: titulo,
        mensaje: mensaje,
        leida: leida ?? this.leida,
        creadoEn: creadoEn,
      );
}
