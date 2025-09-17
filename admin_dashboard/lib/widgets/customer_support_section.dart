import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../theme/admin_theme.dart';

/// Customer support management section for admin dashboard
class CustomerSupportSection extends StatefulWidget {
  const CustomerSupportSection({Key? key}) : super(key: key);

  @override
  State<CustomerSupportSection> createState() => _CustomerSupportSectionState();
}

class _CustomerSupportSectionState extends State<CustomerSupportSection> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  List<Map<String, dynamic>> _conversations = [];
  Map<String, dynamic>? _selectedConversation;
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  String _filter = 'all'; // all, active, unresolved
  
  // Support settings
  int _selectedTab = 0; // 0 = Conversations, 1 = Settings
  final TextEditingController _supportNumberController = TextEditingController();
  final TextEditingController _supportMessageController = TextEditingController();
  bool _isSavingSettings = false;
  
  @override
  void initState() {
    super.initState();
    _loadConversations();
    _loadSupportSettings();
  }

  @override
  void dispose() {
    _supportNumberController.dispose();
    _supportMessageController.dispose();
    super.dispose();
  }

  Future<void> _loadSupportSettings() async {
    try {
      final doc = await _firestore
          .collection('app_config')
          .doc('general_settings')
          .get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        setState(() {
          _supportNumberController.text = data['supportNumber'] ?? '069 361 7576';
          _supportMessageController.text = data['supportMessage'] ?? 'Hi! I need help with my order. Order ID: {ORDER_ID}';
        });
      } else {
        // Set defaults
        setState(() {
          _supportNumberController.text = '069 361 7576';
          _supportMessageController.text = 'Hi! I need help with my order. Order ID: {ORDER_ID}';
        });
      }
    } catch (e) {
      print('Error loading support settings: $e');
      // Set defaults on error
      setState(() {
        _supportNumberController.text = '069 361 7576';
        _supportMessageController.text = 'Hi! I need help with my order. Order ID: {ORDER_ID}';
      });
    }
  }

  Future<void> _saveSupportSettings() async {
    if (_supportNumberController.text.trim().isEmpty || 
        _supportMessageController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all fields'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSavingSettings = true);

    try {
      // Format phone number for WhatsApp
      String phoneNumber = _supportNumberController.text.trim();
      // Remove all non-digit characters
      String cleaned = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
      // If it starts with 0, replace with 27 (South Africa country code)
      if (cleaned.startsWith('0')) {
        cleaned = '27${cleaned.substring(1)}';
      }
      // If it doesn't start with 27, add it
      if (!cleaned.startsWith('27')) {
        cleaned = '27$cleaned';
      }

      await _firestore
          .collection('app_config')
          .doc('general_settings')
          .set({
        'supportNumber': cleaned,
        'supportMessage': _supportMessageController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Support settings saved successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving settings: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isSavingSettings = false);
    }
  }

  Future<void> _loadConversations() async {
    setState(() => _isLoading = true);
    
    try {
      Query query = _firestore
          .collection('chatbot_conversations')
          .orderBy('lastMessageAt', descending: true);
      
      // Apply filters
      switch (_filter) {
        case 'active':
          query = query.where('isActive', isEqualTo: true);
          break;
        case 'unresolved':
          query = query.where('status', isEqualTo: 'active')
                      .where('priority', whereIn: ['high', 'urgent']);
          break;
      }
      
      final snapshot = await query.limit(50).get();
      
      _conversations = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();
      
      // Update analytics
      await _updateSupportAnalytics();
      
    } catch (e) {
      print('❌ Error loading conversations: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMessages(String conversationId) async {
    try {
      final messagesSnapshot = await _firestore
          .collection('chatbot_conversations')
          .doc(conversationId)
          .collection('messages')
          .orderBy('timestamp', descending: false)
          .get();
      
      _messages = messagesSnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();
      
      setState(() {});
    } catch (e) {
      print('❌ Error loading messages: $e');
    }
  }

  Future<void> _updateSupportAnalytics() async {
    try {
      final activeCount = _conversations.where((c) => c['isActive'] == true).length;
      final unresolvedCount = _conversations.where((c) => 
          c['status'] == 'active' && 
          (c['priority'] == 'high' || c['priority'] == 'urgent')).length;
      
      await _firestore.collection('chatbot_analytics').doc('summary').set({
        'totalConversations': _conversations.length,
        'activeConversations': activeCount,
        'unresolvedConversations': unresolvedCount,
        'lastUpdated': FieldValue.serverTimestamp(),
        'avgResponseTime': _calculateAvgResponseTime(),
        'topIssues': _getTopIssues(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('❌ Error updating analytics: $e');
    }
  }

  double _calculateAvgResponseTime() {
    // Simplified calculation - in production, track actual response times
    return 5.2; // minutes
  }

  List<Map<String, dynamic>> _getTopIssues() {
    final issues = <String, int>{};
    
    for (final conversation in _conversations) {
      final tags = conversation['tags'] as List<dynamic>? ?? [];
      for (final tag in tags) {
        issues[tag.toString()] = (issues[tag.toString()] ?? 0) + 1;
      }
    }
    
    final sortedIssues = issues.entries
        .map((e) => {'issue': e.key, 'count': e.value})
        .toList()
      ..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));
    
    return sortedIssues.take(5).toList();
  }

  Future<void> _updateConversationStatus(String conversationId, String status) async {
    try {
      await _firestore
          .collection('chatbot_conversations')
          .doc(conversationId)
          .update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      // Update local state
      final index = _conversations.indexWhere((c) => c['id'] == conversationId);
      if (index != -1) {
        setState(() {
          _conversations[index]['status'] = status;
        });
      }
    } catch (e) {
      print('❌ Error updating conversation status: $e');
    }
  }

  Future<void> _addAdminResponse(String conversationId, String message) async {
    try {
      final messageDoc = {
        'text': message,
        'isUser': false,
        'timestamp': Timestamp.now(),
        'type': 'admin_response',
        'adminId': 'admin', // In production, use actual admin ID
      };
      
      // Add message to conversation
      await _firestore
          .collection('chatbot_conversations')
          .doc(conversationId)
          .collection('messages')
          .add(messageDoc);
      
      // Update conversation metadata
      await _firestore
          .collection('chatbot_conversations')
          .doc(conversationId)
          .update({
        'lastMessageAt': FieldValue.serverTimestamp(),
        'messageCount': FieldValue.increment(1),
        'status': 'admin_responded',
      });
      
      // Reload messages
      await _loadMessages(conversationId);
    } catch (e) {
      print('❌ Error adding admin response: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 24),
          _buildTabBar(),
          const SizedBox(height: 24),
          Expanded(
            child: _selectedTab == 0 ? _buildConversationsTab() : _buildSettingsTab(),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildTabButton('Conversations', 0, Icons.chat),
          ),
          Expanded(
            child: _buildTabButton('Settings', 1, Icons.settings),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(String title, int index, IconData icon) {
    final isSelected = _selectedTab == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected ? AdminTheme.primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : Colors.grey[600],
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey[600],
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConversationsTab() {
    return Column(
      children: [
        _buildSummaryCards(),
        const SizedBox(height: 24),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Conversations list
              Expanded(
                flex: 1,
                child: _buildConversationsList(),
              ),
              const SizedBox(width: 16),
              // Selected conversation details
              Expanded(
                flex: 2,
                child: _buildConversationDetails(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsTab() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSettingsHeader(),
          const SizedBox(height: 24),
          _buildSupportSettingsForm(),
        ],
      ),
    );
  }

  Widget _buildSettingsHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AdminTheme.primaryColor, AdminTheme.primaryColor.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.support_agent,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Seller Contact Configuration',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Configure fallback support number when seller contact is unavailable',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSupportSettingsForm() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Seller Contact Fallback Settings',
              style: AdminTheme.headlineMedium.copyWith(
                color: AdminTheme.primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            
            // Support Number
            TextFormField(
              controller: _supportNumberController,
              decoration: InputDecoration(
                labelText: 'Fallback Support WhatsApp Number',
                hintText: '069 361 7576',
                prefixIcon: const Icon(Icons.phone),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                helperText: 'Used when seller contact number is not available',
              ),
            ),
            const SizedBox(height: 20),
            
            // Support Message Template
            TextFormField(
              controller: _supportMessageController,
              decoration: InputDecoration(
                labelText: 'Support Message Template',
                hintText: 'Hi! I need help with my order. Order ID: {ORDER_ID}',
                prefixIcon: const Icon(Icons.message),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                helperText: 'Use {ORDER_ID} as placeholder for the order ID',
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 20),
            
            // Info Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue[600], size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Configuration Info',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[600],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• Customers will contact the seller directly via WhatsApp',
                    style: TextStyle(fontSize: 14, color: Colors.blue[700]),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '• Fallback number used only when seller contact is unavailable',
                    style: TextStyle(fontSize: 14, color: Colors.blue[700]),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '• The {ORDER_ID} placeholder will be replaced with the actual order ID',
                    style: TextStyle(fontSize: 14, color: Colors.blue[700]),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '• Phone numbers are automatically formatted for WhatsApp (wa.me)',
                    style: TextStyle(fontSize: 14, color: Colors.blue[700]),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // Save Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSavingSettings ? null : _saveSupportSettings,
                icon: _isSavingSettings
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save),
                label: Text(_isSavingSettings ? 'Saving...' : 'Save Settings'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AdminTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Icon(
          Icons.support_agent,
          size: 32,
          color: AdminTheme.primaryColor,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Customer Support',
                style: AdminTheme.headlineLarge,
              ),
              Text(
                'Manage chatbot conversations and customer inquiries',
                style: AdminTheme.bodyMedium.copyWith(
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
        _buildFilterDropdown(),
        const SizedBox(width: 16),
        ElevatedButton.icon(
          onPressed: _loadConversations,
          icon: const Icon(Icons.refresh),
          label: const Text('Refresh'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AdminTheme.primaryColor,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildFilterDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _filter,
          items: const [
            DropdownMenuItem(value: 'all', child: Text('All Conversations')),
            DropdownMenuItem(value: 'active', child: Text('Active Only')),
            DropdownMenuItem(value: 'unresolved', child: Text('Unresolved')),
          ],
          onChanged: (value) {
            if (value != null) {
              setState(() => _filter = value);
              _loadConversations();
            }
          },
        ),
      ),
    );
  }

  Widget _buildSummaryCards() {
    final activeCount = _conversations.where((c) => c['isActive'] == true).length;
    final unresolvedCount = _conversations.where((c) => 
        c['status'] == 'active' && 
        (c['priority'] == 'high' || c['priority'] == 'urgent')).length;
    
    return Row(
      children: [
        Expanded(
          child: _buildSummaryCard(
            'Total Conversations',
            _conversations.length.toString(),
            Icons.chat_bubble_outline,
            Colors.blue,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildSummaryCard(
            'Active Chats',
            activeCount.toString(),
            Icons.chat,
            Colors.green,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildSummaryCard(
            'Needs Attention',
            unresolvedCount.toString(),
            Icons.priority_high,
            Colors.orange,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildSummaryCard(
            'Avg Response',
            '5.2 min',
            Icons.timer,
            Colors.purple,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const Spacer(),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConversationsList() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Conversations',
              style: AdminTheme.headlineMedium,
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: _conversations.length,
                    itemBuilder: (context, index) {
                      final conversation = _conversations[index];
                      return _buildConversationTile(conversation);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildConversationTile(Map<String, dynamic> conversation) {
    final isSelected = _selectedConversation?['id'] == conversation['id'];
    final isActive = conversation['isActive'] ?? false;
    final priority = conversation['priority'] ?? 'normal';
    final lastMessageAt = conversation['lastMessageAt'] as Timestamp?;
    
    Color priorityColor = Colors.grey;
    if (priority == 'high') priorityColor = Colors.orange;
    if (priority == 'urgent') priorityColor = Colors.red;
    
    return Container(
      decoration: BoxDecoration(
        color: isSelected ? AdminTheme.primaryColor.withOpacity(0.1) : null,
        border: Border(
          left: BorderSide(
            color: isSelected ? AdminTheme.primaryColor : Colors.transparent,
            width: 3,
          ),
        ),
      ),
      child: ListTile(
        leading: Stack(
          children: [
            CircleAvatar(
              backgroundColor: priorityColor.withOpacity(0.2),
              child: Text(
                (conversation['userName']?.toString().isNotEmpty == true) 
                  ? conversation['userName'].toString().substring(0, 1).toUpperCase() 
                  : 'U',
                style: TextStyle(color: priorityColor, fontWeight: FontWeight.bold),
              ),
            ),
            if (isActive)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
        title: Text(
          conversation['userName'] ?? 'Anonymous User',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              conversation['userEmail'] ?? '',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            Text(
              '${conversation['messageCount'] ?? 0} messages',
              style: TextStyle(color: Colors.grey[500], fontSize: 11),
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (lastMessageAt != null)
              Text(
                _formatTimestamp(lastMessageAt),
                style: TextStyle(color: Colors.grey[500], fontSize: 11),
              ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: _getStatusColor(conversation['status']),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                conversation['status'] ?? 'active',
                style: const TextStyle(color: Colors.white, fontSize: 10),
              ),
            ),
          ],
        ),
        onTap: () {
          setState(() => _selectedConversation = conversation);
          _loadMessages(conversation['id']);
        },
      ),
    );
  }

  Widget _buildConversationDetails() {
    if (_selectedConversation == null) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text('Select a conversation to view details'),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildConversationHeader(),
          const Divider(height: 1),
          Expanded(child: _buildMessagesList()),
          const Divider(height: 1),
          _buildAdminResponseArea(),
        ],
      ),
    );
  }

  Widget _buildConversationHeader() {
    final conversation = _selectedConversation!;
    
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AdminTheme.primaryColor.withOpacity(0.2),
            child: Text(
              (conversation['userName']?.toString().isNotEmpty == true) 
                  ? conversation['userName']!.toString().substring(0, 1).toUpperCase()
                  : 'U',
              style: TextStyle(color: AdminTheme.primaryColor, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  conversation['userName'] ?? 'Anonymous User',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                ),
                Text(
                  conversation['userEmail'] ?? '',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              _updateConversationStatus(conversation['id'], value);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'active', child: Text('Mark Active')),
              const PopupMenuItem(value: 'resolved', child: Text('Mark Resolved')),
              const PopupMenuItem(value: 'escalated', child: Text('Escalate')),
              const PopupMenuItem(value: 'closed', child: Text('Close')),
            ],
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _getStatusColor(conversation['status']),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    conversation['status'] ?? 'active',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_drop_down, color: Colors.white, size: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessagesList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        return _buildMessageBubble(message);
      },
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> message) {
    final isUser = message['isUser'] ?? false;
    final isAdmin = message['type'] == 'admin_response';
    final timestamp = message['timestamp'] as Timestamp?;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: isAdmin ? AdminTheme.primaryColor : Colors.grey[400],
              child: Icon(
                isAdmin ? Icons.admin_panel_settings : Icons.smart_toy,
                color: Colors.white,
                size: 16,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isUser 
                    ? AdminTheme.primaryColor
                    : isAdmin 
                        ? Colors.green[100]
                        : Colors.grey[100],
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message['text'] ?? '',
                    style: TextStyle(
                      color: isUser ? Colors.white : Colors.black87,
                      fontSize: 14,
                    ),
                  ),
                  if (timestamp != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      _formatMessageTime(timestamp),
                      style: TextStyle(
                        color: isUser ? Colors.white70 : Colors.grey[600],
                        fontSize: 10,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.blue[400],
              child: const Icon(Icons.person, color: Colors.white, size: 16),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAdminResponseArea() {
    final controller = TextEditingController();
    
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: 'Type admin response...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
              ),
              maxLines: null,
              onSubmitted: (text) {
                if (text.trim().isNotEmpty) {
                  _addAdminResponse(_selectedConversation!['id'], text.trim());
                  controller.clear();
                }
              },
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isNotEmpty) {
                _addAdminResponse(_selectedConversation!['id'], text);
                controller.clear();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminTheme.primaryColor,
              foregroundColor: Colors.white,
              shape: const CircleBorder(),
              padding: const EdgeInsets.all(16),
            ),
            child: const Icon(Icons.send),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'active':
        return Colors.green;
      case 'resolved':
        return Colors.blue;
      case 'escalated':
        return Colors.orange;
      case 'closed':
        return Colors.grey;
      case 'admin_responded':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  String _formatTimestamp(Timestamp timestamp) {
    final date = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inMinutes < 1) {
      return 'now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h';
    } else {
      return DateFormat('MMM d').format(date);
    }
  }

  String _formatMessageTime(Timestamp timestamp) {
    return DateFormat('HH:mm').format(timestamp.toDate());
  }
}
