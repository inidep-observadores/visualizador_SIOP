import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:ui' as ui; // IMPORTANTE: Necesario para el efecto Blur

class CustomGridLayer extends StatelessWidget {
  final Color lineColor;
  final double lineWidth;
  final TextStyle labelStyle;
  // Nuevo parámetro para controlar el color del fondo de las etiquetas
  final Color labelBackgroundColor;

  const CustomGridLayer({
    super.key,
    this.lineColor = const Color(0x44000000), // Un poco más oscuro para contraste
    this.lineWidth = 0.5,
    this.labelStyle = const TextStyle(
      color: Colors.black87, // Color del texto
      fontSize: 11,
      fontWeight: FontWeight.w600,
    ),
    // Blanco semitransparente para el fondo, ajustable
    this.labelBackgroundColor = const Color(0xB3FFFFFF), 
  });

  @override
  Widget build(BuildContext context) {
    final camera = MapCamera.of(context);

    return MobileLayerTransformer(
      child: SizedBox.expand( 
        child: CustomPaint(
          painter: _GridPainter(
            camera: camera,
            lineColor: lineColor,
            lineWidth: lineWidth,
            labelStyle: labelStyle,
            labelBackgroundColor: labelBackgroundColor,
          ),
        ),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  final MapCamera camera;
  final Color lineColor;
  final double lineWidth;
  final TextStyle labelStyle;
  final Color labelBackgroundColor;

  // Constante: Grosor de la franja del borde donde van los textos
  static const double bandThickness = 28.0;

  _GridPainter({
    required this.camera,
    required this.lineColor,
    required this.lineWidth,
    required this.labelStyle,
    required this.labelBackgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = camera.visibleBounds;
    if (bounds.south == 0 && bounds.north == 0 || size.isEmpty) return;

    // 1. PINTAR LAS FRANJAS DE FONDO CON BLUR
    // Preparamos la "pintura" para el fondo
    final backgroundPaint = Paint()
      ..color = labelBackgroundColor
      ..style = PaintingStyle.fill
      // El filtro mágico para el desenfoque
      ..imageFilter = ui.ImageFilter.blur(sigmaX: 3.0, sigmaY: 3.0);

    // Dibujamos las 4 franjas en los bordes
    // Franja Superior
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, bandThickness), backgroundPaint);
    // Franja Inferior
    canvas.drawRect(Rect.fromLTWH(0, size.height - bandThickness, size.width, bandThickness), backgroundPaint);
    // Franja Izquierda (ajustamos altura para no superponer esquinas)
    canvas.drawRect(Rect.fromLTWH(0, bandThickness, bandThickness, size.height - (bandThickness * 2)), backgroundPaint);
    // Franja Derecha
    canvas.drawRect(Rect.fromLTWH(size.width - bandThickness, bandThickness, bandThickness, size.height - (bandThickness * 2)), backgroundPaint);


    // 2. PINTAR LA GRILLA Y TEXTOS
    final gridPaint = Paint()
      ..color = lineColor
      ..strokeWidth = lineWidth
      ..style = PaintingStyle.stroke;

    final double step = _getStep(camera.zoom);

    // --- LONGITUDES (Verticales) ---
    double currentLng = (bounds.west / step).floor() * step;
    while (currentLng <= bounds.east + step) {
      final p1 = camera.latLngToScreenPoint(LatLng(bounds.north + 10, currentLng));
      final p2 = camera.latLngToScreenPoint(LatLng(bounds.south - 10, currentLng));
      // Dibujamos la línea
      canvas.drawLine(Offset(p1.x, p1.y), Offset(p2.x, p2.y), gridPaint);
      
      // Etiquetas (Ajustadas posiciones para centrar en las franjas)
      final pBottom = camera.latLngToScreenPoint(LatLng(bounds.south, currentLng));
      if (pBottom.x > -20 && pBottom.x < size.width + 20) {
        _drawText(canvas, "${currentLng.toStringAsFixed(2)}°", Offset(pBottom.x, size.height - (bandThickness/2)));
      }

      final pTop = camera.latLngToScreenPoint(LatLng(bounds.north, currentLng));
      if (pTop.x > -20 && pTop.x < size.width + 20) {
        _drawText(canvas, "${currentLng.toStringAsFixed(2)}°", Offset(pTop.x, bandThickness/2));
      }
      currentLng += step;
    }

    // --- LATITUDES (Horizontales) ---
    double currentLat = (bounds.south / step).floor() * step;
    while (currentLat <= bounds.north + step) {
      final p1 = camera.latLngToScreenPoint(LatLng(currentLat, bounds.west - 10));
      final p2 = camera.latLngToScreenPoint(LatLng(currentLat, bounds.east + 10));
      // Dibujamos la línea
      canvas.drawLine(Offset(p1.x, p1.y), Offset(p2.x, p2.y), gridPaint);
      
      // Etiquetas
      final pLeft = camera.latLngToScreenPoint(LatLng(currentLat, bounds.west));
      if (pLeft.y > -20 && pLeft.y < size.height + 20) {
        _drawText(canvas, "${currentLat.toStringAsFixed(2)}°", Offset(bandThickness/2, pLeft.y));
      }

      final pRight = camera.latLngToScreenPoint(LatLng(currentLat, bounds.east));
      if (pRight.y > -20 && pRight.y < size.height + 20) {
        _drawText(canvas, "${currentLat.toStringAsFixed(2)}°", Offset(size.width - (bandThickness/2), pRight.y));
      }
      currentLat += step;
    }
  }

  // Pequeño ajuste en _drawText para centrar mejor el texto en el punto dado
  void _drawText(Canvas canvas, String text, Offset centerPos) {
    final textSpan = TextSpan(text: text, style: labelStyle);
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    textPainter.layout();
    // Calculamos la posición superior izquierda basada en el centro deseado
    final topLeftOffset = Offset(centerPos.dx - (textPainter.width / 2), centerPos.dy - (textPainter.height / 2));
    textPainter.paint(canvas, topLeftOffset);
  }

  double _getStep(double zoom) {
    // (Tu lógica de pasos densos que ya tenías)
    if (zoom < 4) return 10.0; 
    if (zoom < 6) return 5.0;
    if (zoom < 8) return 2.0;
    if (zoom < 10) return 1.0;
    if (zoom < 12) return 0.5;
    if (zoom < 14) return 0.25;
    if (zoom < 16) return 0.05;
    return 0.01;
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) {
    return oldDelegate.camera.center != camera.center ||
           oldDelegate.camera.zoom != camera.zoom ||
           oldDelegate.camera.rotation != camera.rotation ||
           oldDelegate.labelBackgroundColor != labelBackgroundColor;
  }
}