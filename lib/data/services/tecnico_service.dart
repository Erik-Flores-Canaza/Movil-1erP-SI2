import 'package:dio/dio.dart';
import '../../core/dio_client.dart';

class TecnicoMe {
  final String id;
  final String nombreCompleto;
  final String? telefono;
  final double? latitudActual;
  final double? longitudActual;

  const TecnicoMe({
    required this.id,
    required this.nombreCompleto,
    this.telefono,
    this.latitudActual,
    this.longitudActual,
  });

  factory TecnicoMe.fromJson(Map<String, dynamic> json) => TecnicoMe(
        id: json['id'].toString(),
        nombreCompleto: json['nombre_completo'] as String? ?? '',
        telefono: json['telefono'] as String?,
        latitudActual: (json['latitud_actual'] as num?)?.toDouble(),
        longitudActual: (json['longitud_actual'] as num?)?.toDouble(),
      );
}

class EvidenciaOrden {
  final String id;
  final String tipo; // 'imagen' | 'audio'
  final String? archivoUrl;

  const EvidenciaOrden({
    required this.id,
    required this.tipo,
    this.archivoUrl,
  });

  factory EvidenciaOrden.fromJson(Map<String, dynamic> json) => EvidenciaOrden(
        id: json['id'].toString(),
        tipo: json['tipo'] as String? ?? 'imagen',
        archivoUrl: json['archivo_url'] as String?,
      );
}

class OrdenActiva {
  final String id;
  final String incidenteId;
  final String? accionTaller;
  final int? etaMinutos;
  final String? incidenteEstado;
  final String? incidenteDescripcion;
  final String? incidenteResumenIa;
  final double? incidenteLatitud;
  final double? incidenteLongitud;
  final String? incidentePrioridad;
  final String? incidenteClasificacion;
  final String? clienteNombre;
  final String? clienteTelefono;
  final List<EvidenciaOrden> evidencias;

  const OrdenActiva({
    required this.id,
    required this.incidenteId,
    this.accionTaller,
    this.etaMinutos,
    this.incidenteEstado,
    this.incidenteDescripcion,
    this.incidenteResumenIa,
    this.incidenteLatitud,
    this.incidenteLongitud,
    this.incidentePrioridad,
    this.incidenteClasificacion,
    this.clienteNombre,
    this.clienteTelefono,
    this.evidencias = const [],
  });

