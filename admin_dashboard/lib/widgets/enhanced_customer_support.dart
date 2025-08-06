import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../theme/admin_theme.dart';

class EnhancedCustomerSupport extends StatefulWidget {
  final FirebaseFirestore firestore;

  const EnhancedCustomerSupport({
    Key? key,
    required this.firestore,
  }) : super(key: key);

  @override
  State<EnhancedCustomerSupport> createState() => _EnhancedCustomerSupportState();
}

class _EnhancedCustomerSupportState extends State<EnhancedCustomerSupport>
    with TickerProviderStateMixin {
  bool _isLoading = true;
  List<Map<String, dynamic>> _tickets = [];
  List<Map<String, dynamic>> _filteredTickets = [];
  
  // Filter states
  String _selectedPriority = 'All';
  String _selectedStatus = 'All';
  String _selectedCategory = 'All';
  String _searchQuery = '';
  
  final List<String> _priorities = ['All', 'Low', 'Medium', 'High', 'Critical'];
  final List<String> _statuses = ['All', 'Open', 'In Progress', 'Resolved', 'Closed'];
  final List<String> _categories = ['All', 'Technical', 'Billing', 'Order', 'Account', 'General'];
  
  // Real-time updates
  StreamSubscription<QuerySnapshot>? _ticketsSubscription;
  
  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadTickets();
    _setupRealTimeUpdates();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _ticketsSubscription?.cancel();
    super.dispose();
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));
    
    _fadeController.forward();
    _slideController.forward();
  }

  Future<void> _loadTickets() async {
    setState(() => _isLoading = true);
    
    try {
      final snapshot = await widget.firestore
          .collection('support_tickets')
          .orderBy('createdAt', descending: true)
          .limit(100)
          .get();

      _tickets = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();
      
      _applyFilters();
    } catch (e) {
      debugPrint('Error loading tickets: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _setupRealTimeUpdates() {
    _ticketsSubscription = widget.firestore
        .collection('support_tickets')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() {
          _tickets = snapshot.docs.map((doc) {
            final data = doc.data();
            return {
              'id': doc.id,
              ...data,
            };
          }).toList();
        });
        _applyFilters();
      }
    });
  }

  void _applyFilters() {
    _filteredTickets = _tickets.where((ticket) {
      // Priority filter
      if (_selectedPriority != 'All' && ticket['priority'] != _selectedPriority) {
        return false;
      }
      
      // Status filter
      if (_selectedStatus != 'All' && ticket['status'] != _selectedStatus) {
        return false;
      }
      
      // Category filter
      if (_selectedCategory != 'All' && ticket['category'] != _selectedCategory) {
        return false;
      }
      
      // Search query filter
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final subject = ticket['subject']?.toString().toLowerCase() ?? '';
        final description = ticket['description']?.toString().toLowerCase() ?? '';
        final customerName = ticket['customerName']?.toString().toLowerCase() ?? '';
        final ticketId = ticket['id']?.toString().toLowerCase() ?? '';
        
        if (!subject.contains(query) && 
            !description.contains(query) && 
            !customerName.contains(query) &&
            !ticketId.contains(query)) {
          return false;
        }
      }
      
      return true;
    }).toList();
  }

  Future<void> _updateTicketStatus(String ticketId, String newStatus) async {
    try {
      await widget.firestore
          .collection('support_tickets')
          .doc(ticketId)
          .update({
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
        'resolvedAt': newStatus == 'Resolved' || newStatus == 'Closed' 
            ? FieldValue.serverTimestamp() 
            : null,
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ticket status updated to $newStatus'),
          backgroundColor: AdminTheme.deepTeal,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update ticket status: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _addResponse(String ticketId, String response) async {
    try {
      await widget.firestore
          .collection('support_tickets')
          .doc(ticketId)
          .collection('responses')
          .add({
        'message': response,
        'sender': 'admin',
        'timestamp': FieldValue.serverTimestamp(),
      });
      
      // Update ticket status to "In Progress" if it was "Open"
      await widget.firestore
          .collection('support_tickets')
          .doc(ticketId)
          .update({
        'status': 'In Progress',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Response added successfully'),
          backgroundColor: AdminTheme.deepTeal,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to add response: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: Column(
            children: [
              _buildHeader(),
              _buildFilters(),
              _buildSupportStats(),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _buildTicketList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AdminTheme.angel,
        border: Border(
          bottom: BorderSide(color: AdminTheme.silverGray.withOpacity(0.3)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Enhanced Customer Support',
                style: AdminTheme.headlineLarge.copyWith(
                  color: AdminTheme.deepTeal,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Comprehensive ticket management and support',
                style: AdminTheme.bodyMedium.copyWith(
                  color: AdminTheme.darkGrey,
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AdminTheme.deepTeal,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.support_agent,
                  color: AdminTheme.angel,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  '${_filteredTickets.length} Tickets',
                  style: AdminTheme.labelMedium.copyWith(
                    color: AdminTheme.angel,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AdminTheme.whisper,
        border: Border(
          bottom: BorderSide(color: AdminTheme.silverGray.withOpacity(0.3)),
        ),
      ),
      child: Column(
        children: [
          // Search bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: AdminTheme.angel,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AdminTheme.silverGray),
            ),
            child: TextField(
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
                _applyFilters();
              },
              decoration: InputDecoration(
                hintText: 'Search tickets by subject, description, or customer...',
                hintStyle: AdminTheme.bodyMedium.copyWith(
                  color: AdminTheme.darkGrey,
                ),
                border: InputBorder.none,
                icon: Icon(
                  Icons.search,
                  color: AdminTheme.deepTeal,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Filter controls
          Row(
            children: [
              Expanded(
                child: _buildFilterDropdown(
                  'Priority',
                  _selectedPriority,
                  _priorities,
                  (value) {
                    setState(() {
                      _selectedPriority = value;
                    });
                    _applyFilters();
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildFilterDropdown(
                  'Status',
                  _selectedStatus,
                  _statuses,
                  (value) {
                    setState(() {
                      _selectedStatus = value;
                    });
                    _applyFilters();
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildFilterDropdown(
                  'Category',
                  _selectedCategory,
                  _categories,
                  (value) {
                    setState(() {
                      _selectedCategory = value;
                    });
                    _applyFilters();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown(String label, String value, List<String> items, Function(String) onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AdminTheme.angel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminTheme.silverGray),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          items: items.map((item) {
            return DropdownMenuItem(
              value: item,
              child: Text(
                item,
                style: AdminTheme.bodyMedium,
              ),
            );
          }).toList(),
          onChanged: (newValue) {
            if (newValue != null) {
              onChanged(newValue);
            }
          },
        ),
      ),
    );
  }

  Widget _buildSupportStats() {
    final stats = _calculateSupportStats();
    
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              'Total Tickets',
              stats['total'].toString(),
              Icons.support_agent,
              AdminTheme.deepTeal,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              'Open',
              stats['open'].toString(),
              Icons.pending,
              Colors.orange,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              'In Progress',
              stats['inProgress'].toString(),
              Icons.work,
              Colors.blue,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              'Resolved',
              stats['resolved'].toString(),
              Icons.check_circle,
              Colors.green,
            ),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _calculateSupportStats() {
    int total = _filteredTickets.length;
    int open = 0;
    int inProgress = 0;
    int resolved = 0;
    
    for (final ticket in _filteredTickets) {
      final status = ticket['status'] as String? ?? 'Open';
      
      switch (status) {
        case 'Open':
          open++;
          break;
        case 'In Progress':
          inProgress++;
          break;
        case 'Resolved':
        case 'Closed':
          resolved++;
          break;
      }
    }
    
    return {
      'total': total,
      'open': open,
      'inProgress': inProgress,
      'resolved': resolved,
    };
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AdminTheme.cardDecoration(
        color: AdminTheme.angel,
        boxShadow: [
          BoxShadow(
            color: AdminTheme.indigo.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: AdminTheme.titleLarge.copyWith(
              color: AdminTheme.deepTeal,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            title,
            style: AdminTheme.bodySmall.copyWith(
              color: AdminTheme.darkGrey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTicketList() {
    if (_filteredTickets.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.support_agent_outlined,
              size: 64,
              color: AdminTheme.darkGrey,
            ),
            const SizedBox(height: 16),
            Text(
              'No tickets found',
              style: AdminTheme.headlineSmall.copyWith(
                color: AdminTheme.darkGrey,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your filters',
              style: AdminTheme.bodyMedium.copyWith(
                color: AdminTheme.darkGrey,
              ),
            ),
          ],
        ),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredTickets.length,
      itemBuilder: (context, index) {
        final ticket = _filteredTickets[index];
        return _buildTicketCard(ticket);
      },
    );
  }

  Widget _buildTicketCard(Map<String, dynamic> ticket) {
    final ticketId = ticket['id'] as String? ?? '';
    final subject = ticket['subject'] as String? ?? 'No Subject';
    final description = ticket['description'] as String? ?? 'No Description';
    final priority = ticket['priority'] as String? ?? 'Medium';
    final status = ticket['status'] as String? ?? 'Open';
    final category = ticket['category'] as String? ?? 'General';
    final customerName = ticket['customerName'] as String? ?? 'Unknown Customer';
    final customerEmail = ticket['customerEmail'] as String? ?? '';
    final createdAt = (ticket['createdAt'] as Timestamp?)?.toDate();
    final updatedAt = (ticket['updatedAt'] as Timestamp?)?.toDate();
    
    Color priorityColor;
    IconData priorityIcon;
    
    switch (priority) {
      case 'Low':
        priorityColor = Colors.green;
        priorityIcon = Icons.low_priority;
        break;
      case 'Medium':
        priorityColor = Colors.orange;
        priorityIcon = Icons.priority_high;
        break;
      case 'High':
        priorityColor = Colors.red;
        priorityIcon = Icons.priority_high;
        break;
      case 'Critical':
        priorityColor = Colors.purple;
        priorityIcon = Icons.warning;
        break;
      default:
        priorityColor = Colors.grey;
        priorityIcon = Icons.help_outline;
    }
    
    Color statusColor;
    IconData statusIcon;
    
    switch (status) {
      case 'Open':
        statusColor = Colors.orange;
        statusIcon = Icons.pending;
        break;
      case 'In Progress':
        statusColor = Colors.blue;
        statusIcon = Icons.work;
        break;
      case 'Resolved':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'Closed':
        statusColor = Colors.grey;
        statusIcon = Icons.close;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help_outline;
    }
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AdminTheme.angel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminTheme.silverGray.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: AdminTheme.silverGray.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ExpansionTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: priorityColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            priorityIcon,
            color: priorityColor,
            size: 20,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    subject,
                    style: AdminTheme.titleMedium.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    customerName,
                    style: AdminTheme.bodySmall.copyWith(
                      color: AdminTheme.darkGrey,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: priorityColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    priority.toUpperCase(),
                    style: AdminTheme.labelSmall.copyWith(
                      color: priorityColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: AdminTheme.labelSmall.copyWith(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              category,
              style: AdminTheme.bodySmall.copyWith(
                color: AdminTheme.darkGrey,
              ),
            ),
            if (createdAt != null)
              Text(
                'Created: ${DateFormat('MMM dd, yyyy - HH:mm').format(createdAt)}',
                style: AdminTheme.bodySmall.copyWith(
                  color: AdminTheme.darkGrey,
                ),
              ),
          ],
        ),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildTicketDetails(ticket),
                const SizedBox(height: 16),
                _buildTicketActions(ticketId, status),
                const SizedBox(height: 16),
                _buildResponseSection(ticketId),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTicketDetails(Map<String, dynamic> ticket) {
    final description = ticket['description'] as String? ?? 'No description available';
    final customerEmail = ticket['customerEmail'] as String? ?? '';
    final customerPhone = ticket['customerPhone'] as String? ?? '';
    final orderId = ticket['orderId'] as String?;
    final createdAt = (ticket['createdAt'] as Timestamp?)?.toDate();
    final updatedAt = (ticket['updatedAt'] as Timestamp?)?.toDate();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ticket Details',
          style: AdminTheme.titleSmall.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          description,
          style: AdminTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Customer Email:',
              style: AdminTheme.bodySmall.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              customerEmail,
              style: AdminTheme.bodySmall,
            ),
          ],
        ),
        if (customerPhone.isNotEmpty) ...[
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Customer Phone:',
                style: AdminTheme.bodySmall.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                customerPhone,
                style: AdminTheme.bodySmall,
              ),
            ],
          ),
        ],
        if (orderId != null) ...[
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Order ID:',
                style: AdminTheme.bodySmall.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                orderId.substring(0, 8),
                style: AdminTheme.bodySmall,
              ),
            ],
          ),
        ],
        if (createdAt != null) ...[
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Created:',
                style: AdminTheme.bodySmall.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                DateFormat('MMM dd, yyyy - HH:mm').format(createdAt),
                style: AdminTheme.bodySmall,
              ),
            ],
          ),
        ],
        if (updatedAt != null) ...[
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Last Updated:',
                style: AdminTheme.bodySmall.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                DateFormat('MMM dd, yyyy - HH:mm').format(updatedAt),
                style: AdminTheme.bodySmall,
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildTicketActions(String ticketId, String currentStatus) {
    final nextStatuses = _getNextStatuses(currentStatus);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: AdminTheme.titleSmall.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                'Update Status',
                Icons.edit,
                () => _showStatusDialog(ticketId, currentStatus),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildActionButton(
                'Add Response',
                Icons.reply,
                () => _showResponseDialog(ticketId),
              ),
            ),
          ],
        ),
        if (nextStatuses.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: nextStatuses.map((status) {
              return ElevatedButton(
                onPressed: () => _updateTicketStatus(ticketId, status),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AdminTheme.deepTeal,
                  foregroundColor: AdminTheme.angel,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: AdminTheme.labelSmall.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildActionButton(String label, IconData icon, VoidCallback onPressed) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(
        label,
        style: AdminTheme.labelSmall.copyWith(
          fontWeight: FontWeight.bold,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: AdminTheme.deepTeal,
        foregroundColor: AdminTheme.angel,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  Widget _buildResponseSection(String ticketId) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Responses',
          style: AdminTheme.titleSmall.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        StreamBuilder<QuerySnapshot>(
          stream: widget.firestore
              .collection('support_tickets')
              .doc(ticketId)
              .collection('responses')
              .orderBy('timestamp', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Text(
                'Error loading responses: ${snapshot.error}',
                style: AdminTheme.bodySmall.copyWith(
                  color: Colors.red,
                ),
              );
            }
            
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            
            final responses = snapshot.data!.docs;
            
            if (responses.isEmpty) {
              return Text(
                'No responses yet',
                style: AdminTheme.bodySmall.copyWith(
                  color: AdminTheme.darkGrey,
                ),
              );
            }
            
            return Column(
              children: responses.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final message = data['message'] as String? ?? '';
                final sender = data['sender'] as String? ?? '';
                final timestamp = (data['timestamp'] as Timestamp?)?.toDate();
                
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: sender == 'admin' 
                        ? AdminTheme.deepTeal.withOpacity(0.1)
                        : AdminTheme.whisper,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: sender == 'admin' 
                          ? AdminTheme.deepTeal.withOpacity(0.3)
                          : AdminTheme.silverGray.withOpacity(0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            sender == 'admin' ? 'Admin Response' : 'Customer',
                            style: AdminTheme.labelSmall.copyWith(
                              fontWeight: FontWeight.bold,
                              color: sender == 'admin' 
                                  ? AdminTheme.deepTeal
                                  : AdminTheme.darkGrey,
                            ),
                          ),
                          if (timestamp != null)
                            Text(
                              DateFormat('MMM dd, HH:mm').format(timestamp),
                              style: AdminTheme.labelSmall.copyWith(
                                color: AdminTheme.darkGrey,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        message,
                        style: AdminTheme.bodySmall,
                      ),
                    ],
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  List<String> _getNextStatuses(String currentStatus) {
    switch (currentStatus) {
      case 'Open':
        return ['In Progress', 'Resolved'];
      case 'In Progress':
        return ['Resolved', 'Closed'];
      case 'Resolved':
        return ['Closed'];
      case 'Closed':
        return [];
      default:
        return ['In Progress', 'Resolved'];
    }
  }

  void _showStatusDialog(String ticketId, String currentStatus) {
    final statuses = ['Open', 'In Progress', 'Resolved', 'Closed'];
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Update Ticket Status',
          style: AdminTheme.titleLarge.copyWith(
            color: AdminTheme.deepTeal,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: statuses.map((status) {
            return ListTile(
              title: Text(status),
              leading: Radio<String>(
                value: status,
                groupValue: currentStatus,
                onChanged: (value) {
                  if (value != null) {
                    _updateTicketStatus(ticketId, value);
                    Navigator.of(context).pop();
                  }
                },
              ),
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancel',
              style: AdminTheme.bodyMedium.copyWith(
                color: AdminTheme.darkGrey,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showResponseDialog(String ticketId) {
    final controller = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Add Response',
          style: AdminTheme.titleLarge.copyWith(
            color: AdminTheme.deepTeal,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: TextField(
          controller: controller,
          maxLines: 4,
          decoration: InputDecoration(
            labelText: 'Response Message',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancel',
              style: AdminTheme.bodyMedium.copyWith(
                color: AdminTheme.darkGrey,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                _addResponse(ticketId, controller.text.trim());
                Navigator.of(context).pop();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminTheme.deepTeal,
              foregroundColor: AdminTheme.angel,
            ),
            child: Text(
              'Send',
              style: AdminTheme.bodyMedium.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
} 