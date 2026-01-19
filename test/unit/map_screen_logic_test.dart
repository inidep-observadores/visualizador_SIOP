import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart';
import 'dart:ui';
import 'dart:math' as math;

// START: Code copied from map_screen.dart for testing purposes
// Note: In a real-world scenario, this logic would be refactored into
// a testable, non-private class. For this exercise, we copy it.

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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MapPoint &&
          runtimeType == other.runtimeType &&
          position == other.position &&
          timestamp == other.timestamp &&
          shipName == other.shipName &&
          matricula == other.matricula &&
          speed == other.speed &&
          course == other.course;

  @override
  int get hashCode =>
      position.hashCode ^
      timestamp.hashCode ^
      shipName.hashCode ^
      matricula.hashCode ^
      speed.hashCode ^
      course.hashCode;

  @override
  String toString() {
    return 'MapPoint{position: $position, timestamp: $timestamp, speed: $speed}';
  }
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

  int get durationInDays {
    final start = DateTime(startTime.year, startTime.month, startTime.day);
    final end = DateTime(endTime.year, endTime.month, endTime.day);
    return end.difference(start).inDays + 1;
  }
}

// --- Formatting Functions ---

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

  return '$degrees° $minutesStr\u0027 $cardinal';
}

// --- Data Parsing Functions ---

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

String? _getStringFromRow(Map<String, dynamic> row, String columnName) {
  final normalizedTarget = columnName.trim().toLowerCase();
  final matchedKey = row.keys.firstWhere(
    (key) => key.trim().toLowerCase() == normalizedTarget,
    orElse: () => '',
  );
  if (matchedKey.isEmpty) return null;
  final val = row[matchedKey];
  if (val == null) return null;
  return val.toString().trim();
}

double? _coordinateFromRow(Map<String, dynamic> row, String columnName) {
  final normalizedTarget = columnName.trim().toLowerCase();
  final matchedKey = row.keys.firstWhere(
    (key) => key.trim().toLowerCase() == normalizedTarget,
    orElse: () => '',
  );
  if (matchedKey.isEmpty) return null;
  final rawValue = row[matchedKey];
  return _parseDouble(rawValue);
}

LatLng? _latLngFromRow(Map<String, dynamic> row) {
  final latitude = _coordinateFromRow(row, 'latitud');
  final longitude = _coordinateFromRow(row, 'longitud');
  if (latitude == null || longitude == null) return null;
  return LatLng(latitude, longitude);
}

DateTime _convertUtcToLocalMinus3(DateTime utcDate) {
  final utcMillis = utcDate.toUtc().millisecondsSinceEpoch;
  return DateTime.fromMillisecondsSinceEpoch(
    utcMillis + const Duration(hours: -3).inMilliseconds,
    isUtc: false,
  );
}

