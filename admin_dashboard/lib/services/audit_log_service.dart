import 'package:cloud_firestore/cloud_firestore.dart';

class AuditLogService {
  static Future<void> logAdminAction({required String user, required String action, String? details}) async {
    await FirebaseFirestore.instance.collection('auditLogs').add({
      'user': user,
      'action': action,
      'details': details ?? '',
      'timestamp': FieldValue.serverTimestamp(),
    });
  }
} 