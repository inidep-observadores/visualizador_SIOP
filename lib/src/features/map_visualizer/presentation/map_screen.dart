import 'dart:async';
import 'dart:ui';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:visualizador_siop/src/features/map_visualizer/application/providers.dart';
import 'package:visualizador_siop/src/features/map_visualizer/domain/vessel.dart';
import 'package:visualizador_siop/src/features/map_visualizer/application/geojson_service.dart';
import 'package:visualizador_siop/src/features/map_visualizer/data/services/excel_parser.dart';
import 'package:visualizador_siop/src/features/map_visualizer/presentation/widgets/custom_grid_layer.dart';
import 'package:visualizador_siop/src/features/map_visualizer/presentation/widgets/floating_map_card.dart';
import 'package:intl/intl.dart';
import 'package:visualizador_siop/src/features/map_visualizer/presentation/widgets/scale_bar.dart';
import 'package:visualizador_siop/src/features/map_visualizer/presentation/widgets/loading_dialog.dart';
import 'package:visualizador_siop/src/features/map_visualizer/presentation/widgets/custom_date_time_picker.dart';
import 'package:visualizador_siop/src/features/map_visualizer/presentation/widgets/custom_date_range_picker.dart';

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

class _Trip {
  final MapPoint startPoint;
  final MapPoint endPoint;
  final List<LatLng> pathPoints;
  final List<MapPoint> tripPoints;

  Color color;
  bool isVisible = true;
  bool arePointsVisible = false;

  _Trip({
    required this.startPoint,
    required this.endPoint,
    required this.pathPoints,
    required this.tripPoints,
    this.color = Colors.blue,
  });

  DateTime get startTime => startPoint.timestamp!;
  DateTime get endTime => endPoint.timestamp!;

  // Inclusive day calculation: 1st to 2nd is 2 days.
  int get durationInDays {
    final start = DateTime(startTime.year, startTime.month, startTime.day);
    final end = DateTime(endTime.year, endTime.month, endTime.day);
    return end.difference(start).inDays + 1;
  }

  @override
  String toString() {
    return 'Trip: ${DateFormat('dd/MM HH:mm').format(startTime)} -> ${DateFormat('dd/MM HH:mm').format(endTime)} ($durationInDays días)';
  }
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

  // Cursor Position
  LatLng? _cursorPosition;

  // Layer Visibility State
  bool _showPoints = false;
  bool _showTrack = false;
  bool _showCentolla = false;
  bool _showVieira = false;

  // Trips
  List<_Trip> _detectedTrips = [];

  final List<Color> _tripColors = [
    Colors.orange,
    Colors.purple,
    Colors.teal,
    Colors.pink,
    Colors.cyan,
    Colors.amber,
    Colors.indigo,
    Colors.lime,
  ];

  bool _isLoadingFromDb = false;
  bool _didInfinitLoopCheck = false;

  // Drag & Drop
  bool _isDragging = false;

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

    int currentIndex = -1;
    if (_filteredPoints.isNotEmpty) {
      currentIndex = _filteredPoints.indexWhere(
        (p) =>
            p.timestamp != null &&
            p.timestamp!.millisecondsSinceEpoch == _currentSliderValue,
      );
    }

    // Fallback if not exact match (shouldn't happen with snap)
    if (currentIndex == -1 && _filteredPoints.isNotEmpty) {
      // logic to find closest? For now standard
      currentIndex = 0;
    }

    int nextIndex = currentIndex + 1;
    if (nextIndex >= _filteredPoints.length) {
      nextIndex = _filteredPoints.length - 1;
      if (loop) _stopPlayback();
    }

    final double nextVal = _filteredPoints[nextIndex]
        .timestamp!
        .millisecondsSinceEpoch
        .toDouble();

