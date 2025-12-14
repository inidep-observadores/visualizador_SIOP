import 'dart:ui';
import 'package:flutter/material.dart';

class CustomDateTimePicker extends StatefulWidget {
  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;

  const CustomDateTimePicker({
    super.key,
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
  });

  @override
  State<CustomDateTimePicker> createState() => _CustomDateTimePickerState();
}

class _CustomDateTimePickerState extends State<CustomDateTimePicker> {
  late DateTime _selectedDate;
  late int _selectedHour;
  late int _selectedMinute;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate;
    _selectedHour = widget.initialDate.hour;
    _selectedMinute = widget.initialDate.minute;
  }

  void _onDateChanged(DateTime date) {
    setState(() {
      _selectedDate = date;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 650, maxHeight: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SELECCIONAR FECHA Y HORA',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[600],
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatFullDate(
                          _selectedDate,
                          _selectedHour,
                          _selectedMinute,
                        ),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.indigo,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Calendar Side
                  Flexible(
                    flex: 3,
                    child: CalendarDatePicker(
                      initialDate: _selectedDate,
                      firstDate: widget.firstDate,
                      lastDate: widget.lastDate,
                      onDateChanged: _onDateChanged,
                    ),
                  ),
                  // Divider
                  Container(width: 1, color: Colors.grey[200]),
                  // Time Side
                  Flexible(
                    flex: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            "HORA",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildTimeSpinner(
                                value: _selectedHour,
                                itemCount: 24,
                                onChanged: (val) =>
                                    setState(() => _selectedHour = val),
                              ),
                              const Text(
                                ":",
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black45,
                                ),
                              ),
                              _buildTimeSpinner(
                                value: _selectedMinute,
                                itemCount: 60,
                                onChanged: (val) =>
                                    setState(() => _selectedMinute = val),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Actions
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('CANCELAR'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () {
                      final finalDateTime = DateTime(
                        _selectedDate.year,
                        _selectedDate.month,
                        _selectedDate.day,
                        _selectedHour,
                        _selectedMinute,
                      );
                      Navigator.of(context).pop(finalDateTime);
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.indigo,
                    ),
                    child: const Text('ACEPTAR'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeSpinner({
    required int value,
    required int itemCount,
    required ValueChanged<int> onChanged,
  }) {
    return SizedBox(
      height: 120,
      width: 70,
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(
          dragDevices: {PointerDeviceKind.touch, PointerDeviceKind.mouse},
        ),
        child: ListWheelScrollView.useDelegate(
          itemExtent: 40,
          perspective: 0.005,
          diameterRatio: 1.2,
          physics: const FixedExtentScrollPhysics(),
          controller: FixedExtentScrollController(initialItem: value),
          onSelectedItemChanged: onChanged,
          childDelegate: ListWheelChildBuilderDelegate(
            childCount: itemCount,
            builder: (context, index) {
              final isSelected = index == value;
              return Center(
                child: Text(
                  index.toString().padLeft(2, '0'),
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w400,
                    color: isSelected ? Colors.indigo : Colors.grey[400],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  String _formatFullDate(DateTime date, int hour, int minute) {
    // Simple basic formatting
    // You can use DateFormat from intl package if available, keeping it simple dependent-less if possible or reuse existing
    // Assuming intl is available as we used it in main code

    // We'll mimic: "Lun, 13 Oct - 14:30"
    final days = ['Lun', 'Mar', 'Mié', 'Vue', 'Vie', 'Sáb', 'Dom'];
    final months = [
      'Ene',
      'Feb',
      'Mar',
      'Abr',
      'May',
      'Jun',
      'Jul',
      'Ago',
      'Sep',
      'Oct',
      'Nov',
      'Dic',
    ];

    final dayStr = days[date.weekday - 1];
    final monthStr = months[date.month - 1];

    final hourStr = hour.toString().padLeft(2, '0');
    final minStr = minute.toString().padLeft(2, '0');

    return "$dayStr, ${date.day} $monthStr - $hourStr:$minStr";
  }
}
