import 'package:flutter/material.dart';

class AnalyticsCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const AnalyticsCard({required this.icon, required this.label, required this.value, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final highlight = theme.colorScheme.primary;
    final textColor = theme.colorScheme.onSurface;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(18),
        color: theme.cardColor,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {},
          hoverColor: highlight.withOpacity(0.08),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: highlight.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Icon(icon, color: highlight, size: 32),
                ),
                const SizedBox(width: 18),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: highlight,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      label,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: textColor,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
} 