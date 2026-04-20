import 'package:dio/dio.dart';
import '../models/incidente.dart';
import '../../core/constants.dart';

class IncidenteService {
  final Dio _dio = Dio(BaseOptions(
    baseUrl: AppConstants.baseUrl,
    connectTimeout: const Duration(seconds: 20),
    receiveTimeout: const Duration(seconds: 20),
  ));

  Options _auth(String token) =>
      Options(headers: {'Authorization': 'Bearer $token'});

  /// CU-05: Crear incidente (sin evidencias aún)
  Future<Incidente> createIncidente(
    String token, {
    required double latitud,
    required double longitud,
    String? descripcion,
    String? vehiculoId,
  }) async {
    final data = <String, dynamic>{
      'latitud': latitud,
      'longitud': longitud,
      if (descripcion != null && descripcion.isNotEmpty)
        'descripcion': descripcion,
      if (vehiculoId != null) 'vehiculo_id': vehiculoId,
    };

    final response = await _dio.post(
      '/incidentes',
      data: data,
      options: _auth(token),
    );
    return Incidente.fromJson(response.data as Map<String, dynamic>);
  }

  /// CU-05: Subir evidencia (imagen/audio/texto)
  Future<Evidencia> subirEvidencia(
    String token, {
    required String incidenteId,
    required String filePath,
    required String tipo, // 'imagen' | 'audio' | 'texto'
  }) async {
    final formData = FormData.fromMap({
      'tipo': tipo,
      'archivo': await MultipartFile.fromFile(filePath),
    });

    final response = await _dio.post(
      '/incidentes/$incidenteId/evidencias',
      data: formData,
      options: Options(
        headers: {'Authorization': 'Bearer $token'},
        contentType: 'multipart/form-data',
      ),
    );
    return Evidencia.fromJson(response.data as Map<String, dynamic>);
  }

  /// CU-06: Lista de incidentes del cliente autenticado
  Future<List<Incidente>> getMisIncidentes(String token) async {
    final response = await _dio.get(
      '/incidentes/mis-incidentes',
      options: _auth(token),
    );
    final list = response.data as List<dynamic>;
    return list
        .map((e) => Incidente.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// CU-06: Detalle de un incidente (con asignación anidada)
  Future<Incidente> getIncidente(String token, String id) async {
    final response =
        await _dio.get('/incidentes/$id', options: _auth(token));
    return Incidente.fromJson(response.data as Map<String, dynamic>);
  }

  /// CU-05: Cancelar la solicitud (solo cliente, solo si no fue atendida).
  Future<Incidente> cancelar(String token, String incidenteId) async {
    final response = await _dio.post(
      '/incidentes/$incidenteId/cancelar',
      options: _auth(token),
    );
    return Incidente.fromJson(response.data as Map<String, dynamic>);
  }

  /// CU-18+19+20: Dispara análisis IA + asignación sobre las evidencias ya subidas.
  Future<Incidente> analizar(String token, String incidenteId) async {
    final response = await _dio.post(
      '/incidentes/$incidenteId/analizar',
      options: Options(
        headers: {'Authorization': 'Bearer $token'},
        receiveTimeout: const Duration(seconds: 60), // IA puede tardar
      ),
    );
    return Incidente.fromJson(response.data as Map<String, dynamic>);
  }
}
