import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/incidente_provider.dart';
import '../../providers/vehiculo_provider.dart';

class ReportEmergencyScreen extends StatefulWidget {
  const ReportEmergencyScreen({super.key});

  @override
  State<ReportEmergencyScreen> createState() => _ReportEmergencyScreenState();
}

class _ReportEmergencyScreenState extends State<ReportEmergencyScreen> {
  final PageController _pageController = PageController();
  int _step = 0; // 0: vehículo, 1: evidencias, 2: ubicación+enviar

  // Step 1
  String? _vehiculoId;

  // Step 2 — fotos
  final List<XFile> _imagenes = [];
  final TextEditingController _descCtrl = TextEditingController();

  // Step 2 — audio
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();
  String? _audioPath;
  bool _recording = false;
  bool _playingAudio = false;

  // Step 3
  Position? _position;
  bool _gettingLocation = false;
  bool _sending = false;
  String? _incidenteIdCreado; // para cancelar si analizar falla

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<VehiculoProvider>().load(context.read<AuthProvider>().token!);
      _getLocation();
    });
    _player.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _playingAudio = state == PlayerState.playing);
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _descCtrl.dispose();
    _recorder.dispose();
    _player.dispose();
    super.dispose();
  }

  // ── Ubicación ──────────────────────────────────────────────────────────────

  Future<void> _getLocation() async {
    setState(() => _gettingLocation = true);
    try {
      final status = await Permission.locationWhenInUse.request();
      if (!status.isGranted) {
        _showError('Se necesita permiso de ubicación para continuar.');
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );
      setState(() => _position = pos);
    } catch (e) {
      _showError('No se pudo obtener la ubicación.');
    } finally {
      setState(() => _gettingLocation = false);
    }
  }

  // ── Imagen ─────────────────────────────────────────────────────────────────

  Future<void> _pickImage() async {
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      _showError('Se necesita permiso de cámara.');
      return;
    }
    final source = await _showImageSourceDialog();
    if (source == null) return;
    final file = await ImagePicker().pickImage(source: source, imageQuality: 80);
    if (file != null) setState(() => _imagenes.add(file));
  }

  Future<ImageSource?> _showImageSourceDialog() {
    return showDialog<ImageSource>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Agregar foto'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded),
              title: const Text('Tomar foto'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Desde galería'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
  }

  // ── Audio ──────────────────────────────────────────────────────────────────

  Future<void> _toggleGrabacion() async {
    if (_recording) {
      final path = await _recorder.stop();
      setState(() {
        _recording = false;
        _audioPath = path;
      });
    } else {
      final status = await Permission.microphone.request();
      if (!status.isGranted) {
        _showError('Se necesita permiso de micrófono.');
        return;
      }
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/audio_emergencia_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _recorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc, sampleRate: 16000),
        path: path,
      );
      setState(() {
        _recording = true;
        _audioPath = null;
      });
    }
  }

  Future<void> _toggleReproducir() async {
    if (_playingAudio) {
      await _player.stop();
    } else if (_audioPath != null) {
      await _player.play(DeviceFileSource(_audioPath!));
    }
  }

  void _eliminarAudio() {
    _player.stop();
    setState(() => _audioPath = null);
  }

  // ── Flujo principal ────────────────────────────────────────────────────────

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _nextStep() {
    if (_step < 2) {
      setState(() => _step++);
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _prevStep() {
    if (_step > 0) {
      setState(() => _step--);
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _submit() async {
    if (_position == null || _sending) return; // evita doble envío

    // Capturar todas las referencias de context ANTES de cualquier await
    final token    = context.read<AuthProvider>().token!;
    final provider = context.read<IncidenteProvider>();
    final router   = GoRouter.of(context);

    if (_recording) await _recorder.stop();

    setState(() => _sending = true);

    try {
      // Paso 1 — crear incidente
      final inc = await provider.crear(
        token,
        latitud: _position!.latitude,
        longitud: _position!.longitude,
        descripcion: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        vehiculoId: _vehiculoId,
      );
      _incidenteIdCreado = inc.id;

      // Paso 2 — subir imágenes
      for (final img in _imagenes) {
        try {
          await provider.subirEvidencia(
            token, incidenteId: inc.id, filePath: img.path, tipo: 'imagen',
          );
        } catch (_) {}
      }

      // Paso 2 — subir audio
      if (_audioPath != null) {
        try {
          await provider.subirEvidencia(
            token, incidenteId: inc.id, filePath: _audioPath!, tipo: 'audio',
          );
        } catch (_) {}
      }

      // Paso 3 — análisis IA + asignación
      await provider.analizar(token, incidenteId: inc.id);

      if (!mounted) return;
      router.pushReplacement('/monitor/${inc.id}');
    } catch (e) {
      // Si el incidente fue creado pero analizar falló, cancelarlo para
      // no dejar un incidente huérfano sin evidencias en la BD.
      if (_incidenteIdCreado != null) {
        try {
          await provider.cancelar(token, _incidenteIdCreado!);
        } catch (_) {}
        _incidenteIdCreado = null;
      }

      if (!mounted) return;
      // Volver al paso de evidencias para que el usuario pueda agregar algo
      setState(() {
        _sending = false;
        _step = 1;
      });
      _pageController.animateToPage(
        1,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      _showError('Agrega al menos una foto, nota de voz o descripción antes de enviar.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Reportar emergencia — Paso ${_step + 1}/3'),
        leading: _step == 0
            ? IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => context.pop(),
              )
            : IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: _prevStep,
              ),
      ),
      body: Column(
        children: [
          _StepIndicator(step: _step),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _Step1Vehiculo(
                  selected: _vehiculoId,
                  onSelect: (id) => setState(() => _vehiculoId = id),
                  onNext: _nextStep,
                ),
                _Step2Evidencias(
                  imagenes: _imagenes,
                  descCtrl: _descCtrl,
                  onAddImage: _pickImage,
                  onRemove: (i) => setState(() => _imagenes.removeAt(i)),
                  onNext: _nextStep,
                  // audio
                  recording: _recording,
                  playingAudio: _playingAudio,
                  audioPath: _audioPath,
                  onToggleGrabacion: _toggleGrabacion,
                  onToggleReproducir: _toggleReproducir,
                  onEliminarAudio: _eliminarAudio,
                ),
                _Step3Confirmar(
                  position: _position,
                  gettingLocation: _gettingLocation,
                  sending: _sending,
                  onRetryLocation: _getLocation,
                  onSubmit: _submit,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Step indicator ─────────────────────────────────────────────────────────────
class _StepIndicator extends StatelessWidget {
  final int step;
  const _StepIndicator({required this.step});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: List.generate(3, (i) {
          final active = i == step;
          final done = i < step;
          return Expanded(
            child: Container(
              margin: EdgeInsets.only(right: i < 2 ? 6 : 0),
              height: 4,
              decoration: BoxDecoration(
                color: done || active ? AppTheme.primary : AppTheme.border,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ── Step 1: Selección de vehículo ─────────────────────────────────────────────
class _Step1Vehiculo extends StatelessWidget {
  final String? selected;
  final ValueChanged<String?> onSelect;
  final VoidCallback onNext;

  const _Step1Vehiculo({
    required this.selected,
    required this.onSelect,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final vehProv = context.watch<VehiculoProvider>();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('¿Qué vehículo necesita asistencia?',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text('Opcional — ayuda al técnico a prepararse',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          const SizedBox(height: 24),

          if (vehProv.loading)
            const Center(child: CircularProgressIndicator())
          else if (vehProv.vehiculos.isEmpty)
            _EmptyCard(
              icon: Icons.directions_car_outlined,
              text: 'No tienes vehículos registrados.\nPuedes continuar sin seleccionar uno.',
            )
          else
            ...vehProv.vehiculos.map((v) {
              final isSelected = selected == v.id;
              return GestureDetector(
                onTap: () => onSelect(isSelected ? null : v.id),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? AppTheme.primary : AppTheme.border,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.directions_car_rounded,
                          color: isSelected ? AppTheme.primary : AppTheme.textSecondary),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${v.marca} ${v.modelo}',
                                style: const TextStyle(fontWeight: FontWeight.w600)),
                            Text(
                              '${v.placa}${v.anio != null ? ' · ${v.anio}' : ''}${v.color != null ? ' · ${v.color}' : ''}',
                              style: TextStyle(
                                  color: AppTheme.textSecondary, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      if (isSelected)
                        const Icon(Icons.check_circle_rounded,
                            color: AppTheme.primary, size: 20),
                    ],
                  ),
                ),
              );
            }),

          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: onNext,
            child: const Text('Continuar'),
          ),
          if (selected != null) ...[
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: () => onSelect(null),
                child: const Text('Continuar sin vehículo'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Step 2: Evidencias ────────────────────────────────────────────────────────
class _Step2Evidencias extends StatelessWidget {
  final List<XFile> imagenes;
  final TextEditingController descCtrl;
  final VoidCallback onAddImage;
  final ValueChanged<int> onRemove;
  final VoidCallback onNext;

  // audio
  final bool recording;
  final bool playingAudio;
  final String? audioPath;
  final VoidCallback onToggleGrabacion;
  final VoidCallback onToggleReproducir;
  final VoidCallback onEliminarAudio;

  const _Step2Evidencias({
    required this.imagenes,
    required this.descCtrl,
    required this.onAddImage,
    required this.onRemove,
    required this.onNext,
    required this.recording,
    required this.playingAudio,
    required this.audioPath,
    required this.onToggleGrabacion,
    required this.onToggleReproducir,
    required this.onEliminarAudio,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Documenta la emergencia',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text('Se requiere al menos una foto, nota de voz o descripción',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          const SizedBox(height: 24),

          // ── Fotos ──────────────────────────────────────────────────────
          const _SectionLabel(icon: Icons.photo_camera_rounded, label: 'Fotos del problema'),
          const SizedBox(height: 10),
          if (imagenes.isNotEmpty) ...[
            SizedBox(
              height: 110,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: imagenes.length + 1,
                itemBuilder: (ctx, i) {
                  if (i == imagenes.length) {
                    return _AddImageTile(onTap: onAddImage);
                  }
                  return Stack(
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          image: DecorationImage(
                            image: FileImage(File(imagenes[i].path)),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 12,
                        child: GestureDetector(
                          onTap: () => onRemove(i),
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close_rounded,
                                size: 18, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ] else ...[
            _AddImageTile(onTap: onAddImage, fullWidth: true),
          ],

          const SizedBox(height: 24),

          // ── Audio ───────────────────────────────────────────────────────
          const _SectionLabel(icon: Icons.mic_rounded, label: 'Nota de voz'),
          const SizedBox(height: 10),
          _AudioWidget(
            recording: recording,
            playing: playingAudio,
            audioPath: audioPath,
            onToggleGrabacion: onToggleGrabacion,
            onToggleReproducir: onToggleReproducir,
            onEliminar: onEliminarAudio,
          ),

          const SizedBox(height: 24),

          // ── Descripción ────────────────────────────────────────────────
          const _SectionLabel(icon: Icons.text_fields_rounded, label: 'Descripción (opcional)'),
          const SizedBox(height: 10),
          TextField(
            controller: descCtrl,
            maxLines: 3,
            maxLength: 500,
            decoration: const InputDecoration(
              hintText: 'Ej: El motor no enciende, hay humo...',
              alignLabelWithHint: true,
            ),
          ),

          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () {
              final tieneEvidencia = imagenes.isNotEmpty ||
                  audioPath != null ||
                  descCtrl.text.trim().isNotEmpty;
              if (!tieneEvidencia) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Row(
                      children: [
                        Icon(Icons.warning_amber_rounded,
                            color: Colors.white, size: 18),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Agrega al menos una foto, nota de voz o descripción para que podamos clasificar tu emergencia.',
                          ),
                        ),
                      ],
                    ),
                    backgroundColor: AppTheme.error,
                    duration: const Duration(seconds: 4),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                return;
              }
              onNext();
            },
            child: const Text('Continuar'),
          ),
        ],
      ),
    );
  }
}

// ── Widget de grabación de audio ──────────────────────────────────────────────
class _AudioWidget extends StatelessWidget {
  final bool recording;
  final bool playing;
  final String? audioPath;
  final VoidCallback onToggleGrabacion;
  final VoidCallback onToggleReproducir;
  final VoidCallback onEliminar;

  const _AudioWidget({
    required this.recording,
    required this.playing,
    required this.audioPath,
    required this.onToggleGrabacion,
    required this.onToggleReproducir,
    required this.onEliminar,
  });

  @override
  Widget build(BuildContext context) {
    if (audioPath != null) {
      // Audio grabado — mostrar controles
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.success.withAlpha(20),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.success.withAlpha(80)),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle_rounded,
                color: AppTheme.success, size: 20),
            const SizedBox(width: 10),
            const Expanded(
              child: Text('Nota de voz grabada',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.success,
                      fontSize: 14)),
            ),
            // Reproducir / pausar
            IconButton(
              onPressed: onToggleReproducir,
              icon: Icon(
                playing ? Icons.stop_rounded : Icons.play_arrow_rounded,
                color: AppTheme.textSecondary,
              ),
              tooltip: playing ? 'Detener' : 'Escuchar',
            ),
            // Eliminar
            IconButton(
              onPressed: onEliminar,
              icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.error),
              tooltip: 'Eliminar nota',
            ),
          ],
        ),
      );
    }

    // Sin audio — botón para grabar
    return GestureDetector(
      onTap: onToggleGrabacion,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: recording
              ? AppTheme.error.withAlpha(20)
              : AppTheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: recording
                ? AppTheme.error.withAlpha(120)
                : AppTheme.primary.withAlpha(80),
          ),
        ),
        child: Column(
          children: [
            if (recording)
              _PulsingDot()
            else
              const Icon(Icons.mic_rounded, color: AppTheme.primary, size: 30),
            const SizedBox(height: 8),
            Text(
              recording ? 'Grabando... toca para terminar' : 'Toca para grabar una nota de voz',
              style: TextStyle(
                color: recording ? AppTheme.error : AppTheme.primary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Punto pulsante animado durante grabación ──────────────────────────────────
class _PulsingDot extends StatefulWidget {
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: Container(
        width: 18,
        height: 18,
        decoration: const BoxDecoration(
          color: AppTheme.error,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

// ── Step 3: Confirmar ubicación y enviar ──────────────────────────────────────
class _Step3Confirmar extends StatelessWidget {
  final Position? position;
  final bool gettingLocation;
  final bool sending;
  final VoidCallback onRetryLocation;
  final VoidCallback onSubmit;

  const _Step3Confirmar({
    required this.position,
    required this.gettingLocation,
    required this.sending,
    required this.onRetryLocation,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Confirma tu ubicación',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text('Usaremos tu posición GPS para enviar asistencia.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          const SizedBox(height: 28),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.border),
            ),
            child: gettingLocation
                ? const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 12),
                      Text('Obteniendo ubicación...'),
                    ],
                  )
                : position == null
                    ? Column(
                        children: [
                          const Icon(Icons.location_off_rounded,
                              color: AppTheme.error, size: 36),
                          const SizedBox(height: 10),
                          const Text('No se pudo obtener la ubicación',
                              textAlign: TextAlign.center),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: onRetryLocation,
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Reintentar'),
                            style: OutlinedButton.styleFrom(
                              minimumSize: Size.zero,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 10),
                            ),
                          ),
                        ],
                      )
                    : _LocationSuccess(position: position!),
          ),

          const SizedBox(height: 24),

          // Aviso sobre análisis IA
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.secondary.withAlpha(20),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.secondary.withAlpha(60)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.auto_awesome_rounded,
                    color: AppTheme.secondary, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'La IA analizará tus fotos y nota de voz para clasificar el problema y asignar el taller más adecuado.',
                    style: TextStyle(
                        color: AppTheme.textSecondary, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          if (sending) ...[
            const _SendingIndicator(),
          ] else ...[
            ElevatedButton.icon(
              onPressed: (position == null || sending) ? null : onSubmit,
              icon: const Icon(Icons.sos_rounded),
              label: const Text('Solicitar asistencia'),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Indicador de envío con pasos ──────────────────────────────────────────────
class _SendingIndicator extends StatelessWidget {
  const _SendingIndicator();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primary.withAlpha(60)),
      ),
      child: const Column(
        children: [
          SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
          SizedBox(height: 16),
          Text(
            'Enviando solicitud y analizando con IA...',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          SizedBox(height: 6),
          Text(
            'Esto puede tomar unos segundos',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

// ── Ubicación obtenida ────────────────────────────────────────────────────────
class _LocationSuccess extends StatelessWidget {
  final Position position;
  const _LocationSuccess({required this.position});

  _PrecisionInfo get _precision {
    final acc = position.accuracy;
    if (acc <= 10) return _PrecisionInfo('Excelente', AppTheme.success, Icons.signal_wifi_4_bar_rounded);
    if (acc <= 30) return _PrecisionInfo('Buena', AppTheme.success, Icons.network_wifi_rounded);
    if (acc <= 80) return _PrecisionInfo('Moderada', AppTheme.secondary, Icons.network_wifi_2_bar_rounded);
    return _PrecisionInfo('Baja — muévete al exterior', AppTheme.error, Icons.network_wifi_1_bar_rounded);
  }

  @override
  Widget build(BuildContext context) {
    final p = _precision;
    return Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: AppTheme.success.withAlpha(25),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.my_location_rounded,
              color: AppTheme.success, size: 28),
        ),
        const SizedBox(height: 10),
        const Text('Ubicación detectada',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(p.icon, color: p.color, size: 18),
            const SizedBox(width: 6),
            Text('Precisión ${p.label}',
                style: TextStyle(
                    color: p.color,
                    fontWeight: FontWeight.w600,
                    fontSize: 13)),
          ],
        ),
        const SizedBox(height: 4),
        Text('±${position.accuracy.toStringAsFixed(0)} metros',
            style: const TextStyle(
                color: AppTheme.textSecondary, fontSize: 12)),
        const SizedBox(height: 14),
        TextButton.icon(
          onPressed: () async {
            final uri = Uri.parse(
              'https://www.google.com/maps/search/?api=1&query=${position.latitude},${position.longitude}',
            );
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          },
          icon: const Icon(Icons.map_outlined, size: 16),
          label: const Text('Verificar en mapa'),
          style: TextButton.styleFrom(
            foregroundColor: AppTheme.textSecondary,
            textStyle: const TextStyle(fontSize: 13),
          ),
        ),
      ],
    );
  }
}

class _PrecisionInfo {
  final String label;
  final Color color;
  final IconData icon;
  const _PrecisionInfo(this.label, this.color, this.icon);
}

// ── Helpers compartidos ───────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SectionLabel({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.textSecondary),
        const SizedBox(width: 6),
        Text(label,
            style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3)),
      ],
    );
  }
}

class _AddImageTile extends StatelessWidget {
  final VoidCallback onTap;
  final bool fullWidth;
  const _AddImageTile({required this.onTap, this.fullWidth = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: fullWidth ? double.infinity : 100,
        height: 100,
        margin: EdgeInsets.only(right: fullWidth ? 0 : 8),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.primary.withAlpha(80)),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_a_photo_rounded, color: AppTheme.primary, size: 28),
            SizedBox(height: 6),
            Text('Agregar foto',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.primary, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final IconData icon;
  final String text;
  const _EmptyCard({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppTheme.textSecondary, size: 36),
          const SizedBox(height: 10),
          Text(text,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
        ],
      ),
    );
  }
}
