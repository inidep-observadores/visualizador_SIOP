import 'package:flutter/material.dart';
import 'package:siop_data_visualizer/src/features/map_visualizer/presentation/widgets/custom_title_bar.dart';

class MapScreen extends StatelessWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const CustomTitleBar(),
        Expanded(
          child: Column(
            children: [
              // Main content area
              Expanded(
                child: Row(
                  children: [
                    // Sidebar
                    Container(
                      width: 250,
                      color: Colors.grey[200],
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ElevatedButton.icon(
                              onPressed: () {
                                // TODO: Implement file picking
                              },
                              icon: const Icon(Icons.file_upload),
                              label: const Text('Cargar Excel'),
                            ),
                            const SizedBox(height: 20),
                            Text('Información del Buque', style: Theme.of(context).textTheme.titleMedium),
                            const Divider(),
                            const Text('Nombre: N/A'),
                            const Text('Matrícula: N/A'),
                            const SizedBox(height: 20),
                            Text('Estadísticas', style: Theme.of(context).textTheme.titleMedium),
                            const Divider(),
                            const Text('Total de puntos: 0'),
                            const Text('Desde: N/A'),
                            const Text('Hasta: N/A'),
                          ],
                        ),
                      ),
                    ),
                    // Map Area
                    Expanded(
                      child: Container(
                        color: Colors.blueGrey[100],
                        child: const Center(
                          child: Text('Mapa (flutter_map)'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Bottom Timeline Panel
              Container(
                height: 100,
                color: Colors.grey[300],
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            const Text('00:00'),
                            const Expanded(
                              child: Slider(
                                value: 0,
                                onChanged: null, // Disabled
                                min: 0,
                                max: 100,
                              ),
                            ),
                            const Text('23:59'),
                          ],
                        ),
                      ),
                      const Text('Fecha: N/A - Velocidad: 0.0 kn'),
                    ],
                  ),
                ),
              )
            ],
          ),
        ),
      ],
    );
  }
}
