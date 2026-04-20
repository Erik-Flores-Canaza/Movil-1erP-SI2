import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/incidente_provider.dart';
import '../../providers/notificacion_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final token = context.read<AuthProvider>().token!;
      context.read<IncidenteProvider>().cargarMisIncidentes(token);
      context.read<NotificacionProvider>().cargar(token);
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final firstName = user?.nombreCompleto.split(' ').first ?? 'Cliente';
    final notifProv = context.watch<NotificacionProvider>();
    final incProv = context.watch<IncidenteProvider>();

    // Primer incidente activo (pendiente o en_proceso)
    final activeInc = incProv.incidentes
        .where((i) => i.estado == 'pendiente' || i.estado == 'en_proceso')
        .firstOrNull;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.car_repair_rounded,
                color: AppTheme.primary, size: 22),
            const SizedBox(width: 8),
            const Text('EmergenciAuto'),
          ],
        ),
        actions: [
          // ── Notification bell ──────────────────────────────────────────
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                tooltip: 'Notificaciones',
                icon: const Icon(Icons.notifications_outlined),
                onPressed: () => context.push('/notifications'),
              ),
              if (notifProv.noLeidas > 0)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: AppTheme.primary,
                      shape: BoxShape.circle,
                    ),
                    constraints:
                        const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Text(
                      notifProv.noLeidas > 9
                          ? '9+'
                          : '${notifProv.noLeidas}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w700),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          // ── Profile avatar ─────────────────────────────────────────────
          IconButton(
            tooltip: 'Mi perfil',
            icon: CircleAvatar(
              radius: 16,
              backgroundColor: AppTheme.primary.withAlpha(30),
              child: Text(
                firstName.isNotEmpty ? firstName[0].toUpperCase() : 'C',
                style: const TextStyle(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14),
              ),
            ),
            onPressed: () => context.push('/profile'),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Greeting ─────────────────────────────────────────────
              Text(
                'Hola, $firstName 👋',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                activeInc != null
                    ? 'Tienes una emergencia activa'
                    : 'Todo tranquilo por ahora',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 24),

              // ── Active emergency card (if any) ────────────────────────
              if (activeInc != null) ...[
                GestureDetector(
                  onTap: () {
                    context.read<IncidenteProvider>().setActivo(activeInc);
                    context.push('/monitor/${activeInc.id}');
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withAlpha(15),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: AppTheme.primary.withAlpha(80)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withAlpha(30),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.sos_rounded,
                              color: AppTheme.primary, size: 24),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Emergencia activa — ${activeInc.estadoLabel}',
                                  style: const TextStyle(
                                      color: AppTheme.primary,
                                      fontWeight: FontWeight.w700)),
                              const SizedBox(height: 2),
                              Text(
                                activeInc.descripcion ?? 'Ver seguimiento →',
                                style: TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 12),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded,
                            color: AppTheme.primary),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ] else ...[
                // ── No active emergency card ──────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppTheme.success.withAlpha(25),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check_circle_outline_rounded,
                            color: AppTheme.success, size: 26),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Sin emergencias activas',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 2),
                            Text('Tu estado es normal',
                                style: TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 13)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
              ],

              // ── Emergency button ─────────────────────────────────────
              _EmergencyButton(hasActive: activeInc != null),
              const SizedBox(height: 28),

              // ── Quick access ─────────────────────────────────────────
              Text('Accesos rápidos',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _QuickCard(
                      icon: Icons.directions_car_rounded,
                      label: 'Mis vehículos',
                      color: AppTheme.secondary,
                      onTap: () => context.push('/vehicles'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _QuickCard(
                      icon: Icons.history_rounded,
                      label: 'Mis emergencias',
                      color: AppTheme.primary,
                      onTap: () => context.push('/my-emergencies'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
      floatingActionButton: activeInc == null
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/report-emergency'),
              icon: const Icon(Icons.warning_amber_rounded),
              label: const Text('Reportar emergencia',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
            )
          : null,
    );
  }
}

class _EmergencyButton extends StatelessWidget {
  final bool hasActive;
  const _EmergencyButton({required this.hasActive});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push(
          hasActive ? '/my-emergencies' : '/report-emergency'),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: hasActive
                ? [AppTheme.secondary, AppTheme.secondary.withRed(230)]
                : [AppTheme.primary, AppTheme.primary.withRed(200)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: (hasActive ? AppTheme.secondary : AppTheme.primary)
                  .withAlpha(80),
              blurRadius: 20,
              spreadRadius: 2,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasActive ? Icons.track_changes_rounded : Icons.sos_rounded,
              size: 44,
              color: Colors.white,
            ),
            const SizedBox(height: 10),
            Text(
              hasActive ? 'VER SEGUIMIENTO' : 'REPORTAR EMERGENCIA',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              hasActive
                  ? 'Toca para ver el estado de tu solicitud'
                  : 'Toca para activar asistencia inmediata',
              style: TextStyle(
                  color: Colors.white.withAlpha(180), fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withAlpha(25),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
