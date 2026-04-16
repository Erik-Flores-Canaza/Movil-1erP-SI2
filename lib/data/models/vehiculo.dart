class Vehiculo {
  final String id;           // UUID string
  final String propietarioId; // UUID string
  final String placa;
  final String marca;
  final String modelo;
  final int? anio;
  final String? color;
  final DateTime creadoEn;

  const Vehiculo({
    required this.id,
    required this.propietarioId,
    required this.placa,
    required this.marca,
    required this.modelo,
    this.anio,
    this.color,
    required this.creadoEn,
  });

  factory Vehiculo.fromJson(Map<String, dynamic> json) {
    return Vehiculo(
      id: json['id'].toString(),
      propietarioId: json['propietario_id'].toString(),
      placa: json['placa'] as String,
      marca: json['marca'] as String,
      modelo: json['modelo'] as String,
      anio: json['anio'] as int?,
      color: json['color'] as String?,
      creadoEn: json['creado_en'] != null
          ? DateTime.parse(json['creado_en'].toString())
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'placa': placa,
        'marca': marca,
        'modelo': modelo,
        if (anio != null) 'anio': anio,
        if (color != null) 'color': color,
      };

  Vehiculo copyWith({
    String? placa,
    String? marca,
    String? modelo,
    int? anio,
    String? color,
  }) =>
      Vehiculo(
        id: id,
        propietarioId: propietarioId,
        placa: placa ?? this.placa,
        marca: marca ?? this.marca,
        modelo: modelo ?? this.modelo,
        anio: anio ?? this.anio,
        color: color ?? this.color,
        creadoEn: creadoEn,
      );
}
