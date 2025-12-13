import 'dart:ui';
import 'package:flutter/material.dart';

class FloatingMapCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double elevation;

  const FloatingMapCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16.0),
    this.elevation = 2.0,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
        child: Card(
          elevation: elevation,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          color: Colors.white.withValues(alpha: 0.5),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
