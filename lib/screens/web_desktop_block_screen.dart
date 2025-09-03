import 'package:flutter/material.dart';

class WebDesktopBlockScreen extends StatelessWidget {
  const WebDesktopBlockScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFFE8F1F4),
                    const Color(0xFFD5E6EB),
                  ],
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 28,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      height: 96,
                      width: 96,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: const [
                          BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 6)),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Image.asset('assets/logo.png', fit: BoxFit.contain),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Mobile app only (for now)',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700, color: const Color(0xFF1F4654)),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Thanks for visiting! Our full web experience is coming soon. Please open this link on your phone to continue using the app.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(color: const Color(0xFF1F4654).withOpacity(0.80), height: 1.35),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.phone_iphone, color: Color(0xFF1F4654)),
                        const SizedBox(width: 8),
                        Text('Open on your mobile browser', style: theme.textTheme.labelLarge?.copyWith(color: const Color(0xFF1F4654))),
                      ],
                    ),
                    const SizedBox(height: 28),
                    Text(
                      'Web coming soon',
                      style: theme.textTheme.labelMedium?.copyWith(color: const Color(0xFF1F4654).withOpacity(0.7), letterSpacing: 0.6),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}


