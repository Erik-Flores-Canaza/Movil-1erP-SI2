import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../data/models/incidente.dart';
import '../../providers/auth_provider.dart';
import '../../providers/incidente_provider.dart';

class MonitorScreen extends StatefulWidget {
  final String incidenteId;
  const MonitorScreen({super.key, required this.incidenteId});

  @override
  State<MonitorScreen> createState() => _MonitorScreenState();
}

class _MonitorScreenState extends State<MonitorScreen> {
  Timer? _timer;
  bool _cancelando = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _poll());
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => _poll());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _poll() async {
    final token = context.read<AuthProvider>().token;
    if (token == null) return;
    await context.read<IncidenteProvider>().refrescarActivo(
      token,
      widget.incidenteId,
    );
  }

  Future<void> _confirmarCancelar() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Cancelar solicitud?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Si un taller ya fue notificado, perderás tu turno.\n\n'
              'Esta acción no se puede deshacer.',
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.error,
                foregroundColor: Colors.white,
              ),
              child: const Text('Sí, cancelar solicitud'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('No, mantener'),
            ),
          ],
        ),
      ),
    );
    if (confirmar != true || !mounted) return;

    setState(() => _cancelando = true);
    try {
      final token = context.read<AuthProvider>().token!;
      await context.read<IncidenteProvider>().cancelar(
        token,
        widget.incidenteId,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo cancelar la solicitud.')),
        );
      }
    } finally {
      if (mounted) setState(() => _cancelando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final incidente = context.watch<IncidenteProvider>().activo;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Seguimiento de emergencia'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            context.read<IncidenteProvider>().clearActivo();
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
        ),
        actions: [
          Tooltip(
            message: 'Actualiza cada 10 s',
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppTheme.success,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'En vivo',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: incidente == null
          ? _buildLoading()
          : RefreshIndicator(
              onRefresh: _poll,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _EstadoBanner(incidente: incidente),
                    const SizedBox(height: 20),
                    _TimelineCard(incidente: incidente),
                    const SizedBox(height: 16),
                    if (incidente.asignacion?.taller != null) ...[
                      _TallerCard(
                        taller: incidente.asignacion!.taller!,
                        etaMinutos: incidente.asignacion!.etaMinutos,
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (incidente.asignacion?.tecnico != null) ...[
                      _TecnicoCard(tecnico: incidente.asignacion!.tecnico!),
                      const SizedBox(height: 16),
                    ],
                    if (incidente.resumenIa != null) ...[
                      _IaCard(incidente: incidente),
                      const SizedBox(height: 16),
                    ],
                    if (incidente.evidencias.isNotEmpty) ...[
                      _EvidenciasCard(evidencias: incidente.evidencias),
                      const SizedBox(height: 16),
                    ],
                    // Botón Chat — visible desde que el taller está asignado
                    if (incidente.asignacion?.taller != null) ...[
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: () =>
                            context.push('/chat/${incidente.id}'),
                        icon: const Icon(Icons.chat_rounded,
                            color: AppTheme.secondary),
                        label: const Text(
                          'Chat de emergencia',
                          style: TextStyle(color: AppTheme.secondary),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppTheme.secondary),
                          minimumSize: const Size(double.infinity, 48),
                        ),
                      ),
                    ],

                    // Botón Pagar — solo cuando atendido y aún no pagado
                    if (incidente.estado == 'atendido' && !incidente.pagado) ...[
                      const SizedBox(height: 10),
                      ElevatedButton.icon(
                        onPressed: () =>
                            context.push(
                              '/payment/${incidente.id}'
                              '?desc=${Uri.encodeComponent(incidente.descripcion ?? '')}',
                            ),
                        icon: const Icon(Icons.payment_rounded),
                        label: const Text('Pagar servicio'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          minimumSize: const Size(double.infinity, 48),
                        ),
                      ),
                    ],
                    // Indicador de pago completado
                    if (incidente.estado == 'atendido' && incidente.pagado) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppTheme.success.withAlpha(20),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: AppTheme.success.withAlpha(80)),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_circle_rounded,
                                color: AppTheme.success, size: 18),
                            SizedBox(width: 8),
                            Text('Servicio pagado',
                                style: TextStyle(
                                    color: AppTheme.success,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ],

                    if (incidente.estado == 'atendido' ||
                        incidente.estado == 'cancelado') ...[
                      const SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: () {
                          context.read<IncidenteProvider>().clearActivo();
                          context.go('/home');
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.success,
                        ),
                        child: const Text('Volver al inicio'),
                      ),
                    ],
                    // Botón cancelar — solo si el incidente aún está activo
                    if (incidente.estado == 'pendiente' ||
                        incidente.estado == 'en_proceso') ...[
                      const SizedBox(height: 24),
                      Center(
                        child: _cancelando
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : TextButton.icon(
                                onPressed: _confirmarCancelar,
                                icon: const Icon(
                                  Icons.cancel_outlined,
                                  size: 16,
                                ),
                                label: const Text('Cancelar solicitud'),
                                style: TextButton.styleFrom(
                                  foregroundColor: AppTheme.error,
                                  textStyle: const TextStyle(fontSize: 13),
                                ),
                              ),
                      ),
                    ],
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildLoading() => const Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CircularProgressIndicator(),
        SizedBox(height: 16),
        Text('Cargando estado de la emergencia...'),
      ],
    ),
  );
}

