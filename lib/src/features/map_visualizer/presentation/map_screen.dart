import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart'; // Importar flutter_map
import 'package:latlong2/latlong.dart'; // Importar latlong2
import 'package:siop_data_visualizer/src/features/map_visualizer/application/providers.dart';
import 'package:intl/intl.dart';

class MapPoint {
  final LatLng position;
  final DateTime? timestamp;

  MapPoint({required this.position, this.timestamp});
}

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final MapController _mapController = MapController();
  LatLngBounds? _lastFittedBounds;

  // Data state
  List<MapPoint> _allPoints = [];
  List<MapPoint> _filteredPoints = [];
  DateTime? _minDate;
  DateTime? _maxDate;
  RangeValues?
  _currentRangeValues; // Stores timestamps as milliseconds since epoch (double)
  double? _currentSliderValue;

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

  void _processData(List<Map<String, dynamic>>? data) {
    if (data == null) {
      if (mounted) {
        setState(() {
          _allPoints = [];
          _filteredPoints = [];
          _minDate = null;
          _maxDate = null;
          _currentRangeValues = null;
          _currentSliderValue = null;
        });
      }
      return;
    }

    final points = _extractMapPoints(data);

    DateTime? min;
    DateTime? max;

    if (points.isNotEmpty) {
      final pointsWithTime = points.where((p) => p.timestamp != null).toList();
      if (pointsWithTime.isNotEmpty) {
        min = pointsWithTime
            .map((p) => p.timestamp!)
            .reduce((a, b) => a.isBefore(b) ? a : b);
        max = pointsWithTime
            .map((p) => p.timestamp!)
            .reduce((a, b) => a.isAfter(b) ? a : b);
      }
    }

    if (mounted) {
      setState(() {
        _allPoints = points;
        _minDate = min;
        _maxDate = max;

        // Initialize range to full span
        if (min != null && max != null && min != max) {
          _currentRangeValues = RangeValues(
            min.millisecondsSinceEpoch.toDouble(),
            max.millisecondsSinceEpoch.toDouble(),
          );
          _currentSliderValue = _currentRangeValues!.start;
        } else {
          _currentRangeValues = null;
          _currentSliderValue = null;
        }

        _filterPoints();
      });
    }

    final trackBounds = points.isNotEmpty
        ? LatLngBounds.fromPoints(points.map((e) => e.position).toList())
        : null;
    final mapCenter = points.isNotEmpty
        ? points[points.length ~/ 2].position
        : const LatLng(40.416775, -3.703790);
    final fallbackZoom = points.isNotEmpty ? 6.0 : 5.0;

    _scheduleViewAdjustment(trackBounds, mapCenter, fallbackZoom);
  }

  void _filterPoints() {
    if (_currentRangeValues == null || _minDate == null || _maxDate == null) {
      _filteredPoints = List.from(_allPoints);
      return;
    }

    final startMs = _currentRangeValues!.start;
    final endMs = _currentRangeValues!.end;

    _filteredPoints = _allPoints.where((p) {
      if (p.timestamp == null) return false;
      final pMs = p.timestamp!.millisecondsSinceEpoch.toDouble();
      return pMs >= startMs && pMs <= endMs;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final excelDataState = ref.watch(excelDataProvider);

    ref.listen<AsyncValue<List<Map<String, dynamic>>?>>(excelDataProvider, (
      _,
      next,
    ) {
      next.when(
        data: (data) {
          if (data != null) {
            _processData(data);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${data.length} filas cargadas con éxito.'),
              ),
            );
          }
        },
        error: (error, stackTrace) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al procesar el archivo: $error')),
          );
        },
        loading: () {
          // No action needed here
        },
      );
    });

    // Check consistency on hot reload
    if (_allPoints.isEmpty &&
        excelDataState.value != null &&
        !_didInfinitLoopCheck) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _processData(excelDataState.value);
      });
      _didInfinitLoopCheck = true;
    }

    final isLoading = excelDataState.isLoading;
    final mapCenter = _filteredPoints.isNotEmpty
        ? _filteredPoints[_filteredPoints.length ~/ 2].position
        : const LatLng(40.416775, -3.703790);

    final positionMarkers = _filteredPoints
        .map(
          (point) => Marker(
            width: 8,
            height: 8,
            point: point.position,
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
                                      child: const CircularProgressIndicator(
                                        strokeWidth: 3,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.file_upload),
                              label: const Text('Cargar Excel'),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'Información del Buque',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const Divider(),
                            const Text('Nombre: N/A'),
                            const Text('Matrícula: N/A'),
                            const SizedBox(height: 20),
                            Text(
                              'Estadísticas',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const Divider(),
                            Text('Total de puntos: ${_allPoints.length}'),
                            Text('Visibles: ${_filteredPoints.length}'),
                            const SizedBox(height: 10),
                            if (_minDate != null)
                              Text('Inicio: ${_formatDateTime(_minDate!)}'),
                            if (_maxDate != null)
                              Text('Fin: ${_formatDateTime(_maxDate!)}'),
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
                          initialZoom: _filteredPoints.isNotEmpty ? 6.0 : 5.0,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName:
                                'com.example.siop_data_visualizer', // Reemplaza con tu package name
                          ),
                          if (_filteredPoints.length > 1)
                            PolylineLayer(
                              polylines: [
                                Polyline(
                                  points: _filteredPoints
                                      .map((p) => p.position)
                                      .toList(),
                                  color: Colors.green.withOpacity(0.7),
                                  strokeWidth: 2.5,
                                ),
                              ],
                            ),
                          MarkerLayer(markers: positionMarkers),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Bottom Timeline Panel
              Container(
                height: 150, // Increased height for two sliders
                color: Colors.grey[300],
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ),
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      rangeValueIndicatorShape:
                          const PaddleRangeSliderValueIndicatorShape(),
                      showValueIndicator: ShowValueIndicator.always,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Sub-range Slider with Tooltip
                        if (_currentRangeValues != null)
                          Slider(
                            value:
                                _currentSliderValue ??
                                _currentRangeValues!.start,
                            min: _currentRangeValues!.start,
                            max: _currentRangeValues!.end,
                            divisions:
                                (_currentRangeValues != null &&
                                    (_currentRangeValues!.end -
                                            _currentRangeValues!.start) >
                                        0)
                                ? math.max(
                                    1,
                                    ((_currentRangeValues!.end -
                                                _currentRangeValues!.start) /
                                            60000)
                                        .round(),
                                  )
                                : null,
                            label: _currentSliderValue != null
                                ? _formatDateTime(
                                    DateTime.fromMillisecondsSinceEpoch(
                                      _currentSliderValue!.toInt(),
                                    ),
                                  )
                                : null,
                            onChanged: (value) {
                              setState(() {
                                _currentSliderValue = value;
                              });
                            },
                          ),

                        // Min/Max and RangeSlider
                        Row(
                          children: [
                            // Min Limit Date
                            Text(
                              _minDate != null
                                  ? _formatDateTime(_minDate!)
                                  : '--:--',
                              style: const TextStyle(fontSize: 12),
                            ),
                            const SizedBox(width: 8),
                            // Range Slider
                            Expanded(
                              child: RangeSlider(
                                values:
                                    _currentRangeValues ??
                                    const RangeValues(0, 1),
                                min:
                                    _minDate?.millisecondsSinceEpoch
                                        .toDouble() ??
                                    0,
                                max:
                                    _maxDate?.millisecondsSinceEpoch
                                        .toDouble() ??
                                    1,
                                divisions: _minDate != null && _maxDate != null
                                    ? (_maxDate!
                                                  .difference(_minDate!)
                                                  .inMinutes >
                                              0
                                          ? _maxDate!
                                                .difference(_minDate!)
                                                .inMinutes
                                          : null)
                                    : null,
                                labels: _currentRangeValues != null
                                    ? RangeLabels(
                                        _formatDateTime(
                                          DateTime.fromMillisecondsSinceEpoch(
                                            _currentRangeValues!.start.toInt(),
                                          ),
                                        ),
                                        _formatDateTime(
                                          DateTime.fromMillisecondsSinceEpoch(
                                            _currentRangeValues!.end.toInt(),
                                          ),
                                        ),
                                      )
                                    : null,
                                onChanged:
                                    (_minDate != null &&
                                        _maxDate != null &&
                                        _minDate != _maxDate)
                                    ? (RangeValues values) {
                                        setState(() {
                                          _currentRangeValues = values;
                                          // Update single slider if out of bounds
                                          if (_currentSliderValue != null) {
                                            if (_currentSliderValue! <
                                                values.start) {
                                              _currentSliderValue =
                                                  values.start;
                                            } else if (_currentSliderValue! >
                                                values.end) {
                                              _currentSliderValue = values.end;
                                            }
                                          }
                                          _filterPoints();
                                        });
                                      }
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Max Limit Date
                            Text(
                              _maxDate != null
                                  ? _formatDateTime(_maxDate!)
                                  : '--:--',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                        // Selected Range Info
                        const SizedBox(height: 4),
                        Text(
                          _currentRangeValues != null
                              ? 'Rango: ${_formatDateTime(DateTime.fromMillisecondsSinceEpoch(_currentRangeValues!.start.toInt()))} - ${_formatDateTime(DateTime.fromMillisecondsSinceEpoch(_currentRangeValues!.end.toInt()))}'
                              : 'Cargue un archivo para filtrar por fecha',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  bool _didInfinitLoopCheck = false;

  void _scheduleViewAdjustment(
    LatLngBounds? bounds,
    LatLng fallbackCenter,
    double fallbackZoom,
  ) {
    if (_boundsMatch(_lastFittedBounds, bounds)) return;
    final targetCenter = bounds != null
        ? _centerForBounds(bounds)
        : fallbackCenter;
    final targetZoom = bounds != null ? _zoomForBounds(bounds) : fallbackZoom;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _mapController.move(targetCenter, targetZoom);
    });
    _lastFittedBounds = bounds;
  }

  static LatLng _centerForBounds(LatLngBounds bounds) {
    final latCenter =
        (bounds.southWest.latitude + bounds.northEast.latitude) / 2;
    final lngCenter =
        (bounds.southWest.longitude + bounds.northEast.longitude) / 2;
    return LatLng(latCenter, lngCenter);
  }

  static double _zoomForBounds(LatLngBounds bounds) {
    final latDiff = (bounds.northEast.latitude - bounds.southWest.latitude)
        .abs();
    final lngDiff = (bounds.northEast.longitude - bounds.southWest.longitude)
        .abs();
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

List<MapPoint> _extractMapPoints(List<Map<String, dynamic>> rows) {
  final points = <MapPoint>[];
  for (final row in rows) {
    final latLng = _latLngFromRow(row);
    if (latLng != null) {
      final date = _dateFromRow(row);
      points.add(MapPoint(position: latLng, timestamp: date));
    }
  }
  return points;
}

DateTime? _dateFromRow(Map<String, dynamic> row) {
  // Try to find a date column
  final keys = row.keys.map((k) => k.toLowerCase()).toList();
  String? keyData;
  for (final k in ['fechahora', 'fecha', 'date', 'time', 'timestamp']) {
    final matchedKey = row.keys.firstWhere(
      (key) => key.trim().toLowerCase() == k,
      orElse: () => '',
    );
    if (matchedKey.isNotEmpty) {
      keyData = matchedKey;
      break;
    }
  }

  if (keyData == null) return null;

  final val = row[keyData];
  if (val == null) return null;

  if (val is DateTime) return val;

  final str = val.toString().trim();
  try {
    String isoStr = str.replaceAll(' ', 'T');
    if (!isoStr.endsWith('Z') &&
        !isoStr.contains('+') &&
        !isoStr.contains('-')) {
      isoStr = '${isoStr}Z';
    }

    final utcDate = DateTime.parse(isoStr);
    return utcDate.toLocal();
  } catch (e) {
    return null;
  }
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

String _formatDateTime(DateTime date) {
  return DateFormat('dd/MM/yyyy HH:mm').format(date);
}

String _formatDate(DateTime date) {
  return DateFormat('dd/MM/yyyy').format(date);
}

String _formatTime(DateTime date) {
  return DateFormat('HH:mm').format(date);
}
