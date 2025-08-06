import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SellerReturnsSection extends StatelessWidget {
  final FirebaseAuth auth;
  final FirebaseFirestore firestore;
  const SellerReturnsSection({required this.auth, required this.firestore});

  @override
  Widget build(BuildContext context) {
    final sellerId = auth.currentUser?.uid;
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Returns Management', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24)),
          const SizedBox(height: 24),
          SizedBox(
            height: 400, // Adjust as needed for your layout
            child: StreamBuilder<QuerySnapshot>(
              stream: firestore.collection('returns').where('sellerId', isEqualTo: sellerId).snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final returns = snapshot.data!.docs;
                if (returns.isEmpty) return const Center(child: Text('No returns found.'));
                return ListView.builder(
                  itemCount: returns.length,
                  itemBuilder: (context, i) {
                    final data = returns[i].data() as Map<String, dynamic>;
                    return Card(
                      child: ListTile(
                        title: Text('Order: ${data['orderId']}'),
                        subtitle: Text('Reason: ${data['reason']}'),
                        trailing: Text(data['status'] ?? 'pending', style: TextStyle(fontWeight: FontWeight.bold)),
                        onTap: () async {
                          await showDialog(
                            context: context,
                            builder: (context) => _ReturnDetailsDialog(
                              returnId: returns[i].id,
                              data: data,
                              firestore: firestore,
                            ),
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ReturnDetailsDialog extends StatefulWidget {
  final String returnId;
  final Map<String, dynamic> data;
  final FirebaseFirestore firestore;
  const _ReturnDetailsDialog({required this.returnId, required this.data, required this.firestore});

  @override
  State<_ReturnDetailsDialog> createState() => _ReturnDetailsDialogState();
}

class _ReturnDetailsDialogState extends State<_ReturnDetailsDialog> {
  late String status;
  late TextEditingController notesController;

  @override
  void initState() {
    super.initState();
    status = widget.data['status'] ?? 'pending';
    notesController = TextEditingController(text: widget.data['notes'] ?? '');
  }

  @override
  void dispose() {
    notesController.dispose();
    super.dispose();
  }

  Future<void> _updateStatus(String newStatus) async {
    await widget.firestore.collection('returns').doc(widget.returnId).update({
      'status': newStatus,
      'notes': notesController.text,
      'processedAt': FieldValue.serverTimestamp(),
    });
    setState(() {
      status = newStatus;
    });
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Return Details'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Order ID: ${widget.data['orderId']}'),
            Text('Product ID: ${widget.data['productId']}'),
            Text('Buyer ID: ${widget.data['buyerId']}'),
            Text('Reason: ${widget.data['reason']}'),
            if (widget.data['buyerPhone'] != null && widget.data['buyerPhone'].toString().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0, bottom: 4.0),
                child: GestureDetector(
                  onTap: () async {
                    final phone = widget.data['buyerPhone'];
                    final url = 'tel:$phone';
                    // Use url_launcher if available
                    // await launchUrl(Uri.parse(url));
                  },
                  child: Row(
                    children: [
                      Icon(Icons.phone, size: 18, color: Theme.of(context).colorScheme.primary),
                      SizedBox(width: 6),
                      Text('Buyer Phone: ${widget.data['buyerPhone']}', style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 12),
            Text('Status: $status', style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
            const SizedBox(height: 12),
            TextField(
              controller: notesController,
              decoration: InputDecoration(labelText: 'Notes (optional)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
              maxLines: 2,
            ),
          ],
        ),
      ),
      actions: [
        if (status == 'pending') ...[
          TextButton(
            onPressed: () => _updateStatus('approved'),
            child: const Text('Approve'),
          ),
          TextButton(
            onPressed: () => _updateStatus('rejected'),
            child: const Text('Reject'),
          ),
        ],
        if (status == 'approved')
          TextButton(
            onPressed: () => _updateStatus('completed'),
            child: const Text('Mark as Completed'),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
} 