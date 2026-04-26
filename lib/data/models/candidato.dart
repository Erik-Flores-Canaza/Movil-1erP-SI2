class TallerCandidato {
  final String id;
  final String nombre;
  final String? direccion;
  final double? distanciaKm;
  final int? etaMinutos;
  final List<String> tipoServicios;
  final bool esFavorito;

  const TallerCandidato({
    required this.id,
    required this.nombre,
    this.direccion,
    this.distanciaKm,
    this.etaMinutos,
    required this.tipoServicios,
    required this.esFavorito,
  });

  factory TallerCandidato.fromJson(Map<String, dynamic> json) => TallerCandidato(
        id: json['id'].toString(),
        nombre: json['nombre'] as String,
        direccion: json['direccion'] as String?,
        distanciaKm: (json['distancia_km'] as num?)?.toDouble(),
        etaMinutos: json['eta_minutos'] as int?,
        tipoServicios: (json['tipo_servicios'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
        esFavorito: json['es_favorito'] as bool? ?? false,
      );

  TallerCandidato copyWith({bool? esFavorito}) => TallerCandidato(
        id: id,
        nombre: nombre,
        direccion: direccion,
        distanciaKm: distanciaKm,
        etaMinutos: etaMinutos,
        tipoServicios: tipoServicios,
        esFavorito: esFavorito ?? this.esFavorito,
      );
}
