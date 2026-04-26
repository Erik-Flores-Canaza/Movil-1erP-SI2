import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../data/services/tecnico_service.dart';
import '../../providers/auth_provider.dart';

// ── Helper: diálogo para registrar el monto (reutilizable) ───────────────────

typedef _MontoMetodo = ({double monto, String metodo});

Future<void> mostrarDialogoMonto(
  BuildContext context, {
  required String incidenteId,
  required VoidCallback onExito,
}) async {
  final token = context.read<AuthProvider>().token;
  if (token == null) return;

  final controller = TextEditingController();
  final service = TecnicoService();

  // Devuelve monto + método, o null si el técnico cancela
  final resultado = await showDialog<_MontoMetodo>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      String? error;
      String metodo = 'efectivo'; // opción predeterminada

      return StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Registrar cobro del servicio'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Método de pago ─────────────────────────────────────
              const Text(
                'MÉTODO DE COBRO',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _MetodoBtn(
                      label: 'Efectivo',
                      icon: Icons.payments_rounded,
                      selected: metodo == 'efectivo',
                      onTap: () => setS(() => metodo = 'efectivo'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _MetodoBtn(
                      label: 'Stripe',
                      icon: Icons.credit_card_rounded,
                      selected: metodo == 'stripe',
                      onTap: () => setS(() => metodo = 'stripe'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Descripción contextual
              Text(
                metodo == 'efectivo'
                    ? 'El cobro se cierra ahora. El cliente recibirá confirmación.'
                    : 'El cliente pagará desde la app con tarjeta.',
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 20),

              // ── Monto ──────────────────────────────────────────────
              const Text(
                'MONTO (Bs.)',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: controller,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                autofocus: true,
                decoration: InputDecoration(
                  prefixText: 'Bs. ',
                  hintText: '0.00',
                  errorText: error,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) => setS(() => error = null),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Omitir por ahora'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: metodo == 'efectivo'
                    ? AppTheme.success
                    : AppTheme.primary,
              ),
              onPressed: () {
                final v = double.tryParse(controller.text.trim());
                if (v == null || v <= 0) {
                  setS(() => error = 'Ingresa un monto mayor a 0');
                  return;
                }
                Navigator.pop(ctx, (monto: v, metodo: metodo));
              },
              child: Text(
                metodo == 'efectivo' ? 'Cobré en efectivo' : 'Cliente pagará online',
              ),
            ),
          ],
        ),
      );
    },
  );

  if (resultado == null || !context.mounted) return;

  try {
    await service.registrarMonto(
      token,
      incidenteId: incidenteId,
      monto: resultado.monto,
      metodoPago: resultado.metodo,
    );
    if (context.mounted) {
      final msg = resultado.metodo == 'efectivo'
          ? 'Cobro en efectivo de Bs. ${resultado.monto.toStringAsFixed(2)} registrado.'
          : 'Monto Bs. ${resultado.monto.toStringAsFixed(2)} registrado. El cliente pagará online.';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(msg)));
      onExito();
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('No se pudo registrar el cobro. Intenta de nuevo.')),
      );
    }
  }
}

// ── Botón de selección de método ──────────────────────────────────────────────

class _MetodoBtn extends StatelessWidget {
  const _MetodoBtn({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primary.withAlpha(20) : AppTheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppTheme.primary : AppTheme.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon,
                color: selected ? AppTheme.primary : AppTheme.textSecondary,
                size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: selected ? AppTheme.primary : AppTheme.textSecondary,
                fontSize: 13,
                fontWeight:
                    selected ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MisServiciosScreen extends StatefulWidget {
  const MisServiciosScreen({super.key});

  @override
  State<MisServiciosScreen> createState() => _MisServiciosScreenState();
}

class _MisServiciosScreenState extends State<MisServiciosScreen> {
  final _service = TecnicoService();
  List<ServicioHistorial>? _servicios;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _cargar());
  }

  Future<void> _cargar() async {
    final token = context.read<AuthProvider>().token;
    if (token == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _service.getMisServicios(token);
      if (mounted) setState(() => _servicios = data);
    } catch (e) {
      if (mounted) setState(() => _error = 'No se pudo cargar el historial.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis servicios'),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _cargar,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                color: AppTheme.error, size: 48),
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: AppTheme.textSecondary)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _cargar,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }
    if (_servicios == null || _servicios!.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_long_rounded,
                size: 64, color: AppTheme.textSecondary),
            SizedBox(height: 16),
            Text(
              'Sin servicios aún',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary),
            ),
            SizedBox(height: 8),
            Text(
              'Aquí aparecerán los servicios\nque hayas completado.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _cargar,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _servicios!.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) => _ServicioCard(
          servicio: _servicios![i],
          onMontoRegistrado: _cargar, // recarga la lista tras registrar
        ),
      ),
    );
  }
}

