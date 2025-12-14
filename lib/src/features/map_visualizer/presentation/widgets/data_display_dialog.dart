import 'package:flutter/material.dart';

class DataDisplayDialog extends StatelessWidget {
  final List<Map<String, dynamic>> data;

  const DataDisplayDialog({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const AlertDialog(
        title: Text('Datos Cargados'),
        content: Text('No se encontró información para mostrar.'),
      );
    }

    // Extract headers from the first row
    final headers = data.first.keys.toList();

    return AlertDialog(
      title: const Text('Datos Cargados'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: DataTable(
            columns: headers.map((header) => DataColumn(label: Text(header))).toList(),
            rows: data.map((row) {
              return DataRow(
                cells: headers.map((header) {
                  final value = row[header];
                  return DataCell(Text(value?.toString() ?? 'N/A'));
                }).toList(),
              );
            }).toList(),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }
}
