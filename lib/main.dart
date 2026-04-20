import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/router.dart';
import 'core/theme.dart';
import 'providers/auth_provider.dart';
import 'providers/vehiculo_provider.dart';
import 'providers/incidente_provider.dart';
import 'providers/notificacion_provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final authProvider = AuthProvider();
  runApp(EmergenciAutoApp(authProvider: authProvider));
}

class EmergenciAutoApp extends StatefulWidget {
  final AuthProvider authProvider;
  const EmergenciAutoApp({super.key, required this.authProvider});

  @override
  State<EmergenciAutoApp> createState() => _EmergenciAutoAppState();
}

class _EmergenciAutoAppState extends State<EmergenciAutoApp> {
  late final router = createRouter(widget.authProvider);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: widget.authProvider),
        ChangeNotifierProvider(create: (_) => VehiculoProvider()),
        ChangeNotifierProvider(create: (_) => IncidenteProvider()),
        ChangeNotifierProvider(create: (_) => NotificacionProvider()),
      ],
      child: MaterialApp.router(
        title: 'EmergenciAuto',
        theme: AppTheme.dark,
        routerConfig: router,
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