// ── Card individual ────────────────────────────────────────────────────────────

class _ServicioCard extends StatefulWidget {
  const _ServicioCard({
    required this.servicio,
    required this.onMontoRegistrado,
  });
  final ServicioHistorial servicio;
  final VoidCallback onMontoRegistrado;

  @override
  State<_ServicioCard> createState() => _ServicioCardState();
}

class _ServicioCardState extends State<_ServicioCard> {
  bool _registrando = false;

  @override
  Widget build(BuildContext context) {
    final servicio = widget.servicio;
    final pagado = servicio.pagoEstado == 'pagado';
    final pendientePago = servicio.pagoEstado == 'pendiente';
    final sinMonto = servicio.pagoEstado == null;

    Color estadoColor;
    String estadoLabel;
    IconData estadoIcon;

    if (pagado) {
      estadoColor = AppTheme.success;
      estadoLabel = 'Pagado';
      estadoIcon = Icons.check_circle_rounded;
    } else if (pendientePago) {
      estadoColor = AppTheme.secondary;
      estadoLabel = 'Pago pendiente del cliente';
      estadoIcon = Icons.schedule_rounded;
    } else {
      estadoColor = AppTheme.error;
      estadoLabel = 'Sin monto registrado';
      estadoIcon = Icons.warning_amber_rounded;
    }

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cliente + clasificación
          Row(
            children: [
              const Icon(Icons.person_rounded,
                  size: 18, color: AppTheme.textSecondary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  servicio.clienteNombre,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ),
              // Badge clasificación
              if (servicio.clasificacionIa != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withAlpha(25),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _clasificacionLabel(servicio.clasificacionIa!),
                    style: const TextStyle(
                        color: AppTheme.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),

          // Fecha completado
          if (servicio.completadoEn != null)
            Row(
              children: [
                const Icon(Icons.calendar_today_rounded,
                    size: 14, color: AppTheme.textSecondary),
                const SizedBox(width: 4),
                Text(
                  _formatFecha(servicio.completadoEn!),
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 12),
                ),
              ],
            ),
          const SizedBox(height: 12),

          // Monto + estado pago
          Row(
            children: [
              Row(
                children: [
                  Icon(estadoIcon, color: estadoColor, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    estadoLabel,
                    style: TextStyle(
                        color: estadoColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const Spacer(),
              if (servicio.pagoMonto != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Bs. ${servicio.pagoMonto!.toStringAsFixed(2)}',
                      style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary),
                    ),
                    if (servicio.pagoMetodo != null)
                      Text(
                        servicio.pagoMetodo == 'efectivo'
                            ? '💵 Efectivo'
                            : '💳 Stripe',
                        style: const TextStyle(
                            color: AppTheme.textSecondary, fontSize: 11),
                      ),
                  ],
                ),
            ],
          ),

          // Botón para registrar monto en servicios viejos sin monto
          if (sinMonto) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _registrando
                    ? null
                    : () async {
                        setState(() => _registrando = true);
                        await mostrarDialogoMonto(
                          context,
                          incidenteId: servicio.incidenteId,
                          onExito: widget.onMontoRegistrado,
                        );
                        if (mounted) setState(() => _registrando = false);
                      },
                icon: _registrando
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add_circle_outline_rounded, size: 16),
                label: Text(_registrando ? 'Guardando…' : 'Registrar monto ahora'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primary,
                  side: const BorderSide(color: AppTheme.primary),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _clasificacionLabel(String k) => const {
        'bateria': 'Batería',
        'llanta': 'Llanta',
        'choque': 'Choque',
        'motor': 'Motor',
        'otro': 'Otro',
        'incierto': 'Sin clasificar',
      }[k] ??
      k;

  String _formatFecha(DateTime dt) {
    final local = dt.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/'
        '${local.year}  '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }
}
