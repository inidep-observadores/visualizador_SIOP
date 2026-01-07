import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CustomDateRangePicker extends StatefulWidget {
  final DateTime initialStartDate;
  final DateTime initialEndDate;
  final DateTime firstDate;
  final DateTime lastDate;

  const CustomDateRangePicker({
    super.key,
    required this.initialStartDate,
    required this.initialEndDate,
    required this.firstDate,
    required this.lastDate,
  });

  @override
  State<CustomDateRangePicker> createState() => _CustomDateRangePickerState();
}

class _CustomDateRangePickerState extends State<CustomDateRangePicker> {
  late DateTime _startDate;
  late DateTime _endDate;
  late DateTime _startDisplayedMonth;
  late DateTime _endDisplayedMonth;

  @override
  void initState() {
    super.initState();
    _startDate = _clampDate(widget.initialStartDate);
    _endDate = _clampDate(widget.initialEndDate);
    if (_endDate.isBefore(_startDate)) {
      _endDate = _startDate;
    }
    _startDisplayedMonth = _monthOnly(_startDate);
    _endDisplayedMonth = _monthOnly(_endDate);
  }

  DateTime _clampDate(DateTime date) {
    if (date.isBefore(widget.firstDate)) return widget.firstDate;
    if (date.isAfter(widget.lastDate)) return widget.lastDate;
    return date;
  }

  DateTime _monthOnly(DateTime date) {
    return DateTime(date.year, date.month);
  }

  int _compareMonth(DateTime a, DateTime b) {
    if (a.year != b.year) return a.year.compareTo(b.year);
    return a.month.compareTo(b.month);
  }

  DateTime _shiftDateToMonth(DateTime date, DateTime month) {
    final daysInMonth = DateUtils.getDaysInMonth(month.year, month.month);
    final day = date.day > daysInMonth ? daysInMonth : date.day;
    return DateTime(month.year, month.month, day);
  }

  void _syncStartToMonth(DateTime month) {
    _startDate = _clampDate(_shiftDateToMonth(_startDate, month));
    if (_startDate.isAfter(_endDate)) {
      _startDate = _endDate;
    }
    _startDisplayedMonth = _monthOnly(_startDate);
  }

  void _syncEndToMonth(DateTime month) {
    _endDate = _clampDate(_shiftDateToMonth(_endDate, month));
    if (_endDate.isBefore(_startDate)) {
      _endDate = _startDate;
    }
    _endDisplayedMonth = _monthOnly(_endDate);
  }

  void _onStartDateChanged(DateTime date) {
    setState(() {
      _startDate = _clampDate(date);
      _startDisplayedMonth = _monthOnly(_startDate);
      if (_endDate.isBefore(_startDate)) {
        _endDate = _startDate;
        _endDisplayedMonth = _monthOnly(_endDate);
      }
    });
  }

  void _onEndDateChanged(DateTime date) {
    setState(() {
      _endDate = _clampDate(date);
      _endDisplayedMonth = _monthOnly(_endDate);
      if (_startDate.isAfter(_endDate)) {
        _startDate = _endDate;
        _startDisplayedMonth = _monthOnly(_startDate);
      }
    });
  }

  void _onStartDisplayedMonthChanged(DateTime month) {
    final normalized = _monthOnly(month);
    setState(() {
      _startDisplayedMonth = normalized;
      if (_compareMonth(_startDisplayedMonth, _endDisplayedMonth) > 0) {
        _syncEndToMonth(normalized);
      }
    });
  }

  void _onEndDisplayedMonthChanged(DateTime month) {
    final normalized = _monthOnly(month);
    setState(() {
      _endDisplayedMonth = normalized;
      if (_compareMonth(_endDisplayedMonth, _startDisplayedMonth) < 0) {
        _syncStartToMonth(normalized);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final rangeLabel =
        '${_formatDate(_startDate)} - ${_formatDate(_endDate)}';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 520),
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
                        'SELECCIONAR PERIODO',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[600],
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        rangeLabel,
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
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildCalendar(
                        label: 'Inicio',
                        selectedDate: _startDate,
                        firstDate: widget.firstDate,
                        lastDate: widget.lastDate,
                        onDateChanged: _onStartDateChanged,
                        onDisplayedMonthChanged: _onStartDisplayedMonthChanged,
                        key: ValueKey<DateTime>(_startDate),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildCalendar(
                        label: 'Fin',
                        selectedDate: _endDate,
                        firstDate: widget.firstDate,
                        lastDate: widget.lastDate,
                        onDateChanged: _onEndDateChanged,
                        onDisplayedMonthChanged: _onEndDisplayedMonthChanged,
                        key: ValueKey<DateTime>(_endDate),
                      ),
                    ),
                  ],
                ),
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
                      Navigator.of(context).pop(
                        DateTimeRange(start: _startDate, end: _endDate),
                      );
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.indigo,
                    ),
                    child: const Text('SELECCIONAR'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendar({
    required String label,
    required DateTime selectedDate,
    required DateTime firstDate,
    required DateTime lastDate,
    required ValueChanged<DateTime> onDateChanged,
    required ValueChanged<DateTime> onDisplayedMonthChanged,
    required Key key,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.black54,
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: CalendarDatePicker(
            key: key,
            initialDate: selectedDate,
            firstDate: firstDate,
            lastDate: lastDate,
            onDateChanged: onDateChanged,
            onDisplayedMonthChanged: onDisplayedMonthChanged,
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return DateFormat('dd/MM/yyyy').format(date);
  }
}
