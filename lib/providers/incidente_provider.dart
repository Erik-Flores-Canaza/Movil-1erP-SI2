import 'package:flutter/foundation.dart';
import '../data/models/incidente.dart';
import '../data/services/incidente_service.dart';

class IncidenteProvider extends ChangeNotifier {
  final _service = IncidenteService();

  List<Incidente> _incidentes = [];
  Incidente? _activo; // incidente en monitoreo actual
  bool _loading = false;
  String? _error;

  List<Incidente> get incidentes => _incidentes;
  Incidente? get activo => _activo;
  bool get loading => _loading;
  String? get error => _error;

  void _setLoading(bool v) {
    _loading = v;
    notifyListeners();
  }

  Future<Incidente> crear(
    String token, {
    required double latitud,
    required double longitud,
    String? descripcion,
    String? vehiculoId,
  }) async {
    _setLoading(true);
    _error = null;
    try {
      final inc = await _service.createIncidente(
        token,
        latitud: latitud,
        longitud: longitud,
        descripcion: descripcion,
        vehiculoId: vehiculoId,
      );
      _activo = inc;
      _incidentes = [inc, ..._incidentes];
      notifyListeners();
      return inc;
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// CU-18+19+20: Llama al endpoint que dispara análisis IA + asignación.
  Future<void> analizar(String token, {required String incidenteId}) async {
    final inc = await _service.analizar(token, incidenteId);
    _activo = inc;
    final idx = _incidentes.indexWhere((i) => i.id == incidenteId);
    if (idx != -1) _incidentes[idx] = inc;
    notifyListeners();
  }

  Future<void> subirEvidencia(
    String token, {
    required String incidenteId,
    required String filePath,
    required String tipo,
  }) async {
    await _service.subirEvidencia(
      token,
      incidenteId: incidenteId,
      filePath: filePath,
      tipo: tipo,
    );
  }

  Future<void> cargarMisIncidentes(String token) async {
    _setLoading(true);
    _error = null;
    try {
      _incidentes = await _service.getMisIncidentes(token);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  /// CU-05: Cancelar solicitud — solo disponible mientras no fue atendida.
  Future<void> cancelar(String token, String incidenteId) async {
    final inc = await _service.cancelar(token, incidenteId);
    _activo = inc;
    final idx = _incidentes.indexWhere((i) => i.id == incidenteId);
    if (idx != -1) _incidentes[idx] = inc;
    notifyListeners();
  }

  /// Refresca el incidente activo (para polling en MonitorScreen)
  Future<void> refrescarActivo(String token, String id) async {
    try {
      final inc = await _service.getIncidente(token, id);
      _activo = inc;
      // Actualiza también en la lista si existe
      final idx = _incidentes.indexWhere((i) => i.id == id);
      if (idx != -1) _incidentes[idx] = inc;
      notifyListeners();
    } catch (_) {
      // No mostrar error en polling silencioso
    }
  }

  void setActivo(Incidente inc) {
    _activo = inc;
    notifyListeners();
  }

  void clearActivo() {
    _activo = null;
    notifyListeners();
  }
}
