import 'package:flutter/material.dart';

class CustomDateTimePicker extends StatefulWidget {
  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;
  final bool includeTime;

  const CustomDateTimePicker({
    super.key,
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
    this.includeTime = true,
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

  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _selectedHour, minute: _selectedMinute),
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            alwaysUse24HourFormat: true,
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
    if (picked == null) {
      return;
    }
    setState(() {
      _selectedHour = picked.hour;
      _selectedMinute = picked.minute;
    });
  }

  @override
  Widget build(BuildContext context) {
    final showTimePicker = widget.includeTime;
    final timeLabel = _formatTime(_selectedHour, _selectedMinute);
    final headerTitle =
        showTimePicker ? 'SELECCIONAR FECHA Y HORA' : 'SELECCIONAR FECHA';
    final headerValue = showTimePicker
        ? _formatFullDate(_selectedDate, _selectedHour, _selectedMinute)
        : _formatDateOnly(_selectedDate);

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
                        headerTitle,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[600],
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        headerValue,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.indigo,
                        ),
                      ),
                    ],
                  ),
                  if (showTimePicker) ...[
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: _selectTime,
                      icon: const Icon(Icons.access_time),
                      label: Text(timeLabel),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        textStyle: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        foregroundColor: Colors.indigo,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: CalendarDatePicker(
                initialDate: _selectedDate,
                firstDate: widget.firstDate,
                lastDate: widget.lastDate,
                onDateChanged: _onDateChanged,
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
                      final finalDateTime = showTimePicker
                          ? DateTime(
                              _selectedDate.year,
                              _selectedDate.month,
                              _selectedDate.day,
                              _selectedHour,
                              _selectedMinute,
                            )
                          : DateTime(
                              _selectedDate.year,
                              _selectedDate.month,
                              _selectedDate.day,
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

  String _formatFullDate(DateTime date, int hour, int minute) {
    final dateLabel = _formatDateOnly(date);
    final hourStr = hour.toString().padLeft(2, '0');
    final minStr = minute.toString().padLeft(2, '0');
    return "$dateLabel - $hourStr:$minStr";
  }

  String _formatDateOnly(DateTime date) {
    // We'll mimic: "Lun, 13 Oct"
    final days = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
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
    return "$dayStr, ${date.day} $monthStr";
  }

  String _formatTime(int hour, int minute) {
    final hourStr = hour.toString().padLeft(2, '0');
    final minStr = minute.toString().padLeft(2, '0');
    return "$hourStr:$minStr";
  }
}
