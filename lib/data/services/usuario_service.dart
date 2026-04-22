import 'package:dio/dio.dart';
import '../models/usuario.dart';
import '../../core/dio_client.dart';

class UsuarioService {
  final Dio _dio = DioClient.instance.dio;

  Options _auth(String token) =>
      Options(headers: {'Authorization': 'Bearer $token'});

  Future<Usuario> getMe(String token) async {
    final response = await _dio.get('/usuarios/me', options: _auth(token));
    return Usuario.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Usuario> updateMe(
    String token, {
    String? nombreCompleto,
    String? telefono,
  }) async {
    final data = <String, dynamic>{};
    if (nombreCompleto != null) data['nombre_completo'] = nombreCompleto;
    if (telefono != null) data['telefono'] = telefono;

    final response = await _dio.patch(
      '/usuarios/me',
      data: data,
      options: _auth(token),
    );
    return Usuario.fromJson(response.data as Map<String, dynamic>);
  }
}
