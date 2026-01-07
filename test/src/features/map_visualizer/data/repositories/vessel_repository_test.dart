import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sqflite/sqflite.dart';
import 'package:visualizador_siop/src/features/map_visualizer/data/repositories/vessel_repository.dart';
import 'package:visualizador_siop/src/features/map_visualizer/domain/vessel.dart';
import 'package:visualizador_siop/src/features/map_visualizer/domain/vessel_position.dart';

class MockDatabase extends Mock implements Database {}

class MockBatch extends Mock implements Batch {}

void main() {
  late VesselRepository repository;
  late MockDatabase mockDb;
  late MockBatch mockBatch;

  setUp(() {
    mockDb = MockDatabase();
    mockBatch = MockBatch();
    repository = VesselRepository(database: mockDb);

    // Default setup for batch
    when(() => mockDb.batch()).thenReturn(mockBatch);
    when(
      () => mockBatch.commit(noResult: any(named: 'noResult')),
    ).thenAnswer((_) async => []);
  });

  group('VesselRepository', () {
    test('getOrCreateVessel returns existing vessel if found', () async {
      final existingVesselMap = {
        'id': 1,
        'nombre': 'BARCO EXISTENTE',
        'matricula': '1234',
      };

      when(
        () => mockDb.query(
          'buques',
          where: any(named: 'where'),
          whereArgs: any(named: 'whereArgs'),
        ),
      ).thenAnswer((_) async => [existingVesselMap]);

      final result = await repository.getOrCreateVessel(
        'BARCO EXISTENTE',
        '1234',
      );

      expect(result.id, 1);
      expect(result.nombre, 'BARCO EXISTENTE');
      expect(result.matricula, '1234');

      verify(
        () =>
            mockDb.query('buques', where: 'matricula = ?', whereArgs: ['1234']),
      ).called(1);
    });

    test('getOrCreateVessel creates new vessel if not found', () async {
      when(
        () => mockDb.query(
          'buques',
          where: any(named: 'where'),
          whereArgs: any(named: 'whereArgs'),
        ),
      ).thenAnswer((_) async => []);

      when(() => mockDb.insert('buques', any())).thenAnswer((_) async => 2);

      final result = await repository.getOrCreateVessel('NUEVO BARCO', '5678');

      expect(result.id, 2);
      expect(result.nombre, 'NUEVO BARCO');
      expect(result.matricula, '5678');

      verify(() => mockDb.insert('buques', any())).called(1);
    });

    test('insertPositions uses batch and commit', () async {
      final positions = [
        VesselPosition(
          buqueId: 1,
          fecha: DateTime.now(),
          latitud: -38.0,
          longitud: -57.0,
        ),
      ];

      await repository.insertPositions(positions);

      verify(() => mockDb.batch()).called(1);
      verify(
        () => mockBatch.insert(
          'posiciones',
          any(),
          conflictAlgorithm: ConflictAlgorithm.ignore,
        ),
      ).called(1);
      verify(() => mockBatch.commit(noResult: true)).called(1);
    });

    test('getAllVessels returns list of vessels', () async {
      final vesselMaps = [
        {'id': 1, 'nombre': 'BARCO A', 'matricula': 'AAA'},
        {'id': 2, 'nombre': 'BARCO B', 'matricula': 'BBB'},
      ];

      when(
        () => mockDb.query('buques', orderBy: any(named: 'orderBy')),
      ).thenAnswer((_) async => vesselMaps);

      final result = await repository.getAllVessels();

      expect(result.length, 2);
      expect(result[0].nombre, 'BARCO A');
      expect(result[1].nombre, 'BARCO B');
    });
  });
}
