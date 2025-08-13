// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marketplace_app/services/input_validator.dart';
import 'package:marketplace_app/services/rate_limiter.dart';
import 'package:marketplace_app/services/performance_monitor.dart';
import 'package:marketplace_app/services/error_recovery_service.dart';

void main() {
  group('InputValidator Tests', () {
    test('email validation', () {
      expect(InputValidator.isValidEmail('test@example.com'), true);
      expect(InputValidator.isValidEmail('invalid-email'), false);
      expect(InputValidator.isValidEmail(''), false);
    });

    test('phone validation', () {
      expect(InputValidator.isValidPhone('+1234567890'), true);
      expect(InputValidator.isValidPhone('1234567890'), true);
      expect(InputValidator.isValidPhone('123'), false);
      expect(InputValidator.isValidPhone(''), false);
    });

    test('password validation', () {
      expect(InputValidator.isValidPassword('StrongPass123!'), true);
      expect(InputValidator.isValidPassword('weak'), false);
      expect(InputValidator.isValidPassword(''), false);
    });

    test('message validation', () {
      expect(InputValidator.isValidMessage('Hello world'), true);
      expect(InputValidator.isValidMessage(''), false);
      expect(InputValidator.isValidMessage('   '), false);
    });

    test('input sanitization', () {
      expect(InputValidator.sanitizeInput('<script>alert("xss")</script>'), 'alert("xss")');
      expect(InputValidator.sanitizeInput('javascript:alert("xss")'), 'alert("xss")');
      expect(InputValidator.sanitizeInput('normal text'), 'normal text');
    });
  });

  group('RateLimiter Tests', () {
    setUp(() {
      RateLimiter.clearAllData();
    });

    test('basic rate limiting', () {
      expect(RateLimiter.canMakeRequest('user1'), true);
      expect(RateLimiter.canMakeRequest('user1'), false); // Should be rate limited
    });

    test('different users should not interfere', () {
      expect(RateLimiter.canMakeRequest('user1'), true);
      expect(RateLimiter.canMakeRequest('user2'), true);
    });

    test('message rate limiting', () {
      expect(RateLimiter.canSendMessage('user1', 'chat1'), true);
      expect(RateLimiter.canSendMessage('user1', 'chat1'), false);
    });

    test('search rate limiting', () {
      expect(RateLimiter.canSearch('user1'), true);
      expect(RateLimiter.canSearch('user1'), false);
    });

    test('get remaining requests', () {
      RateLimiter.canMakeRequest('user1');
      expect(RateLimiter.getRemainingRequests('user1'), 59);
    });
  });

  group('PerformanceMonitor Tests', () {
    setUp(() {
      PerformanceMonitor.clearData();
    });

    test('timer functionality', () {
      PerformanceMonitor.startTimer('test_timer');
      PerformanceMonitor.endTimer('test_timer');
      
      final stats = PerformanceMonitor.getOperationStats('test_timer');
      expect(stats['count'], 1);
      expect(stats['name'], 'test_timer');
    });

    test('monitor function', () async {
      final result = await PerformanceMonitor.monitor('test_monitor', () async {
        await Future.delayed(const Duration(milliseconds: 10));
        return 'test_result';
      });
      
      expect(result, 'test_result');
      
      final stats = PerformanceMonitor.getOperationStats('test_monitor');
      expect(stats['count'], 1);
    });

    test('monitor sync function', () {
      final result = PerformanceMonitor.monitorSync('test_sync', () {
        return 'test_result';
      });
      
      expect(result, 'test_result');
      
      final stats = PerformanceMonitor.getOperationStats('test_sync');
      expect(stats['count'], 1);
    });
  });

  group('ErrorRecoveryService Tests', () {
    setUp(() {
      ErrorRecoveryService.clearErrorCounts();
    });

    test('error type detection', () {
      expect(ErrorRecoveryService.isRecoverable(Exception('network error')), true);
      expect(ErrorRecoveryService.isRecoverable(Exception('permission denied')), false);
    });

    test('user friendly messages', () {
      final message = ErrorRecoveryService.getUserFriendlyMessage(Exception('network error'));
      expect(message, contains('Network error'));
    });

    test('error statistics', () {
      ErrorRecoveryService.attemptRecovery(Exception('test error'), context: 'test');
      final stats = ErrorRecoveryService.getErrorStats();
      expect(stats['errorCounts'], isNotEmpty);
    });
  });

  group('Integration Tests', () {
    test('input validation with rate limiting', () {
      // Test that rate limiting works with input validation
      final user = 'test_user';
      
      // First request should succeed
      expect(RateLimiter.canMakeRequest(user), true);
      
      // Second request should be rate limited
      expect(RateLimiter.canMakeRequest(user), false);
      
      // But input validation should still work
      expect(InputValidator.isValidEmail('test@example.com'), true);
    });

    test('performance monitoring with error recovery', () async {
      // Test that performance monitoring works with error recovery
      bool hasError = false;
      
      try {
        await PerformanceMonitor.monitor('test_error', () async {
          throw Exception('test error');
        });
      } catch (e) {
        hasError = true;
        final canRecover = await ErrorRecoveryService.attemptRecovery(e);
        expect(canRecover, true);
      }
      
      expect(hasError, true);
    });
  });
}
