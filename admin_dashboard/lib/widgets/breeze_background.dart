import 'package:flutter/material.dart';
import '../theme/admin_theme.dart';

class BreezeBackground extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;

  const BreezeBackground({
    required this.child,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AdminTheme.whisper, AdminTheme.angel],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -80,
            right: -60,
            child: _softCircle(220, AdminTheme.breeze.withOpacity(0.25)),
          ),
          Positioned(
            bottom: -100,
            left: -80,
            child: _softCircle(260, AdminTheme.cloud.withOpacity(0.2)),
          ),
          Positioned(
            top: 140,
            left: -60,
            child: _softCircle(140, AdminTheme.breeze.withOpacity(0.18)),
          ),
          Positioned.fill(
            child: Padding(
              padding: padding ?? EdgeInsets.zero,
              child: child,
            ),
          ),
        ],
      ),
    );
  }

  Widget _softCircle(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.25),
            blurRadius: 40,
            spreadRadius: 10,
          ),
        ],
      ),
    );
  }
}
