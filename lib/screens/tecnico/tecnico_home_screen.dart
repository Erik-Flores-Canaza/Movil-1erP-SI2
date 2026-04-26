import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../data/services/tecnico_service.dart';
import 'mis_servicios_screen.dart' show mostrarDialogoMonto;
import '../../providers/auth_provider.dart';
import '../../providers/notificacion_provider.dart';

class TecnicoHomeScreen extends StatefulWidget {
  const TecnicoHomeScreen({super.key});

  @override
  State<TecnicoHomeScreen> createState() => _TecnicoHomeScreenState();
}

class _TecnicoHomeScreenState extends State<TecnicoHomeScreen> {
  final _service = TecnicoService();

  TecnicoMe? _tecnico;
  OrdenActiva? _orden;
  bool _loading = true;
  bool _updatingLocation = false;
  bool _completing = false;
  bool _llegado = false;       // "Ya llegué" ya fue presionado
  bool _reportandoLlegada = false;
  Timer? _pollTimer;
  Timer? _locationTimer;       // auto-actualiza ubicación cada 30s con orden activa

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _locationTimer?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    setState(() => _loading = true);
    await _loadData();
    setState(() => _loading = false);
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) => _loadOrden());
    // Actualización automática de ubicación cada 30s cuando hay orden activa
    _locationTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _actualizarUbicacionSilenciosa(),
    );

    // Cargar notificaciones
    if (!mounted) return;
    final token = context.read<AuthProvider>().token;
    if (token != null) {
      context.read<NotificacionProvider>().cargar(token);
    }

    // Actualizar ubicación al entrar — silenciosamente si ya tenemos permiso,
    // o pedirlo si es la primera vez
    _actualizarUbicacionAlEntrar();
  }

  Future<void> _actualizarUbicacionAlEntrar() async {
    if (_tecnico == null) return;
    final token = context.read<AuthProvider>().token;
    if (token == null) return;

    // Verificar permiso primero
    var locationStatus = await Permission.locationWhenInUse.status;
    if (locationStatus.isDenied) {
      locationStatus = await Permission.locationWhenInUse.request();
    }
    if (!locationStatus.isGranted) return;

    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );
      await _service.actualizarUbicacionSilenciosa(
        token,
        tecnicoId: _tecnico!.id,
        latitud: pos.latitude,
        longitud: pos.longitude,
      );
    } catch (_) {}
  }

  Future<void> _loadData() async {
    final token = context.read<AuthProvider>().token;
    if (token == null) return;
    try {
      _tecnico = await _service.getMe(token);
      _orden = await _service.getOrdenActiva(token);
      // Restaurar estado "ya llegué" desde almacenamiento persistente
      if (_orden != null) {
        final prefs = await SharedPreferences.getInstance();
        final llegadoId = prefs.getString('llegado_asignacion_id');
        _llegado = llegadoId == _orden!.id;
      } else {
        _llegado = false;
      }
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) _showError('Error al cargar datos: ${e.toString()}');
    }
  }

  Future<void> _loadOrden() async {
    final token = context.read<AuthProvider>().token;
    if (token == null) return;
    try {
      _orden = await _service.getOrdenActiva(token);
      if (mounted) setState(() {});
    } catch (_) {}
  }

  /// Actualización silenciosa cada 30s — solo cuando hay orden activa
  Future<void> _actualizarUbicacionSilenciosa() async {
    if (_orden == null || _tecnico == null) return;
    final token = context.read<AuthProvider>().token;
    if (token == null) return;
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 10),
      );
      await _service.actualizarUbicacionSilenciosa(
        token,
        tecnicoId: _tecnico!.id,
        latitud: pos.latitude,
        longitud: pos.longitude,
      );
    } catch (_) {}
  }

  Future<void> _actualizarUbicacion() async {
    if (_tecnico == null) return;
    final status = await Permission.locationWhenInUse.request();
    if (!status.isGranted) {
      _showError('Se necesita permiso de ubicación.');
      return;
    }
    setState(() => _updatingLocation = true);
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );
      if (!mounted) return;
      final token = context.read<AuthProvider>().token;
      if (token == null) return;
      await _service.actualizarUbicacion(
        token,
        tecnicoId: _tecnico!.id,
        latitud: pos.latitude,
        longitud: pos.longitude,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ubicación actualizada correctamente')),
        );
      }
    } catch (e) {
      _showError('No se pudo obtener la ubicación. Intenta de nuevo.');
    } finally {
      if (mounted) setState(() => _updatingLocation = false);
    }
  }

  Future<void> _reportarLlegada() async {
    if (_orden == null) return;
    final token = context.read<AuthProvider>().token;
    if (token == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Ya llegaste?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('El cliente recibirá una notificación indicando que ya estás en su ubicación.'),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Sí, ya llegué'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
          ],
        ),
      ),
    );
    if (confirm != true || !mounted) return;

    setState(() => _reportandoLlegada = true);
    try {
      await _service.reportarLlegada(token, _orden!.id);
      // Persistir para sobrevivir cierres de sesión y reinicios
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('llegado_asignacion_id', _orden!.id);
      if (mounted) {
        setState(() => _llegado = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('El cliente fue notificado de tu llegada.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo enviar la notificación.')),
        );
      }
    } finally {
      if (mounted) setState(() => _reportandoLlegada = false);
    }
  }

  Future<void> _completarOrden() async {
    if (_orden == null) return;
    final token = context.read<AuthProvider>().token;
    if (token == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Completar servicio'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('¿Confirmas que el servicio fue atendido exitosamente?'),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.success,
                foregroundColor: Colors.white,
              ),
              child: const Text('Confirmar servicio'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
          ],
        ),
      ),
    );
    if (confirm != true) return;

    setState(() => _completing = true);
    try {
      await _service.completarOrden(token, _orden!.id);
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('llegado_asignacion_id');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Servicio completado. Buen trabajo.')),
        );
        // Guardar incidenteId antes de limpiar la orden
        final incidenteId = _orden!.incidenteId;
        setState(() { _orden = null; _llegado = false; });
        // Preguntar al técnico el monto a cobrar
        await _pedirMonto(token, incidenteId);
      }
    } catch (e) {
      _showError('Error al completar el servicio.');
    } finally {
      if (mounted) setState(() => _completing = false);
    }
  }

  /// Muestra el diálogo para registrar el monto (lógica en mis_servicios_screen.dart).
  Future<void> _pedirMonto(String token, String incidenteId) async {
    if (!mounted) return;
    await mostrarDialogoMonto(
      context,
      incidenteId: incidenteId,
      onExito: () {}, // no necesita recargar nada desde aquí
    );
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final notifProv = context.watch<NotificacionProvider>();
    final nombre = auth.user?.nombreCompleto.split(' ').first ?? 'Técnico';

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.engineering_rounded,
                color: AppTheme.secondary, size: 22),
            const SizedBox(width: 8),
            const Text('Panel Técnico'),
          ],
        ),
        actions: [
          // Campana de notificaciones
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                tooltip: 'Notificaciones',
                icon: const Icon(Icons.notifications_rounded),
                onPressed: () => context.push('/notifications'),
              ),
              if (notifProv.noLeidas > 0)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: const BoxDecoration(
                      color: AppTheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        notifProv.noLeidas > 9
                            ? '9+'
                            : '${notifProv.noLeidas}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            tooltip: 'Mis servicios',
            icon: const Icon(Icons.receipt_long_rounded),
            onPressed: () => context.push('/tecnico-servicios'),
          ),
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout_rounded),
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('¿Cerrar sesión?'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text('Se cerrará tu sesión como técnico.'),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.error,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Cerrar sesión'),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancelar'),
                      ),
                    ],
                  ),
                ),
              );
              if (ok == true && context.mounted) auth.logout();
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Saludo
                    Text('Hola, $nombre',
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(
                      _orden != null
                          ? 'Tienes una emergencia activa'
                          : 'Sin órdenes activas por ahora',
                      style: TextStyle(
                          color: _orden != null
                              ? AppTheme.primary
                              : AppTheme.textSecondary,
                          fontSize: 13,
                          fontWeight: _orden != null
                              ? FontWeight.w600
                              : FontWeight.normal),
                    ),
                    const SizedBox(height: 24),

                    if (_orden != null)
                      _OrdenActivaCard(
                        orden: _orden!,
                        completing: _completing,
                        updatingLocation: _updatingLocation,
                        llegado: _llegado,
                        reportandoLlegada: _reportandoLlegada,
                        onCompletar: _completarOrden,
                        onActualizarUbicacion: _actualizarUbicacion,
                        onReportarLlegada: _reportarLlegada,
                        onChat: () => context.push('/chat/${_orden!.incidenteId}'),
                      )
                    else
                      _NoOrdenCard(),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }
}

