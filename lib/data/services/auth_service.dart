import 'package:dio/dio.dart';
import '../models/usuario.dart';
import '../../core/constants.dart';

class AuthService {
  final Dio _dio = Dio(BaseOptions(
    baseUrl: AppConstants.baseUrl,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
  ));

  /// Returns access_token and optional refresh_token.
  /// El endpoint espera JSON: { "correo": "...", "contrasena": "..." }
  Future<Map<String, dynamic>> login(String correo, String password) async {
    final response = await _dio.post(
      '/auth/login',
      data: {'correo': correo, 'contrasena': password},
    );
    return response.data as Map<String, dynamic>;
  }

  /// Registers a new client. Endpoint: POST /auth/registro
  /// Campos: nombre_completo, correo, contrasena, telefono (rol lo asigna el backend)
  Future<Usuario> register({
    required String nombreCompleto,
    required String correo,
    required String telefono,
    required String password,
  }) async {
    final response = await _dio.post('/auth/registro', data: {
      'nombre_completo': nombreCompleto,
      'correo': correo,
      'contrasena': password,
      'telefono': telefono,
    });
    return Usuario.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> logout(String token) async {
    try {
      await _dio.post(
        '/auth/logout',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
    } catch (_) {
      // Silently ignore — we clear local session regardless
    }
  }
}
