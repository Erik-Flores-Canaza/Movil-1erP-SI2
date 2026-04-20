import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../data/services/usuario_service.dart';
import '../../providers/auth_provider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _service = UsuarioService();
  bool _loading = false;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user;
    _nombreCtrl.text = user?.nombreCompleto ?? '';
    _telefonoCtrl.text = user?.telefono ?? '';

    _nombreCtrl.addListener(_onChanged);
    _telefonoCtrl.addListener(_onChanged);
  }

  void _onChanged() => setState(() => _dirty = true);

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _telefonoCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    try {
      final auth = context.read<AuthProvider>();
      final updated = await _service.updateMe(
        auth.token!,
        nombreCompleto: _nombreCtrl.text.trim(),
        telefono: _telefonoCtrl.text.trim(),
      );
      auth.setUser(updated);
      setState(() => _dirty = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(children: [
              Icon(Icons.check_circle_outline, color: AppTheme.success, size: 18),
              SizedBox(width: 8),
              Text('Perfil actualizado correctamente'),
            ]),
          ),
        );
      }
    } on DioException catch (e) {
      if (!mounted) return;
      final detail = e.response?.data;
      final msg = detail is Map ? detail['detail']?.toString() : null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg ?? 'No se pudo actualizar el perfil'),
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

  Future<void> _confirmLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('¿Estás seguro de que quieres cerrar tu sesión?'),
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

    if (confirm == true && mounted) {
      await context.read<AuthProvider>().logout();
      if (mounted) context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi perfil'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (_dirty)
            TextButton(
              onPressed: _loading ? null : _save,
              child: const Text('Guardar'),
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // ── Avatar ────────────────────────────────────────────────
              CircleAvatar(
                radius: 40,
                backgroundColor: AppTheme.primary.withAlpha(25),
                child: Text(
                  user?.nombreCompleto.isNotEmpty == true
                      ? user!.nombreCompleto[0].toUpperCase()
                      : 'C',
                  style: const TextStyle(
                      color: AppTheme.primary,
                      fontSize: 32,
                      fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                user?.nombreCompleto ?? '',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.secondary.withAlpha(20),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Cliente',
                  style: TextStyle(
                      color: AppTheme.secondary,
                      fontWeight: FontWeight.w600,
                      fontSize: 12),
                ),
              ),
              const SizedBox(height: 28),

              // ── Form ──────────────────────────────────────────────────
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Información personal',
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(color: AppTheme.textSecondary)),
                    const SizedBox(height: 12),

                    // Nombre
                    TextFormField(
                      controller: _nombreCtrl,
                      textCapitalization: TextCapitalization.words,
                      style: const TextStyle(color: AppTheme.textPrimary),
                      decoration: const InputDecoration(
                        labelText: 'Nombre completo',
                        prefixIcon: Icon(Icons.person_outline_rounded),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'El nombre no puede estar vacío';
                        }
                        if (v.trim().length < 3) return 'Mínimo 3 caracteres';
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),

                    // Teléfono
                    TextFormField(
                      controller: _telefonoCtrl,
                      keyboardType: TextInputType.phone,
                      style: const TextStyle(color: AppTheme.textPrimary),
                      decoration: const InputDecoration(
                        labelText: 'Teléfono',
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return 'El teléfono no puede estar vacío';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),

                    // Correo (read-only)
                    TextFormField(
                      initialValue: user?.correo ?? '',
                      readOnly: true,
                      style: TextStyle(color: AppTheme.textSecondary),
                      decoration: InputDecoration(
                        labelText: 'Correo electrónico',
                        prefixIcon: const Icon(Icons.email_outlined),
                        suffixIcon: const Icon(Icons.lock_outline_rounded,
                            size: 16),
                        fillColor: AppTheme.surface.withAlpha(180),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              BorderSide(color: AppTheme.border.withAlpha(100)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text('  El correo no puede modificarse',
                        style:
                            TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                    const SizedBox(height: 28),

                    // Save button
                    ElevatedButton(
                      onPressed: (_loading || !_dirty) ? null : _save,
                      child: _loading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2.5, color: Colors.white),
                            )
                          : const Text('Guardar cambios'),
                    ),
                    const SizedBox(height: 32),

                    const Divider(),
                    const SizedBox(height: 16),

                    // Logout
                    OutlinedButton.icon(
                      onPressed: _confirmLogout,
                      icon: const Icon(Icons.logout_rounded,
                          color: AppTheme.error, size: 18),
                      label: const Text('Cerrar sesión',
                          style: TextStyle(color: AppTheme.error)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppTheme.error),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
