import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/order_migration_utils.dart';

class OrderMigrationScreen extends StatefulWidget {
  const OrderMigrationScreen({Key? key}) : super(key: key);

  @override
  State<OrderMigrationScreen> createState() => _OrderMigrationScreenState();
}

class _OrderMigrationScreenState extends State<OrderMigrationScreen> {
  bool _isMigrating = false;
  String _migrationStatus = '';
  int _migratedCount = 0;
  int _skippedCount = 0;

  Future<void> _runMigration() async {
    setState(() {
      _isMigrating = true;
      _migrationStatus = 'Starting migration...';
    });

    try {
      await OrderMigrationUtils.migrateExistingOrders();
      
      setState(() {
        _migrationStatus = 'Migration completed successfully!';
        _isMigrating = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Order migration completed successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() {
        _migrationStatus = 'Migration failed: $e';
        _isMigrating = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Migration failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Order Migration Tool',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'This tool will migrate existing orders to include the buyerName field for better customer identification in order management.',
                    style: TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '⚠️ Important:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                  const Text(
                    '• This migration will update existing orders in the database\n'
                    '• Make sure you have a backup before running this\n'
                    '• This process cannot be undone',
                    style: TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Migration Status',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  if (_isMigrating)
                    const LinearProgressIndicator()
                  else
                    const SizedBox(height: 4),
                  const SizedBox(height: 8),
                  Text(
                    _migrationStatus.isEmpty ? 'Ready to migrate' : _migrationStatus,
                    style: TextStyle(
                      color: _isMigrating ? Colors.blue : Colors.green,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: ElevatedButton.icon(
              onPressed: _isMigrating ? null : _runMigration,
              icon: _isMigrating 
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync),
              label: Text(_isMigrating ? 'Migrating...' : 'Start Migration'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
} 