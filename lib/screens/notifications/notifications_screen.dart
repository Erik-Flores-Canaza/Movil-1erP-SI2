import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../data/models/notificacion.dart';
import '../../providers/auth_provider.dart';
import '../../providers/notificacion_provider.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context
          .read<NotificacionProvider>()
          .cargar(context.read<AuthProvider>().token!);
    });
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<NotificacionProvider>();
    final token = context.read<AuthProvider>().token!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificaciones'),
        actions: [
          if (prov.noLeidas > 0)
            TextButton(
              onPressed: () => prov.marcarTodasLeidas(token),
              child: const Text('Marcar todas leídas'),
            ),
        ],
      ),
      body: prov.loading && prov.notificaciones.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : prov.notificaciones.isEmpty
              ? _EmptyState()
              : RefreshIndicator(
                  onRefresh: () => prov.cargar(token),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: prov.notificaciones.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (ctx, i) => _NotifTile(
                      notif: prov.notificaciones[i],
                      onTap: () {
                        if (!prov.notificaciones[i].leida) {
                          prov.marcarLeida(token, prov.notificaciones[i].id);
                        }
                      },
                    ),
                  ),
                ),
    );
  }
}

class _NotifTile extends StatelessWidget {
  final Notificacion notif;
  final VoidCallback onTap;
  const _NotifTile({required this.notif, required this.onTap});

  IconData get _icon {
    final t = notif.titulo.toLowerCase();
    if (t.contains('taller')) return Icons.store_rounded;
    if (t.contains('técnico') || t.contains('tecnico')) {
      return Icons.engineering_rounded;
    }
    if (t.contains('complet')) return Icons.check_circle_rounded;
    if (t.contains('rechaz')) return Icons.cancel_rounded;
    return Icons.notifications_rounded;
  }

  Color get _color {
    final t = notif.titulo.toLowerCase();
    if (t.contains('rechaz') || t.contains('cancel')) return AppTheme.error;
    if (t.contains('complet') || t.contains('acept')) return AppTheme.success;
    return AppTheme.secondary;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: notif.leida
              ? AppTheme.surface
              : AppTheme.surfaceElevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: notif.leida ? AppTheme.border : _color.withAlpha(80),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _color.withAlpha(25),
                shape: BoxShape.circle,
              ),
              child: Icon(_icon, color: _color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          notif.titulo,
                          style: TextStyle(
                            fontWeight: notif.leida
                                ? FontWeight.w500
                                : FontWeight.w700,
                          ),
                        ),
                      ),
                      if (!notif.leida)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppTheme.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    notif.mensaje,
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _relativeTime(notif.creadoEn),
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _relativeTime(DateTime dt) {
    // toUtc() en ambos lados para evitar problemas de zona horaria
    final diff = DateTime.now().toUtc().difference(dt.toUtc());
    final mins = diff.inMinutes.abs();
    if (mins < 1)  return 'Ahora mismo';
    if (mins < 60) return 'Hace $mins min';
    final h = diff.inHours.abs();
    if (h < 24)    return 'Hace $h h';
    return 'Hace ${diff.inDays.abs()} días';
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_none_rounded,
              color: AppTheme.textSecondary, size: 56),
          SizedBox(height: 16),
          Text('Sin notificaciones',
              style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600)),
          SizedBox(height: 6),
          Text('Recibirás alertas sobre tus emergencias aquí',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
        ],
      ),
    );
  }
}
