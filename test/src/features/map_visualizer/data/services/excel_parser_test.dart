import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:visualizador_siop/src/features/map_visualizer/data/services/excel_parser.dart';

void main() {
  group('ExcelParser - CSV Parsing', () {
    test('parseCsvBytes correctly parses a standard CSV', () {
      final csvContent = '''
Buque,Matricula,Fecha,Latitud,Longitud,Velocidad,Rumbo
BARCO TEST,1234,12/7/2025 00:08:57,-38.1234,-57.5678,10.5,180
''';
      final bytes = utf8.encode(csvContent);

      final result = parseCsvBytes(bytes);

      expect(result.length, 1);
      expect(result.first['Buque'], 'BARCO TEST');
      expect(
        result.first['Matricula'],
        1234,
      ); // csv parser might auto-detect types
      expect(result.first['Fecha'], isA<DateTime>());
      expect(result.first['Latitud'], -38.1234);
      expect(result.first['Longitud'], -57.5678);
    });

    test('parseCsvBytes handles semicolon delimiter', () {
      final csvContent = '''
Buque;Matricula;Fecha;Latitud;Longitud;Velocidad;Rumbo
BARCO TEST;1234;12/7/2025 00:08:57;-38.1234;-57.5678;10.5;180
''';
      final bytes = utf8.encode(csvContent);

      final result = parseCsvBytes(bytes);

      expect(result.length, 1);
      expect(result.first['Buque'], 'BARCO TEST');
    });

    test('parseCsvBytes handles UTC-16 LE with BOM', () {
      // Small sample of UTF-16 LE with BOM
      final header = 'Buque,Matricula\n';
      final data = 'TEST,123\n';
      final content = header + data;

      final List<int> bytes = [0xFF, 0xFE]; // BOM
      for (final charCode in content.codeUnits) {
        bytes.add(charCode & 0xFF);
        bytes.add((charCode >> 8) & 0xFF);
      }

      final result = parseCsvBytes(bytes);
      expect(result.length, 1);
      expect(result.first['Buque'], 'TEST');
    });

    test('parseCsvBytes skips empty rows', () {
      final csvContent = '''
Buque,Matricula,Fecha,Latitud,Longitud,Velocidad,Rumbo
BARCO TEST,1234,12/7/2025 00:08:57,-38.1234,-57.5678,10.5,180
,,,,,,
''';
      final bytes = utf8.encode(csvContent);

      final result = parseCsvBytes(bytes);

      expect(result.length, 1);
    });

    test('getUniqueVessels extracts unique vessel and matricula pairs', () {
      final data = [
        {'buque': 'BARCO A', 'matricula': '111', 'otro': 'data'},
        {'buque': 'BARCO A', 'matricula': '111', 'otro': 'more'},
        {'buque': 'BARCO B', 'matricula': '222', 'otro': 'data'},
        {
          'buque': 'barco a',
          'matricula': '111',
          'otro': 'case',
        }, // case insensitive
        {'buque': 'BARCO A', 'matricula': '333', 'otro': 'different mat'},
      ];

      final vessels = DataFileParser.getUniqueVessels(data);

      expect(vessels.length, 3);
      expect(vessels[0]['nombre'], 'BARCO A');
      expect(vessels[0]['matricula'], '111');
      expect(vessels[1]['nombre'], 'BARCO B');
      expect(vessels[1]['matricula'], '222');
      expect(vessels[2]['nombre'], 'BARCO A');
      expect(vessels[2]['matricula'], '333');
    });

    test('parseCsvBytes handles multiple vessels in same file', () {
      final csvContent = '''
Buque,Matricula,Fecha,Latitud,Longitud,Velocidad,Rumbo
BARCO A,111,12/7/2025 00:08:57,-38.1,-57.1,10.0,180
BARCO B,222,12/7/2025 00:10:00,-38.2,-57.2,11.0,190
BARCO A,111,12/7/2025 00:12:00,-38.3,-57.3,10.0,180
''';
      final bytes = utf8.encode(csvContent);

      final result = parseCsvBytes(bytes);

      expect(result.length, 3);
      expect(result[0]['Buque'], 'BARCO A');
      expect(result[1]['Buque'], 'BARCO B');
      expect(result[2]['Buque'], 'BARCO A');

      final vessels = DataFileParser.getUniqueVessels(result);
      expect(vessels.length, 2);
      expect(vessels.any((v) => v['nombre'] == 'BARCO A'), true);
      expect(vessels.any((v) => v['nombre'] == 'BARCO B'), true);
    });
  });
}
