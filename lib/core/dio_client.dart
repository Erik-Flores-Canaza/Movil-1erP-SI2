import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'constants.dart';

/// Singleton Dio compartido por todos los servicios.
/// Intercepta 401, intenta refrescar el token automáticamente y reintenta
/// la petición original. Si el refresh también falla, notifica [sessionExpired].
class DioClient {
  DioClient._();
  static final DioClient instance = DioClient._();

  // Notifica al root widget cuando la sesión caducó y no pudo renovarse.
  final ValueNotifier<bool> sessionExpired = ValueNotifier(false);

  // Callback que actualiza el _token en AuthProvider sin notifyListeners()
  void Function(String newToken)? onTokenRefreshed;

  String? _refreshToken;

  late final Dio _dio = _build();

  Dio get dio => _dio;

  void setRefreshToken(String? token) => _refreshToken = token;

  Dio _build() {
    final dio = Dio(BaseOptions(
      baseUrl: AppConstants.baseUrl,
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 20),
    ));

    dio.interceptors.add(InterceptorsWrapper(
      onError: (error, handler) async {
        if (error.response?.statusCode != 401 || _refreshToken == null) {
          handler.next(error);
          return;
        }

        // Evitar bucle: si el propio request de refresh devuelve 401
        final path = error.requestOptions.path;
        if (path.contains('/auth/refresh')) {
          handler.next(error);
          return;
        }

        try {
          // Usar Dio sin interceptor para no causar recursión
          final refreshDio = Dio(BaseOptions(baseUrl: AppConstants.baseUrl));
          final res = await refreshDio.post(
            '/auth/refresh',
            data: {'refresh_token': _refreshToken},
          );

          final data = res.data as Map<String, dynamic>;
          final newAccess = data['access_token'] as String;
          final newRefresh = data['refresh_token'] as String?;

          _refreshToken = newRefresh ?? _refreshToken;

          // Persistir en SharedPreferences
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(AppConstants.tokenKey, newAccess);
          if (newRefresh != null) {
            await prefs.setString(AppConstants.refreshTokenKey, newRefresh);
          }

          // Notificar a AuthProvider para que actualice su _token en memoria
          onTokenRefreshed?.call(newAccess);

          // Reintentar la petición original con el nuevo token
          error.requestOptions.headers['Authorization'] = 'Bearer $newAccess';
          final retry = await _dio.fetch(error.requestOptions);
          handler.resolve(retry);
        } catch (_) {
          // El refresh también falló: sesión expirada definitivamente
          _refreshToken = null;
          sessionExpired.value = true;
          handler.next(error);
        }
      },
    ));

    return dio;
  }
}
