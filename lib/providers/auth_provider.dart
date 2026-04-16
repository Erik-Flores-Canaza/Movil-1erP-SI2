import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/models/usuario.dart';
import '../data/services/auth_service.dart';
import '../data/services/usuario_service.dart';
import '../core/constants.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthProvider extends ChangeNotifier {
  final _authService = AuthService();
  final _usuarioService = UsuarioService();

  AuthStatus _status = AuthStatus.unknown;
  Usuario? _user;
  String? _token;

  AuthStatus get status => _status;
  Usuario? get user => _user;
  String? get token => _token;
  bool get isAuthenticated => _status == AuthStatus.authenticated;

  /// Called once at app launch from SplashScreen.
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(AppConstants.tokenKey);

    if (saved != null) {
      try {
        _token = saved;
        _user = await _usuarioService.getMe(saved);
        if (_user!.rol != 'cliente') {
          await _clearSession();
          _status = AuthStatus.unauthenticated;
        } else {
          _status = AuthStatus.authenticated;
        }
      } catch (_) {
        await _clearSession();
        _status = AuthStatus.unauthenticated;
      }
    } else {
      _status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  Future<void> login(String correo, String password) async {
    final data = await _authService.login(correo, password);
    _token = data['access_token'] as String;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.tokenKey, _token!);
    if (data['refresh_token'] != null) {
      await prefs.setString(
          AppConstants.refreshTokenKey, data['refresh_token'] as String);
    }

    _user = await _usuarioService.getMe(_token!);

    if (_user!.rol != 'cliente') {
      final nombre = _user!.nombreCompleto.trim().split(' ').first;
      await _clearSession();
      throw Exception(
        'Hola, $nombre. Esta app es para conductores que necesitan '
        'asistencia en carretera. Si eres parte de un taller, '
        'ingresa desde la plataforma web.',
      );
    }

    _status = AuthStatus.authenticated;
    notifyListeners();
  }

  Future<void> logout() async {
    if (_token != null) await _authService.logout(_token!);
    await _clearSession();
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  /// Registers a new client account then immediately logs in.
  Future<void> registerAndLogin({
    required String nombreCompleto,
    required String correo,
    required String telefono,
    required String password,
  }) async {
    await _authService.register(
      nombreCompleto: nombreCompleto,
      correo: correo,
      telefono: telefono,
      password: password,
    );
    await login(correo, password);
  }

  /// Called after profile update so UI reflects the new data.
  void setUser(Usuario updated) {
    _user = updated;
    notifyListeners();
  }

  Future<void> _clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.tokenKey);
    await prefs.remove(AppConstants.refreshTokenKey);
    _token = null;
    _user = null;
  }
}
