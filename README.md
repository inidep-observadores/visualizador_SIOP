# Visualizador SIOP

**Visualizador SIOP** es una aplicación de escritorio de alto rendimiento desarrollada con Flutter para Windows. Su objetivo principal es permitir a los usuarios cargar, analizar y visualizar trayectorias de buques a partir de datos exportados del sistema SIOP, proporcionando herramientas avanzadas de navegación temporal y detección de etapas de pesca.

## 🚀 Funcionalidades Principales

- **Visualización Cartográfica Dinámica:** Representación precisa de la derrota del buque sobre un mapa interactivo (FlutterMap).
- **Simulación y Reproducción:** Timeline interactivo que permite animar la posición del buque, con controles de velocidad, play/pausa y navegación paso a paso.
- **Detección Automática de Etapas:** Algoritmo inteligente que identifica automáticamente los viajes o etapas de pesca basándose en el comportamiento de la velocidad y el posicionamiento.
- **Filtro Temporal Avanzado:** Slider de rango de fechas que permite aislar periodos específicos de navegación para un análisis detallado.
- **Soporte Multiformato Inteligente:** Carga de archivos **Excel (.xlsx)** y **CSV** con detección automática de buques. Soporta archivos con múltiples embarcaciones, separando y asociando los datos automáticamente.
- **Panel de Información Detallada:** Visualización en tiempo real de coordenadas (GGº MM.MMM'), rumbo, velocidad y datos del buque.
- **Gestión de Capas:** Control total sobre la visibilidad de los puntos de posición, la trayectoria y áreas geográficas específicas.

## 🛠️ Requisitos Previos

- **Sistema:** Windows 10/11 (64 bits).
- **Desarrollo:**
  - Flutter (canal `stable`) con el entorno configurado para Windows.
  - Visual Studio con el workload "Desktop development with C++".
  - NSIS 3.x para la generación del instalador.

## 💻 Guía de Desarrollo

### 1. Configuración del Entorno
1. Ejecuta `flutter pub get` para instalar las dependencias.
2. Genera el código de los providers de Riverpod:
   ```bash
   dart run build_runner build --delete-conflicting-outputs
   ```
3. Verifica la configuración de `bitsdojo_window` en `windows/runner/main.cpp` (ver notas en el código).

### 2. Arquitectura del Proyecto
La aplicación sigue una arquitectura limpia dividida en capas:
- **Domain:** Modelos inmutables como `ShipPosition`.
- **Data:** Servicios de parsing para Excel/CSV y repositorios de datos.
- **Application:** Gestión de estado mediante Riverpod (providers para playback, filtrado y carga de archivos).
- **Presentation:** Widgets reactivos y pantallas optimizadas para escritorio.

### 3. Comandos Útiles
- **Ejecutar en desarrollo:** `flutter run -d windows`
- **Analizar código:** `flutter analyze`
- **Ejecutar tests:** `flutter test`

## 📦 Generación de Releases

Para generar una nueva versión de la aplicación:

1. **Compilar el binario:**
   ```bash
   flutter build windows --release
   ```
2. **Generar el instalador:** Asegúrate de que `docs/LICENSE.txt` esté actualizado y ejecuta:
   ```bash
   makensis installer.nsi
   ```
   El instalador se generará en la carpeta `installer/`.

## 📄 Documentación Adicional

- [Notas de Lanzamiento 1.0.0](docs/releases/1.0.0.md)
- [Manual de Usuario](docs/Manual%20de%20Usuario.md)
- [Requisitos Funcionales](docs/RequisitosFuncionales.md)

---
*Desarrollado para el análisis y visualización de datos de pesca.*
