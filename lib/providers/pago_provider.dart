import 'package:flutter/foundation.dart';
import '../data/models/pago.dart';
import '../data/services/pago_service.dart';

class PagoProvider extends ChangeNotifier {
  final _service = PagoService();

  bool _loading = false;
  String? _error;
  Pago? _pagoConfirmado;

  bool get loading => _loading;
  String? get error => _error;
  Pago? get pagoConfirmado => _pagoConfirmado;

  Future<CrearIntentResponse?> crearIntent(
    String token, {
    required String incidenteId,
    required double monto,
  }) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      return await _service.crearIntent(token,
          incidenteId: incidenteId, monto: monto);
    } catch (e) {
      _error = e.toString();
      return null;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<bool> confirmarPago(
    String token, {
    required String incidenteId,
    required String paymentIntentId,
  }) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _pagoConfirmado = await _service.confirmarPago(
        token,
        incidenteId: incidenteId,
        paymentIntentId: paymentIntentId,
      );
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void reset() {
    _loading = false;
    _error = null;
    _pagoConfirmado = null;
    notifyListeners();
  }
}
