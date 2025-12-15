# Visualizador SIOP

Aplicación de escritorio Flutter para Windows que carga archivos Excel del sistema SIOP y dibuja la derrota completa de un buque sobre un mapa, habilitando un timeline para animar su posición a lo largo del tiempo.

## Requisitos previos
- Windows 10/11 con herramientas de desarrollo habilitadas (Visual Studio con workload de "Desktop development with C++").
- Flutter en el canal `stable` y `flutter doctor` limpio para Windows.
- NSIS 3.x instalado para empaquetar el instalador (makensis disponible en `PATH`).
- Excel con columnas: `Buque`, `Matricula`, `Fecha` (formato `dd/MM/yyyy HH:mm` o serial), `Latitud`, `Longitud`, `Velocidad` y `Rumbo`.

## Paso 1: Preparar el entorno de desarrollo
1. Ejecuta `flutter pub get` para descargar dependencias.
2. Genera los providers anotados con Riverpod: `dart run build_runner build --delete-conflicting-outputs`.
3. Corre `flutter analyze` para validar tipos y reglas estrictas definidas en `analysis_options.yaml`.
4. Abre `windows/runner/main.cpp` y antes de `runLoop` agrega la configuración de `bitsdojo_window`:
   ```cpp
   #include <bitsdojo_window_windows/bitsdojo_window_plugin.h>
   auto bdw = bitsdojo_window_configure(BDW_CUSTOM_FRAME | BDW_HIDE_ON_STARTUP);
   ```
   Esto habilita la barra de título personalizada y respeta el ancho mínimo especificado.

## Paso 2: Entender la arquitectura
- **Domain:** `ShipPosition` es el modelo inmutable con las propiedades `vesselName`, `registration`, `timestamp`, `latitude`, `longitude`, `speed` y `heading`.
- **Data:** Un servicio de parsing lee el Excel usando `excel`, detecta fechas como texto o número serial y devuelve una lista ordenada cronológicamente.
- **Presentation:** Widgets impulsados por Riverpod consumen los providers generados y mantienen todo acoplado de forma reactiva.

### Providers clave (riverpod_annotation obligatorio)
1. `filePickerProvider`: controla el diálogo de `file_picker` y entrega el archivo seleccionado.
2. `shipTrackRepositoryProvider`: instancia que parsea el Excel y construye `ShipPosition`.
3. `trackDataProvider`: FutureProvider que depende del file picker y retorna la lista ordenada de puntos.
4. `playbackControllerProvider`: Notifier que guarda `currentIndex`, `isPlaying` y `playbackSpeed` y expone `seekTo`, `nextFrame` y `togglePlay` para el slider y los controles.

## Paso 3: UI y comportamiento
- **Sidebar/Header:** incluye el botón "Cargar Excel", muestra nombre y matrícula del buque (primera fila) y estadísticas como total de puntos y rango de fechas.
- **Mapa (FlutterMap + latlong2):**
  - La `Polyline` gris/azul claro traza toda la ruta usando todos los puntos.
  - El `Marker` representa el barco en `trackData[currentIndex]` y rota según `heading` para simular el rumbo.
  - Usa `MapController` para centrar la vista cuando se carga una nueva hoja y evitar redraw innecesario.
- **Panel inferior (timeline):**
  - Slider de `0` a `totalPoints - 1` enlazado a `playbackControllerProvider` para que moverlo actualice inmediatamente la posición del `Marker`.
  - Labels muestran la fecha/hora formateada con `intl` y la velocidad en el punto activo.
  - Controles de reproducción (`Play/Pause`) usan `togglePlay` y pueden adelantar con `nextFrame`.
- **Errores:** Si el archivo tiene formato incorrecto, muestra un `Snackbar` o `Dialog` amigable (no dejar la app bloqueada).
- **Performance:** Si el listado supera los 10.000 puntos, se puede simplificar la `Polyline` pero el `Marker` debe seguir asíncornamente con precisión.

## Comandos de desarrollo
- Ejecutar en modo escritorio: `flutter run -d windows`.
- Recompilar providers tras cambios: `dart run build_runner build --delete-conflicting-outputs`.
- Validar código: `flutter analyze`.
- Ejecutar tests unitarios: `flutter test`.

## Generar el instalador para Windows
1. Compilar release: `flutter build windows --release`. Esto coloca el ejecutable y recursos en `build/windows/x64/runner/Release/`.
2. Asegurarse de tener `docs/LICENSE.txt` actualizado, ya que la NSIS copia ese archivo explicítamente.
3. Ejecutar `makensis installer.nsi` desde la raíz del proyecto. El script ya define nombre del instalador (`installer/InstalarVisualizadorSIOP.exe`), accesos directos en escritorio y menú inicio, y registra el desinstalador.
4. Si necesitas modificar la UI del instalador o el icono, edita `installer.nsi` y los íconos en `windows/runner/resources/`.

## Recomendaciones finales
- Mantén los modelos anotados con `@immutable` y evita lógica de parsing dentro de la UI.
- Mantén los widgets reutilizables; extrae componentes comunes para cumplir con DRY.
- El mapa, el parsing del Excel y el control del timeline deben mantenerse separados (Separation of Concerns).
- Si se detectan errores al parsear fechas, agrega logging y muestra retroalimentación clara para el usuario.

Con estos pasos estarás listo para continuar con el desarrollo y empaquetado del Visualizador SIOP en Windows.
