import 'dart:io';
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

  final header = sheet.row(0).map((cell) => cell?.value?.toString().trim() ?? '').toList();

  for (var i = 1; i < sheet.maxRows; i++) {
    final row = sheet.row(i);
    final rowData = <String, dynamic>{};
    for (var j = 0; j < header.length; j++) {
      final key = header[j];
      if (key.isEmpty) continue;

      final cell = (row.length > j) ? row[j] : null;
      dynamic value = cell?.value;

      if (key == 'FECHA Y HORA' && value != null) {
        if (value is String) {
          if (value == '0') {
            rowData[key] = null;
          } else {
            try {
              // The format from the user is "12/7/2025 00:08:57"
              rowData[key] = DateFormat("d/M/yyyy HH:mm:ss").parse(value);
            } catch (e) {
              // Keep original string if parsing fails
              rowData[key] = value;
            }
          }
        } else if (value is double || value is int) {
          // Handle numeric dates from Excel.
          // Excel's epoch starts on 1899-12-30.
          final excelEpoch = DateTime(1899, 12, 30);
          final duration = Duration(days: (value as num).toInt());
          rowData[key] = excelEpoch.add(duration);
        } else {
          rowData[key] = value;
        }
      } else {
        rowData[key] = value;
      }
    }
    // Only add row if it contains any data
    if (rowData.values.any((v) => v != null && v.toString().isNotEmpty)) {
      dataList.add(rowData);
    }
  }
  return dataList;
}


/// A utility class for parsing Excel files containing vessel track data.
class ExcelParser {
  // This is a utility class, no need to instantiate it.
  ExcelParser._();

  /// Parses the demo Excel file included in the app assets.
  static Future<List<Map<String, dynamic>>> parseDemoData() async {
    final byteData = await rootBundle.load("docs/demo.xls");
    final bytes = byteData.buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes);
    return compute(parseExcelBytes, bytes);
  }

  /// Parses an Excel file from a given file system [path].
  static Future<List<Map<String, dynamic>>> parseFile(String path) async {
    final bytes = await File(path).readAsBytes();
    return compute(parseExcelBytes, bytes);
  }
}

