import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_theme.dart';

class AuthStatusIndicator extends StatelessWidget {
  const AuthStatusIndicator({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        final user = snapshot.data;
        
        return Container(
          padding: const EdgeInsets.all(8),
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: user != null ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: user != null ? Colors.green : Colors.orange,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                user != null ? Icons.check_circle : Icons.warning,
                color: user != null ? Colors.green : Colors.orange,
                size: 16,
              ),
              const SizedBox(width: 4),
              Text(
                user != null ? 'Logged in' : 'Not logged in',
                style: TextStyle(
                  fontSize: 12,
                  color: user != null ? Colors.green : Colors.orange,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (user != null) ...[
                const SizedBox(width: 8),
                Text(
                  '(${user.email})',
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.grey,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
} 