DateTime? _dateFromRow(Map<String, dynamic> row) {
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
    DateTime temp = DateTime.parse(isoStr);
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

List<MapPoint> _extractMapPoints(List<Map<String, dynamic>> rows) {
  final points = <MapPoint>[];
  for (final row in rows) {
    final latLng = _latLngFromRow(row);
    if (latLng != null) {
      points.add(
        MapPoint(
          position: latLng,
          timestamp: _dateFromRow(row),
          shipName: _getStringFromRow(row, 'buque'),
          matricula: _getStringFromRow(row, 'matricula'),
          speed: _coordinateFromRow(row, 'velocidad'),
          course: _coordinateFromRow(row, 'rumbo'),
        ),
      );
    }
  }
  return points;
}

// --- Trip Detection Logic ---

final List<Color> _tripColors = [Colors.orange, Colors.purple, Colors.teal];

List<_Trip> _detectTripsMethod1(List<MapPoint> points) {
  if (points.length < 6) return [];

  List<_Trip> trips = [];
  int? pendingDepartureIndex;

  for (int i = 0; i <= points.length - 6; i++) {
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

    if (first5Zero && lastGtZero) {
      pendingDepartureIndex = i + 5;
    }

    bool last5Zero = true;
    for (int j = 1; j < 6; j++) {
      if (points[i + j].speed != 0) {
        last5Zero = false;
        break;
      }
    }
    bool firstGtZero = points[i].speed! > 0;

    if (firstGtZero && last5Zero) {
      if (pendingDepartureIndex != null) {
        final endIndex = i;
        final startPoint = points[pendingDepartureIndex];
        final endPoint = points[endIndex];
        final duration = endPoint.timestamp!.difference(startPoint.timestamp!);

        double sumSpeed = 0.0;
        int count = 0;
        for (int k = pendingDepartureIndex; k <= endIndex; k++) {
          if (points[k].speed != null) {
            sumSpeed += points[k].speed!;
            count++;
          }
        }
        final double avgSpeed = count > 0 ? sumSpeed / count : 0.0;

        if (duration.inHours >= 5 && avgSpeed >= 2) {
          if (endIndex > pendingDepartureIndex) {
            final tripPoints = points.sublist(
              pendingDepartureIndex,
              endIndex + 1,
            );
            trips.add(
              _Trip(
                startPoint: startPoint,
                endPoint: endPoint,
                pathPoints: tripPoints.map((p) => p.position).toList(),
                tripPoints: tripPoints,
                color: _tripColors[trips.length % _tripColors.length],
              ),
            );
            pendingDepartureIndex = null;
          }
        } else {
          pendingDepartureIndex = null;
        }
      }
    }
  }
  return trips;
}

List<_Trip> _detectTripsMethod2(List<MapPoint> points) {
  if (points.length < 6) return [];
  List<_Trip> trips = [];
  int? pendingDepartureIndex;
  for (int i = 0; i <= points.length - 6; i++) {
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
      if (points[i + j].speed! >= 0.5) {
        first5Zero = false;
        break;
      }
    }
    bool lastGtZero = points[i + 5].speed! > 1.0;
    if (first5Zero && lastGtZero) {
      pendingDepartureIndex = i + 5;
    }
    bool last5Zero = true;
    for (int j = 1; j < 6; j++) {
      if (points[i + j].speed! >= 0.3) {
        last5Zero = false;
        break;
      }
    }
    bool firstGtZero = points[i].speed! > 0.3;
    if (firstGtZero && last5Zero) {
      if (pendingDepartureIndex != null) {
        final endIndex = i;
        final startPoint = points[pendingDepartureIndex];
        final endPoint = points[endIndex];
        final duration = endPoint.timestamp!.difference(startPoint.timestamp!);
        if (duration.inHours >= 5) {
          if (endIndex > pendingDepartureIndex) {
            final tripPoints = points.sublist(
              pendingDepartureIndex,
              endIndex + 1,
            );
            trips.add(
              _Trip(
                startPoint: startPoint,
                endPoint: endPoint,
                pathPoints: tripPoints.map((p) => p.position).toList(),
                tripPoints: tripPoints,
                color: _tripColors[trips.length % _tripColors.length],
              ),
            );
            pendingDepartureIndex = null;
          }
        } else {
          pendingDepartureIndex = null;
        }
      }
    }
  }
  return trips;
}

