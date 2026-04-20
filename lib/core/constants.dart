class AppConstants {
  // Backend base URL
  // Android emulator: 10.0.2.2 maps to host machine localhost
  // iOS simulator: use localhost
  // Physical device: use your machine's LAN IP (e.g. 192.168.x.x)192.168.100.11
  // Para web/iOS simulator usa localhost; para emulador Android usa 10.0.2.2
  // Dispositivo físico por USB → ejecutar: adb reverse tcp:8000 tcp:8000
  // Emulador Android           → cambiar a http://10.0.2.2:8000
  // Dispositivo físico por WiFi → cambiar a http://192.168.100.11:8000
  static const String baseUrl = 'http://localhost:8000';

  // SharedPreferences keys
  static const String tokenKey = 'access_token';
  static const String refreshTokenKey = 'refresh_token';
}
