import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;

    // Prevent race conditions during initialization
    return await _initDatabase();
  }

  static Future<Database>? _initFuture;

  Future<Database> _initDatabase() async {
    if (_initFuture != null) return _initFuture!;

    _initFuture = _doInitDatabase();
    return _initFuture!;
  }

  Future<Database> _doInitDatabase() async {
    try {
      final Directory appDir = await getApplicationSupportDirectory();
      final String dbPath = join(appDir.path, 'databases');

      // Ensure parent directory exists
      await Directory(dbPath).create(recursive: true);

      final path = join(dbPath, 'vessel_visualizer.db');

      _database = await openDatabase(path, version: 1, onCreate: _onCreate);
      return _database!;
    } catch (e) {
      debugPrint('DatabaseHelper ERROR: $e');
      _initFuture = null; // Allow retry on error
      rethrow;
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    debugPrint('DatabaseHelper: Creando tablas...');
    // Table: buques
    await db.execute('''
      CREATE TABLE buques (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT NOT NULL,
        matricula TEXT NOT NULL UNIQUE
      )
    ''');

    // Table: posiciones
    await db.execute('''
      CREATE TABLE posiciones (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        buque_id INTEGER NOT NULL,
        fecha TEXT NOT NULL,
        latitud REAL NOT NULL,
        longitud REAL NOT NULL,
        velocidad REAL,
        rumbo REAL,
        FOREIGN KEY (buque_id) REFERENCES buques (id) ON DELETE CASCADE,
        UNIQUE(buque_id, fecha)
      )
    ''');

    // Index for faster queries on a specific vessel's track
    await db.execute(
      'CREATE INDEX idx_posiciones_buque_fecha ON posiciones (buque_id, fecha)',
    );
    debugPrint('DatabaseHelper: Tablas creadas correctamente');
  }
}
