import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:visualizador_siop/src/features/map_visualizer/data/services/database_helper.dart';
import 'package:visualizador_siop/src/features/map_visualizer/domain/vessel.dart';
import 'package:visualizador_siop/src/features/map_visualizer/domain/vessel_position.dart';

class VesselRepository {
  final _dbHelper = DatabaseHelper();

  Future<Database> get _db => _dbHelper.database;

  /// Gets a vessel by matricula or creates it if it doesn't exist.
  Future<Vessel> getOrCreateVessel(String nombre, String matricula) async {
    final db = await _db;
    final List<Map<String, dynamic>> maps = await db.query(
      'buques',
      where: 'matricula = ?',
      whereArgs: [matricula],
    );

    if (maps.isNotEmpty) {
      return Vessel.fromMap(maps.first);
    } else {
      final vessel = Vessel(nombre: nombre, matricula: matricula);
      final id = await db.insert('buques', vessel.toMap());
      return vessel.copyWith(id: id);
    }
  }

  /// Inserts a list of positions using a batch for efficiency.
  /// Uses INSERT OR IGNORE to avoid duplicates based on (buque_id, fecha).
  Future<void> insertPositions(List<VesselPosition> positions) async {
    if (positions.isEmpty) return;

    final db = await _db;
    final batch = db.batch();

    for (final pos in positions) {
      batch.insert(
        'posiciones',
        pos.toMap(),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }

    await batch.commit(noResult: true);
  }

  /// Searches vessels by name for autocomplete.
  Future<List<Vessel>> searchVessels(String query) async {
    if (query.isEmpty) return [];

    final db = await _db;
    final List<Map<String, dynamic>> maps = await db.query(
      'buques',
      where: 'nombre LIKE ?',
      whereArgs: ['%$query%'],
      limit: 20,
    );

    return List.generate(maps.length, (i) => Vessel.fromMap(maps[i]));
  }

  /// Retrieves all vessels in the DB.
  Future<List<Vessel>> getAllVessels() async {
    try {
      final db = await _db;
      final List<Map<String, dynamic>> maps = await db.query(
        'buques',
        orderBy: 'nombre ASC',
      );
      return List.generate(maps.length, (i) => Vessel.fromMap(maps[i]));
    } catch (e) {
      debugPrint('VesselRepository ERROR en getAllVessels: $e');
      rethrow;
    }
  }

  /// Gets all positions for a specific vessel, ordered chronologically.
  Future<List<VesselPosition>> getVesselPositions(int buqueId) async {
    final db = await _db;
    final List<Map<String, dynamic>> maps = await db.query(
      'posiciones',
      where: 'buque_id = ?',
      whereArgs: [buqueId],
      orderBy: 'fecha ASC',
    );

    return List.generate(maps.length, (i) => VesselPosition.fromMap(maps[i]));
  }
}