// ── Orden activa ──────────────────────────────────────────────────────────────
class _OrdenActivaCard extends StatelessWidget {
  final OrdenActiva orden;
  final bool completing;
  final bool updatingLocation;
  final bool llegado;
  final bool reportandoLlegada;
  final VoidCallback onCompletar;
  final VoidCallback onActualizarUbicacion;
  final VoidCallback onReportarLlegada;
  final VoidCallback onChat;

  const _OrdenActivaCard({
    required this.orden,
    required this.completing,
    required this.updatingLocation,
    required this.llegado,
    required this.reportandoLlegada,
    required this.onCompletar,
    required this.onActualizarUbicacion,
    required this.onReportarLlegada,
    required this.onChat,
  });

  Color get _estadoColor {
    switch (orden.incidenteEstado) {
      case 'en_proceso':
        return AppTheme.primary;
      case 'atendido':
        return AppTheme.success;
      case 'cancelado':
        return AppTheme.error;
      default:
        return AppTheme.secondary;
    }
  }

  Color get _prioridadColor {
    switch (orden.incidentePrioridad) {
      case 'alta':
        return AppTheme.primary;
      case 'media':
        return AppTheme.secondary;
      default:
        return AppTheme.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _estadoColor.withAlpha(80)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: _estadoColor.withAlpha(18),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(13)),
            ),
            child: Row(
              children: [
                const Icon(Icons.assignment_turned_in_rounded, size: 18),
                const SizedBox(width: 8),
                const Text('Orden activa',
                    style: TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14)),
                const Spacer(),
                // Estado badge
                _Badge(
                  label: orden.estadoLabel,
                  color: _estadoColor,
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Tipo y prioridad ───────────────────────────────────
                if (orden.incidenteClasificacion != null ||
                    orden.incidentePrioridad != null)
                  Row(
                    children: [
                      if (orden.incidenteClasificacion != null)
                        _Badge(
                          label: orden.clasificacionLabel,
                          color: AppTheme.secondary,
                        ),
                      if (orden.incidenteClasificacion != null &&
                          orden.incidentePrioridad != null)
                        const SizedBox(width: 8),
                      if (orden.incidentePrioridad != null)
                        _Badge(
                          label: 'Prioridad ${orden.prioridadLabel}',
                          color: _prioridadColor,
                        ),
                    ],
                  ),

                // ── Descripción ────────────────────────────────────────
                if (orden.incidenteDescripcion != null) ...[
                  const SizedBox(height: 14),
                  const _Label('Descripción del cliente'),
                  const SizedBox(height: 4),
                  Text(
                    orden.incidenteDescripcion!,
                    style: const TextStyle(fontSize: 14),
                  ),
                ],

                // ── Resumen IA ─────────────────────────────────────────
                if (orden.incidenteResumenIa != null) ...[
                  const SizedBox(height: 14),
                  const _Label('Resumen IA'),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.secondary.withAlpha(15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.secondary.withAlpha(50)),
                    ),
                    child: Text(
                      orden.incidenteResumenIa!,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],

                // ── Evidencias (fotos/audio del cliente) ──────────────
                if (orden.evidencias.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  const _Label('Evidencias del cliente'),
                  const SizedBox(height: 8),
                  _EvidenciasRow(evidencias: orden.evidencias),
                ],

                // ── Ubicación ──────────────────────────────────────────
                if (orden.incidenteLatitud != null &&
                    orden.incidenteLongitud != null) ...[
                  const SizedBox(height: 14),
                  const _Label('Ubicación del cliente'),
                  const SizedBox(height: 6),
                  _MapButton(
                    latitud: orden.incidenteLatitud!,
                    longitud: orden.incidenteLongitud!,
                  ),
                ],

                // ── Cliente ────────────────────────────────────────────
                if (orden.clienteNombre != null) ...[
                  const SizedBox(height: 14),
                  const _Label('Cliente'),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.person_rounded,
                          size: 15, color: AppTheme.textSecondary),
                      const SizedBox(width: 6),
                      Text(orden.clienteNombre!,
                          style: const TextStyle(fontSize: 14)),
                    ],
                  ),
                  if (orden.clienteTelefono != null) ...[
                    const SizedBox(height: 8),
                    _PhoneButton(telefono: orden.clienteTelefono!),
                  ],
                ],

                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 14),

                // ── Chat con el cliente ────────────────────────────────
                OutlinedButton.icon(
                  onPressed: onChat,
                  icon: const Icon(Icons.chat_rounded,
                      color: AppTheme.secondary),
                  label: const Text(
                    'Chat con el cliente',
                    style: TextStyle(color: AppTheme.secondary),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppTheme.secondary),
                    minimumSize: const Size(double.infinity, 44),
                  ),
                ),
                const SizedBox(height: 10),

                // ── Actualizar ubicación ───────────────────────────────
                OutlinedButton.icon(
                  onPressed: updatingLocation ? null : onActualizarUbicacion,
                  icon: updatingLocation
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppTheme.secondary))
                      : const Icon(Icons.my_location_rounded,
                          color: AppTheme.secondary),
                  label: Text(
                    updatingLocation
                        ? 'Obteniendo GPS...'
                        : 'Actualizar mi ubicación',
                    style: const TextStyle(color: AppTheme.secondary),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppTheme.secondary),
                    minimumSize: const Size(double.infinity, 44),
                  ),
                ),
                const SizedBox(height: 10),

                // ── Ya llegué ──────────────────────────────────────────
                ElevatedButton.icon(
                  onPressed: (llegado || reportandoLlegada) ? null : onReportarLlegada,
                  icon: reportandoLlegada
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Icon(llegado
                          ? Icons.where_to_vote_rounded
                          : Icons.location_on_rounded),
                  label: Text(llegado
                      ? 'Cliente notificado de tu llegada'
                      : reportandoLlegada
                          ? 'Enviando...'
                          : 'Ya llegué al lugar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: llegado
                        ? AppTheme.success.withAlpha(160)
                        : AppTheme.primary,
                    minimumSize: const Size(double.infinity, 44),
                  ),
                ),
                const SizedBox(height: 10),

                // ── Completar — solo visible tras confirmar llegada ────
                if (llegado) ...[
                  ElevatedButton.icon(
                    onPressed: completing ? null : onCompletar,
                    icon: completing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.check_circle_outline_rounded),
                    label: Text(completing
                        ? 'Completando...'
                        : 'Marcar como completado'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.success,
                      minimumSize: const Size(double.infinity, 44),
                    ),
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.lock_outline_rounded,
                            size: 15, color: AppTheme.textSecondary),
                        SizedBox(width: 6),
                        Text(
                          'Confirma tu llegada primero',
                          style: TextStyle(
                              color: AppTheme.textSecondary, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Sin orden ─────────────────────────────────────────────────────────────────
class _NoOrdenCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          const Icon(Icons.inbox_rounded,
              color: AppTheme.textSecondary, size: 52),
          const SizedBox(height: 14),
          const Text('Sin órdenes activas',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 6),
          const Text(
            'Cuando el taller te asigne una emergencia, aparecerá aquí.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// ── Mapa ──────────────────────────────────────────────────────────────────────
class _MapButton extends StatelessWidget {
  final double latitud;
  final double longitud;
  const _MapButton({required this.latitud, required this.longitud});

  Future<void> _abrirMapa(BuildContext context) async {
    final uri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$latitud,$longitud');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir el mapa.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _abrirMapa(context),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: AppTheme.secondary.withAlpha(15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.secondary.withAlpha(60)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.map_rounded, size: 16, color: AppTheme.secondary),
            const SizedBox(width: 8),
            const Text(
              'Ver en mapa',
              style: TextStyle(
                color: AppTheme.secondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.open_in_new_rounded,
                size: 12, color: AppTheme.secondary),
          ],
        ),
      ),
    );
  }
}

