DateTime _parseUtc(String s) =>
    DateTime.parse(s.endsWith('Z') || s.contains('+') ? s : '${s}Z');

class Mensaje {
  final String id;
  final String incidenteId;
  final String remitenteId;
  final String rolRemitente;   // 'cliente' | 'taller' | 'tecnico'
  final String nombreRemitente;
  final String contenido;
  final bool leido;
  final DateTime creadoEn;

  const Mensaje({
    required this.id,
    required this.incidenteId,
    required this.remitenteId,
    required this.rolRemitente,
    required this.nombreRemitente,
    required this.contenido,
    required this.leido,
    required this.creadoEn,
  });

  factory Mensaje.fromJson(Map<String, dynamic> json) => Mensaje(
        id: json['id'].toString(),
        incidenteId: json['incidente_id'].toString(),
        remitenteId: json['remitente_id'].toString(),
        rolRemitente: json['rol_remitente'] as String? ?? 'cliente',
        nombreRemitente: json['nombre_remitente'] as String? ?? 'Desconocido',
        contenido: json['contenido'] as String? ?? '',
        leido: json['leido'] as bool? ?? false,
        creadoEn: json['creado_en'] != null
            ? _parseUtc(json['creado_en'].toString())
            : DateTime.now(),
      );
}