// ── Estado banner ─────────────────────────────────────────────────────────────
class _EstadoBanner extends StatelessWidget {
  final Incidente incidente;
  const _EstadoBanner({required this.incidente});

  ({Color color, IconData icon, String label, String? subtitle}) get _meta {
    final asig = incidente.asignacion;
    final estado = incidente.estado;

    if (estado == 'atendido') {
      return (
        color: AppTheme.success,
        icon: Icons.check_circle_rounded,
        label: 'Emergencia atendida',
        subtitle: null,
      );
    }
    if (estado == 'cancelado') {
      return (
        color: AppTheme.error,
        icon: Icons.cancel_rounded,
        label: 'Cancelada',
        subtitle: null,
      );
    }
    if (estado == 'en_proceso') {
      final nombre = asig?.tecnico?.nombreCompleto;
      return (
        color: AppTheme.primary,
        icon: Icons.engineering_rounded,
        label: 'Técnico en camino',
        subtitle: nombre != null ? 'Atendido por $nombre' : null,
      );
    }

    // estado == 'pendiente' — distinguir subestados
    if (asig == null) {
      return (
        color: AppTheme.secondary,
        icon: Icons.hourglass_top_rounded,
        label: 'Buscando taller disponible',
        subtitle: 'El sistema está asignando automáticamente',
      );
    }
    if (asig.accionTaller == null) {
      final nombre = asig.taller?.nombre;
      return (
        color: AppTheme.secondary,
        icon: Icons.store_rounded,
        label: 'Esperando confirmación del taller',
        subtitle: nombre != null ? '$nombre está revisando la solicitud' : null,
      );
    }
    // accionTaller == 'aceptado' pero estado aún pendiente (sin técnico asignado aún)
    final nombre = asig.taller?.nombre;
    return (
      color: AppTheme.primary,
      icon: Icons.assignment_turned_in_rounded,
      label: 'Taller confirmado',
      subtitle: nombre != null
          ? '$nombre asignará un técnico en breve'
          : 'Asignando técnico...',
    );
  }

