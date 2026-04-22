import 'dart:async';
import 'package:flutter/foundation.dart';
import '../data/models/mensaje.dart';
import '../data/services/chat_service.dart';

class ChatProvider extends ChangeNotifier {
  final _service = ChatService();

  List<Mensaje> _mensajes = [];
  bool _loading = false;
  bool _connected = false;
  String? _error;
  StreamSubscription<Mensaje>? _sub;

  List<Mensaje> get mensajes => _mensajes;
  bool get loading => _loading;
  bool get connected => _connected;
  String? get error => _error;

  Future<void> cargarYConectar(
      String token, String incidenteId) async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      _mensajes = await _service.getMensajes(token, incidenteId);
    } catch (e) {
      _error = e.toString();
    }

    _loading = false;
    notifyListeners();

    // Conectar WebSocket para mensajes en tiempo real
    _sub?.cancel();
    _service.connect(token, incidenteId);
    _connected = true;
    notifyListeners();

    _sub = _service.mensajesStream.listen((msg) {
      // Evitar duplicados (el WS puede reemitir el mensaje propio)
      if (!_mensajes.any((m) => m.id == msg.id)) {
        _mensajes = [..._mensajes, msg];
        notifyListeners();
      }
    });
  }

  void enviar(String texto) {
    if (!_connected || texto.trim().isEmpty) return;
    _service.enviarTexto(texto.trim());
  }

  void desconectar() {
    _sub?.cancel();
    _service.disconnect();
    _connected = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _service.dispose();
    super.dispose();
  }
}
