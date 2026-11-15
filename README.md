# PARQUE AUTOMOTOR BENJAMIN PAZ

App Flutter offline-first para gestión de vehículos y choferes, con
alertas de mantenimiento por kilometraje y vencimiento de carnet.

## Puesta en marcha rápida (offline, sin configurar nada)

```bash
cd fleet_app
flutter pub get
flutter run          # con un emulador/dispositivo Android o iOS conectado
```
Con estos 2 comandos la app **ya arranca y funciona 100% offline**
(login, vehículos, choferes, historial, alertas, PDF) sin necesitar
ninguna cuenta ni configuración extra. La sincronización online
(Firebase) es un paso aparte y opcional — ver más abajo.

## Arquitectura

```
lib/
  models/        -> Vehicle, Driver (entidades + lógica de estado)
  services/       -> DatabaseHelper (SQLite), NotificationService, AuthService
  providers/      -> VehicleProvider, DriverProvider (estado con Provider)
  screens/
    auth/          -> SetupScreen (alta única del usuario god), LoginScreen
    auth_gate.dart -> decide Setup / Login / Dashboard según el estado
    dashboard, vehicles/, drivers/
  widgets/        -> StatusBadge, StatCard (componentes reutilizables)
```

## Autenticación y roles

Hay dos tipos de cuentas, ambas con usuario + contraseña:

- **God (única)**: se crea una sola vez en `SetupScreen`, la primera
  vez que se abre la app. Es el único perfil con permiso para crear,
  editar y eliminar vehículos y choferes, y es el único que ve el
  botón **"Administrar usuarios"** (ícono de engranaje en el
  Dashboard).
- **Comunes (las que cree el god)**: se crean, editan y eliminan
  desde `UserManagementScreen` → `UserFormScreen`, accesible solo
  para el god. Un usuario común puede iniciar sesión y **ver** toda
  la información de vehículos y choferes, pero no puede crear,
  editar ni eliminar nada (los formularios se abren en modo lectura,
  sin botón de guardar ni de eliminar, y sin botón "Nuevo").

Las contraseñas se guardan siempre **hasheadas (SHA-256)** en la
base SQLite local (tabla `users`); la sesión activa (qué usuario
quedó logueado) se guarda aparte, cifrada, en el almacenamiento
seguro del sistema (Keychain iOS / Keystore Android).

- Botón de "Cerrar sesión" en el AppBar del Dashboard.
- Para resetear todo en desarrollo: borrar la app o eliminar
  `fleet_app.db` del dispositivo/emulador.

Capas: UI (screens/widgets) → Estado (providers) → Datos (services) → SQLite local.
Para agregar sync a Firebase/Supabase más adelante, se agrega un
`SyncService` que lea/escriba sobre las mismas tablas sin tocar UI.

## Historial de mantenimiento (arreglos y averías)

Además del campo libre "Observaciones", cada vehículo tiene un
historial estructurado (`maintenance_records`): tipo de evento
(Arreglo / Avería / Service / Otro), fecha, descripción, kilometraje
al momento del evento y costo opcional.

- Se accede desde el formulario del vehículo → botón "Ver historial
  de arreglos y averías".
- **Solo el usuario god puede cargar o eliminar registros.** Cualquier
  usuario logueado (god o común) puede verlos.

## Exportar reporte PDF

