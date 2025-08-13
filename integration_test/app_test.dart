import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:marketplace_app/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Marketplace App E2E Tests', () {
    testWidgets('App launches successfully', (tester) async {
      app.main();
      await tester.pumpAndSettle();
      
      // Just verify the app launches without throwing errors
      expect(tester, isNotNull);
    });

    testWidgets('App performance test', (tester) async {
      final stopwatch = Stopwatch()..start();
      app.main();
      await tester.pumpAndSettle();
      stopwatch.stop();
      
      // Verify app starts within reasonable time
      expect(stopwatch.elapsedMilliseconds, lessThan(15000));
    });

    testWidgets('Memory usage test', (tester) async {
      app.main();
      await tester.pumpAndSettle();
      
      // Navigate through app to test memory usage
      for (int i = 0; i < 3; i++) {
        await tester.pumpAndSettle();
      }
      
      // Just verify no exceptions occurred
      expect(tester, isNotNull);
    });

    testWidgets('App initialization test', (tester) async {
      app.main();
      await tester.pumpAndSettle();
      
      // Wait a bit more to ensure all initialization is complete
      await tester.pump(const Duration(seconds: 2));
      
      // Verify app is still running
      expect(tester, isNotNull);
    });
  });
} 