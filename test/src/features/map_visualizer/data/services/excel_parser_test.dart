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
  });
}
