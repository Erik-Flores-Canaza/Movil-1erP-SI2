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
  /// Roles allowed in this mobile app
  static const _allowedRoles = {'cliente', 'tecnico'};

  /// Called once at app launch from SplashScreen.
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(AppConstants.tokenKey);

    if (saved != null) {
      try {
        _token = saved;
        _user = await _usuarioService.getMe(saved);
        if (!_allowedRoles.contains(_user!.rol)) {
          await _clearSession();
          _status = AuthStatus.unauthenticated;
        } else {
          _status = AuthStatus.authenticated;
        }
      } catch (_) {
        // Access token expired or invalid — try refreshing silently.
        final refreshed = await _tryRefresh(prefs);
        if (!refreshed) {
          await _clearSession();
          _status = AuthStatus.unauthenticated;
        }
      }
    } else {
      _status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  /// Attempts to get a new access token using the stored refresh token.
  /// Returns true if successful and session is restored, false otherwise.
  Future<bool> _tryRefresh(SharedPreferences prefs) async {
    final refreshToken = prefs.getString(AppConstants.refreshTokenKey);
    if (refreshToken == null) return false;

    try {
      final data = await _authService.refresh(refreshToken);
      _token = data['access_token'] as String;
      await prefs.setString(AppConstants.tokenKey, _token!);
      if (data['refresh_token'] != null) {
        await prefs.setString(
            AppConstants.refreshTokenKey, data['refresh_token'] as String);
      }
      _user = await _usuarioService.getMe(_token!);
      if (!_allowedRoles.contains(_user!.rol)) return false;
      _status = AuthStatus.authenticated;
      return true;
    } catch (_) {
      return false;
    }
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

    if (!_allowedRoles.contains(_user!.rol)) {
      final nombre = _user!.nombreCompleto.trim().split(' ').first;
      await _clearSession();
      throw Exception(
        'Hola, $nombre. Esta app es solo para conductores y técnicos. '
        'Si administras un taller, accede desde la plataforma web.',
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
