import 'package:excel/excel.dart';
import 'package:flutter/services.dart' show ByteData, rootBundle;
import 'package:intl/intl.dart';

class ExcelParser {
  Future<void> parseDemoData() async {
    try {
      ByteData data = await rootBundle.load("docs/demo.xlsx");
      var bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      var excel = Excel.decodeBytes(bytes);

      print('Excel file loaded successfully.');

      for (var table in excel.tables.keys) {
        print('Table: $table');
        var sheet = excel.tables[table]!;
        
        if (sheet.maxRows <= 1) {
          print('Sheet is empty or has only a header row.');
          continue;
        }

        // Assuming the first row is the header
        var header = sheet.row(0).map((cell) => cell?.value?.toString() ?? '').toList();
        print('Header: $header');

        // Parse the first 5 data rows for testing
        for (var i = 1; i < sheet.maxRows && i < 6; i++) {
          var row = sheet.row(i);
          var rowData = <String, dynamic>{};
          for (var j = 0; j < header.length; j++) {
            var key = header[j];
            var cell = (row.length > j) ? row[j] : null;
            dynamic value = cell?.value;

            if (key == 'FECHA Y HORA' && value is String) {
              try {
                // Handle dates that might be just '0'
                if(value == '0') {
                    rowData[key] = null;
                } else {
                    // Attempt to parse with the specific format
                    rowData[key] = DateFormat("d/M/yyyy HH:mm:ss").parse(value);
                }
              } catch (e) {
                print('Could not parse date: $value. Error: $e');
                rowData[key] = value; // Keep original string if parsing fails
              }
            } else {
              rowData[key] = value;
            }
          }
          print('Row $i: $rowData');
        }
        break; // Only processing the first sheet for this test
      }
    } catch (e) {
      print('Error parsing Excel file: $e');
    }
  }
}
