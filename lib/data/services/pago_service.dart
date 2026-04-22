import 'package:dio/dio.dart';
import '../models/pago.dart';
import '../../core/dio_client.dart';

class PagoService {
  final Dio _dio = DioClient.instance.dio;

  Options _auth(String token) =>
      Options(headers: {'Authorization': 'Bearer $token'});

  /// CU-07: Crea un PaymentIntent en Stripe y devuelve el client_secret
  Future<CrearIntentResponse> crearIntent(
    String token, {
    required String incidenteId,
    required double monto,
  }) async {
    final response = await _dio.post(
      '/pagos/crear-intent',
      data: {'incidente_id': incidenteId, 'monto': monto},
      options: _auth(token),
    );
    return CrearIntentResponse.fromJson(response.data as Map<String, dynamic>);
  }

  /// CU-07: Confirma el pago ya procesado por el cliente en el PaymentSheet
  Future<Pago> confirmarPago(
    String token, {
    required String incidenteId,
    required String paymentIntentId,
    String metodo = 'tarjeta',
  }) async {
    final response = await _dio.post(
      '/pagos/confirmar',
      data: {
        'incidente_id': incidenteId,
        'payment_intent_id': paymentIntentId,
        'metodo_pago': metodo,
      },
      options: _auth(token),
    );
    return Pago.fromJson(response.data as Map<String, dynamic>);
  }
}
