# EmergVial - Aplicación Móvil Cliente (Flutter)

Plataforma de emergencias vehiculares - App cliente para solicitar servicios de emergencia.

**Tecnología:** Flutter + Dart  
**Backend:** FastAPI en `http://localhost:8000` (debe estar corriendo)  
**Estado:** Ciclo 1 (Registro, autenticación, perfil, gestión de vehículos)

---

## Requisitos previos

| Herramienta | Versión mínima | Descarga |
|---|---|---|
| Flutter SDK | 3.9.0+ | [flutter.dev](https://flutter.dev/docs/get-started/install) |
| Dart | 3.9.0+ | Incluido con Flutter |
| Android SDK | 21+ | Incluido con Android Studio |
| iOS | 12.0+ | Requiere macOS + Xcode |
| Backend FastAPI | Corriendo | Ver `INSTRUCCIONES.md` en la raíz |

### Verificar instalación

```bash
flutter --version
flutter doctor
```

Si hay errores, sigue las instrucciones de `flutter doctor`.

---

## 1. Instalación de dependencias

```bash
cd Movil-1erP-SI2

# Descargar dependencias Pub
flutter pub get

# (Opcional) Analizar el código
flutter analyze
```

---

## 2. Configurar backend

El app hace solicitudes HTTP a **`http://localhost:8000`** por defecto.

### Opción A: Emulador Android con backend local
Para que el emulador acceda a `localhost`, abre `lib/core/constants.dart` y verifica:

```dart
const String API_BASE_URL = 'http://10.0.2.2:8000';
```

(Android redirige `10.0.2.2` a tu máquina host)

### Opción B: Dispositivo físico
Reemplaza en `lib/core/constants.dart`:

```dart
const String API_BASE_URL = 'http://<TU_IP_LOCAL>:8000';
```

Ejemplo: `http://192.168.1.100:8000`

### Opción C: iOS Emulator
El iOS Emulator accede a `localhost` directamente:

```dart
const String API_BASE_URL = 'http://localhost:8000';
```

---

## 3. Ejecutar en Android

### Configuración inicial (primera vez)

```bash
cd Movil-1erP-SI2

# Crear emulador o conectar dispositivo físico
flutter devices  # Ver dispositivos disponibles

# Descargar build tools
cd android
./gradlew clean
cd ..
```

### Ejecutar la app

```bash
# En emulador
flutter run

# En dispositivo específico
flutter run -d <device_id>

# Con modo debug
flutter run -v

# Para ver logs en tiempo real
flutter logs
```

### Troubleshooting Android

- **"Android SDK not found"**: Instala Android Studio o configura `ANDROID_HOME`
- **"Gradle build failed"**: Ejecuta `flutter clean && flutter pub get`
- **"Connected device not found"**: Verifica con `flutter devices` y `adb devices`

---

## 4. Ejecutar en iOS (solo macOS)

### Configuración inicial

```bash
cd ios
pod install
cd ..
```

### Ejecutar

```bash
# En simulador iOS
flutter run

# En dispositivo físico
flutter run -d <device_id>

# Ver simuladores disponibles
xcrun simctl list
```

### Troubleshooting iOS

- **Pod install fails**: Ejecuta `rm -rf ios/Pods && rm ios/Podfile.lock && flutter pub get`
- **Xcode permission denied**: Verifica `xcode-select --install`
- **"No provisioning profile found"**: Abre en Xcode (`open ios/Runner.xcworkspace`) y configura signing

---

## 5. Modo desarrollo (hot reload)

Durante el desarrollo, usa hot reload para cambios rápidos:

```bash
# En el CLI, presiona 'r' para hot reload
flutter run
r    # Hot reload
R    # Hot restart
q    # Quit
```

---

## 6. Cómo probar Ciclo 1

Asegúrate de que:
1. ✅ Backend FastAPI está corriendo en puerto 8000
2. ✅ Creaste un admin de taller en el backend (ver `INSTRUCCIONES.md`)
3. ✅ Configuraste la API_BASE_URL correctamente para tu dispositivo/emulador

### Flujo de prueba

#### 1. Registro de cliente

1. Abre la app → Pantalla de login
2. Ingresa email y contraseña nuevos
3. Haz clic en **"Registrarse"**
4. ✅ Debe crearse la cuenta como `cliente`

#### 2. Login

1. Ingresa el email y contraseña del cliente registrado
2. Haz clic en **"Iniciar sesión"**
3. ✅ Debes ver la pantalla **Home** (Dashboard)

#### 3. Perfil (CU-03)

1. Desde Home, toca el botón de **Perfil** (abajo derecha)
2. Verifica que muestre:
   - Nombre completo
   - Email
   - Teléfono (si lo ingresaste)
3. ✅ Edita tu nombre o teléfono y presiona **Guardar**

#### 4. Gestión de vehículos (CU-04)

1. Desde Home, toca el botón de **Vehículos**
2. Deberías ver una lista vacía (primer acceso)
3. Haz clic en **"Agregar vehículo"** (botón "+")
4. Completa:
   - Placa: `ABC-123` (ejemplo)
   - Marca: `Toyota`
   - Modelo: `Corolla`
   - Año: `2020`
5. ✅ Presiona **Crear vehículo**
6. ✅ El vehículo aparecerá en la lista

#### 5. Editar y eliminar vehículos

1. En la lista de vehículos, presiona un vehículo
2. ✅ Verifica datos (edición)
3. Presiona **Eliminar** si lo deseas
4. ✅ El vehículo se elimina de la lista

---

## 7. Endpoints utilizados (Ciclo 1)

| Método | Endpoint | Rol | Descripción |
|---|---|---|---|
| POST | `/auth/registro` | Público | Registrar cliente |
| POST | `/auth/login` | Público | Iniciar sesión |
| GET | `/usuarios/me` | Cliente | Ver perfil propio |
| PATCH | `/usuarios/me` | Cliente | Editar perfil |
| PATCH | `/usuarios/me/contrasena` | Cliente | Cambiar contraseña |
| POST | `/vehiculos` | Cliente | Crear vehículo |
| GET | `/vehiculos` | Cliente | Listar vehículos propios |
| PATCH | `/vehiculos/{id}` | Cliente | Editar vehículo |
| DELETE | `/vehiculos/{id}` | Cliente | Eliminar vehículo |

---

## 8. Estructura del proyecto

```
lib/
├── main.dart                    # Punto de entrada
├── core/
│   ├── constants.dart          # API_BASE_URL, colores, constantes
│   ├── router.dart             # Rutas con GoRouter
│   └── theme.dart              # Tema Material 3
├── data/
│   ├── models/
│   │   ├── usuario.dart        # Modelo Usuario
│   │   └── vehiculo.dart       # Modelo Vehículo
│   └── services/
│       ├── auth_service.dart   # Login, registro, refresh token
│       ├── usuario_service.dart # Ver/editar perfil
│       └── vehiculo_service.dart # CRUD vehículos
├── providers/
│   ├── auth_provider.dart      # Estado auth (Provider)
│   └── vehiculo_provider.dart  # Estado vehículos (Provider)
└── screens/
    ├── splash/
    │   └── splash_screen.dart
    ├── auth/
    │   ├── login_screen.dart
    │   └── register_screen.dart
    ├── home/
    │   └── home_screen.dart    # Dashboard
    ├── profile/
    │   └── profile_screen.dart
    └── vehicles/
        └── vehicles_screen.dart
```

---

## 9. Variables de entorno

Por defecto, el app usa `lib/core/constants.dart` para la configuración. Si necesitas variables de entorno:

1. Crea `.env` en la raíz del proyecto:
   ```
   API_BASE_URL=http://10.0.2.2:8000
   API_TIMEOUT=30000
   ```

2. Usa el paquete `flutter_dotenv`:
   ```bash
   flutter pub add flutter_dotenv
   ```

3. Carga en `main.dart`:
   ```dart
   import 'package:flutter_dotenv/flutter_dotenv.dart';
   
   void main() async {
     await dotenv.load();
     runApp(const MyApp());
   }
   ```

---

## 10. Debugging y logs

### Ver logs en tiempo real

```bash
flutter logs
flutter logs -f  # Seguimiento continuo
```

### Debugger en VS Code

1. Abre `.vscode/launch.json`
2. Añade configuración para Flutter:
   ```json
   {
     "name": "Flutter",
     "type": "dart",
     "request": "launch",
     "program": "lib/main.dart",
     "console": "integratedTerminal",
   }
   ```
3. Presiona F5 para iniciar debug

---

## 11. Build para producción

### Android APK

```bash
flutter build apk --release
# Salida: build/app/outputs/flutter-apk/app-release.apk
```

### Android App Bundle (Google Play)

```bash
flutter build appbundle --release
# Salida: build/app/outputs/bundle/release/app-release.aab
```

### iOS

```bash
flutter build ios --release
# Abre Xcode para distribuir: open ios/Runner.xcworkspace
```

---

## 12. Comandos útiles

```bash
flutter clean              # Limpiar archivos generados
flutter pub get           # Descargar dependencias
flutter analyze           # Lint y análisis estático
flutter test              # Ejecutar tests unitarios
flutter pub upgrade       # Actualizar dependencias
flutter pub outdated      # Verificar dependencias desactualizadas
flutter format .          # Formatear código Dart
```

---

## 13. Contacto y soporte

- **Backend:** Ver `INSTRUCCIONES.md` en raíz del proyecto
- **Documentación API:** http://localhost:8000/docs (Swagger)
- **Flutter Docs:** https://flutter.dev/docs
