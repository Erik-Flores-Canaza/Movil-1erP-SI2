import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../data/models/mensaje.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';

class ChatScreen extends StatefulWidget {
  final String incidenteId;
  const ChatScreen({super.key, required this.incidenteId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  late final ChatProvider _chatProvider;
  String _myId = '';

  @override
  void initState() {
    super.initState();
    _chatProvider = ChatProvider();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final token = context.read<AuthProvider>().token!;
      _myId = context.read<AuthProvider>().user?.id ?? '';
      await _chatProvider.cargarYConectar(token, widget.incidenteId);
      _scrollToBottom();
    });
    _chatProvider.addListener(_onMessagesChanged);
  }

  @override
  void dispose() {
    _chatProvider.removeListener(_onMessagesChanged);
    _chatProvider.desconectar();
    _chatProvider.dispose();
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onMessagesChanged() {
    if (mounted) {
      setState(() {});
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _enviar() {
    final texto = _inputController.text.trim();
    if (texto.isEmpty) return;
    _chatProvider.enviar(texto);
    _inputController.clear();
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.chat_rounded, size: 18, color: AppTheme.secondary),
            const SizedBox(width: 8),
            const Text('Chat de emergencia'),
            const Spacer(),
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: _chatProvider.connected
                    ? AppTheme.success
                    : AppTheme.textSecondary,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              _chatProvider.connected ? 'Conectado' : 'Desconectado',
              style: TextStyle(
                fontSize: 11,
                color: _chatProvider.connected
                    ? AppTheme.success
                    : AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _chatProvider.loading
                ? const Center(child: CircularProgressIndicator())
                : _chatProvider.mensajes.isEmpty
                    ? _EmptyState()
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        itemCount: _chatProvider.mensajes.length,
                        itemBuilder: (ctx, i) {
                          final msg = _chatProvider.mensajes[i];
                          final isMine = msg.remitenteId == _myId;
                          return _MessageBubble(
                            mensaje: msg,
                            isMine: isMine,
                          );
                        },
                      ),
          ),
          // Input bar
          Container(
            decoration: const BoxDecoration(
              color: AppTheme.surface,
              border: Border(top: BorderSide(color: AppTheme.border)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _inputController,
                      onSubmitted: (_) => _enviar(),
                      textInputAction: TextInputAction.send,
                      maxLines: null,
                      decoration: InputDecoration(
                        hintText: 'Escribe un mensaje...',
                        filled: true,
                        fillColor: AppTheme.surfaceElevated,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide:
                              const BorderSide(color: AppTheme.primary),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _chatProvider.connected ? _enviar : null,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: _chatProvider.connected
                            ? AppTheme.primary
                            : AppTheme.border,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.send_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Burbuja de mensaje ────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  final Mensaje mensaje;
  final bool isMine;
  const _MessageBubble({required this.mensaje, required this.isMine});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment:
            isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMine) ...[
            _Avatar(
              nombre: mensaje.nombreRemitente,
              rol: mensaje.rolRemitente,
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!isMine)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3, left: 4),
                    child: Text(
                      '${mensaje.nombreRemitente} · ${_rolLabel(mensaje.rolRemitente)}',
                      style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isMine
                        ? AppTheme.primary
                        : AppTheme.surfaceElevated,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isMine ? 16 : 4),
                      bottomRight: Radius.circular(isMine ? 4 : 16),
                    ),
                    border: isMine
                        ? null
                        : Border.all(color: AppTheme.border),
                  ),
                  child: Text(
                    mensaje.contenido,
                    style: TextStyle(
                      color: isMine ? Colors.white : AppTheme.textPrimary,
                      fontSize: 14,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 3, left: 4, right: 4),
                  child: Text(
                    _hora(mensaje.creadoEn),
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 10),
                  ),
                ),
              ],
            ),
          ),
          if (isMine) ...[
            const SizedBox(width: 8),
            _Avatar(
              nombre: mensaje.nombreRemitente,
              rol: mensaje.rolRemitente,
              isMine: true,
            ),
          ],
        ],
      ),
    );
  }

  String _rolLabel(String rol) {
    switch (rol) {
      case 'taller':
        return 'Taller';
      case 'tecnico':
        return 'Técnico';
      default:
        return 'Cliente';
    }
  }

  String _hora(DateTime dt) {
    final l = dt.toLocal();
    return '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
  }
}

// ── Avatar ────────────────────────────────────────────────────────────────────

class _Avatar extends StatelessWidget {
  final String nombre;
  final String rol;
  final bool isMine;
  const _Avatar({
    required this.nombre,
    required this.rol,
    this.isMine = false,
  });

  Color get _color {
    if (isMine) return AppTheme.primary;
    switch (rol) {
      case 'taller':
        return AppTheme.secondary;
      case 'tecnico':
        return const Color(0xFF58A6FF); // azul para técnico
      default:
        return AppTheme.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: _color.withAlpha(30),
        shape: BoxShape.circle,
        border: Border.all(color: _color.withAlpha(80)),
      ),
      child: Center(
        child: Text(
          nombre.isNotEmpty ? nombre[0].toUpperCase() : '?',
          style: TextStyle(
              color: _color, fontSize: 12, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline_rounded,
              color: AppTheme.textSecondary, size: 52),
          SizedBox(height: 16),
          Text('Sin mensajes aún',
              style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600)),
          SizedBox(height: 6),
          Text('El taller o técnico se comunicará contigo aquí',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
        ],
      ),
    );
  }
}
