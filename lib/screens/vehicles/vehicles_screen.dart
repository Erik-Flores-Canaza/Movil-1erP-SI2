import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../data/models/vehiculo.dart';
import '../../providers/auth_provider.dart';
import '../../providers/vehiculo_provider.dart';

class VehiclesScreen extends StatefulWidget {
  const VehiclesScreen({super.key});

  @override
  State<VehiclesScreen> createState() => _VehiclesScreenState();
}

class _VehiclesScreenState extends State<VehiclesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  void _load() {
    final token = context.read<AuthProvider>().token;
    if (token != null) {
      context.read<VehiculoProvider>().load(token);
    }
  }

  void _openSheet({Vehiculo? vehiculo}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _VehiculoSheet(vehiculo: vehiculo),
    ).then((_) => _load());
  }

  Future<void> _delete(Vehiculo v) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar vehículo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('¿Eliminar ${v.marca} ${v.modelo} (${v.placa})? Esta acción no se puede deshacer.'),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.error,
                foregroundColor: Colors.white,
              ),
              child: const Text('Sí, eliminar'),
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

    try {
      final token = context.read<AuthProvider>().token!;
      await context.read<VehiculoProvider>().delete(token, v.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vehículo eliminado')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo eliminar el vehículo'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis vehículos'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: Consumer<VehiculoProvider>(
        builder: (context, provider, _) {
          if (provider.loading) {
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.primary),
            );
          }

          if (provider.error != null) {
            return _ErrorState(
              message: provider.error!,
              onRetry: _load,
            );
          }

          if (provider.vehiculos.isEmpty) {
            return _EmptyState(onAdd: () => _openSheet());
          }

          return RefreshIndicator(
            color: AppTheme.primary,
            backgroundColor: AppTheme.surface,
            onRefresh: () async => _load(),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: provider.vehiculos.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final v = provider.vehiculos[i];
                return _VehiculoCard(
                  vehiculo: v,
                  onEdit: () => _openSheet(vehiculo: v),
                  onDelete: () => _delete(v),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openSheet(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Agregar vehículo',
            style: TextStyle(fontWeight: FontWeight.w600)),
      ),
    );
  }
}

// ── Vehiculo card ─────────────────────────────────────────────────────────────

