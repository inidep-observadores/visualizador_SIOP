# Manual de Usuario - Visualizador SIOP

El Visualizador SIOP es una herramienta diseñada para la visualización interactiva de datos de posicionamiento de buques, permitiendo el análisis de trayectorias, detección automática de viajes y reproducción temporal de la navegación.

---

## 1. Carga de Datos

Existen tres formas de cargar información en la aplicación:

### A. Botón de Carga
1. Haga clic en el ícono de la **carpeta** en la tarjeta superior izquierda.
2. Seleccione uno o varios archivos **Excel (.xlsx)** o **CSV** de su computadora.

### B. Arrastrar y Soltar (Novedad)
Puede simplemente **arrastrar sus archivos** directamente desde su explorador de archivos y soltarlos sobre cualquier parte del mapa. La aplicación reconocerá automáticamente los datos.

### C. Carga Múltiple y Masiva
Si selecciona o arrastra **muchos archivos a la vez**, o si carga un **único archivo que contiene registros de más de un buque**, el sistema activará el flujo de "Importación Masiva". 

*   **Detección inteligente**: El sistema analiza el contenido antes de procesarlo. Si detecta datos de distintos buques, le informará la cantidad de embarcaciones encontradas.
*   **Guardado directo**: En este modo, la información se guarda automáticamente en la base de datos para garantizar que cada registro quede asociado al buque correspondiente.

---

## 2. Interfaz Principal

### A. Tarjeta de Información (Izquierda Superior)
Muestra los datos del buque y del punto exacto donde se encuentra el marcador en el mapa.
*   **Lupa**: Permite buscar buques que ya han sido guardados previamente en la base de datos.
*   **Tacho de basura**: Limpia el mapa actual para empezar una nueva visualización.
*   **Datos en tiempo real**: Latitud, longitud, fecha, hora, velocidad (en nudos) y rumbo.
*   **Capas Visibles**: Interruptores para mostrar u ocultar los puntos totales, la trayectoria completa o áreas de pesca específicas (Viedma, Centolla).

### B. Lista de Etapas (Derecha Superior)
El sistema detecta automáticamente cuándo el barco salió y volvió a puerto.
*   **Visualización por Etapa**: Cada etapa tiene dos botones especiales:
    *   Icono de **Línea**: Muestra u oculta el recorrido dibujado de ese viaje.
    *   Icono de **Puntos**: Muestra u oculta los puntos individuales de posicionamiento.
*   **Navegación**: Al tocar en "Zarpada" o "Arribo", el mapa se moverá automáticamente al inicio o al final de ese viaje.

### C. Línea de Tiempo y Filtros (Inferior)
*   **Slider de Tiempo**: Mueva el círculo para ver la posición del barco en un momento exacto.
*   **Controles de Play**: Puede darle "Play" para que el barco se mueva solo y simule su navegación.
*   **Ir a una fecha**: Toque el icono de **calendario** a la derecha del slider para elegir un día y hora específicos a los que quiere saltar.
*   **Filtro de Rango (Calendario)**: Toque el botón que muestra las fechas (ej: *01/01/24 - 05/01/24*) para abrir un calendario. Aquí puede elegir un periodo exacto (ej: "solo quiero ver lo que pasó entre el lunes y el miércoles").

---

## 3. Guardado Permanente (Base de Datos)

Cada vez que cargue un archivo nuevo, la aplicación le preguntará: **"¿Desea guardar los datos en la base de datos?"**

*   **¿Para qué sirve?**: Si dice que SÍ, la información se guarda dentro de la aplicación.
*   **Buscador**: La próxima vez que abra el programa, no necesita buscar el archivo Excel. Simplemente toque la **lupa** en la tarjeta superior, busque el nombre del barco o su matrícula, y los datos se cargarán instantáneamente.

---

## 4. Consejos de Uso
*   **Zoom**: Use la rueda del ratón o los botones `+` y `-` para acercarse o alejarse.
*   **Información**: Si pone el cursor sobre un punto del recorrido, aparecerá un pequeño cuadro con los detalles de ese momento exacto.
*   **Centrado automático**: Al mover la línea de tiempo, el mapa siempre intentará mantener al barco a la vista.
