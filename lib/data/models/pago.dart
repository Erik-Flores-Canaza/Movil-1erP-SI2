DateTime _parseUtc(String s) =>
    DateTime.parse(s.endsWith('Z') || s.contains('+') ? s : '${s}Z');

class CrearIntentResponse {
  final String clientSecret;
  final String publishableKey;
  final double montoTotal;
  final double comision;
  final double netoTaller;

  const CrearIntentResponse({
    required this.clientSecret,
    required this.publishableKey,
    required this.montoTotal,
    required this.comision,
    required this.netoTaller,
  });

  factory CrearIntentResponse.fromJson(Map<String, dynamic> json) =>
      CrearIntentResponse(
        clientSecret: json['client_secret'] as String,
        publishableKey: json['publishable_key'] as String,
        montoTotal: (json['monto_total'] as num).toDouble(),
        comision: (json['comision'] as num).toDouble(),
        netoTaller: (json['neto_taller'] as num).toDouble(),
      );
}

class Pago {
  final String id;
  final String incidenteId;
  final double montoTotal;
  final double comisionPlataforma;
  final double netoTaller;
  final String estado;
  final DateTime? pagadoEn;
  final DateTime? creadoEn;

  const Pago({
    required this.id,
    required this.incidenteId,
    required this.montoTotal,
    required this.comisionPlataforma,
    required this.netoTaller,
    required this.estado,
    this.pagadoEn,
    this.creadoEn,
  });

  factory Pago.fromJson(Map<String, dynamic> json) => Pago(
        id: json['id'].toString(),
        incidenteId: json['incidente_id'].toString(),
        montoTotal: (json['monto_total'] as num).toDouble(),
        comisionPlataforma: (json['comision_plataforma'] as num).toDouble(),
        netoTaller: (json['neto_taller'] as num).toDouble(),
        estado: json['estado'] as String? ?? 'pendiente',
        pagadoEn: json['pagado_en'] != null
            ? _parseUtc(json['pagado_en'].toString())
            : null,
        creadoEn: json['creado_en'] != null
            ? _parseUtc(json['creado_en'].toString())
            : null,
      );
}
