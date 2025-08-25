import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/admin_theme.dart';
import 'summary_card.dart';

class FinancialOverviewSection extends StatefulWidget {
  const FinancialOverviewSection({Key? key}) : super(key: key);

  @override
  State<FinancialOverviewSection> createState() => _FinancialOverviewSectionState();
}

class _FinancialOverviewSectionState extends State<FinancialOverviewSection> {
  bool _isLoading = true;
  double _totalOutstanding = 0.0;
  int _sellersWithDebt = 0;
  double _collectionRate = 0.0;
  List<Map<String, dynamic>> _topDebtors = [];

  @override
  void initState() {
    super.initState();
    _loadFinancialData();
  }

  Future<void> _loadFinancialData() async {
    try {
      setState(() => _isLoading = true);

      // Get all platform receivables
      final receivablesSnap = await FirebaseFirestore.instance
          .collection('platform_receivables')
          .get();

      double totalOutstanding = 0.0;
      int sellersWithDebt = 0;
      List<Map<String, dynamic>> debtors = [];

      for (final doc in receivablesSnap.docs) {
        final data = doc.data();
        final amount = (data['amount'] is num) 
            ? (data['amount'] as num).toDouble() 
            : double.tryParse('${data['amount']}') ?? 0.0;
        
        if (amount > 0) {
          totalOutstanding += amount;
          sellersWithDebt++;
          
          // Get seller info for top debtors
          final sellerDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(doc.id)
              .get();
          
          if (sellerDoc.exists) {
            final sellerData = sellerDoc.data() ?? {};
            debtors.add({
              'sellerId': doc.id,
              'storeName': sellerData['storeName'] ?? 'Unknown Store',
              'amount': amount,
              'lastUpdated': data['lastUpdated'],
              'type': data['type'] ?? 'commission',
            });
          }
        }
      }

      // Sort debtors by amount desc and take top 10
      debtors.sort((a, b) => (b['amount'] as double).compareTo(a['amount'] as double));
      final topDebtors = debtors.take(10).toList();

      // Calculate collection rate (simplified - you might want more complex logic)
      final collectionRate = sellersWithDebt > 0 ? (1 - (sellersWithDebt / receivablesSnap.docs.length)) : 1.0;

      setState(() {
        _totalOutstanding = totalOutstanding;
        _sellersWithDebt = sellersWithDebt;
        _topDebtors = topDebtors;
        _collectionRate = collectionRate;
        _isLoading = false;
      });

    } catch (e) {
      print('Error loading financial data: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Financial Overview',
                  style: AdminTheme.headlineLarge,
                ),
                IconButton(
                  onPressed: _loadFinancialData,
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Refresh Data',
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else ...[
              // Summary Cards - Responsive layout
              LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth < 600) {
                    // Stack cards vertically on small screens
                    return Column(
                      children: [
                        SummaryCard(
                          label: 'Total Outstanding',
                          value: 'R${_totalOutstanding.toStringAsFixed(2)}',
                          icon: Icons.account_balance_wallet,
                        ),
                        const SizedBox(height: 16),
                        SummaryCard(
                          label: 'Sellers with Debt',
                          value: _sellersWithDebt.toString(),
                          icon: Icons.people,
                        ),
                        const SizedBox(height: 16),
                        SummaryCard(
                          label: 'Collection Rate',
                          value: '${(_collectionRate * 100).toStringAsFixed(1)}%',
                          icon: Icons.trending_up,
                        ),
                      ],
                    );
                  } else {
                    // Display horizontally on larger screens
                    return Row(
                      children: [
                        Expanded(
                          child: SummaryCard(
                            label: 'Total Outstanding',
                            value: 'R${_totalOutstanding.toStringAsFixed(2)}',
                            icon: Icons.account_balance_wallet,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: SummaryCard(
                            label: 'Sellers with Debt',
                            value: _sellersWithDebt.toString(),
                            icon: Icons.people,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: SummaryCard(
                            label: 'Collection Rate',
                            value: '${(_collectionRate * 100).toStringAsFixed(1)}%',
                            icon: Icons.trending_up,
                          ),
                        ),
                      ],
                    );
                  }
                },
              ),
              
              const SizedBox(height: 32),
              
              // Top Debtors Table
              Text(
                'Top Debtors',
                style: AdminTheme.headlineMedium,
              ),
              const SizedBox(height: 16),
              
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DataTable(
                  headingRowColor: MaterialStateProperty.all(Colors.grey[100]),
                  columns: const [
                    DataColumn(label: Text('Store Name', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Outstanding Amount', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Type', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                  ],
                  rows: _topDebtors.map((debtor) {
                    return DataRow(
                      cells: [
                        DataCell(Text(debtor['storeName'])),
                        DataCell(
                          Text(
                            'R${(debtor['amount'] as double).toStringAsFixed(2)}',
                            style: TextStyle(
                              color: debtor['amount'] > 1000 ? Colors.red : Colors.orange,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        DataCell(
                          Chip(
                            label: Text(debtor['type']),
                            backgroundColor: debtor['type'] == 'commission' ? Colors.blue[100] : Colors.orange[100],
                          ),
                        ),
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                onPressed: () => _viewSellerDetails(debtor['sellerId']),
                                icon: const Icon(Icons.visibility),
                                tooltip: 'View Details',
                              ),
                              IconButton(
                                onPressed: () => _sendPaymentReminder(debtor['sellerId']),
                                icon: const Icon(Icons.email),
                                tooltip: 'Send Reminder',
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Quick Actions
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: _exportDebtReport,
                    icon: const Icon(Icons.download),
                    label: const Text('Export Report'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: _sendBulkReminders,
                    icon: const Icon(Icons.mail_outline),
                    label: const Text('Send Bulk Reminders'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: _manageCollectionSettings,
                    icon: const Icon(Icons.settings),
                    label: const Text('Collection Settings'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[700],
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _viewSellerDetails(String sellerId) {
    // Navigate to seller detail screen
    showDialog(
      context: context,
      builder: (context) => SellerDebtDetailDialog(sellerId: sellerId),
    );
  }

  void _sendPaymentReminder(String sellerId) async {
    try {
      // Send reminder notification/email
      await FirebaseFirestore.instance
          .collection('notifications')
          .add({
        'userId': sellerId,
        'title': 'Payment Reminder',
        'body': 'You have outstanding fees. Please settle your account to maintain COD access.',
        'type': 'payment_reminder',
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment reminder sent successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send reminder: $e')),
      );
    }
  }

  void _exportDebtReport() {
    // TODO: Implement CSV/PDF export
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Export functionality coming soon')),
    );
  }

  void _sendBulkReminders() async {
    try {
      final batch = FirebaseFirestore.instance.batch();
      
      for (final debtor in _topDebtors) {
        final notificationRef = FirebaseFirestore.instance
            .collection('notifications')
            .doc();
        
        batch.set(notificationRef, {
          'userId': debtor['sellerId'],
          'title': 'Payment Reminder',
          'body': 'You have outstanding fees of R${(debtor['amount'] as double).toStringAsFixed(2)}. Please settle your account.',
          'type': 'payment_reminder',
          'createdAt': FieldValue.serverTimestamp(),
          'read': false,
        });
      }
      
      await batch.commit();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sent reminders to ${_topDebtors.length} sellers')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send bulk reminders: $e')),
      );
    }
  }

  void _manageCollectionSettings() {
    // TODO: Navigate to collection settings screen
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Collection settings coming soon')),
    );
  }
}

class SellerDebtDetailDialog extends StatelessWidget {
  final String sellerId;

  const SellerDebtDetailDialog({Key? key, required this.sellerId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 600,
        padding: const EdgeInsets.all(24),
        child: FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance
              .collection('platform_receivables')
              .doc(sellerId)
              .get(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (!snapshot.hasData || !snapshot.data!.exists) {
              return const Center(child: Text('No debt data found'));
            }

            final data = snapshot.data!.data() as Map<String, dynamic>;
            final amount = (data['amount'] is num) 
                ? (data['amount'] as num).toDouble() 
                : double.tryParse('${data['amount']}') ?? 0.0;

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Seller Debt Details',
                      style: AdminTheme.headlineLarge,
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const Divider(),
                const SizedBox(height: 16),
                
                Text('Outstanding Amount: R${amount.toStringAsFixed(2)}'),
                Text('Type: ${data['type'] ?? 'Unknown'}'),
                Text('Description: ${data['description'] ?? 'No description'}'),
                Text('Last Updated: ${data['lastUpdated']?.toDate()?.toString() ?? 'Unknown'}'),
                
                const SizedBox(height: 24),
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Close'),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: () {
                        // TODO: Implement debt forgiveness/adjustment
                        Navigator.of(context).pop();
                      },
                      child: const Text('Adjust Debt'),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
