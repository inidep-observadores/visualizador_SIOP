# **Especificación de Requisitos Funcionales (SRS)**

Proyecto: Vessel Track Visualizer (VTV)  
Plataforma: Windows Desktop (Flutter)  
Versión: 1.0.0

## **1\. Introducción y Objetivo**

El objetivo es desarrollar una herramienta de escritorio ligera y eficiente para la visualización forense de posicionamiento de buques pesqueros y de investigación. La aplicación debe permitir la ingesta de archivos Excel estandarizados, la proyección de la derrota (ruta) en un mapa georreferenciado y la reproducción temporal de la navegación mediante una línea de tiempo interactiva.

## **2\. Definiciones de Datos (Data Dictionary)**

La fuente de verdad es un archivo .xlsx. El sistema debe ser capaz de mapear y normalizar las siguientes columnas obligatorias.

| Columna Excel | Tipo de Dato Interno | Unidad | Descripción |
| :---- | :---- | :---- | :---- |
| **Buque** | String | \- | Nombre del identificador de la embarcación. |
| **Matricula** | String | \- | Identificador único administrativo. |
| **Fecha** | DateTime | \- | Marca temporal. Debe soportar formatos de texto (dd/MM/yyyy HH:mm) y Serial Date de Excel. |
| **Latitud** | double | Grados decimales | Coordenada Y. Rango válido: \-90 a 90\. |
| **Longitud** | double | Grados decimales | Coordenada X. Rango válido: \-180 a 180\. |
| **Velocidad** | double | Nudos (kn) | Velocidad sobre el fondo. |
| **Rumbo** | double | Grados (°) | Dirección de la proa (0-360°). |

## **3\. Requisitos Funcionales (FR)**

### **FR-01: Ingesta y Procesamiento de Datos**

* **REQ-01.1:** El usuario debe poder seleccionar un archivo local mediante un diálogo nativo de Windows (file\_picker).  
* **REQ-01.2:** El sistema debe validar que el archivo contenga las columnas obligatorias definidas en el diccionario de datos. En caso contrario, debe mostrar un error explícito indicando qué columnas faltan.  
* **REQ-01.3:** El sistema debe ordenar automáticamente los registros de forma cronológica ascendente (del más antiguo al más reciente) basándose en la columna Fecha, independientemente del orden original en el Excel.  
* **REQ-01.4:** El parsing debe ser robusto ante celdas vacías en campos no críticos. Si falta Latitud/Longitud/Fecha, el registro completo debe ser descartado y reportado en un log de advertencia, pero no debe detener la carga.
* **REQ-01.5 (Novedad):** El sistema debe soportar archivos que contienen datos de múltiples buques. Debe identificar cada buque de forma única (nombre + matrícula) y asegurar que los registros se guarden asociados al buque correcto en la base de datos.

### **FR-02: Visualización Geoespacial (Mapa)**

* **REQ-02.1:** Se utilizará un mapa base de OpenStreetMap.  
* **REQ-02.2 (Capa Estática):** Se debe dibujar una polilínea (PolylineLayer) que represente la "derrota" completa (todos los puntos válidos del archivo).  
  * *Estilo:* Color sólido (ej. Azul Marino o Gris Oscuro), ancho de trazo medio (3-4px).  
* **REQ-02.3 (Capa Dinámica):** Se debe renderizar un único marcador (MarkerLayer) que represente la posición del buque en el instante de tiempo seleccionado.  
  * *Iconografía:* Icono tipo "barco" o flecha direccional.  
  * *Rotación:* El icono debe rotar dinámicamente según el valor de la columna Rumbo del registro actual.  
* **REQ-02.4:** Al cargar un archivo exitosamente, la cámara del mapa debe ajustarse (fitBounds) automáticamente para encuadrar toda la ruta del buque con un padding razonable.

### **FR-03: Control Temporal (Timeline)**

* **REQ-03.1:** El sistema dispondrá de un panel inferior con un deslizador (Slider) horizontal.  
  * *Valor Min:* 0 (Primer registro).  
  * *Valor Max:* Total de registros \- 1\.  
* **REQ-03.2:** Al arrastrar el deslizador, el marcador del buque en el mapa debe actualizar su posición en tiempo real (sin *jank* ni retrasos perceptibles).  
* **REQ-03.3:** Junto al deslizador, se debe mostrar información contextual del punto seleccionado:  
  * Fecha y Hora exacta.  
  * Velocidad instantánea.  
  * Índice del reporte (ej. "Punto 45 de 2000").  
