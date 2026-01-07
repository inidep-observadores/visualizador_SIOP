# **AGENTS.md \- Vessel Track Visualizer (Flutter Windows)**

## **1\. Contexto del Proyecto**

Desarrollar una aplicación de escritorio en **Flutter** para Windows que permita visualizar datos de posicionamiento de buques (VMS) a partir de archivos Excel.

**Objetivo Principal:** Cargar un Excel, plotear la derrota (ruta) completa en un mapa y utilizar un deslizador temporal (timeline) para animar/mover la posición del buque a lo largo de la ruta según la fecha y hora.

## **2\. Tech Stack & Librerías**

* **Core:** Flutter (Channel Stable).  
* **State Management:** flutter\_riverpod \+ riverpod\_annotation (Code Generation es mandatorio).  
* **Maps:** flutter\_map (OpenStreetMap) \+ latlong2.  
* **Data Parsing:** excel (para leer .xlsx).  
* **File System:** file\_picker (para selección de archivos).  
* **Desktop UI:** bitsdojo\_window (custom title bar) \+ window\_manager (gestión de tamaño/posición).  
* **Utils:** intl (para formateo de fechas).

## **3\. Arquitectura & Principios**

Aplicar **Clean Architecture** simplificada (Pragmatic Clean) y principios **SOLID**.

* **Domain:** Modelos de datos puros.  
* **Data:** Repositorios encargados del parsing del Excel.  
* **Presentation:** Widgets y Riverpod Providers.

**Reglas de Oro:**

1. **DRY (Don't Repeat Yourself):** Extraer widgets comunes y lógica reutilizable.  
2. **Inmutabilidad:** Todos los estados y modelos deben ser inmutables (@immutable).  
3. **Separation of Concerns:** La lógica de parsing NO debe estar en la UI. El manejo del mapa NO debe estar acoplado a la lectura del archivo.

## **4\. Definición de Modelos (Domain Layer)**

Crear un modelo ShipPosition que mapee las columnas del Excel provisto.

* **Propiedades:**  
  * vesselName (String) \- Columna "Buque"  
  * registration (String) \- Columna "Matricula"  
  * timestamp (DateTime) \- Columna "Fecha" (Parsear formato dd/MM/yyyy HH:mm)  
  * latitude (double) \- Columna "Latitud"  
  * longitude (double) \- Columna "Longitud"  
  * speed (double) \- Columna "Velocidad"  
  * heading (double) \- Columna "Rumbo"

## **5\. Gestión de Estado (Riverpod)**

Utilizar @riverpod annotations para generar los providers.

1. **filePickerProvider**: FutureProvider/Notifier que maneja la apertura del archivo y retorna el File o bytes.  
2. **shipTrackRepositoryProvider**: Provider que expone la clase encargada de leer el Excel.  
3. **trackDataProvider**: FutureProvider que depende del file picker, llama al repositorio, parsea el Excel y devuelve una List\<ShipPosition\> ordenada por fecha.  
4. **playbackControllerProvider**: Un Notifier que maneja el estado de la reproducción/visualización.  
   * *State:* Un objeto que contenga currentIndex (int), isPlaying (bool), playbackSpeed (double).  
   * *Methods:* seekTo(int index), nextFrame(), togglePlay().

## **6\. Interfaz de Usuario (UI)**

Diseño Desktop-First.

### **A. Window Configuration (main.dart)**

* Configurar bitsdojo\_window en el runApp.  
* Definir un tamaño mínimo de ventana (ej. 1024x768).  
* Implementar una **Custom Title Bar** usando WindowTitleBarBox de bitsdojo.

### **B. Layout Principal**

* **Sidebar/Header:** Botón "Cargar Excel", información del buque (Nombre, Matrícula), estadísticas (Total de puntos, Rango de fechas).  
* **Main Area:**  
  * FlutterMap:  
    * **Layer 1 (Polyline):** Dibuja toda la ruta en gris o azul claro (estática).  
    * **Layer 2 (Marker):** Muestra el icono del barco en la posición actual (list\[currentIndex\]). Rotar el icono según el heading.  
* **Bottom Panel (Timeline):**  
  * Slider que va de 0 a totalPoints \- 1\.  
  * Labels mostrando la fecha/hora seleccionada y la velocidad en ese punto.  
  * Controles de reproducción (Play/Pause) opcionales.

## **7\. Instrucciones Paso a Paso para el Agente**

1. **Setup Inicial:**  
   * Agregar dependencias al pubspec.yaml.  
   * Configurar analysis\_options.yaml para ser estricto con los tipos.  
2. **Capa de Datos:**  
   * Crear ShipPosition model.  
   * Implementar ExcelParserService. **OJO:** El formato de fecha en Excel puede venir como String ("14/07/2025 12:39") o como Serial Number. Implementar lógica robusta para detectar ambos.  
3. **Capa de Estado:**  
   * Generar los providers con build\_runner.  
4. **UI \- Mapa:**  
   * Implementar el mapa base. Asegurarse de usar un MapController si es necesario centrar la vista al cargar una ruta nueva.  
5. **UI \- Integración:**  
   * Conectar el Slider con el playbackControllerProvider.  
   * Asegurar que el movimiento del slider actualice el marcador en tiempo real sin redibujar todo el mapa (optimización).  
6. **Windows Specifics:**  
   * Recordar modificar windows/runner/main.cpp para bitsdojo\_window si es necesario (el agente debe proveer el código C++ a insertar).

## **8\. Consideraciones Finales**

* Manejo de errores: Si el Excel tiene formato incorrecto, mostrar un Snackbar o Dialog amigable.  
* Performance: Si la lista supera los 10,000 puntos, considerar simplificar la Polyline, pero mantener la precisión del Marker.

\#\#\# Un consejo extra para la configuración de Windows  
Como le pedimos usar \`bitsdojo\_window\`, vas a tener que tocar un archivo de C++ que a veces Gemini no puede editar directamente por permisos o limitaciones del entorno de chat.

Cuando llegues a esa parte, acordate de abrir \`windows/runner/main.cpp\` y agregar esto antes de \`runLoop\`:

\`\`\`cpp  
// windows/runner/main.cpp  
\#include \<bitsdojo\_window\_windows/bitsdojo\_window\_plugin.h\> // \<--- Agregar header  
auto bdw \= bitsdojo\_window\_configure(BDW\_CUSTOM\_FRAME | BDW\_HIDE\_ON\_STARTUP); // \<--- Agregar configuración  
