import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/order_utils.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../SellerOrderDetailScreen.dart';

class OrdersTable extends StatelessWidget {
  final FirebaseAuth auth;
  final FirebaseFirestore firestore;
  final ValueNotifier<String> searchQuery;
  final ValueNotifier<String> statusFilter;
  final ValueNotifier<int> ordersToShow;
  final ValueNotifier<Set<String>> selectedOrders;
  const OrdersTable({
    Key? key,
    required this.auth,
    required this.firestore,
    required this.searchQuery,
    required this.statusFilter,
    required this.ordersToShow,
    required this.selectedOrders,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final sellerId = auth.currentUser?.uid;
    return Column(
      children: [
        Card(
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                // Search bar
                Expanded(
                  child: ValueListenableBuilder<String>(
                    valueListenable: searchQuery,
                    builder: (context, value, _) {
                      return TextField(
                        decoration: InputDecoration(
                          hintText: 'Search orders, products, customers...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                        ),
                        onChanged: (q) => searchQuery.value = q,
                      );
                    },
                  ),
                ),
                const SizedBox(width: 16),
                // Status filter
                ValueListenableBuilder<String>(
                  valueListenable: statusFilter,
                  builder: (context, value, _) {
                    return DropdownButton<String>(
                      value: value,
                      items: const [
                        DropdownMenuItem(value: 'All', child: Text('All Statuses')),
                        DropdownMenuItem(value: 'pending', child: Text('Pending')),
                        DropdownMenuItem(value: 'confirmed', child: Text('Confirmed')),
                        DropdownMenuItem(value: 'preparing', child: Text('Preparing')),
                        DropdownMenuItem(value: 'ready', child: Text('Ready')),
                        DropdownMenuItem(value: 'shipped', child: Text('Shipped')),
                        DropdownMenuItem(value: 'delivered', child: Text('Delivered')),
                        DropdownMenuItem(value: 'cancelled', child: Text('Cancelled')),
                      ],
                      onChanged: (v) => statusFilter.value = v ?? 'All',
                    );
                  },
                ),
                const SizedBox(width: 16),
                // Bulk actions
                ValueListenableBuilder<Set<String>>(
                  valueListenable: selectedOrders,
                  builder: (context, selected, _) {
                    return PopupMenuButton<String>(
                      enabled: selected.isNotEmpty,
                      icon: Icon(Icons.more_vert),
                      itemBuilder: (context) => [
                        const PopupMenuItem(value: 'mark_delivered', child: Text('Mark as Delivered')),
                        const PopupMenuItem(value: 'export', child: Text('Export Selected')),
                      ],
                      onSelected: (action) {
                        // TODO: Implement bulk actions
                        if (action == 'mark_delivered') {
                          // Implement mark as delivered logic
                        } else if (action == 'export') {
                          // Implement export logic
                        }
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        ValueListenableBuilder4<String, String, int, Set<String>>(
          searchQuery,
          statusFilter,
          ordersToShow,
          selectedOrders,
          builder: (context, search, status, toShow, selected, _) {
            return StreamBuilder<QuerySnapshot>(
              stream: firestore
                  .collection('orders')
                  .where('sellerId', isEqualTo: sellerId)
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                var orders = snapshot.data!.docs;
                // Apply search
                if (search.isNotEmpty) {
                  orders = orders.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final orderNumber = (data['orderNumber'] ?? doc.id).toString().toLowerCase();
                    final product = (data['items'] is List && data['items'].isNotEmpty) ? data['items'][0]['name'].toString().toLowerCase() : '';
                    final customer = (data['buyerName'] ?? '').toString().toLowerCase();
                    return orderNumber.contains(search.toLowerCase()) ||
                        product.contains(search.toLowerCase()) ||
                        customer.contains(search.toLowerCase());
                  }).toList();
                }
                // Apply status filter
                if (status != 'All') {
                  orders = orders.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return (data['status'] ?? 'pending').toString() == status;
                  }).toList();
                }
                // Pagination
                final pagedOrders = orders.take(toShow).toList();
                return Column(
                  children: [
                    Card(
                      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            columns: [
                              DataColumn(
                                label: Checkbox(
                                  value: selected.length == pagedOrders.length && pagedOrders.isNotEmpty,
                                  onChanged: (checked) {
                                    if (checked == true) {
                                      selectedOrders.value = pagedOrders.map((doc) => doc.id).toSet();
                                    } else {
                                      selectedOrders.value = {};
                                    }
                                  },
                                ),
                              ),
                              const DataColumn(label: Text('Order #')),
                              const DataColumn(label: Text('Product')),
                              const DataColumn(label: Text('Date')),
                              const DataColumn(label: Text('Price')),
                              const DataColumn(label: Text('Status')),
                              const DataColumn(label: Text('')), // Manage button
                            ],
                            rows: pagedOrders.map((doc) {
                              final data = doc.data() as Map<String, dynamic>;
                              final orderId = doc.id;
                              final orderNumber = data['orderNumber'] ?? orderId;
                              final product = (data['items'] is List && data['items'].isNotEmpty) ? data['items'][0]['name'] : 'Product';
                              final date = (data['timestamp'] is Timestamp) ? (data['timestamp'] as Timestamp).toDate() : DateTime.now();
                              final price = data['totalPrice'] ?? 0.0;
                              final status = (data['status'] ?? 'pending').toString();
                              return DataRow(
                                selected: selected.contains(orderId),
                                onSelectChanged: (checked) {
                                  if (checked == true) {
                                    selectedOrders.value = {...selected, orderId};
                                  } else {
                                    selectedOrders.value = {...selected}..remove(orderId);
                                  }
                                },
                                cells: [
                                  DataCell(Checkbox(
                                    value: selected.contains(orderId),
                                    onChanged: (checked) {
                                      if (checked == true) {
                                        selectedOrders.value = {...selected, orderId};
                                      } else {
                                        selectedOrders.value = {...selected}..remove(orderId);
                                      }
                                    },
                                  )),
                                  DataCell(Row(
                                    children: [
                                      if (data['items'] is List && data['items'].isNotEmpty && data['items'][0]['image'] != null)
                                        Padding(
                                          padding: const EdgeInsets.only(right: 8),
                                          child: CircleAvatar(
                                            backgroundImage: NetworkImage(data['items'][0]['image']),
                                            radius: 16,
                                          ),
                                        ),
                                      Text(OrderUtils.formatShortOrderNumber(orderNumber)),
                                    ],
                                  )),
                                  DataCell(Text(product)),
                                  DataCell(Text('${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}')),
                                  DataCell(Text('R${price.toStringAsFixed(2)}')),
                                  DataCell(GestureDetector(
                                    onTap: () {
                                      showDialog(
                                        context: context,
                                        builder: (ctx) => Dialog(
                                          insetPadding: const EdgeInsets.all(8),
                                          child: LayoutBuilder(
                                            builder: (context, constraints) {
                                              final isMobile = MediaQuery.of(context).size.width < 600;
                                              final maxWidth = isMobile ? MediaQuery.of(context).size.width : 900.0;
                                              final maxHeight = MediaQuery.of(context).size.height * 0.9;
                                              return SizedBox(
                                                width: maxWidth,
                                                height: maxHeight,
                                                child: SingleChildScrollView(
                                                  child: ConstrainedBox(
                                                    constraints: BoxConstraints(
                                                      minWidth: 0,
                                                      maxWidth: maxWidth,
                                                      minHeight: 0,
                                                      maxHeight: maxHeight,
                                                    ),
                                                    child: SellerOrderDetailScreen(orderId: orderId),
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      );
                                    },
                                    child: MouseRegion(
                                      cursor: SystemMouseCursors.click,
                                      child: Text(status[0].toUpperCase() + status.substring(1), style: TextStyle(color: status == 'delivered' ? Colors.green : status == 'cancelled' ? Colors.red : Colors.orange)),
                                    ),
                                  )),
                                  DataCell(
                                    IconButton(
                                      icon: Icon(Icons.manage_accounts, color: Colors.blue),
                                      tooltip: 'Manage Order',
                                      onPressed: () {
                                        showDialog(
                                          context: context,
                                          builder: (ctx) => Dialog(
                                            insetPadding: const EdgeInsets.all(32),
                                            child: SizedBox(
                                              width: 700,
                                              child: SellerOrderDetailScreen(orderId: orderId),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                                color: MaterialStateProperty.resolveWith<Color?>((Set<MaterialState> states) {
                                  if (states.contains(MaterialState.hovered)) return Colors.blue.shade50;
                                  return null;
                                }),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ),
                    if (orders.length > toShow)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: ElevatedButton(
                          onPressed: () => ordersToShow.value += 10,
                          child: const Text('Load More'),
                        ),
                      ),
                  ],
                );
              },
            );
          },
        ),
      ],
    );
  }
}

// Helper for multiple ValueListenableBuilder
class ValueListenableBuilder4<A, B, C, D> extends StatelessWidget {
  final ValueListenable<A> a;
  final ValueListenable<B> b;
  final ValueListenable<C> c;
  final ValueListenable<D> d;
  final Widget Function(BuildContext, A, B, C, D, Widget?) builder;
  final Widget? child;
  const ValueListenableBuilder4(this.a, this.b, this.c, this.d, {required this.builder, this.child, super.key});
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<A>(
      valueListenable: a,
      builder: (context, va, _) => ValueListenableBuilder<B>(
        valueListenable: b,
        builder: (context, vb, _) => ValueListenableBuilder<C>(
          valueListenable: c,
          builder: (context, vc, _) => ValueListenableBuilder<D>(
            valueListenable: d,
            builder: (context, vd, _) => builder(context, va, vb, vc, vd, child),
          ),
        ),
      ),
    );
  }
} 