  @override
  Widget build(BuildContext context) {
    final m = _meta;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: m.color.withAlpha(20),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: m.color.withAlpha(80)),
      ),
      child: Row(
        children: [
          Icon(m.icon, color: m.color, size: 32),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  m.label,
                  style: TextStyle(
                    color: m.color,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                if (m.subtitle != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    m.subtitle!,
                    style: TextStyle(
                      color: m.color.withAlpha(180),
                      fontSize: 12,
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

// ── Timeline ──────────────────────────────────────────────────────────────────

enum _StepState { pending, waiting, done }

class _TimelineStep {
  final String label;
  final String subtitle;
  final _StepState state;
  const _TimelineStep({
    required this.label,
    this.subtitle = '',
    required this.state,
  });
}

class _TimelineCard extends StatelessWidget {
  final Incidente incidente;
  const _TimelineCard({required this.incidente});

  @override
  Widget build(BuildContext context) {
    final asig = incidente.asignacion;
    final tallerNotificado = asig != null;
    final tallerConfirmado = asig?.accionTaller == 'aceptado';
    final tecnicoAsignado =
        tallerConfirmado && incidente.estado == 'en_proceso';
    final completado = incidente.estado == 'atendido';

    final steps = [
      _TimelineStep(
        label: 'Emergencia reportada',
        subtitle: _fmt(incidente.creadoEn),
        state: _StepState.done,
      ),
      _TimelineStep(
        label: tallerConfirmado ? 'Taller confirmado' : 'Contactando taller',
        subtitle: tallerConfirmado
            ? 'El taller aceptó la solicitud'
            : tallerNotificado
            ? 'Esperando respuesta del taller...'
            : '',
        state: tallerConfirmado
            ? _StepState.done
            : tallerNotificado
            ? _StepState.waiting
            : _StepState.pending,
      ),
      _TimelineStep(
        label: 'Técnico en camino',
        subtitle: tecnicoAsignado ? 'El técnico está en ruta' : '',
        state: tecnicoAsignado || completado
            ? _StepState.done
            : _StepState.pending,
      ),
      _TimelineStep(
        label: 'Servicio completado',
        subtitle: asig?.completadoEn != null ? _fmt(asig!.completadoEn!) : '',
        state: completado ? _StepState.done : _StepState.pending,
      ),
    ];

    return _InfoCard(
      title: 'Progreso',
      child: Column(
        children: List.generate(steps.length, (i) {
          final s = steps[i];
          final isLast = i == steps.length - 1;

          final Color dotColor;
          final Widget dotIcon;
          switch (s.state) {
            case _StepState.done:
              dotColor = AppTheme.success;
              dotIcon = const Icon(
                Icons.check_rounded,
                size: 12,
                color: Colors.white,
              );
            case _StepState.waiting:
              dotColor = AppTheme.secondary;
              dotIcon = const Icon(
                Icons.hourglass_top_rounded,
                size: 11,
                color: Colors.white,
              );
            case _StepState.pending:
              dotColor = AppTheme.border;
              dotIcon = const SizedBox.shrink();
          }

          final lineColor = s.state == _StepState.done
              ? AppTheme.success
              : AppTheme.border;

          final labelColor = s.state != _StepState.pending
              ? AppTheme.textPrimary
              : AppTheme.textSecondary;

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: dotColor,
                      shape: BoxShape.circle,
                    ),
                    child: Center(child: dotIcon),
                  ),
                  if (!isLast)
                    Container(width: 2, height: 34, color: lineColor),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.label,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: labelColor,
                        ),
                      ),
                      if (s.subtitle.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          s.subtitle,
                          style: TextStyle(
                            color: s.state == _StepState.waiting
                                ? AppTheme.secondary
                                : AppTheme.textSecondary,
                            fontSize: 12,
                            fontStyle: s.state == _StepState.waiting
                                ? FontStyle.italic
                                : FontStyle.normal,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  String _fmt(DateTime dt) {
    final local = dt.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')} '
        '${local.day}/${local.month}';
  }
}

// ── Teléfono tappable (compartido) ────────────────────────────────────────────
class _PhoneRow extends StatelessWidget {
  final String telefono;
  const _PhoneRow({required this.telefono});

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
            const Icon(Icons.phone_rounded, size: 14, color: AppTheme.primary),
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

// ── Taller card ───────────────────────────────────────────────────────────────
class _TallerCard extends StatelessWidget {
  final TallerResumen taller;
  final int? etaMinutos;
  const _TallerCard({required this.taller, this.etaMinutos});

  @override
  Widget build(BuildContext context) {
    return _InfoCard(
      title: 'Taller asignado',
      icon: Icons.store_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            taller.nombre,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          ),
          if (taller.telefono != null) ...[
            const SizedBox(height: 8),
            _PhoneRow(telefono: taller.telefono!),
          ],
          if (etaMinutos != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.primary.withAlpha(20),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.primary.withAlpha(60)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.timer_rounded,
                    color: AppTheme.primary,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Tiempo estimado de llegada: $etaMinutos min',
                    style: const TextStyle(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Técnico card ──────────────────────────────────────────────────────────────
class _TecnicoCard extends StatelessWidget {
  final TecnicoResumen tecnico;
  const _TecnicoCard({required this.tecnico});

  @override
  Widget build(BuildContext context) {
    return _InfoCard(
      title: 'Técnico asignado',
      icon: Icons.engineering_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tecnico.nombreCompleto,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          ),
          if (tecnico.telefono != null) ...[
            const SizedBox(height: 8),
            _PhoneRow(telefono: tecnico.telefono!),
          ],
        ],
      ),
    );
  }
}

// ── IA card ───────────────────────────────────────────────────────────────────
class _IaCard extends StatelessWidget {
  final Incidente incidente;
  const _IaCard({required this.incidente});

  @override
  Widget build(BuildContext context) {
    return _InfoCard(
      title: 'Análisis IA',
      icon: Icons.auto_awesome_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Badge(
                label: incidente.clasificacionIa ?? '-',
                color: AppTheme.secondary,
              ),
              const SizedBox(width: 8),
              _Badge(
                label: incidente.prioridadLabel,
                color: incidente.prioridad == 'alta'
                    ? AppTheme.primary
                    : incidente.prioridad == 'media'
                    ? AppTheme.secondary
                    : AppTheme.textSecondary,
              ),
            ],
          ),
          if (incidente.resumenIa != null) ...[
            const SizedBox(height: 8),
            Text(
              incidente.resumenIa!,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ── Evidencias card ───────────────────────────────────────────────────────────
class _EvidenciasCard extends StatelessWidget {
  final List<Evidencia> evidencias;
  const _EvidenciasCard({required this.evidencias});

  String _fullUrl(String path) {
    if (path.startsWith('http')) return path;
    return '${AppConstants.baseUrl}$path';
  }

  @override
  Widget build(BuildContext context) {
    return _InfoCard(
      title: 'TUS EVIDENCIAS',
      icon: Icons.photo_library_rounded,
      child: SizedBox(
        height: 88,
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
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: AppTheme.secondary.withAlpha(20),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.secondary.withAlpha(60)),
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.mic_rounded,
                        color: AppTheme.secondary, size: 30),
                    SizedBox(height: 4),
                    Text('Audio',
                        style: TextStyle(
                            fontSize: 11, color: AppTheme.textSecondary)),
                  ],
                ),
              );
            }

            return GestureDetector(
              onTap: () => _verImagen(context, url),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: url.isNotEmpty
                    ? Image.network(
                        url,
                        width: 88,
                        height: 88,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _imgError(),
                      )
                    : _imgError(),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _imgError() => Container(
        width: 88,
        height: 88,
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

// ── Shared card shell ─────────────────────────────────────────────────────────
class _InfoCard extends StatelessWidget {
  final String title;
  final IconData? icon;
  final Widget child;
  const _InfoCard({required this.title, this.icon, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, color: AppTheme.textSecondary, size: 16),
                const SizedBox(width: 6),
              ],
              Text(
                title,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}
