import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../data/models/incidente.dart';
import '../../providers/auth_provider.dart';
import '../../providers/incidente_provider.dart';

class MyEmergenciesScreen extends StatefulWidget {
  const MyEmergenciesScreen({super.key});

  @override
  State<MyEmergenciesScreen> createState() => _MyEmergenciesScreenState();
}

class _MyEmergenciesScreenState extends State<MyEmergenciesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context
          .read<IncidenteProvider>()
          .cargarMisIncidentes(context.read<AuthProvider>().token!);
    });
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<IncidenteProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis emergencias'),
      ),
      body: prov.loading && prov.incidentes.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : prov.incidentes.isEmpty
              ? _EmptyState()
              : RefreshIndicator(
                  onRefresh: () => prov
                      .cargarMisIncidentes(context.read<AuthProvider>().token!),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: prov.incidentes.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (ctx, i) =>
                        _IncidenteCard(inc: prov.incidentes[i]),
                  ),
                ),
    );
  }
}

class _IncidenteCard extends StatelessWidget {
  final Incidente inc;
  const _IncidenteCard({required this.inc});

  static const _estadoMeta = {
    'pendiente': (color: AppTheme.secondary, label: 'Pendiente'),
    'en_proceso': (color: AppTheme.primary, label: 'En proceso'),
    'atendido': (color: AppTheme.success, label: 'Atendido'),
    'cancelado': (color: AppTheme.error, label: 'Cancelado'),
  };

  @override
  Widget build(BuildContext context) {
    final meta = _estadoMeta[inc.estado] ??
        (color: AppTheme.border, label: inc.estado);

    final taller = inc.asignacion?.taller?.nombre;

    return GestureDetector(
      onTap: () {
        context.read<IncidenteProvider>().setActivo(inc);
        context.push('/monitor/${inc.id}');
      },
      child: Container(
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
                Expanded(
                  child: Text(
                    inc.descripcion ?? 'Sin descripción',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: meta.color.withAlpha(30),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: meta.color.withAlpha(80)),
                  ),
                  child: Text(
                    meta.label,
                    style: TextStyle(
                        color: meta.color,
                        fontSize: 11,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.schedule_rounded,
                    size: 13, color: AppTheme.textSecondary),
                const SizedBox(width: 4),
                Text(_formatDate(inc.creadoEn),
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 12)),
                if (taller != null) ...[
                  const SizedBox(width: 12),
                  const Icon(Icons.store_rounded,
                      size: 13, color: AppTheme.textSecondary),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(taller,
                        style: const TextStyle(
                            color: AppTheme.textSecondary, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ),
                ],
              ],
            ),
            if (inc.clasificacionIa != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.auto_awesome_rounded,
                      size: 13, color: AppTheme.textSecondary),
                  const SizedBox(width: 4),
                  Text(inc.clasificacionIa!,
                      style: const TextStyle(
                          color: AppTheme.textSecondary, fontSize: 12)),
                ],
              ),
            ],
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  inc.estado == 'pendiente' || inc.estado == 'en_proceso'
                      ? 'Ver seguimiento →'
                      : 'Ver detalle →',
                  style: TextStyle(
                    color: AppTheme.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final local = dt.toLocal();
    return '${local.day}/${local.month}/${local.year} '
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.history_rounded,
              color: AppTheme.textSecondary, size: 56),
          const SizedBox(height: 16),
          const Text('Sin emergencias registradas',
              style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text('Tus solicitudes de emergencia aparecerán aquí',
              textAlign: TextAlign.center,
              style:
                  TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
        ],
      ),
    );
  }
}
