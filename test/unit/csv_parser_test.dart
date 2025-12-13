import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:siop_data_visualizer/src/features/map_visualizer/data/services/excel_parser.dart';

void main() {
  group('CSV Parser Tests', () {
    test('detects comma delimiter', () {
      final csvContent = 'Header1,Header2\nValue1,Value2';
      final bytes = utf8.encode(csvContent);
      final result = parseCsvBytes(bytes);

      expect(result.length, 1);
      expect(result.first['Header1'], 'Value1');
      expect(result.first['Header2'], 'Value2');
    });

    test('detects semicolon delimiter', () {
      final csvContent = 'Header1;Header2\nValue1;Value2';
      final bytes = utf8.encode(csvContent);
      final result = parseCsvBytes(bytes);

      expect(result.length, 1);
      expect(result.first['Header1'], 'Value1');
      expect(result.first['Header2'], 'Value2');
    });

    test('handles mixed delimiters preferring semicolon if more frequent', () {
      // Scenario where a value might contain a comma, but delimiter is semicolon
      final csvContent = 'Header1;Header2\nValue1,Part2;Value2';
      final bytes = utf8.encode(csvContent);
      final result = parseCsvBytes(bytes);

      expect(result.length, 1);
      expect(result.first['Header1'], 'Value1,Part2');
      expect(result.first['Header2'], 'Value2');
    });
  });
}
