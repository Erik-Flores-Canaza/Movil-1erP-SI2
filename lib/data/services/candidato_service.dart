import 'package:dio/dio.dart';
import '../models/candidato.dart';
import '../models/incidente.dart';
import '../../core/dio_client.dart';

class CandidatoService {
  final Dio _dio = DioClient.instance.dio;

  Options _auth(String token) =>
      Options(headers: {'Authorization': 'Bearer $token'});

  /// CU-20: Lista candidatos para el incidente (favoritos primero, luego por distancia).
  Future<List<TallerCandidato>> getCandidatos(
    String token, {
    required String incidenteId,
  }) async {
    final response = await _dio.get(
      '/incidentes/$incidenteId/candidatos',
      options: _auth(token),
    );
    return (response.data as List<dynamic>)
        .map((e) => TallerCandidato.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// CU-20: El cliente elige un taller específico.
  Future<Incidente> seleccionarTaller(
    String token, {
    required String incidenteId,
    required String tallerId,
  }) async {
    final response = await _dio.post(
      '/incidentes/$incidenteId/seleccionar-taller',
      data: {'taller_id': tallerId},
      options: _auth(token),
    );
    return Incidente.fromJson(response.data as Map<String, dynamic>);
  }

  /// CU-20: El sistema asigna automáticamente el mejor taller disponible.
  Future<Incidente> asignarAutomatico(
    String token, {
    required String incidenteId,
  }) async {
    final response = await _dio.post(
      '/incidentes/$incidenteId/asignar-automatico',
      options: _auth(token),
    );
    return Incidente.fromJson(response.data as Map<String, dynamic>);
  }

  /// Obtiene la lista de talleres favoritos del cliente.
  Future<List<Map<String, dynamic>>> getFavoritos(String token) async {
    final response = await _dio.get(
      '/talleres/favoritos',
      options: _auth(token),
    );
    return (response.data as List<dynamic>)
        .cast<Map<String, dynamic>>();
  }

  /// Marcar taller como favorito.
  Future<void> agregarFavorito(String token, {required String tallerId}) async {
    await _dio.post(
      '/talleres/favoritos/$tallerId',
      options: _auth(token),
    );
  }

  /// Quitar taller de favoritos.
  Future<void> quitarFavorito(String token, {required String tallerId}) async {
    await _dio.delete(
      '/talleres/favoritos/$tallerId',
      options: _auth(token),
    );
  }
}