// ── Teléfono tappable ─────────────────────────────────────────────────────────
class _PhoneButton extends StatelessWidget {
  final String telefono;
  const _PhoneButton({required this.telefono});

  Future<void> _llamar(BuildContext context) async {
    final uri = Uri(scheme: 'tel', path: telefono);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir el marcador.')),
        );
      }
    }
  }

  void _copiar(BuildContext context) {
    Clipboard.setData(ClipboardData(text: telefono));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Número copiado: $telefono'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _llamar(context),
      onLongPress: () => _copiar(context),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
        decoration: BoxDecoration(
          color: AppTheme.primary.withAlpha(15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.primary.withAlpha(60)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.phone_rounded,
                size: 14, color: AppTheme.primary),
            const SizedBox(width: 6),
            Text(
              telefono,
              style: const TextStyle(
                color: AppTheme.primary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.copy_rounded, size: 12, color: AppTheme.primary),
          ],
        ),
      ),
    );
  }
}

// ── Evidencias del cliente ────────────────────────────────────────────────────
class _EvidenciasRow extends StatelessWidget {
  final List<EvidenciaOrden> evidencias;
  const _EvidenciasRow({required this.evidencias});

  String _fullUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    return '${AppConstants.baseUrl}$path';
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 80,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: evidencias.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final ev = evidencias[i];
          final isAudio = ev.tipo == 'audio';
          final url = _fullUrl(ev.archivoUrl);

          if (isAudio) {
            return Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.secondary.withAlpha(20),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.secondary.withAlpha(60)),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.mic_rounded, color: AppTheme.secondary, size: 28),
                  SizedBox(height: 4),
                  Text('Audio',
                      style: TextStyle(
                          fontSize: 11, color: AppTheme.textSecondary)),
                ],
              ),
            );
          }

          // Imagen
          return GestureDetector(
            onTap: () => _verImagen(context, url),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: url.isNotEmpty
                  ? Image.network(
                      url,
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _imgError(),
                    )
                  : _imgError(),
            ),
          );
        },
      ),
    );
  }

  Widget _imgError() => Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: AppTheme.border,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.broken_image_rounded,
            color: AppTheme.textSecondary),
      );

  void _verImagen(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          children: [
            InteractiveViewer(
              child: Image.network(url, fit: BoxFit.contain),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────
class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(28),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Text(label,
          style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3)),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.4));
  }
}