List<_Trip> _detectTripsLegacy(List<MapPoint> points) {
  if (points.length < 6) return [];
  List<_Trip> trips = [];
  int? pendingDepartureIndex;
  for (int i = 0; i <= points.length - 6; i++) {
    final p = points.sublist(i, i + 6);
    if (p.any((pt) => pt.speed == null || pt.timestamp == null)) continue;
    bool isDeparture =
        p[0].speed == 0 &&
        p[1].speed == 0 &&
        p[2].speed == 0 &&
        p[3].speed! > 0 &&
        p[4].speed! > 0 &&
        p[5].speed! > 0;
    bool isArrival =
        p[0].speed! > 0 &&
        p[1].speed! > 0 &&
        p[2].speed! > 0 &&
        p[3].speed == 0 &&
        p[4].speed == 0 &&
        p[5].speed == 0;
    if (isDeparture) {
      pendingDepartureIndex = i + 3;
    } else if (isArrival) {
      if (pendingDepartureIndex != null) {
        final endIndex = i + 3;
        final tripPoints = points.sublist(pendingDepartureIndex, endIndex + 1);
        trips.add(
          _Trip(
            startPoint: points[pendingDepartureIndex],
            endPoint: points[endIndex],
            pathPoints: tripPoints.map((p) => p.position).toList(),
            tripPoints: tripPoints,
            color: _tripColors[trips.length % _tripColors.length],
          ),
        );
        pendingDepartureIndex = null;
      }
    }
  }
  return trips;
}

int _calculateUniqueNavigatedDays(List<_Trip> detectedTrips) {
  if (detectedTrips.isEmpty) return 0;
  final uniqueDays = <String>{};
  final dateFormat = DateFormat('yyyy-MM-dd');
  for (final trip in detectedTrips) {
    DateTime currentDay = DateTime(
      trip.startTime.year,
      trip.startTime.month,
      trip.startTime.day,
    );
    final endDay = DateTime(
      trip.endTime.year,
      trip.endTime.month,
      trip.endTime.day,
    );
    while (!currentDay.isAfter(endDay)) {
      uniqueDays.add(dateFormat.format(currentDay));
      currentDay = currentDay.add(const Duration(days: 1));
    }
  }
  return uniqueDays.length;
}

// END: Code copied from map_screen.dart

