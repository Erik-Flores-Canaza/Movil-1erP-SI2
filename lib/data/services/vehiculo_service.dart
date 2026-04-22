import 'package:dio/dio.dart';
import '../models/vehiculo.dart';
import '../../core/dio_client.dart';

class VehiculoService {
  final Dio _dio = DioClient.instance.dio;

  Options _auth(String token) =>
      Options(headers: {'Authorization': 'Bearer $token'});

  Future<List<Vehiculo>> getVehiculos(String token) async {
    final response = await _dio.get('/vehiculos', options: _auth(token));
    final list = response.data as List<dynamic>;
    return list
        .map((e) => Vehiculo.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Vehiculo> createVehiculo(
    String token, {
    required String placa,
    required String marca,
    required String modelo,
    required int anio,
    required String color,
  }) async {
    final response = await _dio.post(
      '/vehiculos',
      data: {
        'placa': placa,
        'marca': marca,
        'modelo': modelo,
        'anio': anio,
        'color': color,
      },
      options: _auth(token),
    );
    return Vehiculo.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Vehiculo> updateVehiculo(
    String token,
    String id, {
    String? placa,
    String? marca,
    String? modelo,
    int? anio,
    String? color,
  }) async {
    final data = <String, dynamic>{};
    if (placa != null) data['placa'] = placa;
    if (marca != null) data['marca'] = marca;
    if (modelo != null) data['modelo'] = modelo;
    if (anio != null) data['anio'] = anio;
    if (color != null) data['color'] = color;

    final response = await _dio.patch(
      '/vehiculos/$id',
      data: data,
      options: _auth(token),
    );
    return Vehiculo.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> deleteVehiculo(String token, String id) async {
    await _dio.delete('/vehiculos/$id', options: _auth(token));
  }
}
