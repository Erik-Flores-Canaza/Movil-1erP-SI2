import 'package:flutter/foundation.dart';
import '../data/models/notificacion.dart';
import '../data/services/notificacion_service.dart';

class NotificacionProvider extends ChangeNotifier {
  final _service = NotificacionService();

  List<Notificacion> _notificaciones = [];
  bool _loading = false;

  List<Notificacion> get notificaciones => _notificaciones;
  bool get loading => _loading;
  int get noLeidas => _notificaciones.where((n) => !n.leida).length;

  Future<void> cargar(String token) async {
    _loading = true;
    notifyListeners();
    try {
      _notificaciones = await _service.getNotificaciones(token);
    } catch (_) {
      // Fallo silencioso en polling
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> marcarLeida(String token, String id) async {
    try {
      await _service.marcarLeida(token, id);
      final idx = _notificaciones.indexWhere((n) => n.id == id);
      if (idx != -1) {
        _notificaciones[idx] = _notificaciones[idx].copyWith(leida: true);
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> marcarTodasLeidas(String token) async {
    try {
      await _service.marcarTodasLeidas(token);
      _notificaciones =
          _notificaciones.map((n) => n.copyWith(leida: true)).toList();
      notifyListeners();
    } catch (_) {}
  }
}
