# Manual de Usuario - Visualizador SIOP

El Visualizador SIOP es una herramienta diseñada para la visualización interactiva de datos de posicionamiento de buques, permitiendo el análisis de trayectorias, detección automática de mareas de pesca (etapas) y reproducción temporal de la navegación.

## 1. Carga de Datos

Para comenzar a utilizar la aplicación, es necesario cargar un archivo de datos.

### Formatos Soportados
La aplicación soporta los siguientes formatos:
- **Excel (.xlsx)**
- **Valores Separados por Comas (.csv)**

### Estructura de Datos Esperada
El archivo debe contener columnas que incluyan la siguiente información (el sistema intenta detectar automáticamente los nombres de las columnas):
- **Fecha y Hora**: `fechahora`, `fecha`, `date`, `time`, `timestamp`.
- **Posición**: `latitud`, `longitud`.
- **Velocidad** (Opcional): `velocidad` (en nudos).
- **Rumbo** (Opcional): `rumbo` (en grados).
- **Identificación** (Opcional): `buque`, `matricula`.

### Procedimiento
1. En la tarjeta de información (esquina superior izquierda), haga clic en el botón de "Carga" (ícono de carpeta/subida).
2. Seleccione el archivo `.xlsx` o `.csv` desde su explorador de archivos.
3. El sistema procesará los datos y mostrará una notificación con la cantidad de registros cargados.

---

## 2. Interfaz Principal

### A. Tarjeta de Información (Izquierda Superior)
Esta tarjeta muestra información estática del buque y dinámica del punto seleccionado en el tiempo actual.

*   **Cabecera**: Nombre del buque y matrícula (si están disponibles en el archivo). Botón de carga de nuevos archivos.
*   **Posición Actual**: Muestra los datos precisos del punto seleccionado en la línea de tiempo:
    *   Latitud y Longitud (formato GGº MM.MMM').
    *   Fecha y Hora local.
    *   Velocidad (nudos) y Rumbo (grados).
    *   *Nota*: Si no hay un punto seleccionado, mostrará "Seleccione un punto".
*   **Capas Visibles**: Interruptores para activar/desactivar elementos en el mapa:
    *   **Puntos totales**: Muestra todos los puntos de posición cargados.
    *   **Trayectoria total**: Muestra una línea continua conectando todos los puntos.
    *   **Áreas de Vieira / Centolla**: Muestra polígonos de zonas de veda o manejo específico (si están configurados).

### B. Lista de Etapas (Derecha Superior)
El sistema detecta automáticamente "Etapas" o viajes de pesca basándose en el comportamiento de la velocidad del buque.

*   **Resumen**: Indica la cantidad de etapas detectadas y el total de días navegados únicos.
*   **Lista de Etapas**: Cada bloque representa un viaje detectado.
    *   **Indicador de Actividad**: Un ícono de "Play" aparece si la etapa está activa en el tiempo actual seleccionado.
    *   **Duración**: Muestra la duración del viaje en días.
    *   **Navegación Rápida**: Haga clic en la fecha de "Zarpada" para saltar al inicio del viaje, o en "Arribo" para saltar al final.
    *   **Visibilidad por Etapa**:
        *   Ícono **Línea**: Muestra/oculta la trayectoria específica de ese viaje.
        *   Ícono **Puntos**: Muestra/oculta los puntos individuales de ese viaje.

### C. Línea de Tiempo y Reproducción (Inferior Central)
Permite navegar a través de la historia de posiciones del buque.

*   **Controles de Reproducción**:
    *   `|<<` (Inicio): Salta al primer registro.
    *   `<` (Anterior): Retrocede paso a paso.
    *   `Play/Pausa`: Inicia o detiene la animación automática de la trayectoria.
    *   `>` (Siguiente): Avanza paso a paso.
    *   `>>|` (Fin): Salta al último registro.
*   **Slider Principal**: Desplace el control para mover el buque a lo largo de su trayectoria.
*   **Selector de Fecha**: Ícono de calendario para saltar a una fecha específica.
*   **Rango de Fechas (Filtro Global)**: Un slider doble en la parte inferior permite filtrar todo el conjunto de datos entre una fecha mínima y máxima. Ajustar esto recalcula las etapas y lo que se muestra en el mapa.

### D. Mapa y Navegación
*   **Zoom**: Use la rueda del mouse o los botones `+` y `-` en la esquina inferior derecha.
*   **Escala**: Una barra de escala métrica/náutica se encuentra junto a los controles de zoom.
*   **Información en Pantalla**: Al pasar el cursor sobre cualquier punto, se despliega un "Tooltip" con información detallada.
*   **Seguimiento**: Al reproducir o mover el slider, el mapa se centra automáticamente en la posición del buque para mantenerlo visible.

---

## 3. Lógica del Sistema

### Detección de Etapas
El algoritmo identifica automáticamente cuándo el buque sale a navegar usando las siguientes reglas:
1.  **Detección de Salida**: Una secuencia de inactividad (velocidad 0) seguida de movimiento.
2.  **Detección de Arribo**: Movimiento seguido de una secuencia de inactividad.
3.  **Filtrado de Calidad**:
    *   Duración mínima: **5 horas**.
    *   Velocidad promedio: **>= 2 nudos** (para descartar movimientos en puerto o derivas lentas erróneas).

### Interactividad del Mapa
*   Los puntos detectados como parte de una etapa se colorean automáticamente para distinguir diferentes viajes.
*   El marcador del buque rota según el rumbo registrado (si el dato existe).
