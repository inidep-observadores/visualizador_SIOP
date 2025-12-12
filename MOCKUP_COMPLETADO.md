He completado la configuración inicial y el mockup visual de la aplicación.

**Resumen de cambios:**
1.  **Dependencias:** Todas las librerías requeridas (`flutter_map`, `riverpod`, `bitsdojo_window`, etc.) han sido añadidas al archivo `pubspec.yaml`.
2.  **Estructura de Proyecto:** He creado una estructura de carpetas inicial dentro de `lib/src` para seguir los principios de Clean Architecture, separando la presentación (`presentation`) del resto de capas que añadiremos más adelante.
3.  **Layout Principal:** He desarrollado el mockup visual en `lib/src/features/map_visualizer/presentation/map_screen.dart`. Este layout incluye los tres componentes principales descritos en los requisitos:
    *   Un panel lateral (Sidebar) con un botón para cargar archivos y espacio para mostrar metadatos.
    *   Un área principal donde se ubicará el mapa.
    *   Un panel inferior para la línea de tiempo (timeline) y controles de reproducción.
4.  **Ventana de Escritorio:** La aplicación está configurada en `lib/main.dart` para usar una barra de título personalizada gracias a `bitsdojo_window`, y se ha establecido un tamaño de ventana inicial.

**Próximos Pasos (requieren tu intervención):**

Para poder compilar y ver el resultado, necesitas realizar dos acciones manuales:

1.  **Instalar Dependencias:** Abre una terminal en la raíz del proyecto y ejecuta el siguiente comando:
    ```
    flutter pub get
    ```
2.  **Modificar el Runner de Windows:** Abre el archivo `windows/runner/main.cpp` y, justo antes de la línea `runLoop(window);`, añade el siguiente código como se indica en `AGENTS.md`:
    ```cpp
    #include <bitsdojo_window_windows/bitsdojo_window_plugin.h>
    auto bdw = bitsdojo_window_configure(BDW_CUSTOM_FRAME | BDW_HIDE_ON_STARTUP);
    ```
    He dejado un recordatorio de esto también como un comentario en la parte superior de `lib/main.dart`.

Una vez completados estos dos pasos, puedes lanzar la aplicación con `flutter run -d windows`. Verás el layout estático que he creado.

Estoy listo para continuar con el siguiente paso, que sería implementar la lógica para cargar y procesar el archivo Excel.