Botón 📄 en el AppBar del Dashboard, disponible para **cualquier
usuario logueado**. Genera un PDF con el estado de todos los
vehículos y choferes (incluye el nombre "PARQUE AUTOMOTOR BENJAMIN
PAZ" como encabezado) y abre el diálogo nativo de compartir/imprimir
del sistema operativo.

## Ícono de la app y logo institucional

Se integró el **logo oficial** (escudo del Servicio Penitenciario de
Tucumán — Parque Automotor Benjamín Paz) en:
- Ícono de la app en todas las resoluciones de Android
  (`android/app/src/main/res/mipmap-*`) y en el set completo de iOS
  (`ios/Runner/Assets.xcassets/AppIcon.appiconset`).
- `assets/images/logo.png`: usado dentro de la app en las pantallas
  de Login y configuración inicial, y como encabezado del reporte PDF.

Si en algún momento cambian el logo, basta con reemplazar
`assets/images/logo.png` y volver a correr el script de generación
de íconos (o pedírmelo).

## Modo online / offline

La app es **offline-first**: SQLite local es la fuente de verdad y
cubre el 100% de las funciones sin internet (crear/editar vehículos,
choferes, historial, alertas, PDF, login). La sincronización con la
nube (Cloud Firestore) es un agregado opcional para respaldo y para
compartir datos entre varios dispositivos del mismo parque automotor.

**Sin configurar Firebase:** la app funciona igual, 100% offline. El
chip del Dashboard muestra "Modo offline (base local)".

**Con Firebase configurado:**
- Al detectar conexión, sincroniza automáticamente (sube lo local,
  trae lo remoto).
- Botón manual "Sincronizar ahora" (ícono 🔄) en el Dashboard.
- Cada alta/edición/baja de vehículos, choferes e historial de
  mantenimiento se sube a la nube al instante si hay conexión; si no
  la hay, queda guardada en SQLite y se sube sola en la próxima
  sincronización.
- Los usuarios (login) **nunca** se suben a la nube, por seguridad:
  viven solo en SQLite + almacenamiento cifrado del dispositivo.

### Activar la sincronización (una sola vez, opcional)

1. Creá un proyecto gratis en https://console.firebase.google.com
2. Activá **Cloud Firestore** en el proyecto (modo producción).
3. En la carpeta del proyecto:
   ```bash
   dart pub global activate flutterfire_cli
   flutterfire configure
   ```
   Esto genera `lib/firebase_options.dart` con tus credenciales
   reales (reemplazando el placeholder) y coloca `google-services.json`
   / `GoogleService-Info.plist` donde corresponde.
4. Descomentá las 2 líneas de `com.google.gms.google-services` en
   `android/settings.gradle` y `android/app/build.gradle`.
5. En Firestore, configurá reglas de seguridad (ejemplo básico, ajustar
   según necesidad — esto NO incluye autenticación de Firebase, así
   que para producción real conviene sumar Firebase Auth o restringir
   por otro medio):
   ```
   rules_version = '2';
   service cloud.firestore {
     match /databases/{database}/documents {
       match /{document=**} {
         allow read, write: if true; // reemplazar por reglas reales
       }
     }
   }
   ```

## Compilar e instalar

### Cómo publicar una actualización (para que se instale sola, sin desinstalar)

Android solo deja instalar un APK "encima" del que ya está instalado si
dos cosas coinciden: la **firma** es la misma (ver key.properties /
grupo "keystore_credentials" en Codemagic) y el **número de versión**
es más alto que el que ya está instalado.

La firma ya queda resuelta sola si el grupo de variables de Codemagic
está cargado. El número de versión, en cambio, **hay que subirlo a
mano antes de cada build que vayas a instalar como actualización**:

1. Abrí `pubspec.yaml` (en GitHub, desde el navegador, igual que
   cuando corregiste los demás archivos).
2. Buscá la línea `version: 1.0.1+2`.
3. Subí en 1 el número que está después del signo `+` (en este
   ejemplo pasaría a `version: 1.0.2+3`). El número de adelante
   (`1.0.1`) es solo decorativo, no hace falta tocarlo.
4. Guardá el cambio (commit) y recién ahí iniciá el build en
   Codemagic.

Si te olvidás de este paso y el número queda igual al de la versión
instalada, Android va a volver a pedir que desinstales antes de
instalar la nueva.

### Requisitos previos
- Flutter SDK instalado (`flutter --version`)
- Android Studio (para Android) y Xcode (para iOS, solo en Mac)

### Pasos comunes
```bash
cd fleet_app
flutter pub get
```

### Android
```bash
flutter devices                 # ver emulador/dispositivo conectado
flutter run                     # modo debug
flutter build apk --release     # genera build/app/outputs/flutter-apk/app-release.apk
```
Instalar en un dispositivo conectado por USB (con depuración habilitada):
```bash
flutter install
```

### iOS (requiere macOS + Xcode)

Este repo incluye `Info.plist`, `Podfile` y `AppDelegate.swift` ya
configurados. El único archivo que Xcode necesita y que **no se puede
escribir a mano de forma confiable** es el proyecto binario
`Runner.xcodeproj`. Para generarlo (una sola vez, sin tocar tu código
en `lib/`):

```bash
cd fleet_app
flutter create --platforms=ios .   # completa solo lo que falta de iOS
cd ios && pod install && cd ..
open ios/Runner.xcworkspace        # configurar firma/Team en Xcode
flutter run                        # en simulador o dispositivo
flutter build ios --release        # luego archivar/subir desde Xcode
```
Para instalar en un iPhone físico se necesita una cuenta de Apple
Developer y firmar el build desde Xcode (Product > Archive > Distribute App).

> Nota equivalente para Android: si tu Android Studio no reconoce el
> wrapper de Gradle, corré `flutter create --platforms=android .` una
> vez para que complete los archivos binarios del wrapper
> (`gradlew`, `gradlew.bat`, `gradle-wrapper.jar`); el resto de la
> configuración (manifest, build.gradle, ícono) ya está lista en este repo.

## Notas
- Los permisos de notificaciones se piden automáticamente en iOS al iniciar.
- En Android 13+ puede requerirse declarar el permiso `POST_NOTIFICATIONS`
  en `android/app/src/main/AndroidManifest.xml`.
