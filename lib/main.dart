import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:provider/provider.dart';
import 'core/router.dart';
import 'core/theme.dart';
import 'core/dio_client.dart';
import 'providers/auth_provider.dart';
import 'providers/vehiculo_provider.dart';
import 'providers/incidente_provider.dart';
import 'providers/notificacion_provider.dart';
import 'providers/pago_provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  Stripe.publishableKey =
      'pk_test_51TOLnxExIDA2tDULzXwKjMcIBWHJjAzfkBP3VZCbaJnxhvO9i7xVnu9zNbJ6FASu4Ck0tYGuzNv0DcW3WU696AtO009E3QwoqK';
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
  void initState() {
    super.initState();
    // If the interceptor exhausts the refresh token, force logout.
    DioClient.instance.sessionExpired.addListener(_onSessionExpired);
  }

  @override
  void dispose() {
    DioClient.instance.sessionExpired.removeListener(_onSessionExpired);
    super.dispose();
  }

  void _onSessionExpired() {
    if (DioClient.instance.sessionExpired.value) {
      DioClient.instance.sessionExpired.value = false; // reset for reuse
      widget.authProvider.logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: widget.authProvider),
        ChangeNotifierProvider(create: (_) => VehiculoProvider()),
        ChangeNotifierProvider(create: (_) => IncidenteProvider()),
        ChangeNotifierProvider(create: (_) => NotificacionProvider()),
        ChangeNotifierProvider(create: (_) => PagoProvider()),
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