    setState(() {
      _currentSliderValue = nextVal;
    });
    _updateSelectedPoint();
  }

  void _stepBackward() {
    if (_currentSliderValue == null || _currentRangeValues == null) return;

    int currentIndex = -1;
    if (_filteredPoints.isNotEmpty) {
      currentIndex = _filteredPoints.indexWhere(
        (p) =>
            p.timestamp != null &&
            p.timestamp!.millisecondsSinceEpoch == _currentSliderValue,
      );
    }

    int prevIndex = currentIndex - 1;
    if (prevIndex < 0) {
      prevIndex = 0;
    }

    final double prevVal = _filteredPoints[prevIndex]
        .timestamp!
        .millisecondsSinceEpoch
        .toDouble();

    setState(() {
      _currentSliderValue = prevVal;
    });
    _updateSelectedPoint();
  }

  void _skipToStart() {
    if (_currentRangeValues == null) return;
    setState(() {
      _currentSliderValue = _filteredPoints
          .first
          .timestamp!
          .millisecondsSinceEpoch
          .toDouble();
    });
    _updateSelectedPoint();
  }

  void _skipToEnd() {
    if (_currentRangeValues == null) return;
    setState(() {
      _currentSliderValue = _filteredPoints
          .last
          .timestamp!
          .millisecondsSinceEpoch
          .toDouble();
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

  Future<bool?> _showBatchConfirmDialog(
    int count, {
    bool isMultiVesselFile = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.cloud_upload_outlined, color: Colors.indigoAccent),
            const SizedBox(width: 12),
            Text(isMultiVesselFile ? 'Importación Masiva' : 'Confirmar Carga'),
          ],
        ),
        content: Text(
          isMultiVesselFile
              ? 'Este archivo contiene datos de $count buques distintos.\n\n'
                    'Se procesará como una carga masiva y los datos se guardarán directamente en la base de datos.'
              : 'Se han seleccionado $count archivos.\n\n'
                    'Los datos se guardarán en la base de datos local para acceso futuro y '
                    'no se mostrarán en el mapa de inmediato.\n\n'
                    '¿Desea iniciar la carga masiva?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCELAR'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigoAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('INICIAR CARGA'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'csv'],
        allowMultiple: true,
      );

      if (result == null || result.files.isEmpty) return;
      _handleFiles(result.files.map((f) => f.path!).toList());
    } catch (e) {
      _showErrorSnackBar('Error al seleccionar archivos: $e');
    }
  }

  Future<void> _handleFiles(List<String> paths) async {
    if (paths.isEmpty) return;

    if (paths.length == 1) {
      // Single file flow: Load and visualize
      final path = paths.first;
      final extension = path.toLowerCase().split('.').last;

      if (extension == 'xls') {
        _showErrorSnackBar(
          'El formato .xls no está soportado. Use .xlsx o .csv',
        );
        return;
      }

      try {
        // Pre-parse to check if there are multiple vessels
        final data = await DataFileParser.parseFile(path);
        final vessels = DataFileParser.getUniqueVessels(data);

        if (vessels.length > 1) {
          // Detect multiple vessels in a single file -> Batch flow
          if (!mounted) return;
          final confirmed = await _showBatchConfirmDialog(
            vessels.length,
            isMultiVesselFile: true,
          );
          if (confirmed != true || !mounted) return;

          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => _BatchImportDialog(filePaths: [path]),
          );
        } else {
          // Standard single vessel flow
          ref.read(excelDataProvider.notifier).loadFromFile(path);
        }
      } catch (e) {
        _showErrorSnackBar('Error al procesar el archivo: $e');
      }
    } else {
      // Multiple files flow: Batch process with custom loader
      if (!mounted) return;

      // Ask for confirmation before batch processing
      final confirmed = await _showBatchConfirmDialog(paths.length);
      if (confirmed != true || !mounted) return;

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => _BatchImportDialog(filePaths: paths),
      );
    }
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _processData(List<Map<String, dynamic>>? data) {
    if (data == null) {
      if (mounted) {
        _stopPlayback();
        setState(() {
          _allPoints = [];
          _filteredPoints = [];
          _minDate = null;
          _maxDate = null;
          _currentRangeValues = null;
          _currentSliderValue = null;
          _detectedTrips = [];
          _animatedMarkerPosition = null;
          _markerTargetPosition = null;
          _markerStartPos = null;
          _markerEndPos = null;
        });
      }
      return;
    }

    final points = _extractMapPoints(data);
    // Sort by timestamp
    points.sort((a, b) {
      if (a.timestamp == null && b.timestamp == null) return 0;
      if (a.timestamp == null) return 1;
      if (b.timestamp == null) return -1;
      return a.timestamp!.compareTo(b.timestamp!);
    });

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

  List<_Trip> _detectTripsMethod1(List<MapPoint> points) {
    if (points.length < 6) return [];

    List<_Trip> trips = [];
    int? pendingDepartureIndex;

    // New V2 Logic
    // Departure: 5 points with speed 0, followed by >=1 point with speed > 0
    // Arrival:   >=1 point with speed > 0, followed by 5 points with speed 0
    // (Essentially looking for the transition 0,0,0,0,0 -> >0 and >0 -> 0,0,0,0,0)

    for (int i = 0; i <= points.length - 6; i++) {
      // We look at a window of 6 points to see the transition
      // [0, 1, 2, 3, 4] -> [5]

      // Check for validity first
      bool allValid = true;
      for (int j = 0; j < 6; j++) {
        if (points[i + j].speed == null || points[i + j].timestamp == null) {
          allValid = false;
          break;
        }
      }
      if (!allValid) continue;

      bool first5Zero = true;
      for (int j = 0; j < 5; j++) {
        if (points[i + j].speed != 0) {
          first5Zero = false;
          break;
        }
      }

      bool lastGtZero = points[i + 5].speed! > 0;

      // Check Departure condition: 0,0,0,0,0 -> >0
      // The departure point is the first point with speed > 0, which is index i+5
      if (first5Zero && lastGtZero) {
        if (pendingDepartureIndex == null) {
          pendingDepartureIndex = i + 5;
        } else {
          // If we already have a pending departure, we update it?
          // Or we prioritize the first one found?
          // If we find another departure without an arrival, it might mean the previous "trip" was just a short movement.
          // Let's reset start to this new one, assuming the previous one wasn't a real trip.
          pendingDepartureIndex = i + 5;
        }
      }

      // Check Arrival condition: >0 -> 0,0,0,0,0
      // We need to look at window: [i] is > 0, [i+1...i+5] are 0
      // But for that we need a different loop structure or just check both patterns
      // Let's check "Last 5 Zero" and "First > 0"

      bool last5Zero = true;
      for (int j = 1; j < 6; j++) {
        if (points[i + j].speed != 0) {
          last5Zero = false;
          break;
        }
      }
      bool firstGtZero = points[i].speed! > 0;

      // Arrival Condition: >0 -> 0,0,0,0,0
      // The arrival point is the last point with speed > 0, which is index i
      if (firstGtZero && last5Zero) {
        if (pendingDepartureIndex != null) {
          final endIndex = i;

          // Validate Minimum Duration (5 hours)
          final startPoint = points[pendingDepartureIndex];
          final endPoint = points[endIndex];
          final duration = endPoint.timestamp!.difference(
            startPoint.timestamp!,
          );

          double sumSpeed = 0.0;
          int count = 0;
          // Calculate average speed
          for (int k = pendingDepartureIndex; k <= endIndex; k++) {
            if (points[k].speed != null) {
              sumSpeed += points[k].speed!;
              count++;
            }
          }
          final double avgSpeed = count > 0 ? sumSpeed / count : 0.0;

          if (duration.inHours >= 5 && avgSpeed >= 2) {
            final colorIndex = trips.length % _tripColors.length;

            // Indices might be inverted if we scanned weirdly, but here i > pendingDepartureIndex usually
            // Wait, if pendingDepartureIndex = i+5 (from previous steps), and current i (arrival) is later
            // We need to ensure valid sublist ranges

            if (endIndex > pendingDepartureIndex) {
              final tripPoints = points.sublist(
                pendingDepartureIndex,
                endIndex + 1,
              );

              if (pendingDepartureIndex > 0) {
                tripPoints.insert(0, points[pendingDepartureIndex - 1]);
              }

              if (endIndex < points.length - 1) {
                tripPoints.add(points[endIndex + 1]);
              }

              final pathPoints = tripPoints.map((p) => p.position).toList();

              final trip = _Trip(
                startPoint: startPoint,
                endPoint: endPoint,
                pathPoints: pathPoints,
                tripPoints: tripPoints,
                color: _tripColors[colorIndex],
              );
              trips.add(trip);
              pendingDepartureIndex = null;
            }
          } else {
            // Trip too short, discard it.
            pendingDepartureIndex = null;
          }
        }
      }
    }
    return trips;
  }

  // Legacy detection logic (V0) - Unused but preserved

  void _filterPoints() {
    if (_currentRangeValues == null || _minDate == null || _maxDate == null) {
      _filteredPoints = List.from(_allPoints);
    } else {
      final startMs = _currentRangeValues!.start;
      final endMs = _currentRangeValues!.end;

      _filteredPoints = _allPoints.where((p) {
        if (p.timestamp == null) return false;
        final pMs = p.timestamp!.millisecondsSinceEpoch.toDouble();
        return pMs >= startMs && pMs <= endMs;
      }).toList();
    }

    // Capture state to preserve across re-detection
    final hiddenTripStartTimes = _detectedTrips
        .where((t) => !t.isVisible)
        .map((t) => t.startTime.millisecondsSinceEpoch)
        .toSet();

    final pointsVisibleTripStartTimes = _detectedTrips
        .where((t) => t.arePointsVisible)
        .map((t) => t.startTime.millisecondsSinceEpoch)
        .toSet();

    _detectedTrips = _detectTripsMethod1(_filteredPoints);

    // Restore state
    for (final trip in _detectedTrips) {
      final startMs = trip.startTime.millisecondsSinceEpoch;
      if (hiddenTripStartTimes.contains(startMs)) {
        trip.isVisible = false;
      }
      if (pointsVisibleTripStartTimes.contains(startMs)) {
        trip.arePointsVisible = true;
      }
    }
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

  Widget _buildCompactSwitch(
    String label,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Tooltip(
      message: value ? 'Ocultar $label' : 'Mostrar $label',
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12)),
          Transform.scale(
            scale: 0.6,
            alignment: Alignment.centerRight,
            child: Switch(
              value: value,
              onChanged: onChanged,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              // visualDensity: VisualDensity.compact, // Not available in Switch
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final excelDataState = ref.watch(excelDataProvider);
    final geoJsonAsync = ref.watch(geoJsonServiceProvider);
    final vesselsAsync = ref.watch(dbVesselsProvider);
    final hasVessels = vesselsAsync.value?.isNotEmpty ?? false;

    debugPrint('MapScreen build: GeoJson State: $geoJsonAsync');

    ref.listen<AsyncValue<List<Map<String, dynamic>>?>>(excelDataProvider, (
      _,
      next,
    ) {
      next.when(
        data: (data) {
          LoadingDialog.hide(context);
          _processData(data);

          // Confirmar guardado solo si no proviene de la DB y hay datos
          if (data != null && !_isLoadingFromDb) {
            _showPersistConfirmation(context);
          }
          // Reset flag
          _isLoadingFromDb = false;
        },
        error: (error, stackTrace) {
          LoadingDialog.hide(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al procesar el archivo: $error'),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
        loading: () {
          LoadingDialog.show(context);
        },
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
    final isRangeEnabled =
        _minDate != null && _maxDate != null && _minDate != _maxDate;
    final rangeLabel = _currentRangeValues != null
        ? '${_formatDate(DateTime.fromMillisecondsSinceEpoch(_currentRangeValues!.start.toInt()))} - ${_formatDate(DateTime.fromMillisecondsSinceEpoch(_currentRangeValues!.end.toInt()))}'
        : '--/--/-- - --/--/--';

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
                    color: Colors.blueAccent.withValues(alpha: 0.6),
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
      body: DropTarget(
        onDragDone: (detail) {
          final paths = detail.files.map((f) => f.path).toList();
          _handleFiles(paths);
        },
        onDragUpdated: (details) {
          // Explicitly handle drag update if needed for some OS environments
        },
        onDragEntered: (detail) => setState(() => _isDragging = true),
        onDragExited: (detail) => setState(() => _isDragging = false),
        child: Stack(
          children: [
            // 1. Layer del Mapa (Fondo completo)
            Positioned.fill(
              child: MouseRegion(
                onHover: (event) {
                  final point = math.Point(
                    event.localPosition.dx,
                    event.localPosition.dy,
                  );
                  try {
                    final latLng = _mapController.camera.pointToLatLng(point);
                    setState(() {
                      _cursorPosition = latLng;
                    });
                  } catch (e) {
                    // Ignore conversion errors (e.g. if map not ready)
                  }
                },
                hitTestBehavior: HitTestBehavior.translucent,
                child: FlutterMap(
                  key: ValueKey(
                    'map_${_allPoints.hashCode}_${_detectedTrips.length}',
                  ),
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
                          'com.danielditullio.visualizador_siop',
                    ),

                    // Graticule
                    CustomGridLayer(
                      lineColor: Colors.blueGrey.withValues(
                        alpha: 0.3,
                      ), // Color náutico sutil
                      labelStyle: TextStyle(
                        color: Colors.blueGrey[800],
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    // GeoJSON Layers (Below tracks)
                    if (geoJsonAsync.value != null) ...[
                      PolygonLayer(
                        polygons: [
                          ...geoJsonAsync.value!.otherPolygons,
                          if (_showCentolla)
                            ...geoJsonAsync.value!.centollaPolygons,
                          if (_showVieira)
                            ...geoJsonAsync.value!.vieiraPolygons,
                        ],
                      ),
                      PolylineLayer(
                        polylines: [
                          ...geoJsonAsync.value!.otherPolylines,
                          if (_showCentolla)
                            ...geoJsonAsync.value!.centollaPolylines,
                          if (_showVieira)
                            ...geoJsonAsync.value!.vieiraPolylines,
                        ],
                      ),
                    ],

                    if (_filteredPoints.length > 1 && _showTrack)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: _filteredPoints
                                .map((p) => p.position)
                                .toList(),
                            color: Colors.teal.withValues(alpha: 0.8),
                            strokeWidth: 1.0,
                          ),
                        ],
                      ),

                    if (_detectedTrips.any((t) => t.isVisible))
                      PolylineLayer(
                        polylines: [
                          for (final trip in _detectedTrips)
                            if (trip.isVisible)
                              Polyline(
                                points: trip.pathPoints,
                                color: trip.color,
                                strokeWidth: 1.5,
                              ),
                        ],
                      ),

                    // Trip Points Layer
                    MarkerLayer(
                      markers: [
                        for (final trip in _detectedTrips)
                          if (trip.arePointsVisible)
                            for (final point in trip.tripPoints)
                              Marker(
                                point: point.position,
                                width: 6,
                                height: 6,
                                child: Tooltip(
                                  message: _getTooltipMessage(point),
                                  waitDuration: Duration.zero,
                                  padding: const EdgeInsets.all(8.0),
                                  showDuration: Duration.zero,
                                  decoration: BoxDecoration(
                                    color: Colors.black87,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: GestureDetector(
                                    onTap: () {
                                      if (point.timestamp != null) {
                                        _updateSliderAndMarker(
                                          point
                                              .timestamp!
                                              .millisecondsSinceEpoch
                                              .toDouble(),
                                        );
                                      }
                                    },
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: trip.color,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white,
                                          width: 1,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                      ],
                    ),

                    MarkerLayer(
                      markers: [
                        if (_showPoints) ...positionMarkers,
                        if (currentPoint != null)
                          Marker(
                            width: 40,
                            height: 40,
                            point:
                                _animatedMarkerPosition ??
                                currentPoint.position,
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
            ),

            // Cursor Coordinates Display (Bottom Left)
            if (_cursorPosition != null)
              Positioned(
                bottom: 24,
                left: 24,
                child: IgnorePointer(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _formatCoordinate(_cursorPosition!.latitude, true),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            fontFeatures: [FontFeature.tabularFigures()],
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          _formatCoordinate(_cursorPosition!.longitude, false),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            fontFeatures: [FontFeature.tabularFigures()],
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // 2. Tarjeta Flotante de Información (Top Left)
            Positioned(
              top: 24,
              left: 24,
              child: SizedBox(
                width: 200,

                child: FloatingMapCard(
                  elevation: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header premium rediseñado
                      Row(
                        children: [
                          // Icono distintivo
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.indigoAccent.withAlpha(15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.directions_boat_rounded,
                              color: Colors.indigoAccent,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 10),
                          // Información del buque
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  shipName == 'N/A'
                                      ? 'SIN DATOS'
                                      : shipName.toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.black87,
                                    letterSpacing: -0.2,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  matricula == 'N/A'
                                      ? 'Cargar o buscar'
                                      : 'Mat.: ${trimMatricula(matricula)}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Acciones rápidas en nueva fila
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Expanded(
                            child: _buildCompactAction(
                              icon: Icons.search_rounded,
                              onPressed: hasVessels
                                  ? () => _showVesselSearch(context)
                                  : null,
                              color: Colors.indigoAccent,
                              tooltip: 'Buscar en DB',
                              enabled: hasVessels,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildCompactAction(
                              icon: Icons.upload_file_rounded,
                              onPressed: isLoading ? null : _pickFile,
                              color: Colors.indigoAccent,
                              tooltip: 'Cargar archivo',
                              enabled: !isLoading,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildCompactAction(
                              icon: Icons.delete_sweep_rounded,
                              onPressed:
                                  (isLoading || excelDataState.value == null)
                                  ? null
                                  : () {
                                      ref
                                          .read(excelDataProvider.notifier)
                                          .clearData();
                                    },
                              color: Colors.redAccent,
                              tooltip: 'Limpiar mapa',
                              enabled:
                                  !isLoading && excelDataState.value != null,
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
                          _formatCoordinate(
                            currentPoint.position.latitude,
                            true,
                          ),
                          Colors.blue.shade50.withValues(alpha: 0.4),
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
                          Colors.blue.shade50.withValues(alpha: 0.4),
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
                            color: Colors.grey[50]!.withValues(alpha: 0.5),
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

                      const SizedBox(height: 12),
                      const Divider(height: 1),
                      const SizedBox(height: 8),

                      // Layer Controls
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'CAPAS VISIBLES',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[700],
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                      _buildCompactSwitch(
                        'Puntos totales',
                        _showPoints,
                        (val) => setState(() => _showPoints = val),
                      ),
                      _buildCompactSwitch(
                        'Trayectoria total',
                        _showTrack,
                        (val) => setState(() => _showTrack = val),
                      ),
                      const SizedBox(height: 8),
                      _buildCompactSwitch(
                        ' Áreas de Vieira',
                        _showVieira,
                        (val) => setState(() => _showVieira = val),
                      ),
                      _buildCompactSwitch(
                        'Áreas de Centolla',
                        _showCentolla,
                        (val) => setState(() => _showCentolla = val),
                      ),
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
                      vertical: 8.0,
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
                                  icon: const Icon(
                                    Icons.skip_previous,
                                  ), // Start
                                  color: Colors.grey[700],
                                  iconSize: 18,
                                  tooltip: 'Inicio',
                                ),
                                IconButton(
                                  onPressed: _stepBackward,
                                  icon: const Icon(
                                    Icons.navigate_before,
                                  ), // Prev
                                  color: Colors.grey[700],
                                  iconSize: 22,
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
                                  iconSize: 32, // Larger
                                  tooltip: _isPlaying ? 'Pausar' : 'Reproducir',
                                ),
                                IconButton(
                                  onPressed: () => _stepForward(),
                                  icon: const Icon(Icons.navigate_next), // Next
                                  color: Colors.grey[700],
                                  iconSize: 22,
                                  tooltip: 'Siguiente',
                                ),
                                IconButton(
                                  onPressed: _skipToEnd,
                                  icon: const Icon(Icons.skip_next), // End
                                  color: Colors.grey[700],
                                  iconSize: 18,
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
                                        overlayColor: Colors.indigo.withValues(
                                          alpha: 0.2,
                                        ),
                                        trackHeight: 2,
                                        thumbShape: const RoundSliderThumbShape(
                                          enabledThumbRadius: 6,
                                        ),
                                      ),
                                      child: Slider(
                                        value: _getSliderValueIndex(),
                                        min: 0.0,
                                        max: math.max(
                                          0.0,
                                          (_filteredPoints.length - 1)
                                              .toDouble(),
                                        ),
                                        divisions: math.max(
                                          1,
                                          _filteredPoints.length - 1,
                                        ),
                                        label: _currentSliderValue != null
                                            ? _formatDateTime(
                                                DateTime.fromMillisecondsSinceEpoch(
                                                  _currentSliderValue!.toInt(),
                                                ),
                                              )
                                            : null,
                                        onChanged: (value) {
                                          final index = value.round();
                                          if (index >= 0 &&
                                              index < _filteredPoints.length) {
                                            setState(() {
                                              _currentSliderValue =
                                                  _filteredPoints[index]
                                                      .timestamp!
                                                      .millisecondsSinceEpoch
                                                      .toDouble();
                                            });
                                            final selected = _selectedPoint;
                                            if (selected != null) {
                                              _updateMarkerTarget(
                                                selected.position,
                                                animate: true,
                                              );
                                              _ensureVisible(selected.position);
                                            }
                                          }
                                        },
                                      ),
                                    )
                                  : const LinearProgressIndicator(value: 0),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              onPressed: _pickDateAndTime,
                              icon: const Icon(Icons.calendar_month),
                              iconSize: 22,
                              color: Colors.indigoAccent,
                              tooltip: 'Ir a fecha...',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),

                        // Range Slider & Dates
                        const SizedBox(height: 0),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            // color: Colors.grey[50]!.withOpacity(0.5),
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _minDate != null
                                        ? _formatDateTime(_minDate!)
                                        : '--/--/-- --:--',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey[700],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    _maxDate != null
                                        ? _formatDateTime(_maxDate!)
                                        : '--/--/-- --:--',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey[700],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(
                                height: 32,
                                child: Row(
                                  children: [
                                    Tooltip(
                                      message: 'Rango de fechas',
                                      child: OutlinedButton.icon(
                                        onPressed: isRangeEnabled
                                            ? _pickDateRange
                                            : null,
                                        icon: const Icon(
                                          Icons.date_range,
                                          size: 16,
                                        ),
                                        label: Text(
                                          rangeLabel,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          textStyle: const TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                          ),
                                          foregroundColor: Colors.indigo,
                                          visualDensity: const VisualDensity(
                                            horizontal: -4,
                                            vertical: -4,
                                          ),
                                          tapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: SliderTheme(
                                        data: SliderTheme.of(context).copyWith(
                                          activeTrackColor: Colors.indigoAccent,
                                          inactiveTrackColor: Colors.black12,
                                          trackHeight: 2,
                                          rangeThumbShape:
                                              const RoundRangeSliderThumbShape(
                                                enabledThumbRadius: 4,
                                              ),
                                          overlayColor: Colors.indigo
                                              .withValues(alpha: 0.2),
                                          valueIndicatorColor: Colors.indigo,
                                          valueIndicatorTextStyle:
                                              const TextStyle(
                                                color: Colors.white,
                                              ),
                                          showValueIndicator:
                                              ShowValueIndicator.onDrag,
                                        ),
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
                                          labels: _currentRangeValues != null
                                              ? RangeLabels(
                                                  _formatDateTime(
                                                    DateTime.fromMillisecondsSinceEpoch(
                                                      _currentRangeValues!.start
                                                          .toInt(),
                                                    ),
                                                  ),
                                                  _formatDateTime(
                                                    DateTime.fromMillisecondsSinceEpoch(
                                                      _currentRangeValues!.end
                                                          .toInt(),
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
                                                    _currentRangeValues =
                                                        values;
                                                    if (_currentSliderValue !=
                                                        null) {
                                                      if (_currentSliderValue! <
                                                              values.start ||
                                                          _currentSliderValue! >
                                                              values.end) {
                                                        // Clamp slider if range moves past it?
                                                        // Or just let filter handle hiding point
                                                        _filterPoints();
                                                      } else {
                                                        _filterPoints();
                                                      }
                                                    } else {
                                                      _filterPoints();
                                                    }
                                                  });
                                                }
                                              : null,
                                        ),
                                      ),
                                    ),
                                  ],
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
            // 4. Tarjeta Flotante de Etapas (Top Right)
            if (_allPoints.isNotEmpty)
              Positioned(
                top: 24,
                right: 24,
                child: SizedBox(
                  width: 220,
                  child: FloatingMapCard(
                    elevation: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${_detectedTrips.length} ${_detectedTrips.length == 1 ? "ETAPA" : "ETAPAS"}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                            letterSpacing: 1,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${_calculateUniqueNavigatedDays()} ${_calculateUniqueNavigatedDays() == 1 ? "día" : "días"} navegados',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey[700],
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        const Divider(height: 1),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 500),
                          child: _detectedTrips.isEmpty
                              ? Container(
                                  padding: const EdgeInsets.all(16),
                                  alignment: Alignment.center,
                                  child: const Text(
                                    'No se encontraron etapas',
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 12,
                                      fontStyle: FontStyle.italic,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                )
                              : ListView.builder(
                                  padding: const EdgeInsets.only(top: 8),
                                  shrinkWrap: true,
                                  itemCount: _detectedTrips.length,
                                  itemBuilder: (context, index) {
                                    final trip = _detectedTrips[index];

                                    // Check if active based on slider time
                                    bool isActive = false;
                                    if (_currentSliderValue != null) {
                                      final currentTime =
                                          DateTime.fromMillisecondsSinceEpoch(
                                            _currentSliderValue!.toInt(),
                                          );
                                      // Relaxed check: is currentTime within [start, end]?
                                      // Use slight buffer or inclusive check
                                      if (currentTime.isAfter(
                                            trip.startTime.subtract(
                                              const Duration(minutes: 1),
                                            ),
                                          ) &&
                                          currentTime.isBefore(
                                            trip.endTime.add(
                                              const Duration(minutes: 1),
                                            ),
                                          )) {
                                        isActive = true;
                                      }
                                    }

                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: trip.color.withValues(
                                          alpha: isActive ? 0.15 : 0.05,
                                        ),
                                        border: Border(
                                          left: BorderSide(
                                            color: trip.color,
                                            width: 4,
                                          ),
                                        ),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Stack(
                                        children: [
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              right: 24.0,
                                            ), // Reserve space for icon
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        if (isActive)
                                                          Padding(
                                                            padding:
                                                                const EdgeInsets.only(
                                                                  right: 4,
                                                                ),
                                                            child: Icon(
                                                              Icons.play_arrow,
                                                              size: 10,
                                                              color: trip.color,
                                                            ),
                                                          ),
                                                        Text(
                                                          'Etapa ${index + 1}',
                                                          style: TextStyle(
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontSize: 12,
                                                            color: trip.color,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    Container(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 6,
                                                            vertical: 2,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: trip.color,
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              10,
                                                            ),
                                                      ),
                                                      child: Text(
                                                        '${trip.durationInDays} ${trip.durationInDays == 1 ? "día" : "días"}',
                                                        style: const TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 10,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 4),
                                                InkWell(
                                                  onTap: () {
                                                    _updateSliderAndMarker(
                                                      trip
                                                          .startTime
                                                          .millisecondsSinceEpoch
                                                          .toDouble(),
                                                    );
                                                    _animatedMapMove(
                                                      trip.startPoint.position,
                                                      _mapController
                                                          .camera
                                                          .zoom,
                                                    );
                                                  },
                                                  child: Text(
                                                    'Zarpada: ${DateFormat('dd/MM HH:mm').format(trip.startTime)}',
                                                    style: const TextStyle(
                                                      fontSize: 11,
                                                    ),
                                                  ),
                                                ),
                                                InkWell(
                                                  onTap: () {
                                                    _updateSliderAndMarker(
                                                      trip
                                                          .endTime
                                                          .millisecondsSinceEpoch
                                                          .toDouble(),
                                                    );
                                                    _animatedMapMove(
                                                      trip.endPoint.position,
                                                      _mapController
                                                          .camera
                                                          .zoom,
                                                    );
                                                  },
                                                  child: Text(
                                                    'Arribo:    ${DateFormat('dd/MM HH:mm').format(trip.endTime)}',
                                                    style: const TextStyle(
                                                      fontSize: 11,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Positioned(
                                            bottom: 0,
                                            right: 0,
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                InkWell(
                                                  onTap: () {
                                                    setState(() {
                                                      trip.isVisible =
                                                          !trip.isVisible;
                                                    });
                                                  },
                                                  child: Tooltip(
                                                    message: trip.isVisible
                                                        ? 'Ocultar trayectoria de esta etapa'
                                                        : 'Mostrar trayectoria de esta etapa',
                                                    child: Icon(
                                                      Icons.timeline,
                                                      size: 20,
                                                      color: trip.color
                                                          .withValues(
                                                            alpha:
                                                                trip.isVisible
                                                                ? 1.0
                                                                : 0.3,
                                                          ),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                InkWell(
                                                  onTap: () {
                                                    setState(() {
                                                      trip.arePointsVisible =
                                                          !trip
                                                              .arePointsVisible;
                                                    });
                                                  },
                                                  child: Tooltip(
                                                    message:
                                                        trip.arePointsVisible
                                                        ? 'Ocultar puntos de esta etapa'
                                                        : 'Mostrar puntos de esta etapa',
                                                    child: Icon(
                                                      Icons.scatter_plot,
                                                      size: 20,
                                                      color: trip.color.withValues(
                                                        alpha:
                                                            trip.arePointsVisible
                                                            ? 1.0
                                                            : 0.3,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            Positioned(
              bottom: 24,
              right: 80, // Left of zoom buttons
              child: ScaleBar(
                mapController: _mapController,
                textStyle: TextStyle(
                  fontSize: 10,
                  color: Colors.grey[800],
                  fontWeight: FontWeight.bold,
                ),
                lineColor: Colors.grey[800]!,
              ),
            ),
            Positioned(
              bottom: 24,
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
            // Overlay de Drag & Drop
            if (_isDragging)
              Positioned.fill(
                child: Container(
                  color: Colors.indigoAccent.withAlpha(40),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 24,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(40),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.cloud_upload_outlined,
                            size: 64,
                            color: Colors.indigoAccent,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Suelta los archivos aquí',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Soportados: .xlsx y .csv',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  int _calculateUniqueNavigatedDays() {
    if (_detectedTrips.isEmpty) return 0;

    final uniqueDays = <String>{};
    final dateFormat = DateFormat('yyyy-MM-dd');

    for (final trip in _detectedTrips) {
      // Iterate from start to end day
      DateTime current = trip.startTime;
      // We want to include the end date day as well
      // But we need to be careful with time components.
      // Let's normalize to midnight for safety in loop
      final end = trip.endTime;

      // Normalize current to midnight
      DateTime currentDay = DateTime(current.year, current.month, current.day);
      final endDay = DateTime(end.year, end.month, end.day);

      while (!currentDay.isAfter(endDay)) {
        uniqueDays.add(dateFormat.format(currentDay));
        currentDay = currentDay.add(const Duration(days: 1));
      }
    }

    return uniqueDays.length;
  }

  Future<void> _pickDateRange() async {
    if (_allPoints.isEmpty || _minDate == null || _maxDate == null) return;

    final currentRange = _currentRangeValues;
    final initialStart = currentRange != null
        ? DateTime.fromMillisecondsSinceEpoch(currentRange.start.toInt())
        : _minDate!;
    final initialEnd = currentRange != null
        ? DateTime.fromMillisecondsSinceEpoch(currentRange.end.toInt())
        : _maxDate!;

    final selectedRange = await showDialog<DateTimeRange>(
      context: context,
      builder: (context) => CustomDateRangePicker(
        initialStartDate: DateTime(
          initialStart.year,
          initialStart.month,
          initialStart.day,
        ),
        initialEndDate: DateTime(
          initialEnd.year,
          initialEnd.month,
          initialEnd.day,
        ),
        firstDate: DateTime(_minDate!.year, _minDate!.month, _minDate!.day),
        lastDate: DateTime(_maxDate!.year, _maxDate!.month, _maxDate!.day),
      ),
    );

    if (selectedRange == null || !mounted) return;

    final startDate = DateTime(
      selectedRange.start.year,
      selectedRange.start.month,
      selectedRange.start.day,
    );
    final endDate = DateTime(
      selectedRange.end.year,
      selectedRange.end.month,
      selectedRange.end.day,
      23,
      59,
      59,
      999,
    );

    final minMs = _minDate!.millisecondsSinceEpoch.toDouble();
    final maxMs = _maxDate!.millisecondsSinceEpoch.toDouble();
    double startMs = startDate.millisecondsSinceEpoch.toDouble();
    double endMs = endDate.millisecondsSinceEpoch.toDouble();

    if (startMs < minMs) startMs = minMs;
    if (endMs > maxMs) endMs = maxMs;
    if (endMs < startMs) endMs = startMs;

    setState(() {
      _currentRangeValues = RangeValues(startMs, endMs);
    });

    double clampedValue = _currentSliderValue ?? startMs;
    if (clampedValue < startMs) {
      clampedValue = startMs;
    } else if (clampedValue > endMs) {
      clampedValue = endMs;
    }
    _updateSliderAndMarker(clampedValue);
  }

  Future<void> _pickDateAndTime() async {
    if (_allPoints.isEmpty || _minDate == null || _maxDate == null) return;

    // Use current selection as initial date if available, else minDate
    final initialDate = _currentSliderValue != null
        ? DateTime.fromMillisecondsSinceEpoch(_currentSliderValue!.toInt())
        : _minDate!;

    final selectedDateTime = await showDialog<DateTime>(
      context: context,
      builder: (context) => CustomDateTimePicker(
        initialDate: initialDate,
        firstDate: _minDate!,
        lastDate: _maxDate!,
      ),
    );

    if (selectedDateTime != null && mounted) {
      _jumpToDate(selectedDateTime);
    }
  }

  void _jumpToDate(DateTime target) {
    if (_allPoints.isEmpty) return;

    // Find closest point in ALL points (even if currently filtered out)
    final closest = _allPoints.reduce((a, b) {
      if (a.timestamp == null || b.timestamp == null) return a;
      final aDiff =
          (a.timestamp!.millisecondsSinceEpoch - target.millisecondsSinceEpoch)
              .abs();
      final bDiff =
          (b.timestamp!.millisecondsSinceEpoch - target.millisecondsSinceEpoch)
              .abs();
      return aDiff < bDiff ? a : b;
    });

    if (closest.timestamp == null) return;

    final newTimestamp = closest.timestamp!.millisecondsSinceEpoch.toDouble();

    // Ensure it is within current range values. If not, expand/shift the range.
    if (_currentRangeValues != null) {
      double start = _currentRangeValues!.start;
      double end = _currentRangeValues!.end;
      bool changed = false;

      // Expand to include the new point if outside
      if (newTimestamp < start) {
        start = newTimestamp;
        changed = true;
      }
      if (newTimestamp > end) {
        end = newTimestamp;
        changed = true;
      }

      if (changed) {
        // Also ensure we respect min/max global limits just in case
        if (_minDate != null &&
            start < _minDate!.millisecondsSinceEpoch.toDouble()) {
          start = _minDate!.millisecondsSinceEpoch.toDouble();
        }
        if (_maxDate != null &&
            end > _maxDate!.millisecondsSinceEpoch.toDouble()) {
          end = _maxDate!.millisecondsSinceEpoch.toDouble();
        }

        setState(() {
          _currentRangeValues = RangeValues(start, end);
        });
      }
    }

    // Now update slider and marker (this will also trigger filter refresh)
    _updateSliderAndMarker(newTimestamp);

    // Also ensure map follows text to speech... I mean follows position
    _ensureVisible(closest.position);
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
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accentColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: accentColor.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            textAlign: TextAlign.center,
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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (bounds != null) {
        try {
          _mapController.fitCamera(
            CameraFit.bounds(
              bounds: bounds,
              padding: const EdgeInsets.all(60.0),
            ),
          );
        } catch (e) {
          debugPrint('Error fitting camera: $e');
          final targetCenter = _centerForBounds(bounds);
          final targetZoom = _zoomForBounds(bounds);
          _animatedMapMove(targetCenter, targetZoom);
        }
      } else {
        _animatedMapMove(fallbackCenter, fallbackZoom);
      }
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

  void _updateSliderAndMarker(double timestamp) {
    setState(() {
      _currentSliderValue = timestamp;
      _filterPoints();
    });
    // Find closest point to timestamp to update marker
    if (_filteredPoints.isNotEmpty) {
      final closest = _filteredPoints.reduce((a, b) {
        return (a.timestamp!.millisecondsSinceEpoch - timestamp).abs() <
                (b.timestamp!.millisecondsSinceEpoch - timestamp).abs()
            ? a
            : b;
      });
      _updateMarkerTarget(closest.position, animate: true);
    }
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

  double _getSliderValueIndex() {
    if (_filteredPoints.isEmpty || _currentSliderValue == null) return 0.0;

    // Find precise index
    final index = _filteredPoints.indexWhere(
      (p) =>
          p.timestamp != null &&
          p.timestamp!.millisecondsSinceEpoch == _currentSliderValue,
    );

    if (index != -1) return index.toDouble();

    return 0.0;
  }

  Widget _buildCompactAction({
    required IconData icon,
    required VoidCallback? onPressed,
    required Color color,
    required String tooltip,
    bool enabled = true,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: enabled ? color.withAlpha(20) : Colors.grey.withAlpha(15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: IconButton(
        icon: Icon(icon, size: 20),
        onPressed: onPressed,
        tooltip: tooltip,
        color: enabled ? color : Colors.grey,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
      ),
    );
  }

  void _showPersistConfirmation(BuildContext screenContext) {
    showDialog(
      context: screenContext,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Guardar en Base de Datos'),
        content: const Text(
          '¿Desea guardar los datos cargados en la base de datos local para acceso rápido futuro?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('NO'),
          ),
          ElevatedButton(
            onPressed: () async {
              // 1. Close the alert dialog using its own context
              Navigator.pop(dialogContext);

              // 2. Show the loading dialog using the screen context
              debugPrint('MapScreen: Mostrando diálogo de guardado...');
              LoadingDialog.show(screenContext, message: 'Guardando datos...');

              try {
                // 3. Perform the save operation
                await ref.read(excelDataProvider.notifier).saveCurrentToDb();

                debugPrint('MapScreen: Guardado finalizado en el provider.');

                // 4. Hide the loading dialog using the screen context
                if (screenContext.mounted) {
                  debugPrint('MapScreen: Ocultando diálogo de carga...');
                  LoadingDialog.hide(screenContext);
                  ScaffoldMessenger.of(screenContext).showSnackBar(
                    const SnackBar(
                      content: Text('Datos guardados correctamente.'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } else {
                  debugPrint(
                    'MapScreen WARNING: screenContext no está montado al finalizar.',
                  );
                }
              } catch (e) {
                debugPrint('MapScreen ERROR al guardar: $e');
                if (screenContext.mounted) {
                  LoadingDialog.hide(screenContext);
                  ScaffoldMessenger.of(screenContext).showSnackBar(
                    SnackBar(
                      content: Text('Error al guardar: $e'),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                }
              }
            },
            child: const Text('SÍ, GUARDAR'),
          ),
        ],
      ),
    );
  }

  void _showVesselSearch(BuildContext context) async {
    final vessel = await showDialog<Vessel?>(
      context: context,
      builder: (context) => const _VesselSearchDialog(),
    );

    if (vessel != null && context.mounted) {
      _isLoadingFromDb = true; // Indicar que los datos ya están en la DB
      await ref.read(excelDataProvider.notifier).loadFromDb(vessel.id!);
    }
  }
}

class _BatchImportDialog extends ConsumerStatefulWidget {
  final List<String> filePaths;
  const _BatchImportDialog({required this.filePaths});

  @override
  ConsumerState<_BatchImportDialog> createState() => _BatchImportDialogState();
}

class _BatchImportDialogState extends ConsumerState<_BatchImportDialog> {
  final Map<String, String> _statuses = {};
  bool _isProcessing = true;
  int _completedCount = 0;
  int _successCount = 0;
  int _errorCount = 0;
  final ScrollController _scrollController = ScrollController();
  final Map<int, GlobalKey> _itemKeys = {};

  @override
  void initState() {
    super.initState();
    for (final p in widget.filePaths) {
      _statuses[p] = 'Pendiente';
    }
    _processFiles();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _processFiles() async {
    final notifier = ref.read(excelDataProvider.notifier);

    for (int i = 0; i < widget.filePaths.length; i++) {
      final path = widget.filePaths[i];
      setState(() {
        _statuses[path] = 'Procesando...';
      });

      // Auto-scroll to current item
      _scrollToItem(i);

      try {
        await notifier.saveFileToDb(path);
        if (!mounted) return;
        setState(() {
          _statuses[path] = 'Listo';
          _completedCount++;
          _successCount++;
        });
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _statuses[path] = 'Error: $e';
          _completedCount++;
          _errorCount++;
        });
      }
    }

    if (mounted) {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  void _scrollToItem(int index) {
    // We use a small delay to ensure the framework has had a chance to build the item if needed
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final keyContext = _itemKeys[index]?.currentContext;
      if (keyContext != null) {
        Scrollable.ensureVisible(
          keyContext,
          alignment: 0.5,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final progress = widget.filePaths.isEmpty
        ? 1.0
        : _completedCount / widget.filePaths.length;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 450, maxHeight: 550),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blueAccent.withAlpha(20),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _isProcessing ? Icons.cloud_upload : Icons.check_circle,
                    color: Colors.blueAccent,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isProcessing
                            ? 'Procesando Archivos'
                            : 'Proceso Finalizado',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _isProcessing
                            ? 'Cargando datos en la base de datos local'
                            : 'Total: ${widget.filePaths.length} | Éxito: $_successCount | Error: $_errorCount',
                        style: TextStyle(
                          color: _isProcessing
                              ? Colors.grey[600]
                              : (_errorCount > 0
                                    ? Colors.orange[800]
                                    : Colors.green[700]),
                          fontSize: 13,
                          fontWeight: _isProcessing
                              ? FontWeight.normal
                              : FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey[200],
              color: Colors.blueAccent,
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '$_completedCount de ${widget.filePaths.length} completados',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'DETALLE:',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: ListView.separated(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(8),
                  itemCount: widget.filePaths.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    _itemKeys[index] ??= GlobalKey();
                    final path = widget.filePaths[index];
                    final fileName = path.split('\\').last.split('/').last;
                    final status = _statuses[path] ?? '';

                    final isError = status.startsWith('Error');
                    IconData statusIcon = Icons.more_horiz;
                    Color statusColor = Colors.grey;

                    if (status == 'Procesando...') {
                      statusColor = Colors.blue;
                    } else if (status == 'Listo') {
                      statusIcon = Icons.check_circle;
                      statusColor = Colors.green;
                    } else if (isError) {
                      statusIcon = Icons.error;
                      statusColor = Colors.red;
                    }

                    return ListTile(
                      key: _itemKeys[index],
                      dense: true,
                      leading: status == 'Procesando...'
                          ? _LoadingIcon(color: statusColor)
                          : Icon(statusIcon, color: statusColor, size: 20),
                      title: Text(
                        fileName,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: isError
                          ? Text(
                              status,
                              style: TextStyle(
                                color: statusColor,
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                            )
                          : null,
                      trailing: !isError
                          ? Text(
                              status,
                              style: TextStyle(
                                color: statusColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            )
                          : const SizedBox(width: 20), // Placeholder for align
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isProcessing ? null : () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey[300],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: Text(_isProcessing ? 'PROCESANDO...' : 'CERRAR'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingIcon extends StatefulWidget {
  final Color color;
  const _LoadingIcon({required this.color});

  @override
  State<_LoadingIcon> createState() => _LoadingIconState();
}

class _LoadingIconState extends State<_LoadingIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _controller,
      child: const Icon(Icons.sync, color: Colors.blue, size: 20),
    );
  }
}

class _VesselSearchDialog extends ConsumerStatefulWidget {
  const _VesselSearchDialog();

  @override
  ConsumerState<_VesselSearchDialog> createState() =>
      _VesselSearchDialogState();
}

class _VesselSearchDialogState extends ConsumerState<_VesselSearchDialog> {
  final TextEditingController _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vesselsAsync = ref.watch(dbVesselsProvider);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 500),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.indigoAccent.withAlpha(20),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.directions_boat,
                    color: Colors.indigoAccent,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Buscar en Base de Datos',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Nombre o matrícula...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _controller.clear();
                          setState(() => _query = '');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              onChanged: (val) => setState(() => _query = val),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: vesselsAsync.when(
                data: (vessels) {
                  final filtered = vessels.where((v) {
                    final q = _query.toLowerCase();
                    return v.nombre.toLowerCase().contains(q) ||
                        v.matricula.toLowerCase().contains(q);
                  }).toList();

                  if (filtered.isEmpty) {
                    return const Center(
                      child: Text('No hay buques que coincidan.'),
                    );
                  }

                  return ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final v = filtered[index];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                        ),
                        title: Text(
                          v.nombre.toUpperCase(),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text('Matrícula: ${v.matricula}'),
                        onTap: () => Navigator.pop(context, v),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, s) => Center(child: Text('Error: $e')),
              ),
            ),
          ],
        ),
      ),
    );
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

DateTime _convertUtcToLocalMinus3(DateTime utcDate) {
  final utcMillis = utcDate.toUtc().millisecondsSinceEpoch;
  return DateTime.fromMillisecondsSinceEpoch(
    utcMillis + const Duration(hours: -3).inMilliseconds,
    isUtc: false,
  );
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

  if (val is DateTime) {
    return _convertUtcToLocalMinus3(val);
  }

  final str = val.toString().trim();
  try {
    String isoStr = str.replaceAll(' ', 'T');

    // Naively parse first
    DateTime temp = DateTime.parse(isoStr);

    // If it parsed as Local (implied by no offset/Z), but we Treat Input As UTC:
    if (!temp.isUtc) {
      temp = DateTime.utc(
        temp.year,
        temp.month,
        temp.day,
        temp.hour,
        temp.minute,
        temp.second,
        temp.millisecond,
        temp.microsecond,
      );
    }

    return _convertUtcToLocalMinus3(temp);
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
