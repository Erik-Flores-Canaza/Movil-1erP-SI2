import 'package:flutter/foundation.dart';
import '../data/models/pago.dart';
import '../data/services/pago_service.dart';

class PagoProvider extends ChangeNotifier {
  final _service = PagoService();

  bool _loading = false;
  String? _error;
  Pago? _pagoPendiente;
  Pago? _pagoConfirmado;

  bool get loading => _loading;
  String? get error => _error;
  Pago? get pagoPendiente => _pagoPendiente;
  Pago? get pagoConfirmado => _pagoConfirmado;

  /// Carga el pago registrado por el técnico (puede estar pendiente o ya pagado).
  Future<Pago?> cargarPago(String token, {required String incidenteId}) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _pagoPendiente = await _service.getPago(token, incidenteId: incidenteId);
      return _pagoPendiente;
    } catch (e) {
      _error = e.toString();
      _pagoPendiente = null;
      return null;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Crea el PaymentIntent en Stripe (monto ya registrado por el técnico).
  Future<CrearIntentResponse?> crearIntent(
    String token, {
    required String incidenteId,
  }) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      return await _service.crearIntent(token, incidenteId: incidenteId);
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
    _pagoPendiente = null;
    _pagoConfirmado = null;
    notifyListeners();
  }
}
