import 'dart:convert';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';

// This function will be run in a separate isolate to prevent UI blockage.
List<Map<String, dynamic>> parseExcelBytes(List<int> bytes) {
  final excel = Excel.decodeBytes(bytes);
  final List<Map<String, dynamic>> dataList = [];

  if (excel.tables.keys.isEmpty) return dataList;

  final sheet = excel.tables[excel.tables.keys.first]!;

  if (sheet.maxRows <= 1) {
    return dataList;
  }

  // Helper to safely get string value
  String getCellValue(Data? cell) {
    return cell?.value?.toString().trim() ?? '';
  }

  final header = sheet.row(0).map((cell) => getCellValue(cell)).toList();

  for (var i = 1; i < sheet.maxRows; i++) {
    final row = sheet.row(i);
    final rowData = <String, dynamic>{};
    for (var j = 0; j < header.length; j++) {
      final key = header[j];
      if (key.isEmpty) continue;

      final cell = (row.length > j) ? row[j] : null;
      dynamic value = cell?.value;

      // Normalize value for shared parsing
      // Excel might give us double, int, SharedString, or DateTime (if cell type is date)
      // But the library usually returns value as is.
      // Shared logic expects basic types.

      _parseCellData(rowData, key, value);
    }
    // Only add row if it contains any data
    if (rowData.values.any((v) => v != null && v.toString().isNotEmpty)) {
      dataList.add(rowData);
    }
  }
  return dataList;
}

List<Map<String, dynamic>> parseCsvBytes(List<int> bytes) {
  // Decode bytes to string, checking for BOM
  String content;
  if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE) {
    // UTF-16 LE
    final payload = bytes.sublist(2);
    final buffer = StringBuffer();
    for (var i = 0; i < payload.length; i += 2) {
      if (i + 1 < payload.length) {
        final charCode = payload[i] | (payload[i + 1] << 8);
        buffer.writeCharCode(charCode);
      }
    }
    content = buffer.toString();
  } else {
    // Fallback to UTF-8
    content = utf8.decode(bytes, allowMalformed: true);
  }

  // Normalize EOL to \n to ensure parser works consistently
  content = content.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

  // Detect delimiter
  String fieldDelimiter = ',';
  if (content.isNotEmpty) {
    final firstLine = content.split('\n').first;
    if (firstLine.contains(';') && !firstLine.contains(',')) {
      fieldDelimiter = ';';
    } else if (firstLine.split(';').length > firstLine.split(',').length) {
      // More semicolons than commas, likely semicolon separated
      fieldDelimiter = ';';
    }
  }

  // Parse CSV
  final List<List<dynamic>> rows = const CsvToListConverter().convert(
    content,
    eol: '\n',
    fieldDelimiter: fieldDelimiter,
  );

  final List<Map<String, dynamic>> dataList = [];
  if (rows.isEmpty) return dataList;

  final header = rows.first.map((e) => e.toString().trim()).toList();

  for (var i = 1; i < rows.length; i++) {
    final row = rows[i];
    final rowData = <String, dynamic>{};
    for (var j = 0; j < header.length; j++) {
      final key = header[j];
      if (key.isEmpty) continue;

      final dynamic value = (row.length > j) ? row[j] : null;
      _parseCellData(rowData, key, value);
    }
    // Only add row if it contains any data
    if (rowData.values.any((v) => v != null && v.toString().isNotEmpty)) {
      dataList.add(rowData);
    }
  }
  return dataList;
}

void _parseCellData(Map<String, dynamic> rowData, String key, dynamic value) {
  if (key == 'FECHA Y HORA' && value != null) {
    if (value is String) {
      if (value == '0') {
        rowData[key] = null;
      } else {
        try {
          // The format from the user is "12/7/2025 00:08:57"
          // Also handle slight variations if needed, but strict is safer for now.
          // Use explicit pattern to match existing logic
          rowData[key] = DateFormat("d/M/yyyy HH:mm:ss").parse(value);
        } catch (e) {
          // Fallback: try standard ISO or other common formats if needed
          // For now, keep original behavior:
          rowData[key] = value;
        }
      }
    } else if (value is double || value is int) {
      // Handle numeric dates from Excel.
      // Excel's epoch starts on 1899-12-30.
      final excelEpoch = DateTime(1899, 12, 30);
      final duration = Duration(days: (value as num).toInt());
      // Add fractional day for time?
      // The 'value' from excel might be integer for date only, or double for date+time.
      // (value as num).toDouble() gives days.
      final double valDouble = (value as num).toDouble();
      final int days = valDouble.floor();
      final double fraction = valDouble - days;
      final int milliseconds = (fraction * 24 * 60 * 60 * 1000).round();

      rowData[key] = excelEpoch.add(
        Duration(days: days, milliseconds: milliseconds),
      );
    } else {
      rowData[key] = value;
    }
  } else {
    rowData[key] = value;
  }
}

/// A utility class for parsing Excel files containing vessel track data.
class DataFileParser {
  // This is a utility class, no need to instantiate it.
  DataFileParser._();

  /// Parses the demo Excel file included in the app assets.
  static Future<List<Map<String, dynamic>>> parseDemoData() async {
    final byteData = await rootBundle.load("docs/demo.xls");
    final bytes = byteData.buffer.asUint8List(
      byteData.offsetInBytes,
      byteData.lengthInBytes,
    );
    return compute(parseExcelBytes, bytes);
  }

  /// Parses an Excel file from a given file system [path].
  static Future<List<Map<String, dynamic>>> parseFile(String path) async {
    final file = File(path);
    final bytes = await file.readAsBytes();
    final extension = path.toLowerCase().split('.').last;

    if (extension == 'csv') {
      return compute(parseCsvBytes, bytes);
    } else {
      // Default to Excel
      return compute(parseExcelBytes, bytes);
    }
  }
}
