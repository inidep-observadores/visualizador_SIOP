import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart'; // Importar flutter_map
import 'package:latlong2/latlong.dart'; // Importar latlong2
import 'package:siop_data_visualizer/src/features/map_visualizer/application/providers.dart';
import 'package:siop_data_visualizer/src/features/map_visualizer/presentation/widgets/data_display_dialog.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final MapController _mapController = MapController();
  LatLngBounds? _lastFittedBounds;

  /// Opens the file picker and triggers the data loading process via the provider.
  Future<void> _pickFile() async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xls', 'xlsx'],
      );

      if (result != null && result.files.single.path != null) {
        final path = result.files.single.path!;
        ref.read(excelDataProvider.notifier).loadFromFile(path);
      }
    } catch (e) {
      // Show a generic error for file picking issues
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Error al seleccionar el archivo: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final excelDataState = ref.watch(excelDataProvider);

    // Listen to the provider state to show SnackBars for success or error.
    ref.listen<AsyncValue<List<Map<String, dynamic>>?>>(excelDataProvider, (_, next) {
      next.when(
        data: (data) {
          if (data != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('${data.length} filas cargadas con éxito.')),
            );
          }
        },
        error: (error, stackTrace) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al procesar el archivo: $error')),
          );
        },
        loading: () {
          // No action needed here, the UI below handles the loading indicator.
        },
      );
    });

    final excelData = excelDataState.asData?.value;
    final isLoading = excelDataState.isLoading;
    final trackPoints = excelData != null ? _extractTrackPoints(excelData) : <LatLng>[];
    final mapCenter = trackPoints.isNotEmpty ? trackPoints[trackPoints.length ~/ 2] : const LatLng(40.416775, -3.703790);
    final trackBounds = trackPoints.length > 1 ? LatLngBounds.fromPoints(trackPoints) : null;
    final fallbackZoom = trackPoints.isNotEmpty ? 6.0 : 5.0;
    _scheduleViewAdjustment(trackBounds, mapCenter, fallbackZoom);
    final positionMarkers = trackPoints
        .map(
          (point) => Marker(
            width: 8,
            height: 8,
            point: point,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.blueAccent,
                shape: BoxShape.circle,
              ),
            ),
          ),
        )
        .toList();

    return Column(
      children: [
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
                              onPressed: isLoading ? null : _pickFile,
                              icon: isLoading
                                  ? Container(
                                      width: 24,
                                      height: 24,
                                      padding: const EdgeInsets.all(2.0),
                                      child: const CircularProgressIndicator(strokeWidth: 3, color: Colors.white),
                                    )
                                  : const Icon(Icons.file_upload),
                              label: const Text('Cargar Excel'),
                            ),
                            const SizedBox(height: 8),
                            OutlinedButton.icon(
                              onPressed: excelData == null || excelData.isEmpty
                                  ? null
                                  : () {
                                      showDialog(
                                        context: context,
                                        builder: (_) => DataDisplayDialog(data: excelData),
                                      );
                                    },
                              icon: const Icon(Icons.table_rows),
                              label: const Text('Ver Datos'),
                            ),
                            const SizedBox(height: 20),
                            Text('Información del Buque', style: Theme.of(context).textTheme.titleMedium),
                            const Divider(),
                            const Text('Nombre: N/A'),
                            const Text('Matrícula: N/A'),
                            const SizedBox(height: 20),
                            Text('Estadísticas', style: Theme.of(context).textTheme.titleMedium),
                            const Divider(),
                            Text('Total de puntos: ${excelData?.length ?? 0}'),
                            const Text('Desde: N/A'),
                            const Text('Hasta: N/A'),
                          ],
                        ),
                      ),
                    ),
                    // Map Area
                    Expanded(
                      child: FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter: mapCenter,
                          initialZoom: trackPoints.isNotEmpty ? 6.0 : 5.0,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.example.siop_data_visualizer', // Reemplaza con tu package name
                          ),
                          if (trackPoints.length > 1)
                            PolylineLayer(
                              polylines: [
                                Polyline(
                                  points: trackPoints,
                                  color: Colors.blueAccent.withValues(alpha: 0.6),
                                  strokeWidth: 2.5,
                                ),
                              ],
                            ),
                          MarkerLayer(
                            markers: positionMarkers,
                          ),
                        ],
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

  void _scheduleViewAdjustment(LatLngBounds? bounds, LatLng fallbackCenter, double fallbackZoom) {
    if (_boundsMatch(_lastFittedBounds, bounds)) return;
    final targetCenter = bounds != null ? _centerForBounds(bounds) : fallbackCenter;
    final targetZoom = bounds != null ? _zoomForBounds(bounds) : fallbackZoom;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _mapController.move(targetCenter, targetZoom);
    });
    _lastFittedBounds = bounds;
  }

  static LatLng _centerForBounds(LatLngBounds bounds) {
    final latCenter = (bounds.southWest.latitude + bounds.northEast.latitude) / 2;
    final lngCenter = (bounds.southWest.longitude + bounds.northEast.longitude) / 2;
    return LatLng(latCenter, lngCenter);
  }

  static double _zoomForBounds(LatLngBounds bounds) {
    final latDiff = (bounds.northEast.latitude - bounds.southWest.latitude).abs();
    final lngDiff = (bounds.northEast.longitude - bounds.southWest.longitude).abs();
    final maxDiff = math.max(latDiff, lngDiff);
    if (maxDiff < 0.005) return 15.0;
    if (maxDiff < 0.02) return 13.5;
    if (maxDiff < 0.1) return 11.0;
    if (maxDiff < 0.5) return 9.0;
    if (maxDiff < 2.0) return 7.0;
    if (maxDiff < 5.0) return 5.5;
    return 4.5;
  }

  static bool _boundsMatch(LatLngBounds? previous, LatLngBounds? current) {
    if (previous == null || current == null) return previous == current;
    return previous.southWest.latitude == current.southWest.latitude &&
        previous.southWest.longitude == current.southWest.longitude &&
        previous.northEast.latitude == current.northEast.latitude &&
        previous.northEast.longitude == current.northEast.longitude;
  }
}

List<LatLng> _extractTrackPoints(List<Map<String, dynamic>> rows) {
  final points = <LatLng>[];
  for (final row in rows) {
    final latLng = _latLngFromRow(row);
    if (latLng != null) {
      points.add(latLng);
    }
  }
  return points;
}

LatLng? _latLngFromRow(Map<String, dynamic> row) {
  final latitude = _coordinateFromRow(row, 'latitud');
  final longitude = _coordinateFromRow(row, 'longitud');
  if (latitude == null || longitude == null) {
    return null;
  }
  return LatLng(latitude, longitude);
}

double? _coordinateFromRow(Map<String, dynamic> row, String columnName) {
  final normalizedTarget = columnName.trim().toLowerCase();
  final matchedKey = row.keys.firstWhere(
    (key) => key.trim().toLowerCase() == normalizedTarget,
    orElse: () => '',
  );

  if (matchedKey.isEmpty) {
    return null;
  }

  final rawValue = row[matchedKey];
  return _parseDouble(rawValue);
}

double? _parseDouble(Object? value) {
  if (value == null) {
    return null;
  }

  if (value is num) {
    return value.toDouble();
  }

  final text = value.toString().trim().replaceAll(',', '.');
  if (text.isEmpty) {
    return null;
  }

  return double.tryParse(text);
}
