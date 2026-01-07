import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:visualizador_siop/src/features/map_visualizer/data/repositories/vessel_repository.dart';
import 'package:visualizador_siop/src/features/map_visualizer/data/services/excel_parser.dart';
import 'package:visualizador_siop/src/features/map_visualizer/domain/vessel.dart';
import 'package:visualizador_siop/src/features/map_visualizer/domain/vessel_position.dart';

part 'providers.g.dart';

@Riverpod(keepAlive: true)
VesselRepository vesselRepository(Ref ref) {
  return VesselRepository();
}

@Riverpod(keepAlive: true)
class ExcelData extends _$ExcelData {
  @override
  Future<List<Map<String, dynamic>>?> build() async {
    return null;
  }

  Future<void> loadFromFile(String path) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => DataFileParser.parseFile(path));
  }

  Future<void> saveCurrentToDb() async {
    final data = state.value;
    if (data == null || data.isEmpty) return;

    final repo = ref.read(vesselRepositoryProvider);

    try {
      debugPrint(
        'ExcelData: Iniciando guardado de ${data.length} posiciones...',
      );

      final firstRow = data.first;
      final nombre = _getStringFromRow(firstRow, 'buque') ?? 'Desconocido';
      final matricula = _getStringFromRow(firstRow, 'matricula') ?? 'S/N';

      debugPrint('ExcelData: Buque: $nombre, Mat: $matricula');

      final vessel = await repo.getOrCreateVessel(nombre, matricula);
      debugPrint('ExcelData: Vessel ID obtenido/creado: ${vessel.id}');

      final positions = data
          .map((row) {
            DateTime? fecha;
            final rawFecha = _getRawValueFromRow(row, 'fecha');

            if (rawFecha is DateTime) {
              fecha = rawFecha;
            } else if (rawFecha != null) {
              fecha = DateTime.tryParse(rawFecha.toString());
            }

            final lat = _parseDouble(_getRawValueFromRow(row, 'latitud'));
            final lon = _parseDouble(_getRawValueFromRow(row, 'longitud'));

            if (fecha == null || lat == null || lon == null) return null;

            return VesselPosition(
              buqueId: vessel.id!,
              fecha: fecha,
              latitud: lat,
              longitud: lon,
              velocidad: _parseDouble(_getRawValueFromRow(row, 'velocidad')),
              rumbo: _parseDouble(_getRawValueFromRow(row, 'rumbo')),
            );
          })
          .whereType<VesselPosition>()
          .toList();

      debugPrint(
        'ExcelData: Mapeadas ${positions.length} posiciones. Insertando...',
      );
      await repo.insertPositions(positions);
      debugPrint('ExcelData: Guardado exitoso.');

      ref.invalidate(dbVesselsProvider);
    } catch (e, stack) {
      debugPrint('ExcelData ERROR al guardar: $e');
      debugPrint(stack.toString());
      rethrow;
    }
  }

  Future<void> loadFromDb(int vesselId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(vesselRepositoryProvider);
      final positions = await repo.getVesselPositions(vesselId);
      final vessels = await repo.getAllVessels();
      final vessel = vessels.firstWhere((v) => v.id == vesselId);

      return positions
          .map(
            (p) => {
              'Buque': vessel.nombre,
              'Matricula': vessel.matricula,
              'Fecha': p.fecha,
              'Latitud': p.latitud,
              'Longitud': p.longitud,
              'Velocidad': p.velocidad,
              'Rumbo': p.rumbo,
            },
          )
          .toList();
    });
  }

  Object? _getRawValueFromRow(Map<String, dynamic> row, String columnName) {
    final normalizedTarget = columnName.trim().toLowerCase();
    final matchedKey = row.keys.firstWhere(
      (key) => key.trim().toLowerCase() == normalizedTarget,
      orElse: () => '',
    );
    if (matchedKey.isEmpty) return null;
    return row[matchedKey];
  }

  String? _getStringFromRow(Map<String, dynamic> row, String columnName) {
    final val = _getRawValueFromRow(row, columnName);
    return val?.toString().trim();
  }

  double? _parseDouble(dynamic val) {
    if (val == null) return null;
    if (val is num) return val.toDouble();
    if (val is String) {
      return double.tryParse(val.replaceAll(',', '.'));
    }
    return null;
  }
}

@Riverpod(keepAlive: true)
Future<List<Vessel>> dbVessels(Ref ref) {
  return ref.watch(vesselRepositoryProvider).getAllVessels();
}
