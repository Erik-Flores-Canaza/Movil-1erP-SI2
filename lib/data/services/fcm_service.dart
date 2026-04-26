import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../../core/dio_client.dart';

/// Maneja el token FCM y los permisos de notificaciones push.
class FcmService {
  final Dio _dio = DioClient.instance.dio;
  final _messaging = FirebaseMessaging.instance;

  /// Solicita permisos y registra el token FCM en el backend.
  /// Llamar después de un login exitoso.
  Future<void> init(String token) async {
    // Pedir permiso al usuario (iOS lo muestra, Android lo acepta automático)
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.denied) return;

    // Obtener el token del dispositivo
    final fcmToken = await _messaging.getToken();
    if (fcmToken == null) return;

    // Registrar en el backend
    await _enviarToken(token, fcmToken);

    // Si el token se renueva, actualizarlo en el backend
    _messaging.onTokenRefresh.listen((newToken) {
      _enviarToken(token, newToken);
    });

    // Manejar notificación cuando la app está en primer plano
    FirebaseMessaging.onMessage.listen((message) {
      // La notificación ya la muestra el sistema operativo en background.
      // En foreground puedes mostrar un snackbar/dialog si quieres.
      // Por ahora solo se registra — el provider de notificaciones
      // ya hace polling y WebSocket no aplica a Flutter.
    });
  }

  Future<void> _enviarToken(String authToken, String fcmToken) async {
    try {
      await _dio.patch(
        '/usuarios/me/fcm-token',
        data: {'fcm_token': fcmToken},
        options: Options(headers: {'Authorization': 'Bearer $authToken'}),
      );
    } catch (_) {
      // Silencioso — no es crítico para el flujo principal
    }
  }
}
