/// El backend envía ISO-8601 sin 'Z'. Forzamos UTC para comparaciones correctas.
DateTime _parseUtc(String s) =>
    DateTime.parse(s.endsWith('Z') || s.contains('+') ? s : '${s}Z');

class TallerResumen {
  final String id;
  final String nombre;
  final String? telefono;
  final double? latitud;
  final double? longitud;

  const TallerResumen({
    required this.id,
    required this.nombre,
    this.telefono,
    this.latitud,
    this.longitud,
  });

  factory TallerResumen.fromJson(Map<String, dynamic> json) => TallerResumen(
        id: json['id'].toString(),
        nombre: json['nombre'] as String,
        telefono: json['telefono'] as String?,
        latitud: (json['latitud'] as num?)?.toDouble(),
        longitud: (json['longitud'] as num?)?.toDouble(),
      );
}

class TecnicoResumen {
  final String id;
  final String nombreCompleto;
  final String? telefono;
  final double? latitudActual;
  final double? longitudActual;

  const TecnicoResumen({
    required this.id,
    required this.nombreCompleto,
    this.telefono,
    this.latitudActual,
    this.longitudActual,
  });

  factory TecnicoResumen.fromJson(Map<String, dynamic> json) => TecnicoResumen(
        id: json['id'].toString(),
        nombreCompleto: json['nombre_completo'] as String? ?? '',
        telefono: json['telefono'] as String?,
        latitudActual: (json['latitud_actual'] as num?)?.toDouble(),
        longitudActual: (json['longitud_actual'] as num?)?.toDouble(),
      );
}

class AsignacionResumen {
  final String id;
  final String? accionTaller;
  final int? etaMinutos;
  final DateTime? completadoEn;
  final TallerResumen? taller;
  final TecnicoResumen? tecnico;

  const AsignacionResumen({
    required this.id,
    this.accionTaller,
    this.etaMinutos,
    this.completadoEn,
    this.taller,
    this.tecnico,
  });

  factory AsignacionResumen.fromJson(Map<String, dynamic> json) =>
      AsignacionResumen(
        id: json['id'].toString(),
        accionTaller: json['accion_taller'] as String?,
        etaMinutos: json['eta_minutos'] as int?,
        completadoEn: json['completado_en'] != null
            ? _parseUtc(json['completado_en'].toString())
            : null,
        taller: json['taller'] != null
            ? TallerResumen.fromJson(json['taller'] as Map<String, dynamic>)
            : null,
        tecnico: json['tecnico'] != null
            ? TecnicoResumen.fromJson(json['tecnico'] as Map<String, dynamic>)
            : null,
      );
}

class Evidencia {
  final String id;
  final String tipo;
  final String archivoUrl;

  const Evidencia({
    required this.id,
    required this.tipo,
    required this.archivoUrl,
  });

  factory Evidencia.fromJson(Map<String, dynamic> json) => Evidencia(
        id: json['id'].toString(),
        tipo: json['tipo'] as String? ?? 'imagen',
        archivoUrl: json['archivo_url'] as String? ?? '',
      );
}

class Incidente {
  final String id;
  final String estado;
  final String? descripcion;
  final double latitud;
  final double longitud;
  final String? clasificacionIa;
  final String? prioridad;
  final String? resumenIa;
  final DateTime creadoEn;
  final String? vehiculoId;
  final AsignacionResumen? asignacion;
  final List<Evidencia> evidencias;
  final bool pagado;

  const Incidente({
    required this.id,
    required this.estado,
    this.descripcion,
    required this.latitud,
    required this.longitud,
    this.clasificacionIa,
    this.prioridad,
    this.resumenIa,
    required this.creadoEn,
    this.vehiculoId,
    this.asignacion,
    this.evidencias = const [],
    this.pagado = false,
  });

  factory Incidente.fromJson(Map<String, dynamic> json) => Incidente(
        id: json['id'].toString(),
        estado: json['estado'] as String? ?? 'pendiente',
        descripcion: json['descripcion'] as String?,
        latitud: (json['latitud'] as num).toDouble(),
        longitud: (json['longitud'] as num).toDouble(),
        clasificacionIa: json['clasificacion_ia'] as String?,
        prioridad: json['prioridad'] as String?,
        resumenIa: json['resumen_ia'] as String?,
        creadoEn: json['creado_en'] != null
            ? _parseUtc(json['creado_en'].toString())
            : DateTime.now(),
        vehiculoId: json['vehiculo_id']?.toString(),
        asignacion: json['asignacion'] != null
            ? AsignacionResumen.fromJson(
                json['asignacion'] as Map<String, dynamic>)
            : null,
        evidencias: (json['evidencias'] as List<dynamic>?)
                ?.map((e) => Evidencia.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        pagado: json['pagado'] as bool? ?? false,
      );

  /// Human-readable label for estado
  String get estadoLabel {
    const map = {
      'pendiente': 'Pendiente',
      'en_proceso': 'En proceso',
      'atendido': 'Atendido',
      'cancelado': 'Cancelado',
    };
    return map[estado] ?? estado;
  }

  /// Human-readable label for prioridad
  String get prioridadLabel {
    const map = {
      'alta': 'Alta',
      'media': 'Media',
      'baja': 'Baja',
      'incierto': 'Por clasificar',
    };
    return map[prioridad ?? ''] ?? (prioridad ?? '-');
  }
}