void main() {
  group('Map Screen Logic - Formatting Functions', () {
    test('trimMatricula shortens long strings', () {
      expect(trimMatricula('A1B2C3D4E5F6G7H8I9J0K1L2'), 'A1B2C3D4E5F6G7H8I...');
    });

    test('trimMatricula does not shorten short strings', () {
      expect(trimMatricula('SHORT_MAT'), 'SHORT_MAT');
    });

    test('_formatCoordinate correctly formats latitude', () {
      expect(_formatCoordinate(-42.123456, true), '42° 7,407\u0027 S');
    });

    test('_formatCoordinate correctly formats longitude', () {
      expect(_formatCoordinate(-65.98765, false), '65° 59,259\u0027 O');
    });

    test('_formatDate, _formatTime, _formatDateTime work correctly', () {
      final date = DateTime(2023, 10, 26, 14, 30);
      expect(_formatDate(date), '26/10/2023');
      expect(_formatTime(date), '14:30');
      expect(_formatDateTime(date), '26/10/2023 14:30');
    });
  });

  group('Map Screen Logic - Data Parsing', () {
    test('_parseDouble handles various formats', () {
      expect(_parseDouble(123), 123.0);
      expect(_parseDouble(123.45), 123.45);
      expect(_parseDouble('123.45'), 123.45);
      expect(_parseDouble('123,45'), 123.45);
      expect(_parseDouble(' -10.5 '), -10.5);
      expect(_parseDouble(null), null);
      expect(_parseDouble(''), null);
      expect(_parseDouble('abc'), null);
    });

    test('_getStringFromRow finds string by case-insensitive key', () {
      final row = {'Buque': 'My Ship', 'MATRICULA': '12345'};
      expect(_getStringFromRow(row, 'buque'), 'My Ship');
      expect(_getStringFromRow(row, 'matricula'), '12345');
      expect(_getStringFromRow(row, 'nonexistent'), null);
    });

    test('_coordinateFromRow finds coordinate by case-insensitive key', () {
      final row = {'Latitud': '-42.5', '  longitud  ': '-65,5 '};
      expect(_coordinateFromRow(row, 'latitud'), -42.5);
      expect(_coordinateFromRow(row, 'longitud'), -65.5);
    });

    test('_dateFromRow parses various date formats', () {
      final utcDate = DateTime.utc(2023, 1, 1, 12);
      // Dart's DateTime.parse assumes UTC if Z is present, otherwise local.
      // Our function standardizes this by assuming UTC input if no TZ info.
      expect(
        _dateFromRow({'fechahora': '2023-10-26 14:30:00'}),
        DateTime(2023, 10, 26, 11, 30),
      );
      expect(_dateFromRow({'date': utcDate}), DateTime(2023, 1, 1, 9));
    });

    test('_latLngFromRow creates LatLng object', () {
      final row = {'latitud': -42.0, 'longitud': -65.0};
      expect(_latLngFromRow(row), const LatLng(-42.0, -65.0));
    });

    test('_extractMapPoints converts list of rows to MapPoints', () {
      final rows = [
        {
          'buque': 'Ship1',
          'latitud': -42.0,
          'longitud': -65.0,
          'velocidad': 5.0,
          'fechahora': '2023-10-26 10:00:00',
        },
        {
          'buque': 'Ship1',
          'latitud': -42.1,
          'longitud': -65.1,
          'velocidad': 0.0,
          'fechahora': '2023-10-26 11:00:00',
        },
      ];
      final points = _extractMapPoints(rows);
      expect(points.length, 2);
      expect(points[0].shipName, 'Ship1');
      expect(points[0].position, const LatLng(-42.0, -65.0));
      expect(points[0].speed, 5.0);
    });
  });

  group('Map Screen Logic - Trip Detection & Calculation', () {
    // Helper to generate points
    MapPoint createPoint(DateTime time, double speed) =>
        MapPoint(position: const LatLng(0, 0), timestamp: time, speed: speed);

    final t = DateTime.now();
    final pointsForTrip = [
      // In port
      for (int i = 0; i < 5; i++) createPoint(t.add(Duration(hours: i)), 0.0),
      // Departure (7 hours of movement to satisfy >= 5h duration)
      createPoint(t.add(const Duration(hours: 5)), 5.0),
      createPoint(t.add(const Duration(hours: 6)), 5.0),
      createPoint(t.add(const Duration(hours: 7)), 5.0),
      createPoint(t.add(const Duration(hours: 8)), 5.0),
      createPoint(t.add(const Duration(hours: 9)), 5.0),
      createPoint(t.add(const Duration(hours: 10)), 5.0),
      createPoint(t.add(const Duration(hours: 11)), 5.0),
      // Arrival
      createPoint(t.add(const Duration(hours: 12)), 0.0),
      createPoint(t.add(const Duration(hours: 13)), 0.0),
      createPoint(t.add(const Duration(hours: 14)), 0.0),
      createPoint(t.add(const Duration(hours: 15)), 0.0),
      createPoint(t.add(const Duration(hours: 16)), 0.0),
    ];

    test('_detectTripsMethod1 identifies a valid trip', () {
      final trips = _detectTripsMethod1(pointsForTrip);
      expect(trips.length, 1);
      expect(trips[0].startPoint.timestamp, t.add(const Duration(hours: 5)));
      expect(trips[0].endPoint.timestamp, t.add(const Duration(hours: 11)));
      expect(trips[0].durationInDays, 1);
    });

    test(
      '_detectTripsMethod2 identifies a valid trip with different thresholds',
      () {
        final pointsForMethod2 = [
          for (int i = 0; i < 5; i++)
            createPoint(t.add(Duration(hours: i)), 0.2), // speed < 0.5
          // Movement (> 5h)
          createPoint(t.add(const Duration(hours: 5)), 1.5),
          createPoint(t.add(const Duration(hours: 6)), 1.5),
          createPoint(t.add(const Duration(hours: 7)), 1.5),
          createPoint(t.add(const Duration(hours: 8)), 1.5),
          createPoint(t.add(const Duration(hours: 9)), 1.5),
          createPoint(t.add(const Duration(hours: 10)), 1.5),
          createPoint(t.add(const Duration(hours: 11)), 1.5),
          // Arrival
          createPoint(t.add(const Duration(hours: 12)), 0.2), // speed < 0.3
          for (int i = 1; i < 5; i++)
            createPoint(t.add(Duration(hours: 12 + i)), 0.1),
        ];
        final trips = _detectTripsMethod2(pointsForMethod2);
        expect(trips.length, 1);
        expect(trips[0].startPoint.timestamp, t.add(const Duration(hours: 5)));
        expect(trips[0].endPoint.timestamp, t.add(const Duration(hours: 11)));
      },
    );

    test('_detectTripsLegacy identifies a valid trip', () {
      final pointsForLegacy = [
        createPoint(t.add(Duration(hours: 0)), 0.0),
        createPoint(t.add(Duration(hours: 1)), 0.0),
        createPoint(t.add(Duration(hours: 2)), 0.0),
        createPoint(t.add(Duration(hours: 3)), 5.0),
        createPoint(t.add(Duration(hours: 4)), 5.0),
        createPoint(t.add(Duration(hours: 5)), 5.0),
        createPoint(t.add(Duration(hours: 6)), 0.0),
        createPoint(t.add(Duration(hours: 7)), 0.0),
        createPoint(t.add(Duration(hours: 8)), 0.0),
      ];
      final trips = _detectTripsLegacy(pointsForLegacy);
      expect(trips.length, 1);
      expect(trips[0].startPoint.timestamp, t.add(const Duration(hours: 3)));
      expect(trips[0].endPoint.timestamp, t.add(const Duration(hours: 6)));
    });

    test(
      '_Trip.durationInDays calculates correctly for single and multi-day trips',
      () {
        final start = DateTime(2023, 10, 26, 10, 00);
        final endSameDay = DateTime(2023, 10, 26, 18, 00);
        final endNextDay = DateTime(2023, 10, 27, 2, 00);
        final trip1 = _Trip(
          startPoint: MapPoint(position: const LatLng(0, 0), timestamp: start),
          endPoint: MapPoint(
            position: const LatLng(0, 0),
            timestamp: endSameDay,
          ),
          pathPoints: [],
          tripPoints: [],
        );
        final trip2 = _Trip(
          startPoint: MapPoint(position: const LatLng(0, 0), timestamp: start),
          endPoint: MapPoint(
            position: const LatLng(0, 0),
            timestamp: endNextDay,
          ),
          pathPoints: [],
          tripPoints: [],
        );

        expect(trip1.durationInDays, 1);
        expect(trip2.durationInDays, 2);
      },
    );

    test(
      '_calculateUniqueNavigatedDays works with overlapping and distinct trips',
      () {
        final t1 = _Trip(
          startPoint: MapPoint(
            position: LatLng(0, 0),
            timestamp: DateTime(2023, 1, 1),
          ),
          endPoint: MapPoint(
            position: LatLng(0, 0),
            timestamp: DateTime(2023, 1, 3),
          ),
          pathPoints: [],
          tripPoints: [],
        ); // 3 days
        final t2 = _Trip(
          startPoint: MapPoint(
            position: LatLng(0, 0),
            timestamp: DateTime(2023, 1, 3),
          ),
          endPoint: MapPoint(
            position: LatLng(0, 0),
            timestamp: DateTime(2023, 1, 5),
          ),
          pathPoints: [],
          tripPoints: [],
        ); // 3 days, 1 overlapping
        final t3 = _Trip(
          startPoint: MapPoint(
            position: LatLng(0, 0),
            timestamp: DateTime(2023, 1, 10),
          ),
          endPoint: MapPoint(
            position: LatLng(0, 0),
            timestamp: DateTime(2023, 1, 10),
          ),
          pathPoints: [],
          tripPoints: [],
        ); // 1 day

        expect(_calculateUniqueNavigatedDays([t1, t2, t3]), 6); // 1,2,3,4,5,10
      },
    );
  });
}