  factory OrdenActiva.fromJson(Map<String, dynamic> json) {
    final incidente = json['incidente'] as Map<String, dynamic>?;
    final cliente = incidente?['cliente'] as Map<String, dynamic>?;
    final evidList = incidente?['evidencias'] as List<dynamic>?;
    return OrdenActiva(
      id: json['id'].toString(),
      incidenteId: json['incidente_id'].toString(),
      accionTaller: json['accion_taller'] as String?,
      etaMinutos: json['eta_minutos'] as int?,
      incidenteEstado: incidente?['estado'] as String?,
      incidenteDescripcion: incidente?['descripcion'] as String?,
      incidenteResumenIa: incidente?['resumen_ia'] as String?,
      incidenteLatitud: (incidente?['latitud'] as num?)?.toDouble(),
      incidenteLongitud: (incidente?['longitud'] as num?)?.toDouble(),
      incidentePrioridad: incidente?['prioridad'] as String?,
      incidenteClasificacion: incidente?['clasificacion_ia'] as String?,
      clienteNombre: cliente?['nombre_completo'] as String?,
      clienteTelefono: cliente?['telefono'] as String?,
      evidencias: evidList
              ?.map((e) => EvidenciaOrden.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  String get estadoLabel => const {
        'pendiente': 'Pendiente',
        'en_proceso': 'En proceso',
        'atendido': 'Atendido',
        'cancelado': 'Cancelado',
      }[incidenteEstado ?? ''] ??
      (incidenteEstado ?? '-');

  String get prioridadLabel => const {
        'alta': 'Alta',
        'media': 'Media',
        'baja': 'Baja',
        'incierto': 'Sin clasificar',
      }[incidentePrioridad ?? ''] ??
      (incidentePrioridad ?? '-');

  String get clasificacionLabel => const {
        'bateria': 'Batería',
        'llanta': 'Llanta',
        'choque': 'Choque',
        'motor': 'Motor',
        'otro': 'Otro',
        'incierto': 'Sin clasificar',
      }[incidenteClasificacion ?? ''] ??
      (incidenteClasificacion ?? '-');
}

// ── Historial de servicios del técnico ────────────────────────────────────────

class ServicioHistorial {
  final String incidenteId;
  final String clienteNombre;
  final String? clasificacionIa;
  final String? prioridad;
  final DateTime? completadoEn;
  final String? pagoEstado;   // 'pendiente' | 'pagado' | null
  final double? pagoMonto;
  final String? pagoMetodo;   // 'efectivo' | 'stripe' | null

  const ServicioHistorial({
    required this.incidenteId,
    required this.clienteNombre,
    this.clasificacionIa,
    this.prioridad,
    this.completadoEn,
    this.pagoEstado,
    this.pagoMonto,
    this.pagoMetodo,
  });

  factory ServicioHistorial.fromJson(Map<String, dynamic> json) =>
      ServicioHistorial(
        incidenteId: json['incidente_id'].toString(),
        clienteNombre: json['cliente_nombre'] as String? ?? '–',
        clasificacionIa: json['clasificacion_ia'] as String?,
        prioridad: json['prioridad'] as String?,
        completadoEn: json['completado_en'] != null
            ? DateTime.tryParse('${json['completado_en']}Z')
            : null,
        pagoEstado: json['pago_estado'] as String?,
        pagoMonto: (json['pago_monto'] as num?)?.toDouble(),
        pagoMetodo: json['pago_metodo'] as String?,
      );
}

// ─────────────────────────────────────────────────────────────────────────────

class TecnicoService {
  final Dio _dio = DioClient.instance.dio;

  Options _auth(String token) =>
      Options(headers: {'Authorization': 'Bearer $token'});

  /// Obtiene el perfil del técnico autenticado (devuelve su tecnico.id)
  Future<TecnicoMe> getMe(String token) async {
    final response = await _dio.get('/tecnicos/me', options: _auth(token));
    return TecnicoMe.fromJson(response.data as Map<String, dynamic>);
  }

  /// CU-16+17: Obtiene la orden activa del técnico autenticado
  Future<OrdenActiva?> getOrdenActiva(String token) async {
    final response =
        await _dio.get('/tecnicos/me/orden-activa', options: _auth(token));
    if (response.data == null) return null;
    return OrdenActiva.fromJson(response.data as Map<String, dynamic>);
  }

  /// CU-16: Actualiza la ubicación GPS del técnico
  Future<void> actualizarUbicacion(
    String token, {
    required String tecnicoId,
    required double latitud,
    required double longitud,
  }) async {
    await _dio.patch(
      '/tecnicos/$tecnicoId/ubicacion',
      data: {'latitud': latitud, 'longitud': longitud},
      options: _auth(token),
    );
  }

  /// CU-17: Marca la asignación como completada
  Future<void> completarOrden(String token, String asignacionId) async {
    await _dio.patch(
      '/asignaciones/$asignacionId/completar',
      options: _auth(token),
    );
  }

  /// Notifica al cliente que el técnico ya llegó a su ubicación
  Future<void> reportarLlegada(String token, String asignacionId) async {
    await _dio.post(
      '/asignaciones/$asignacionId/tecnico-en-sitio',
      options: _auth(token),
    );
  }

  /// CU-07 Paso 0: El técnico registra el monto y el método de cobro.
  /// [metodoPago] = 'efectivo' cierra el pago en sitio.
  /// [metodoPago] = 'stripe'  deja pendiente para pago online del cliente.
  Future<void> registrarMonto(
    String token, {
    required String incidenteId,
    required double monto,
    String metodoPago = 'stripe',
  }) async {
    await _dio.post(
      '/pagos/registrar-monto',
      data: {
        'incidente_id': incidenteId,
        'monto': monto,
        'metodo_pago': metodoPago,
      },
      options: _auth(token),
    );
  }

  /// Historial de servicios completados por el técnico
  Future<List<ServicioHistorial>> getMisServicios(String token) async {
    final response = await _dio.get('/tecnicos/me/servicios', options: _auth(token));
    final list = response.data as List<dynamic>;
    return list
        .map((e) => ServicioHistorial.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Actualización silenciosa de ubicación (sin UI, para auto-polling)
  Future<void> actualizarUbicacionSilenciosa(
    String token, {
    required String tecnicoId,
    required double latitud,
    required double longitud,
  }) async {
    try {
      await _dio.patch(
        '/tecnicos/$tecnicoId/ubicacion',
        data: {'latitud': latitud, 'longitud': longitud},
        options: _auth(token),
      );
    } catch (_) {
      // Fallo silencioso — no interrumpir al técnico
    }
  }
}
