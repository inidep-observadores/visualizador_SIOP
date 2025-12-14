import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

class ScaleBar extends StatefulWidget {
  final MapController mapController;
  final TextStyle? textStyle;
  final Color lineColor;
  final double padding;

  const ScaleBar({
    super.key,
    required this.mapController,
    this.textStyle,
    this.lineColor = Colors.black,
    this.padding = 10,
  });

  @override
  State<ScaleBar> createState() => _ScaleBarState();
}

class _ScaleBarState extends State<ScaleBar> {
  // 1 Nautical Mile in meters
  static const double _nmInMeters = 1852.0;

  @override
  void initState() {
    super.initState();
    // Rebuild when the map moves or zooms
    widget.mapController.mapEventStream.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    // Basic safety check
    if (widget.mapController.camera.zoom < 0) return const SizedBox();

    // Calculate scale
    // Calculate meters represented by the widget width (e.g. 100px)
    // Formula for meters per pixel at latitude:
    // (earthCircumference * cos(lat)) / 2^zoom / 256
    const double earthCircumference = 40075016.686;
    final lat = widget.mapController.camera.center.latitude;
    final zoom = widget.mapController.camera.zoom;

    final metersPerPixel =
        (earthCircumference * cos(lat * pi / 180)) / pow(2, zoom + 8);

    // Let's target a bar of roughly 100 pixels
    const double targetWidth = 100.0;
    final double metersInTarget = metersPerPixel * targetWidth;
    final double nmInTarget = metersInTarget / _nmInMeters;

    // Find a nice round number for NM
    double displayNm;
    if (nmInTarget > 100) {
      displayNm = (nmInTarget / 50).round() * 50;
    } else if (nmInTarget > 10) {
      displayNm = (nmInTarget / 10).round() * 10;
    } else if (nmInTarget > 1) {
      displayNm = (nmInTarget).roundToDouble();
    } else {
      // For very closer zooms, maybe use decimals e.g 0.5 NM
      displayNm = (nmInTarget * 10).round() / 10;
    }

    if (displayNm == 0) displayNm = 0.1;

    // Recalculate width based on the rounded NM
    final double finalWidth = (displayNm * _nmInMeters) / metersPerPixel;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          '$displayNm MN',
          style:
              widget.textStyle ??
              const TextStyle(fontSize: 10, color: Colors.black),
        ),
        Container(
          height: 6,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: widget.lineColor, width: 2),
              left: BorderSide(color: widget.lineColor, width: 2),
              right: BorderSide(color: widget.lineColor, width: 2),
            ),
          ),
          width: finalWidth,
        ),
      ],
    );
  }
}
