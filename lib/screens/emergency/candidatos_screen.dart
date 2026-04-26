import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../data/models/candidato.dart';
import '../../providers/auth_provider.dart';
import '../../providers/candidato_provider.dart';
import '../../providers/incidente_provider.dart';

class CandidatosScreen extends StatefulWidget {
  final String incidenteId;
  const CandidatosScreen({super.key, required this.incidenteId});

  @override
  State<CandidatosScreen> createState() => _CandidatosScreenState();
}

class _CandidatosScreenState extends State<CandidatosScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _cargar());
  }

  Future<void> _cargar() async {
    final token = context.read<AuthProvider>().token!;
    await context
        .read<CandidatoProvider>()
        .cargarCandidatos(token, incidenteId: widget.incidenteId);
  }

  Future<void> _seleccionar(TallerCandidato taller) async {
    final token = context.read<AuthProvider>().token!;
    final prov = context.read<CandidatoProvider>();
    final inc = await prov.seleccionarTaller(token,
        incidenteId: widget.incidenteId, tallerId: taller.id);
    if (!mounted) return;
    if (inc != null) {
      context.read<IncidenteProvider>().setActivo(inc);
      context.go('/monitor/${widget.incidenteId}');
    } else {
      _mostrarError(prov.error ?? 'No se pudo seleccionar el taller.');
    }
  }

  Future<void> _asignarAuto() async {
    final token = context.read<AuthProvider>().token!;
    final prov = context.read<CandidatoProvider>();
    final inc = await prov.asignarAutomatico(token, incidenteId: widget.incidenteId);
    if (!mounted) return;
    if (inc != null) {
      context.read<IncidenteProvider>().setActivo(inc);
      context.go('/monitor/${widget.incidenteId}');
    } else {
      _mostrarError(prov.error ?? 'No hay talleres disponibles.');
    }
  }

  void _mostrarError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppTheme.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<CandidatoProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Elige un taller'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: prov.loading ? null : _cargar,
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: prov.loading
          ? const Center(child: CircularProgressIndicator())
          : prov.candidatos.isEmpty
              ? _buildVacio()
              : _buildLista(prov),
      bottomNavigationBar: _buildBotonAuto(prov),
    );
  }

  Widget _buildVacio() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.store_outlined,
                size: 64, color: AppTheme.textSecondary),
            const SizedBox(height: 16),
            const Text(
              'No hay talleres disponibles',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 8),
            const Text(
              'Todos los talleres cercanos están ocupados o no cubren tu tipo de problema. Intenta de nuevo en unos minutos.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _cargar,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Actualizar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLista(CandidatoProvider prov) {
    final favoritos = prov.candidatos.where((c) => c.esFavorito).toList();
    final otros = prov.candidatos.where((c) => !c.esFavorito).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      children: [
        if (favoritos.isNotEmpty) ...[
          _Seccion(titulo: '★ Tus talleres favoritos'),
          ...favoritos.map((c) => _TallerCard(
                candidato: c,
                asignando: prov.asignando,
                onSeleccionar: () => _seleccionar(c),
                onToggleFav: () => context.read<CandidatoProvider>().toggleFavorito(
                      context.read<AuthProvider>().token!,
                      tallerId: c.id,
                      esFavorito: c.esFavorito,
                    ),
              )),
          const SizedBox(height: 8),
        ],
        if (otros.isNotEmpty) ...[
          _Seccion(titulo: 'Talleres disponibles cercanos'),
          ...otros.map((c) => _TallerCard(
                candidato: c,
                asignando: prov.asignando,
                onSeleccionar: () => _seleccionar(c),
                onToggleFav: () => context.read<CandidatoProvider>().toggleFavorito(
                      context.read<AuthProvider>().token!,
                      tallerId: c.id,
                      esFavorito: c.esFavorito,
                    ),
              )),
        ],
      ],
    );
  }

  Widget _buildBotonAuto(CandidatoProvider prov) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Divider(),
            const SizedBox(height: 4),
            const Text(
              'O deja que el sistema elija por ti',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: prov.asignando ? null : _asignarAuto,
              icon: prov.asignando
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome_rounded),
              label: const Text('Asignación automática'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                side: const BorderSide(color: AppTheme.primary),
                foregroundColor: AppTheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Sección header ──────────────────────────────────────────────────────────

class _Seccion extends StatelessWidget {
  final String titulo;
  const _Seccion({required this.titulo});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Text(
        titulo,
        style: const TextStyle(
          color: AppTheme.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ── Tarjeta de taller ────────────────────────────────────────────────────────

class _TallerCard extends StatelessWidget {
  final TallerCandidato candidato;
  final bool asignando;
  final VoidCallback onSeleccionar;
  final VoidCallback onToggleFav;

  const _TallerCard({
    required this.candidato,
    required this.asignando,
    required this.onSeleccionar,
    required this.onToggleFav,
  });

  @override
  Widget build(BuildContext context) {
    final c = candidato;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: c.esFavorito
              ? AppTheme.secondary.withAlpha(120)
              : AppTheme.border,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Nombre + estrella favorito
            Row(
              children: [
                Expanded(
                  child: Text(
                    c.nombre,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                ),
                GestureDetector(
                  onTap: onToggleFav,
                  child: Icon(
                    c.esFavorito ? Icons.star_rounded : Icons.star_border_rounded,
                    color: c.esFavorito
                        ? AppTheme.secondary
                        : AppTheme.textSecondary,
                    size: 22,
                  ),
                ),
              ],
            ),
            if (c.direccion != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.location_on_rounded,
                      size: 13, color: AppTheme.textSecondary),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      c.direccion!,
                      style: const TextStyle(
                          color: AppTheme.textSecondary, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            // Distancia + ETA
            Row(
              children: [
                if (c.distanciaKm != null) ...[
                  _Chip(
                    icon: Icons.directions_car_rounded,
                    label: '${c.distanciaKm!.toStringAsFixed(1)} km',
                  ),
                  const SizedBox(width: 6),
                ],
                if (c.etaMinutos != null) ...[
                  _Chip(
                    icon: Icons.timer_rounded,
                    label: '~${c.etaMinutos} min',
                    color: AppTheme.primary,
                  ),
                  const SizedBox(width: 6),
                ],
              ],
            ),
            // Servicios compatibles
            if (c.tipoServicios.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: c.tipoServicios
                    .map((s) => _Chip(label: s, small: true))
                    .toList(),
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: asignando ? null : onSeleccionar,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                child: asignando
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Seleccionar este taller',
                        style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color color;
  final bool small;

  const _Chip({
    required this.label,
    this.icon,
    this.color = AppTheme.textSecondary,
    this.small = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: small ? 6 : 8, vertical: small ? 2 : 3),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: color),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: TextStyle(
                color: color,
                fontSize: small ? 10 : 11,
                fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
