import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../data/models/pago.dart';
import '../../providers/auth_provider.dart';
import '../../providers/pago_provider.dart';

class PaymentScreen extends StatefulWidget {
  final String incidenteId;
  final String? descripcion;
  const PaymentScreen({super.key, required this.incidenteId, this.descripcion});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  bool _processing = false;
  bool _success = false;
  String? _errorMsg;

  // Pago registrado por el técnico (leído de la BD)
  Pago? _pagoPendiente;
  bool _cargandoPago = true;
  String? _errorCarga;
  bool _pagoEfectivo = false; // true si ya fue cobrado en efectivo

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _cargarPago());
  }

  Future<void> _cargarPago() async {
    final token = context.read<AuthProvider>().token!;
    final pagoProvider = context.read<PagoProvider>();
    setState(() {
      _cargandoPago = true;
      _errorCarga = null;
    });
    final pago = await pagoProvider.cargarPago(token,
        incidenteId: widget.incidenteId);
    if (mounted) {
      setState(() {
        _cargandoPago = false;
        if (pago == null) {
          _errorCarga =
              'El técnico aún no ha registrado el monto del servicio. Espera un momento e intenta de nuevo.';
        } else if (pago.estado == 'pagado') {
          _success = true;
          _pagoEfectivo = pago.metodoPago == 'efectivo';
        } else {
          _pagoPendiente = pago;
        }
      });
    }
  }

  Future<void> _pagar() async {
    if (_pagoPendiente == null) return;

    final token = context.read<AuthProvider>().token!;
    final pagoProvider = context.read<PagoProvider>();
    setState(() {
      _processing = true;
      _errorMsg = null;
    });

    try {
      // 1. Crear intent en el backend (monto ya está en la BD)
      final intent = await pagoProvider.crearIntent(
        token,
        incidenteId: widget.incidenteId,
      );
      if (intent == null) {
        setState(() {
          _errorMsg = pagoProvider.error ?? 'Error al crear el pago.';
          _processing = false;
        });
        return;
      }

      // 2. Inicializar el PaymentSheet
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          merchantDisplayName: 'EmergenciAuto',
          paymentIntentClientSecret: intent.clientSecret,
          style: ThemeMode.dark,
          appearance: const PaymentSheetAppearance(
            colors: PaymentSheetAppearanceColors(
              primary: Color(0xFFE53935),
              background: Color(0xFF0D1117),
              componentBackground: Color(0xFF161B22),
              componentText: Color(0xFFF0F6FC),
              primaryText: Color(0xFFF0F6FC),
              secondaryText: Color(0xFF8B949E),
            ),
          ),
        ),
      );

      // 3. Presentar el PaymentSheet al usuario
      await Stripe.instance.presentPaymentSheet();

      // 4. Confirmar en el backend
      final paymentIntentId = intent.clientSecret.split('_secret_').first;
      if (!mounted) return;
      final ok = await pagoProvider.confirmarPago(
        token,
        incidenteId: widget.incidenteId,
        paymentIntentId: paymentIntentId,
      );

      setState(() {
        _processing = false;
        _success = ok;
        if (!ok) _errorMsg = pagoProvider.error ?? 'No se pudo confirmar el pago.';
      });
    } on StripeException catch (e) {
      setState(() {
        _processing = false;
        if (e.error.code != FailureCode.Canceled) {
          _errorMsg = e.error.localizedMessage ?? 'Error de pago.';
        }
      });
    } catch (e) {
      setState(() {
        _processing = false;
        _errorMsg = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pagar servicio')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _success
              ? _buildSuccess()
              : _cargandoPago
                  ? const Center(child: CircularProgressIndicator())
                  : _errorCarga != null
                      ? _buildErrorCarga()
                      : _buildForm(),
        ),
      ),
    );
  }

  Widget _buildErrorCarga() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.hourglass_empty_rounded,
              size: 64, color: AppTheme.textSecondary),
          const SizedBox(height: 16),
          Text(
            _errorCarga!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _cargarPago,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Actualizar'),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccess() {
    final titulo = _pagoEfectivo ? '¡Pago en efectivo registrado!' : '¡Pago completado!';
    final mensaje = _pagoEfectivo
        ? 'El técnico registró el cobro en efectivo. No es necesaria ninguna acción adicional.'
        : 'Tu pago fue procesado correctamente. Gracias por usar EmergenciAuto.';

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: AppTheme.success.withAlpha(25),
            shape: BoxShape.circle,
          ),
          child: Icon(
            _pagoEfectivo ? Icons.payments_rounded : Icons.check_circle_rounded,
            color: AppTheme.success,
            size: 44,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          titulo,
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(fontWeight: FontWeight.w700),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          mensaje,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
        ),
        const SizedBox(height: 40),
        ElevatedButton.icon(
          onPressed: () => context.go('/home'),
          icon: const Icon(Icons.home_rounded),
          label: const Text('Volver al inicio'),
        ),
      ],
    );
  }

  Widget _buildForm() {
    final pago = _pagoPendiente!;
    final comision = pago.comisionPlataforma;
    final neto = pago.netoTaller;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header del servicio
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.border),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withAlpha(20),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.build_circle_rounded,
                  color: AppTheme.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Servicio de emergencia vial',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.descripcion?.isNotEmpty == true
                          ? widget.descripcion!
                          : 'Asistencia en carretera',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: AppTheme.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Monto fijado por el técnico (solo lectura)
        const Text(
          'MONTO A PAGAR',
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.border),
          ),
          child: Text(
            'Bs. ${pago.montoTotal.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: 8),

        // Desglose
        Row(
          children: [
            const Expanded(
              child: Text('Comisión plataforma (10%)',
                  style: TextStyle(
                      color: AppTheme.textSecondary, fontSize: 12)),
            ),
            Text('Bs. ${comision.toStringAsFixed(2)}',
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 12)),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            const Expanded(
              child: Text('Neto para el técnico',
                  style: TextStyle(
                      color: AppTheme.textSecondary, fontSize: 12)),
            ),
            Text('Bs. ${neto.toStringAsFixed(2)}',
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 12)),
          ],
        ),

        if (_errorMsg != null) ...[
          const SizedBox(height: 16),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.error.withAlpha(20),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.error.withAlpha(80)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline_rounded,
                    color: AppTheme.error, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(_errorMsg!,
                      style: const TextStyle(
                          color: AppTheme.error, fontSize: 13)),
                ),
              ],
            ),
          ),
        ],

        const Spacer(),

        // Botón pagar
        ElevatedButton(
          onPressed: _processing ? null : _pagar,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primary,
            minimumSize: const Size(double.infinity, 54),
          ),
          child: _processing
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.lock_rounded, size: 18),
                    SizedBox(width: 8),
                    Text('Pagar ahora',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                  ],
                ),
        ),
        const SizedBox(height: 12),
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.security_rounded,
                size: 14, color: AppTheme.textSecondary),
            SizedBox(width: 4),
            Text(
              'Pagos procesados de forma segura por Stripe',
              style:
                  TextStyle(color: AppTheme.textSecondary, fontSize: 11),
            ),
          ],
        ),
      ],
    );
  }
}
