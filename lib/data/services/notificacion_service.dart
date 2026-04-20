import 'package:dio/dio.dart';
import '../models/notificacion.dart';
import '../../core/constants.dart';

class NotificacionService {
  final Dio _dio = Dio(BaseOptions(
    baseUrl: AppConstants.baseUrl,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
  ));

  Options _auth(String token) =>
      Options(headers: {'Authorization': 'Bearer $token'});

  Future<List<Notificacion>> getNotificaciones(String token) async {
    final response =
        await _dio.get('/notificaciones', options: _auth(token));
    final list = response.data as List<dynamic>;
    return list
        .map((e) => Notificacion.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> marcarLeida(String token, String id) async {
    await _dio.patch('/notificaciones/$id/leer', options: _auth(token));
  }

  Future<void> marcarTodasLeidas(String token) async {
    await _dio.patch('/notificaciones/leer-todas', options: _auth(token));
  }
}
