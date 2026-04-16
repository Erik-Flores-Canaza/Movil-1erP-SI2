import 'package:flutter/foundation.dart';
import '../data/models/vehiculo.dart';
import '../data/services/vehiculo_service.dart';

class VehiculoProvider extends ChangeNotifier {
  final _service = VehiculoService();

  List<Vehiculo> _vehiculos = [];
  bool _loading = false;
  String? _error;

  List<Vehiculo> get vehiculos => _vehiculos;
  bool get loading => _loading;
  String? get error => _error;

  Future<void> load(String token) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _vehiculos = await _service.getVehiculos(token);
    } catch (_) {
      _error = 'No se pudieron cargar los vehículos';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> add(
    String token, {
    required String placa,
    required String marca,
    required String modelo,
    required int anio,
    required String color,
  }) async {
    final v = await _service.createVehiculo(
      token,
      placa: placa,
      marca: marca,
      modelo: modelo,
      anio: anio,
      color: color,
    );
    _vehiculos.add(v);
    notifyListeners();
  }

  Future<void> update(
    String token,
    String id, {
    String? placa,
    String? marca,
    String? modelo,
    int? anio,
    String? color,
  }) async {
    final updated = await _service.updateVehiculo(
      token,
      id,
      placa: placa,
      marca: marca,
      modelo: modelo,
      anio: anio,
      color: color,
    );
    final idx = _vehiculos.indexWhere((v) => v.id == id);
    if (idx != -1) {
      _vehiculos[idx] = updated;
      notifyListeners();
    }
  }

  Future<void> delete(String token, String id) async {
    await _service.deleteVehiculo(token, id);
    _vehiculos.removeWhere((v) => v.id == id);
    notifyListeners();
  }
}
