import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_geojson/flutter_map_geojson.dart';

import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'geojson_service.g.dart';

@riverpod
Future<GeoJsonData> geoJsonService(Ref ref) async {
  // ref inferred or use explicit type if generated
  final service = GeoJsonService();
  return service.loadAllLayers();
}

class GeoJsonData {
  final List<Polygon> centollaPolygons;
  final List<Polyline> centollaPolylines;
  final List<Polygon> vieiraPolygons;
  final List<Polyline> vieiraPolylines;
  final List<Polygon> otherPolygons;
  final List<Polyline> otherPolylines;

  GeoJsonData({
    this.centollaPolygons = const [],
    this.centollaPolylines = const [],
    this.vieiraPolygons = const [],
    this.vieiraPolylines = const [],
    this.otherPolygons = const [],
    this.otherPolylines = const [],
  });

  // Backward compatibility getter if strictly needed, or just remove if unused
  List<Polygon> get allPolygons => [
    ...centollaPolygons,
    ...vieiraPolygons,
    ...otherPolygons,
  ];
  List<Polyline> get allPolylines => [
    ...centollaPolylines,
    ...vieiraPolylines,
    ...otherPolylines,
  ];
}

class GeoJsonService {
  Future<GeoJsonData> loadAllLayers() async {
    // Hardcoded list to avoid AssetManifest runtime issues
    final geoJsonFiles = [
      'area_centolla_C1.geojson',
      'area_centolla_C2.geojson',
      'area_centolla_C3.geojson',
      'area_centolla_C4.geojson',
      'area_centolla_C5.geojson',
      'area_centolla_S1.geojson',
      'area_centolla_S2.geojson',
      'area_centolla_S3.geojson',
      'area_centolla_S4.geojson',
      'areas_vieira.geojson',
      'mar_territorial.geojson',
      'zona_economica_exclusiva.geojson',
      'ZCP.geojson',
      'Veda 2014.geojson',
      'Veda Merluza Negra.geojson',
    ];

    final geoJsonPaths = geoJsonFiles.map((f) => 'assets/geojson/$f').toList();

    debugPrint('GeoJSON: Loading ${geoJsonPaths.length} hardcoded paths');

    List<Polygon> centollaPolygons = [];
    List<Polyline> centollaPolylines = [];
    List<Polygon> vieiraPolygons = [];
    List<Polyline> vieiraPolylines = [];
    List<Polygon> otherPolygons = [];
    List<Polyline> otherPolylines = [];

    for (final path in geoJsonPaths) {
      final fileName = path.split('/').last;

      // Determine color based on filename or random/seeded
      final color = _getColorForFile(fileName);

      try {
        final jsonString = await rootBundle.loadString(path);

        // Create parser with styling
        final parser = GeoJsonParser(
          defaultPolygonBorderColor: color.withValues(alpha: 0.8),
          defaultPolygonFillColor: color,
          defaultPolylineColor: color.withValues(alpha: 0.8),
          defaultPolylineStroke: 2.0,
        );

        // Parse
        // parser.parseGeoJsonAsString(jsonString);

        // Manual decode and sanitize to Ensure doubles
        final Map<String, dynamic> jsonMap = json.decode(jsonString);
        _sanitizeGeoJson(jsonMap);

        parser.parseGeoJson(jsonMap);

        if (fileName.contains('centolla')) {
          centollaPolygons.addAll(parser.polygons);
          centollaPolylines.addAll(parser.polylines);
        } else if (fileName.contains('vieira')) {
          vieiraPolygons.addAll(parser.polygons);
          vieiraPolylines.addAll(parser.polylines);
        } else {
          otherPolygons.addAll(parser.polygons);
          otherPolylines.addAll(parser.polylines);
        }

        debugPrint('GeoJSON: Processing $fileName with color $color');
        debugPrint('  - Polygons: ${parser.polygons.length}');
        debugPrint('  - Polylines: ${parser.polylines.length}');
        debugPrint('  - Markers: ${parser.markers.length}');

        if (parser.polylines.isNotEmpty) {
          debugPrint(
            '  - Sample Polyline Point: ${parser.polylines.first.points.first}',
          );
        }
      } catch (e) {
        debugPrint('GeoJSON: Error processing $fileName: $e');
      }
    }

    debugPrint(
      'GeoJSON: Total loaded - Centolla: ${centollaPolygons.length}, Vieira: ${vieiraPolygons.length}, Other: ${otherPolygons.length}',
    );

    return GeoJsonData(
      centollaPolygons: centollaPolygons,
      centollaPolylines: centollaPolylines,
      vieiraPolygons: vieiraPolygons,
      vieiraPolylines: vieiraPolylines,
      otherPolygons: otherPolygons,
      otherPolylines: otherPolylines,
    );
  }

  Color _getColorForFile(String fileName) {
    // Basic heuristics for color coding
    if (fileName.contains('Veda')) {
      return Colors.red.withValues(alpha: 0.3);
    }
    if (fileName.contains('centolla')) {
      return Colors.orange.withValues(alpha: 0.3);
    }
    if (fileName.contains('vieira')) {
      return Colors.purple.withValues(alpha: 0.3);
    }
    if (fileName.contains('area') || fileName.contains('ZCP')) {
      return Colors.green.withValues(alpha: 0.2); // areas_protegidas
    }
    if (fileName.contains('zona') || fileName.contains('mar')) {
      return Colors.blue.withValues(alpha: 0.1);
    }

    // Fallback random-ish based on hash
    final random = Random(fileName.hashCode);
    return Color.fromRGBO(
      random.nextInt(256),
      random.nextInt(256),
      random.nextInt(256),
      0.2, // Low opacity default
    );
  }

  void _sanitizeGeoJson(Map<String, dynamic> json) {
    if (json['type'] == 'FeatureCollection') {
      final features = json['features'] as List;
      for (final f in features) {
        _sanitizeFeature(f);
      }
    } else if (json['type'] == 'Feature') {
      _sanitizeFeature(json);
    } else {
      _sanitizeGeometry(json);
    }
  }

  void _sanitizeFeature(Map<String, dynamic> feature) {
    if (feature['geometry'] != null) {
      _sanitizeGeometry(feature['geometry']);
    }
  }

  void _sanitizeGeometry(Map<String, dynamic> geometry) {
    final coords = geometry['coordinates'];
    if (coords is List) {
      geometry['coordinates'] = _deepConvertToDouble(coords);
    }
  }

  List _deepConvertToDouble(List list) {
    return list.map((item) {
      if (item is List) {
        return _deepConvertToDouble(item);
      } else if (item is num) {
        return item.toDouble();
      }
      return item;
    }).toList();
  }
}
