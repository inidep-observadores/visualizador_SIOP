import 'dart:async';
import 'dart:ui';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:siop_data_visualizer/src/features/map_visualizer/application/providers.dart';
import 'package:siop_data_visualizer/src/features/map_visualizer/presentation/widgets/floating_map_card.dart';
import 'package:intl/intl.dart';

class MapPoint {
  final LatLng position;
  final DateTime? timestamp;
  final String? shipName;
  final String? matricula;
  final double? speed;
  final double? course;

  MapPoint({
    required this.position,
    this.timestamp,
    this.shipName,
    this.matricula,
    this.speed,
    this.course,
  });
}

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen>
    with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  LatLngBounds? _lastFittedBounds;

  // Data state
  List<MapPoint> _allPoints = [];
  List<MapPoint> _filteredPoints = [];
  DateTime? _minDate;
  DateTime? _maxDate;
  RangeValues? _currentRangeValues;
  double? _currentSliderValue;

  // Marker Animation
  late AnimationController _markerAnimController;
  LatLng? _animatedMarkerPosition;
  LatLng? _markerTargetPosition;
  LatLng? _markerStartPos;
  LatLng? _markerEndPos;

  // Playback
  bool _isPlaying = false;
  Timer? _playbackTimer;

  @override
  void initState() {
    super.initState();
    _markerAnimController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _markerAnimController.addListener(() {
      if (_markerStartPos != null && _markerEndPos != null) {
        setState(() {
          final t = _markerAnimController.value;
          final lat = lerpDouble(
            _markerStartPos!.latitude,
            _markerEndPos!.latitude,
            t,
          )!;
          final lng = lerpDouble(
            _markerStartPos!.longitude,
            _markerEndPos!.longitude,
            t,
          )!;
          _animatedMarkerPosition = LatLng(lat, lng);
        });
      }
    });
  }

  @override
  void dispose() {
    _markerAnimController.dispose();
    _playbackTimer?.cancel();
    super.dispose();
  }

  void _togglePlay() {
    setState(() {
      _isPlaying = !_isPlaying;
    });
    if (_isPlaying) {
      _startPlayback();
    } else {
      _stopPlayback();
    }
  }

  void _startPlayback() {
    _playbackTimer?.cancel();
    _playbackTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      _stepForward(loop: true);
    });
  }

  void _stopPlayback() {
    _playbackTimer?.cancel();
    if (mounted) {
      setState(() {
        _isPlaying = false;
      });
    }
  }

  void _stepForward({bool loop = false}) {
    if (_currentSliderValue == null || _currentRangeValues == null) return;

    // Avanzar ~1 minuto o al siguiente punto
    // Mejor usar un paso fijo basado en la densidad de datos o tiempo?
    // Por ahora usemos un paso relativo al slider visual = 60000ms (1 min) si es gran escala, o algun delta.
    // O mejor: Next available point timestamp.

    double nextVal = _currentSliderValue! + 60000; // +1 min default
    // Find precise next point if available
    final nextPoint = _allPoints.firstWhere(
      (p) =>
          p.timestamp != null &&
          p.timestamp!.millisecondsSinceEpoch > _currentSliderValue!,
      orElse: () => MapPoint(position: const LatLng(0, 0)), // Dummy
    );

    if (nextPoint.timestamp != null) {
      // Si el siguiente punto está muy lejos (ej > 1 hora), saltamos a él?
      // Para visualización fluida mejor saltar al siguiente punto real.
      nextVal = nextPoint.timestamp!.millisecondsSinceEpoch.toDouble();
    }

    if (nextVal >= _currentRangeValues!.end) {
      nextVal = _currentRangeValues!.end;
      if (loop) _stopPlayback();
    }

    setState(() {
      _currentSliderValue = nextVal;
    });
    _updateSelectedPoint();
  }

  void _stepBackward() {
    if (_currentSliderValue == null || _currentRangeValues == null) return;

    // Previous available point
    final prevPoint = _allPoints.lastWhere(
      (p) =>
          p.timestamp != null &&
          p.timestamp!.millisecondsSinceEpoch < _currentSliderValue!,
      orElse: () => MapPoint(position: const LatLng(0, 0)),
    );

    double prevVal = _currentSliderValue! - 60000;
    if (prevPoint.timestamp != null) {
      prevVal = prevPoint.timestamp!.millisecondsSinceEpoch.toDouble();
    }

    if (prevVal <= _currentRangeValues!.start) {
      prevVal = _currentRangeValues!.start;
    }

    setState(() {
      _currentSliderValue = prevVal;
    });
    _updateSelectedPoint();
  }

  void _skipToStart() {
    if (_currentRangeValues == null) return;
    setState(() {
      _currentSliderValue = _currentRangeValues!.start;
    });
    _updateSelectedPoint();
  }

  void _skipToEnd() {
    if (_currentRangeValues == null) return;
    setState(() {
      _currentSliderValue = _currentRangeValues!.end;
    });
    _updateSelectedPoint();
  }

  void _updateSelectedPoint() {
    final selected = _selectedPoint;
    if (selected != null) {
      _updateMarkerTarget(selected.position, animate: true);
      _ensureVisible(selected.position);
    }
  }

  void _updateMarkerTarget(LatLng newTarget, {bool animate = true}) {
    if (_markerTargetPosition == newTarget) return;
    _markerTargetPosition = newTarget;

    if (!animate || _animatedMarkerPosition == null) {
      _animatedMarkerPosition = newTarget;
      _markerAnimController.stop();
      return;
    }

    _markerStartPos = _animatedMarkerPosition;
    _markerEndPos = newTarget;
    _markerAnimController.forward(from: 0.0);
  }

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

        // 4. Set initial marker position
        final initialPoint = _selectedPoint;
        if (initialPoint != null) {
          _updateMarkerTarget(initialPoint.position, animate: false);
        }
      });
    }

    final trackBounds = points.isNotEmpty
        ? LatLngBounds.fromPoints(points.map((e) => e.position).toList())
        : null;
    final mapCenter = points.isNotEmpty
        ? points[points.length ~/ 2].position
        : const LatLng(-38.0055, -57.5426); // Mar del Plata
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

  // Helper to find the "selected" point based on current slider value
  MapPoint? get _selectedPoint {
    if (_currentSliderValue == null || _allPoints.isEmpty) return null;

    // Find point closest to current timestamp
    MapPoint? closest;
    double minDiff = double.infinity;

    for (final p in _allPoints) {
      if (p.timestamp != null) {
        final diff =
            (p.timestamp!.millisecondsSinceEpoch - _currentSliderValue!).abs();
        if (diff < minDiff) {
          minDiff = diff;
          closest = p;
        }
      }
    }
    return closest;
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
                behavior: SnackBarBehavior.floating,
                width: 400,
              ),
            );
          }
        },
        error: (error, stackTrace) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al procesar el archivo: $error'),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
        loading: () {},
      );
    });

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
        : const LatLng(-38.0055, -57.5426);

    final positionMarkers = _filteredPoints
        .map(
          (point) => Marker(
            width: 8,
            height: 8,
            point: point.position,
            child: GestureDetector(
              onTap: () {
                if (point.timestamp != null) {
                  setState(() {
                    _currentSliderValue = point
                        .timestamp!
                        .millisecondsSinceEpoch
                        .toDouble();
                  });
                  _updateSelectedPoint();
                }
              },
              child: Tooltip(
                message: _getTooltipMessage(point),
                waitDuration: Duration.zero,
                padding: const EdgeInsets.all(8.0),
                showDuration: Duration.zero,
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(8),
                ),
                textStyle: const TextStyle(color: Colors.white, fontSize: 12),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.blueAccent.withOpacity(0.6),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1),
                  ),
                ),
              ),
            ),
          ),
        )
        .toList();

    final currentPoint = _selectedPoint;
    final shipName =
        currentPoint?.shipName ??
        (_allPoints.isNotEmpty ? _allPoints.first.shipName : 'N/A') ??
        'N/A';
    final matricula =
        currentPoint?.matricula ??
        (_allPoints.isNotEmpty ? _allPoints.first.matricula : 'N/A') ??
        'N/A';

    return Scaffold(
      body: Stack(
        children: [
          // 1. Layer del Mapa (Fondo completo)
          Positioned.fill(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: mapCenter,
                initialZoom: _filteredPoints.isNotEmpty ? 6.0 : 5.0,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.siop_data_visualizer',
                ),
                if (_filteredPoints.length > 1)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: _filteredPoints.map((p) => p.position).toList(),
                        color: Colors.teal.withOpacity(0.8),
                        strokeWidth: 3.0,
                      ),
                    ],
                  ),
                MarkerLayer(
                  markers: [
                    ...positionMarkers,
                    if (currentPoint != null)
                      Marker(
                        width: 40,
                        height: 40,
                        point: _animatedMarkerPosition ?? currentPoint.position,
                        child: Tooltip(
                          message: _getTooltipMessage(currentPoint),
                          waitDuration: Duration.zero,
                          padding: const EdgeInsets.all(8.0),
                          showDuration: Duration.zero,
                          decoration: BoxDecoration(
                            color: Colors.black87,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: AnimatedRotation(
                            turns: (currentPoint.course ?? 0) / 360,
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeInOut,
                            child: const Icon(
                              Icons.navigation,
                              color: Colors.indigoAccent,
                              size: 40,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),

          // 2. Tarjeta Flotante de Información (Top Left)
          Positioned(
            top: 24,
            left: 24,
            child: SizedBox(
              width: 190, // Reduced width

              child: FloatingMapCard(
                elevation: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header con carga de archivo
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Buque',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[700],
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                shipName == 'N/A'
                                    ? 'Sin datos'
                                    : shipName.toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                matricula == 'N/A'
                                    ? ''
                                    : 'Mat. ${trimMatricula(matricula)}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[800],
                                ),
                              ),
                            ],
                          ),
                        ),
                        FloatingActionButton.small(
                          onPressed: isLoading ? null : _pickFile,
                          elevation: 0,
                          backgroundColor: Colors.white.withOpacity(0.5),
                          foregroundColor: Colors.indigoAccent,
                          child: isLoading
                              ? const SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(
                                  Icons.upload_file_outlined,
                                  size: 18,
                                ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(height: 1),
                    const SizedBox(height: 12),

                    Text(
                      'POSICIÓN ACTUAL',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 8),

                    if (currentPoint != null &&
                        currentPoint.timestamp != null) ...[
                      // 1. Latitud
                      _buildDataBox(
                        'LATITUD',
                        _formatCoordinate(currentPoint.position.latitude, true),
                        Colors.blue.shade50.withOpacity(0.4),
                        Colors.blue.shade900,
                      ),
                      const SizedBox(height: 8),

                      // 2. Longitud
                      _buildDataBox(
                        'LONGITUD',
                        _formatCoordinate(
                          currentPoint.position.longitude,
                          false,
                        ),
                        Colors.blue.shade50.withOpacity(0.4),
                        Colors.blue.shade900,
                      ),
                      const SizedBox(height: 12),

                      // 3. Fecha
                      _buildInfoRow(
                        Icons.calendar_today_outlined,
                        'Fecha',
                        _formatDate(currentPoint.timestamp!),
                      ),
                      // 4. Hora
                      _buildInfoRow(
                        Icons.access_time_outlined,
                        'Hora local',
                        _formatTime(currentPoint.timestamp!),
                      ),

                      const SizedBox(height: 8),
                      const Divider(height: 1),
                      const SizedBox(height: 8),

                      // Speed/Course Compact at bottom
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Vel: ${currentPoint.speed?.toStringAsFixed(1) ?? "-"} kn',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[700],
                            ),
                          ),
                          Text(
                            'Rumbo: ${currentPoint.course?.toStringAsFixed(0) ?? "-"}º',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.grey[50]!.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: const Text(
                          'Seleccione un punto',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),

          // 3. Tarjeta Flotante de Timeline (Bottom Center)
          Positioned(
            left: 24,
            right: 24,
            bottom: 24,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: FloatingMapCard(
                  elevation: 3,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24.0,
                    vertical: 16.0,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Main Slider
                      // Main Slider
                      Row(
                        children: [
                          // Controls Group
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                onPressed: _skipToStart,
                                icon: const Icon(Icons.skip_previous), // Start
                                color: Colors.grey[700],
                                iconSize: 20,
                                tooltip: 'Inicio',
                              ),
                              IconButton(
                                onPressed: _stepBackward,
                                icon: const Icon(Icons.navigate_before), // Prev
                                color: Colors.grey[700],
                                iconSize: 24,
                                tooltip: 'Anterior',
                              ),
                              IconButton(
                                onPressed: _togglePlay,
                                icon: Icon(
                                  _isPlaying
                                      ? Icons.pause_circle_filled
                                      : Icons.play_circle_filled,
                                ),
                                color: Colors.indigoAccent,
                                iconSize: 36, // Larger
                                tooltip: _isPlaying ? 'Pausar' : 'Reproducir',
                              ),
                              IconButton(
                                onPressed: () => _stepForward(),
                                icon: const Icon(Icons.navigate_next), // Next
                                color: Colors.grey[700],
                                iconSize: 24,
                                tooltip: 'Siguiente',
                              ),
                              IconButton(
                                onPressed: _skipToEnd,
                                icon: const Icon(Icons.skip_next), // End
                                color: Colors.grey[700],
                                iconSize: 20,
                                tooltip: 'Fin',
                              ),
                            ],
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _currentRangeValues != null
                                ? SliderTheme(
                                    data: SliderTheme.of(context).copyWith(
                                      activeTrackColor: Colors.indigoAccent,
                                      thumbColor: Colors.indigo,
                                      overlayColor: Colors.indigo.withOpacity(
                                        0.2,
                                      ),
                                      trackHeight: 4,
                                      thumbShape: const RoundSliderThumbShape(
                                        enabledThumbRadius: 8,
                                      ),
                                    ),
                                    child: Slider(
                                      value:
                                          _currentSliderValue ??
                                          _currentRangeValues!.start,
                                      min: _currentRangeValues!.start,
                                      max: _currentRangeValues!.end,
                                      divisions:
                                          (_currentRangeValues!.end -
                                                  _currentRangeValues!.start) >
                                              0
                                          ? math.max(
                                              1,
                                              ((_currentRangeValues!.end -
                                                          _currentRangeValues!
                                                              .start) /
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
                                        final selected = _selectedPoint;
                                        if (selected != null) {
                                          _updateMarkerTarget(
                                            selected.position,
                                            animate: true,
                                          );
                                          _ensureVisible(selected.position);
                                        }
                                      },
                                    ),
                                  )
                                : const LinearProgressIndicator(value: 0),
                          ),
                        ],
                      ),

                      // Range Slider & Dates
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          // color: Colors.grey[50]!.withOpacity(0.5),
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _minDate != null
                                      ? _formatDateTime(_minDate!)
                                      : '--/--/-- --:--',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[700],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  _maxDate != null
                                      ? _formatDateTime(_maxDate!)
                                      : '--/--/-- --:--',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[700],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(
                              height: 30,
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
                                activeColor: Colors.grey[700],
                                inactiveColor: Colors.black12,
                                onChanged:
                                    (_minDate != null &&
                                        _maxDate != null &&
                                        _minDate != _maxDate)
                                    ? (RangeValues values) {
                                        setState(() {
                                          _currentRangeValues = values;
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
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 200,
            right: 24,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton.small(
                  heroTag: 'zoom_in',
                  onPressed: () {
                    final currentZoom = _mapController.camera.zoom;
                    _animatedMapMove(
                      _mapController.camera.center,
                      currentZoom + 1,
                    );
                  },
                  backgroundColor: Colors.white,
                  child: const Icon(Icons.add, color: Colors.indigoAccent),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: 'zoom_out',
                  onPressed: () {
                    final currentZoom = _mapController.camera.zoom;
                    _animatedMapMove(
                      _mapController.camera.center,
                      currentZoom - 1,
                    );
                  },
                  backgroundColor: Colors.white,
                  child: const Icon(Icons.remove, color: Colors.indigoAccent),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.indigoAccent),
          const SizedBox(width: 8),
          Text(
            '$label:',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(width: 8),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildDataBox(
    String label,
    String value,
    Color bgColor,
    Color accentColor,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accentColor.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: accentColor.withOpacity(0.8),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: accentColor,
            ),
          ),
        ],
      ),
    );
  }

  bool _didInfinitLoopCheck = false;

  void _animatedMapMove(LatLng destLocation, double destZoom) {
    // Create some tweens. These serve to split up the transition from one location to another.
    // In our case, we want to split the transition be<tween> our current map center and the destination.
    final latTween = Tween<double>(
      begin: _mapController.camera.center.latitude,
      end: destLocation.latitude,
    );
    final lngTween = Tween<double>(
      begin: _mapController.camera.center.longitude,
      end: destLocation.longitude,
    );
    final zoomTween = Tween<double>(
      begin: _mapController.camera.zoom,
      end: destZoom,
    );

    // Create a controller that will handle the rotation of the map
    final controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    // The animation determines what path the animation will take. You can try different Curves values, although I found
    // fastOutSlowIn to be completely adequate.
    final Animation<double> animation = CurvedAnimation(
      parent: controller,
      curve: Curves.fastOutSlowIn,
    );

    controller.addListener(() {
      _mapController.move(
        LatLng(latTween.evaluate(animation), lngTween.evaluate(animation)),
        zoomTween.evaluate(animation),
      );
    });

    animation.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        controller.dispose();
      } else if (status == AnimationStatus.dismissed) {
        controller.dispose();
      }
    });

    controller.forward();
  }

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
      _animatedMapMove(targetCenter, targetZoom);
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

  bool _boundsMatch(LatLngBounds? previous, LatLngBounds? current) {
    if (previous == null || current == null) return previous == current;
    return previous.southWest.latitude == current.southWest.latitude &&
        previous.southWest.longitude == current.southWest.longitude &&
        previous.northEast.latitude == current.northEast.latitude &&
        previous.northEast.longitude == current.northEast.longitude;
  }

  String _getTooltipMessage(MapPoint point) {
    return 'Fecha: ${point.timestamp != null ? _formatDate(point.timestamp!) : "N/A"}\n'
        'Hora: ${point.timestamp != null ? _formatTime(point.timestamp!) : "N/A"}\n'
        'Lat: ${_formatCoordinate(point.position.latitude, true)}\n'
        'Lon: ${_formatCoordinate(point.position.longitude, false)}\n'
        'Vel: ${point.speed?.toStringAsFixed(1) ?? "0.0"} kn\n'
        'Rumbo: ${point.course?.toStringAsFixed(0) ?? "0"}º';
  }

  void _ensureVisible(LatLng point) {
    if (!mounted) return;
    final bounds = _mapController.camera.visibleBounds;
    // Increase buffer to 25% to account for floating UI cards
    final latBuffer = (bounds.north - bounds.south).abs() * 0.25;
    final lngBuffer = (bounds.east - bounds.west).abs() * 0.25;

    final safeBounds = LatLngBounds(
      LatLng(bounds.south + latBuffer, bounds.west + lngBuffer),
      LatLng(bounds.north - latBuffer, bounds.east - lngBuffer),
    );

    if (!safeBounds.contains(point)) {
      _animatedMapMove(point, _mapController.camera.zoom);
    }
  }
}

List<MapPoint> _extractMapPoints(List<Map<String, dynamic>> rows) {
  final points = <MapPoint>[];
  for (final row in rows) {
    final latLng = _latLngFromRow(row);
    if (latLng != null) {
      final date = _dateFromRow(row);
      final shipName = _getStringFromRow(row, 'buque');
      final matricula = _getStringFromRow(row, 'matricula');
      final speed = _coordinateFromRow(row, 'velocidad');
      final course = _coordinateFromRow(row, 'rumbo');

      points.add(
        MapPoint(
          position: latLng,
          timestamp: date,
          shipName: shipName,
          matricula: matricula,
          speed: speed,
          course: course,
        ),
      );
    }
  }
  return points;
}

DateTime? _dateFromRow(Map<String, dynamic> row) {
  // Try to find a date column
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

String? _getStringFromRow(Map<String, dynamic> row, String columnName) {
  final normalizedTarget = columnName.trim().toLowerCase();
  final matchedKey = row.keys.firstWhere(
    (key) => key.trim().toLowerCase() == normalizedTarget,
    orElse: () => '',
  );

  if (matchedKey.isEmpty) {
    return null;
  }

  final val = row[matchedKey];
  if (val == null) return null;
  return val.toString().trim();
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

String trimMatricula(String mat) {
  if (mat.length > 20) {
    return '${mat.substring(0, 17)}...';
  }
  return mat;
}

String _formatCoordinate(double value, bool isLat) {
  final absVal = value.abs();
  final degrees = absVal.floor();
  final minutes = (absVal - degrees) * 60;

  final minutesStr = minutes.toStringAsFixed(3).replaceAll('.', ',');

  String cardinal = '';
  if (isLat) {
    cardinal = value >= 0 ? 'N' : 'S';
  } else {
    cardinal = value >= 0 ? 'E' : 'O';
  }

  return '$degrees° $minutesStr\' $cardinal';
}
