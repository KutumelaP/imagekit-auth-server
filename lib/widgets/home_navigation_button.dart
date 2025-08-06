import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class HomeNavigationButton extends StatelessWidget {
  final Color? backgroundColor;
  final Color? iconColor;
  final double? size;

  const HomeNavigationButton({
    Key? key,
    this.backgroundColor,
    this.iconColor,
    this.size,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor ?? AppTheme.deepTeal,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            Navigator.of(context).pushReplacementNamed('/home');
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Icon(
              Icons.home,
              color: iconColor ?? AppTheme.angel,
              size: size ?? 24,
            ),
          ),
        ),
      ),
    );
  }
} 