class AppConstants {
  // Backend base URL
  // Android emulator: 10.0.2.2 maps to host machine localhost
  // iOS simulator: use localhost
  // Physical device: use your machine's LAN IP (e.g. 192.168.x.x)
  // Para web/iOS simulator usa localhost; para emulador Android usa 10.0.2.2
  static const String baseUrl = 'http://localhost:8000';

  // SharedPreferences keys
  static const String tokenKey = 'access_token';
  static const String refreshTokenKey = 'refresh_token';
}
