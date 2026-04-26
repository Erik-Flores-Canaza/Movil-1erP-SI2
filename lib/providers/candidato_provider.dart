import 'package:flutter/foundation.dart';
import '../data/models/candidato.dart';
import '../data/models/incidente.dart';
import '../data/services/candidato_service.dart';

class CandidatoProvider extends ChangeNotifier {
  final _service = CandidatoService();

  List<TallerCandidato> _candidatos = [];
  bool _loading = false;
  bool _asignando = false;
  String? _error;

  /// IDs de talleres favoritos del cliente (cargados aparte para el monitor).
  final Set<String> _favoritoIds = {};

  List<TallerCandidato> get candidatos => _candidatos;
  bool get loading => _loading;
  bool get asignando => _asignando;
  String? get error => _error;

  bool esFavorito(String tallerId) => _favoritoIds.contains(tallerId);

  /// Carga la lista de candidatos para el incidente dado.
  Future<void> cargarCandidatos(String token,
      {required String incidenteId}) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _candidatos = await _service.getCandidatos(token, incidenteId: incidenteId);
    } catch (e) {
      _error = e.toString();
      _candidatos = [];
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// El cliente elige un taller específico. Retorna el incidente actualizado.
  Future<Incidente?> seleccionarTaller(
    String token, {
    required String incidenteId,
    required String tallerId,
  }) async {
    _asignando = true;
    _error = null;
    notifyListeners();
    try {
      final inc = await _service.seleccionarTaller(token,
          incidenteId: incidenteId, tallerId: tallerId);
      return inc;
    } catch (e) {
      _error = _parseError(e);
      return null;
    } finally {
      _asignando = false;
      notifyListeners();
    }
  }

  /// El sistema asigna automáticamente. Retorna el incidente actualizado.
  Future<Incidente?> asignarAutomatico(String token,
      {required String incidenteId}) async {
    _asignando = true;
    _error = null;
    notifyListeners();
    try {
      final inc = await _service.asignarAutomatico(token, incidenteId: incidenteId);
      return inc;
    } catch (e) {
      _error = _parseError(e);
      return null;
    } finally {
      _asignando = false;
      notifyListeners();
    }
  }

  /// Carga la lista de IDs de talleres favoritos del cliente.
  /// Usado en el monitor para saber si el taller asignado es favorito.
  Future<void> cargarFavoritos(String token) async {
    try {
      final lista = await _service.getFavoritos(token);
      _favoritoIds
        ..clear()
        ..addAll(lista.map((f) => f['taller_id'] as String));
      notifyListeners();
    } catch (_) {
      // silencioso — no crítico
    }
  }

  /// Toggle favorito local + llamada al backend.
  /// Funciona tanto para la lista de candidatos como para el monitor.
  Future<void> toggleFavorito(
    String token, {
    required String tallerId,
    required bool esFavoritoActual,
  }) async {
    // Optimistic update
    _candidatos = _candidatos
        .map((c) => c.id == tallerId ? c.copyWith(esFavorito: !esFavoritoActual) : c)
        .toList();
    if (esFavoritoActual) {
      _favoritoIds.remove(tallerId);
    } else {
      _favoritoIds.add(tallerId);
    }
    notifyListeners();

    try {
      if (esFavoritoActual) {
        await _service.quitarFavorito(token, tallerId: tallerId);
      } else {
        await _service.agregarFavorito(token, tallerId: tallerId);
      }
    } catch (_) {
      // Revertir si falla
      _candidatos = _candidatos
          .map((c) => c.id == tallerId ? c.copyWith(esFavorito: esFavoritoActual) : c)
          .toList();
      if (esFavoritoActual) {
        _favoritoIds.add(tallerId);
      } else {
        _favoritoIds.remove(tallerId);
      }
      notifyListeners();
    }
  }

  void reset() {
    _candidatos = [];
    _loading = false;
    _asignando = false;
    _error = null;
    notifyListeners();
  }

  String _parseError(Object e) {
    final str = e.toString();
    if (str.contains('409')) return 'El taller ya no está disponible. Elige otro.';
    if (str.contains('503')) return 'No hay talleres disponibles en este momento.';
    return 'Error al procesar la selección.';
  }
}
