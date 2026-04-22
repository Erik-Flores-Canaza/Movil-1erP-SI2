import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/mensaje.dart';
import '../../core/constants.dart';
import '../../core/dio_client.dart';

class ChatService {
  final Dio _dio = DioClient.instance.dio;

  Options _auth(String token) =>
      Options(headers: {'Authorization': 'Bearer $token'});

  WebSocketChannel? _channel;
  final _controller = StreamController<Mensaje>.broadcast();
  bool _intentionalClose = false;

  Stream<Mensaje> get mensajesStream => _controller.stream;

  /// Carga el historial de mensajes del incidente
  Future<List<Mensaje>> getMensajes(String token, String incidenteId) async {
    final response = await _dio.get(
      '/mensajes/$incidenteId',
      options: _auth(token),
    );
    final list = response.data as List<dynamic>;
    return list
        .map((e) => Mensaje.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Conecta al WebSocket para recibir mensajes en tiempo real
  void connect(String token, String incidenteId) {
    _intentionalClose = false;
    final wsBase = AppConstants.baseUrl
        .replaceFirst('http://', 'ws://')
        .replaceFirst('https://', 'wss://');
    final uri = Uri.parse('$wsBase/ws/chat/$incidenteId?token=$token');

    _channel = WebSocketChannel.connect(uri);
    _channel!.stream.listen(
      (raw) {
        try {
          final data = jsonDecode(raw as String) as Map<String, dynamic>;
          _controller.add(Mensaje.fromJson(data));
        } catch (_) {
          // Ignorar mensajes mal formados
        }
      },
      onError: (_) => _channel = null,
      onDone: () {
        if (!_intentionalClose) _channel = null;
      },
    );
  }

  /// Envía un mensaje de texto a través del WebSocket
  void enviarTexto(String texto) {
    _channel?.sink.add(jsonEncode({'contenido': texto}));
  }

  /// Desconecta el WebSocket
  void disconnect() {
    _intentionalClose = true;
    _channel?.sink.close();
    _channel = null;
  }

  void dispose() {
    disconnect();
    _controller.close();
  }
}