class _VehiculoCard extends StatelessWidget {
  final Vehiculo vehiculo;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _VehiculoCard({
    required this.vehiculo,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppTheme.secondary.withAlpha(20),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.directions_car_rounded,
                  color: AppTheme.secondary, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${vehiculo.marca} ${vehiculo.modelo}',
                    style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 15),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _Tag(vehiculo.placa),
                      const SizedBox(width: 6),
                      _Tag('${vehiculo.anio}'),
                      const SizedBox(width: 6),
                      _Tag(vehiculo.color ?? '—'),
                    ],
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              color: AppTheme.surfaceElevated,
              icon: const Icon(Icons.more_vert_rounded,
                  color: AppTheme.textSecondary),
              onSelected: (v) {
                if (v == 'edit') onEdit();
                if (v == 'delete') onDelete();
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(children: [
                    Icon(Icons.edit_outlined,
                        size: 16, color: AppTheme.textPrimary),
                    SizedBox(width: 8),
                    Text('Editar'),
                  ]),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(children: [
                    Icon(Icons.delete_outline_rounded,
                        size: 16, color: AppTheme.error),
                    SizedBox(width: 8),
                    Text('Eliminar',
                        style: TextStyle(color: AppTheme.error)),
                  ]),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String text;
  const _Tag(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.border.withAlpha(120),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(text,
          style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w500)),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.surface,
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.border),
              ),
              child: const Icon(Icons.directions_car_outlined,
                  size: 40, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 20),
            Text('Sin vehículos registrados',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(
              'Agrega tu primer vehículo para poder\nreportar emergencias.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: 200,
              child: ElevatedButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Agregar vehículo'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Error state ───────────────────────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded,
                size: 48, color: AppTheme.textSecondary),
            const SizedBox(height: 16),
            Text(message,
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textSecondary)),
            const SizedBox(height: 20),
            SizedBox(
              width: 160,
              child: ElevatedButton(
                onPressed: onRetry,
                child: const Text('Reintentar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Add / Edit bottom sheet ───────────────────────────────────────────────────

class _VehiculoSheet extends StatefulWidget {
  final Vehiculo? vehiculo;
  const _VehiculoSheet({this.vehiculo});

  @override
  State<_VehiculoSheet> createState() => _VehiculoSheetState();
}

class _VehiculoSheetState extends State<_VehiculoSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _placaCtrl;
  late final TextEditingController _marcaCtrl;
  late final TextEditingController _modeloCtrl;
  late final TextEditingController _anioCtrl;
  late final TextEditingController _colorCtrl;
  bool _loading = false;

  bool get _isEditing => widget.vehiculo != null;

  @override
  void initState() {
    super.initState();
    final v = widget.vehiculo;
    _placaCtrl = TextEditingController(text: v?.placa ?? '');
    _marcaCtrl = TextEditingController(text: v?.marca ?? '');
    _modeloCtrl = TextEditingController(text: v?.modelo ?? '');
    _anioCtrl =
        TextEditingController(text: v != null ? '${v.anio}' : '');
    _colorCtrl = TextEditingController(text: v?.color ?? '');
  }

  @override
  void dispose() {
    _placaCtrl.dispose();
    _marcaCtrl.dispose();
    _modeloCtrl.dispose();
    _anioCtrl.dispose();
    _colorCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    try {
      final token = context.read<AuthProvider>().token!;
      final provider = context.read<VehiculoProvider>();
      final anio = int.parse(_anioCtrl.text.trim());

      if (_isEditing) {
        await provider.update(
          token,
          widget.vehiculo!.id,
          placa: _placaCtrl.text.trim(),
          marca: _marcaCtrl.text.trim(),
          modelo: _modeloCtrl.text.trim(),
          anio: anio,
          color: _colorCtrl.text.trim(),
        );
      } else {
        await provider.add(
          token,
          placa: _placaCtrl.text.trim(),
          marca: _marcaCtrl.text.trim(),
          modelo: _modeloCtrl.text.trim(),
          anio: anio,
          color: _colorCtrl.text.trim(),
        );
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditing
                ? 'Vehículo actualizado'
                : 'Vehículo agregado correctamente'),
          ),
        );
      }
    } on DioException catch (e) {
      if (!mounted) return;
      final detail = e.response?.data;
      final msg = detail is Map ? detail['detail']?.toString() : null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg ?? 'No se pudo guardar el vehículo'),
          backgroundColor: AppTheme.error,
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error de conexión'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          Text(
            _isEditing ? 'Editar vehículo' : 'Agregar vehículo',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 20),

          Form(
            key: _formKey,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _Field(
                        controller: _placaCtrl,
                        label: 'Placa',
                        hint: 'ABC-123',
                        textCapitalization: TextCapitalization.characters,
                        validator: (v) => (v == null || v.isEmpty)
                            ? 'Requerido'
                            : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _Field(
                        controller: _anioCtrl,
                        label: 'Año',
                        hint: '2020',
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Requerido';
                          final y = int.tryParse(v);
                          if (y == null || y < 1900 || y > 2030) {
                            return 'Año inválido';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _Field(
                        controller: _marcaCtrl,
                        label: 'Marca',
                        hint: 'Toyota',
                        validator: (v) => (v == null || v.isEmpty)
                            ? 'Requerido'
                            : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _Field(
                        controller: _modeloCtrl,
                        label: 'Modelo',
                        hint: 'Corolla',
                        validator: (v) => (v == null || v.isEmpty)
                            ? 'Requerido'
                            : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _Field(
                  controller: _colorCtrl,
                  label: 'Color',
                  hint: 'Blanco',
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Requerido' : null,
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: Colors.white),
                        )
                      : Text(_isEditing ? 'Guardar cambios' : 'Agregar'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final String? Function(String?)? validator;

  const _Field({
    required this.controller,
    required this.label,
    required this.hint,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.sentences,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      textInputAction: TextInputAction.next,
      style: const TextStyle(color: AppTheme.textPrimary),
      decoration: InputDecoration(labelText: label, hintText: hint),
      validator: validator,
    );
  }
}