* **REQ-03.4 (Reproducción Automática):** Se debe incluir un botón "Play/Pause".  
  * Al dar Play, el deslizador y el barco deben avanzar automáticamente a una velocidad constante predefinida.  
  * Al llegar al final, la reproducción se detiene.

### **FR-04: Interfaz de Escritorio (Desktop Experience)**

* **REQ-04.1:** La ventana debe utilizar una barra de título personalizada (bitsdojo\_window) que se integre con el tema de la aplicación.  
* **REQ-04.2:** La aplicación debe iniciar con un tamaño predeterminado (ej. 1280x720) y permitir redimensionamiento, respetando un tamaño mínimo de 800x600 px para evitar roturas de layout.  
* **REQ-04.3:** Panel lateral (Sidebar) colapsable o fijo que muestre los metadatos estáticos del viaje: Nombre del Buque, Matrícula, Fecha Inicio, Fecha Fin, Velocidad Promedio y Distancia Total Recorrida (cálculo opcional).

### **FR-05: Persistencia de Datos (SQLite)**

* **REQ-05.1:** El sistema debe contar con una base de datos local SQLite para persistir los datos importados.
* **REQ-05.2 (Esquema):** Se deben implementar dos tablas principales:
    * `buques`: Almacena `uuid` (PK), `nombre` y `matricula` (UNIQUE).
    * `posiciones`: Almacena las posiciones vinculadas por `buque_id`, con `fecha` como clave única por buque (UNIQUE(`buque_id`, `fecha`)).
* **REQ-05.3 (Flujo de Persistencia):** Al cargar un archivo, se debe preguntar al usuario si desea guardar los datos en la base de datos además de visualizarlos.
* **REQ-05.4 (Eficiencia):** La inserción de datos debe ser optimizada (batch inserts) y evitar duplicados basándose en las restricciones de unicidad (Insert if not exists).
* **REQ-05.5 (Visualización desde DB):** El usuario debe poder optar por visualizar datos ya existentes en la base de datos.
* **REQ-05.6 (Búsqueda):** Se debe proveer un control de búsqueda con autocompletado para seleccionar buques presentes en la base de datos.
* **REQ-05.7 (Consistencia):** Al cargar datos desde la DB, la funcionalidad del mapa, línea de tiempo y paneles informativos debe ser idéntica a la carga de archivos.

## **4\. Requisitos No Funcionales (NFR)**

### **NFR-01: Rendimiento**

* La aplicación debe ser capaz de procesar y renderizar archivos con hasta **10,000 puntos** de posición sin degradación notable del rendimiento (60 FPS durante la animación del slider).  
* El tiempo de carga y parsing de un archivo de 5,000 registros no debe superar los 3 segundos en hardware promedio.

### **NFR-02: Usabilidad**

* Feedback visual inmediato: Mostrar indicador de carga (CircularProgressIndicator) durante el procesamiento del Excel.  
* Manejo de errores amigable: Mensajes claros ("El archivo está corrupto" vs "Error 500").

### **NFR-03: Arquitectura y Calidad de Código**

* Estricto cumplimiento de **Clean Architecture**.  
* Gestión de estado mediante **Riverpod**.  
* Separación total entre la lógica de parsing (Repository) y la capa de presentación (Widget/Notifier).

## **5\. Casos Borde y Manejo de Errores (Edge Cases)**

1. **Excel vacío:** Mostrar mensaje "El archivo no contiene datos".  
2. **Fechas inválidas:** Si una fecha no puede parsearse, el registro se omite. Si ningún registro tiene fecha válida, se aborta la carga.  
3. **Coordenadas (0,0):** A menudo indican error de GPS. Deben ser filtradas visualmente o advertidas, ya que distorsionan el fitBounds del mapa (el mapa se alejaría hasta mostrar el Golfo de Guinea).  
4. **Archivo en uso:** Si el Excel está abierto en Microsoft Excel, file\_picker o la librería excel podrían lanzar una excepción de I/O. Capturar y notificar: "Cierre el archivo antes de cargarlo".

Aprobado por: Área Técnica / Usuario Final  
Fecha: 12/12/2025