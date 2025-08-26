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
  
  // Platform earnings data
  double _totalCollected = 0.0;
  double _totalCodCommission = 0.0;
  double _totalOnlineCommission = 0.0;
  int _totalOrders = 0;

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

      // Sort debtors by amount desc and take top 10 (safely handle empty lists)
      List<Map<String, dynamic>> topDebtors = [];
      if (debtors.isNotEmpty) {
        debtors.sort((a, b) => (b['amount'] as double).compareTo(a['amount'] as double));
        topDebtors = debtors.take(debtors.length > 10 ? 10 : debtors.length).toList();
      }

      // Calculate collection rate (simplified - you might want more complex logic)
      final collectionRate = sellersWithDebt > 0 ? (1 - (sellersWithDebt / receivablesSnap.docs.length)) : 1.0;

      // Calculate platform earnings from collected commissions
      double totalCollected = 0.0;
      double totalCodCommission = 0.0;
      double totalOnlineCommission = 0.0;
      int totalOrders = 0;

      // Get all orders to calculate total platform earnings
      final ordersSnap = await FirebaseFirestore.instance
          .collection('orders')
          .where('status', isEqualTo: 'completed')
          .get();

      final commission_pct = 0.1; // 10% commission

      for (final orderDoc in ordersSnap.docs) {
        final orderData = orderDoc.data();
        final total = (orderData['totalPrice'] ?? orderData['total'] ?? 0.0).toDouble();
        final paymentMethod = (orderData['paymentMethod'] ?? '').toString().toLowerCase();
        final commission = total * commission_pct;

        totalOrders++;
        totalCollected += commission;

        if (paymentMethod.contains('cash')) {
          totalCodCommission += commission;
        } else {
          totalOnlineCommission += commission;
        }
      }

      setState(() {
        _totalOutstanding = totalOutstanding;
        _sellersWithDebt = sellersWithDebt;
        _topDebtors = topDebtors;
        _collectionRate = collectionRate;
        _totalCollected = totalCollected;
        _totalCodCommission = totalCodCommission;
        _totalOnlineCommission = totalOnlineCommission;
        _totalOrders = totalOrders;
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
              // Platform Earnings Section
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.monetization_on, color: Colors.green[700], size: 24),
                        const SizedBox(width: 8),
                        Text(
                          'Platform Earnings (Your Share)',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green[700]),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    LayoutBuilder(
                      builder: (context, constraints) {
                        if (constraints.maxWidth < 800) {
                          return Column(
                            children: [
                              _buildEarningsCard('Total Commission Earned', 'R${_totalCollected.toStringAsFixed(2)}', Icons.attach_money, Colors.green),
                              const SizedBox(height: 12),
                              _buildEarningsCard('From Online Orders', 'R${_totalOnlineCommission.toStringAsFixed(2)}', Icons.credit_card, Colors.blue),
                              const SizedBox(height: 12),
                              _buildEarningsCard('From COD Orders', 'R${_totalCodCommission.toStringAsFixed(2)}', Icons.local_atm, Colors.orange),
                              const SizedBox(height: 12),
                              _buildEarningsCard('Total Orders Processed', _totalOrders.toString(), Icons.shopping_cart, Colors.purple),
                            ],
                          );
                        } else {
                          return Row(
                            children: [
                              Expanded(child: _buildEarningsCard('Total Commission Earned', 'R${_totalCollected.toStringAsFixed(2)}', Icons.attach_money, Colors.green)),
                              const SizedBox(width: 12),
                              Expanded(child: _buildEarningsCard('From Online Orders', 'R${_totalOnlineCommission.toStringAsFixed(2)}', Icons.credit_card, Colors.blue)),
                              const SizedBox(width: 12),
                              Expanded(child: _buildEarningsCard('From COD Orders', 'R${_totalCodCommission.toStringAsFixed(2)}', Icons.local_atm, Colors.orange)),
                              const SizedBox(width: 12),
                              Expanded(child: _buildEarningsCard('Total Orders Processed', _totalOrders.toString(), Icons.shopping_cart, Colors.purple)),
                            ],
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Outstanding Amounts Section
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.account_balance_wallet, color: Colors.orange[700], size: 24),
                        const SizedBox(width: 8),
                        Text(
                          'Outstanding Collections',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange[700]),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    LayoutBuilder(
                      builder: (context, constraints) {
                        if (constraints.maxWidth < 600) {
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
                  ],
                ),
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

  Widget _buildEarningsCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
          ),
        ],
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
