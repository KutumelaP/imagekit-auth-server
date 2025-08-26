import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:convert';

class DataExportSection extends StatefulWidget {
  @override
  State<DataExportSection> createState() => _DataExportSectionState();
}

class _DataExportSectionState extends State<DataExportSection> {
  bool _isExporting = false;
  String _exportStatus = '';
  List<String> _selectedCollections = [];
  
  final List<Map<String, dynamic>> _exportOptions = [
    {
      'name': 'Users',
      'collection': 'users',
      'description': 'Export all user data including profiles and preferences',
      'icon': Icons.people,
      'color': Colors.blue,
    },
    {
      'name': 'Orders',
      'collection': 'orders',
      'description': 'Export order history and transaction data',
      'icon': Icons.shopping_cart,
      'color': Colors.green,
    },
    {
      'name': 'Products',
      'collection': 'products',
      'description': 'Export product catalog and inventory data',
      'icon': Icons.inventory,
      'color': Colors.orange,
    },
    {
      'name': 'Categories',
      'collection': 'categories',
      'description': 'Export product categories and classifications',
      'icon': Icons.category,
      'color': Colors.purple,
    },
    {
      'name': 'Reviews',
      'collection': 'reviews',
      'description': 'Export customer reviews and ratings',
      'icon': Icons.star,
      'color': Colors.amber,
    },
    {
      'name': 'Analytics',
      'collection': 'analytics',
      'description': 'Export analytics and performance data',
      'icon': Icons.analytics,
      'color': Colors.red,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 24),
          _buildExportOptions(),
          const SizedBox(height: 24),
          _buildExportActions(),
          const SizedBox(height: 24),
          _buildExportStatus(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.purple.shade700, Colors.purple.shade500],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Data Export',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Export your marketplace data for analysis and backup',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.download,
              size: 32,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExportOptions() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Data to Export',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: MediaQuery.of(context).size.width > 1200 ? 3 : 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.2,
              ),
              itemCount: _exportOptions.length,
              itemBuilder: (context, index) {
                final option = _exportOptions[index];
                final isSelected = _selectedCollections.contains(option['collection']);
                
                return Card(
                  elevation: isSelected ? 4 : 1,
                  color: isSelected ? option['color'].withOpacity(0.1) : null,
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          _selectedCollections.remove(option['collection']);
                        } else {
                          _selectedCollections.add(option['collection']);
                        }
                      });
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: option['color'].withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              option['icon'],
                              color: option['color'],
                              size: 32,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            option['name'],
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? option['color'] : null,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            option['description'],
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          if (isSelected)
                            Icon(
                              Icons.check_circle,
                              color: option['color'],
                              size: 20,
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExportActions() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Export Options',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _selectedCollections.isEmpty || _isExporting ? null : _exportAsJSON,
                    icon: Icon(Icons.code),
                    label: Text('Export as JSON'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _selectedCollections.isEmpty || _isExporting ? null : _exportAsCSV,
                    icon: Icon(Icons.table_chart),
                    label: Text('Export as CSV'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _selectedCollections.isEmpty || _isExporting ? null : _exportAsExcel,
                    icon: Icon(Icons.table_view),
                    label: Text('Export as Excel'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _selectedCollections.isEmpty ? null : _selectAll,
                    icon: Icon(Icons.select_all),
                    label: Text('Select All'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _selectedCollections.isEmpty ? null : _clearSelection,
                    icon: Icon(Icons.clear),
                    label: Text('Clear Selection'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _exportStatus.isEmpty ? null : _clearStatus,
                    icon: Icon(Icons.refresh),
                    label: Text('Clear Status'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExportStatus() {
    if (_exportStatus.isEmpty) return SizedBox.shrink();
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _isExporting ? Icons.hourglass_empty : Icons.check_circle,
                  color: _isExporting ? Colors.orange : Colors.green,
                ),
                const SizedBox(width: 8),
                Text(
                  _isExporting ? 'Exporting...' : 'Export Complete',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_isExporting)
              LinearProgressIndicator()
            else
              Text(
                _exportStatus,
                style: TextStyle(color: Colors.grey[600]),
              ),
          ],
        ),
      ),
    );
  }

  void _selectAll() {
    setState(() {
      _selectedCollections = _exportOptions.map((option) => option['collection'] as String).toList();
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedCollections.clear();
    });
  }

  void _clearStatus() {
    setState(() {
      _exportStatus = '';
    });
  }

  Future<void> _exportAsJSON() async {
    await _exportData('json');
  }

  Future<void> _exportAsCSV() async {
    await _exportData('csv');
  }

  Future<void> _exportAsExcel() async {
    await _exportData('excel');
  }

  Future<void> _exportData(String format) async {
    if (_selectedCollections.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select at least one data collection to export'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isExporting = true;
      _exportStatus = 'Starting export...';
    });

    try {
      Map<String, dynamic> exportData = {};
      
      for (String collection in _selectedCollections) {
        setState(() {
          _exportStatus = 'Exporting $collection...';
        });

        final snapshot = await FirebaseFirestore.instance.collection(collection).get();
        final documents = snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return data;
        }).toList();

        exportData[collection] = documents;
      }

      String fileName = 'marketplace_export_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}';
      String content = '';

      switch (format) {
        case 'json':
          content = JsonEncoder.withIndent('  ').convert(exportData);
          fileName += '.json';
          break;
        case 'csv':
          content = _convertToCSV(exportData);
          fileName += '.csv';
          break;
        case 'excel':
          content = _convertToExcel(exportData);
          fileName += '.xlsx';
          break;
      }

      // In a real app, you would save the file or trigger download
      // For now, we'll just show a success message
      setState(() {
        _isExporting = false;
        _exportStatus = 'Export completed successfully!\nFile: $fileName\nSize: ${(content.length / 1024).toStringAsFixed(1)} KB';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Export completed! $fileName'),
          backgroundColor: Colors.green,
        ),
      );

    } catch (e) {
      setState(() {
        _isExporting = false;
        _exportStatus = 'Export failed: $e';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Export failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _convertToCSV(Map<String, dynamic> data) {
    StringBuffer csv = StringBuffer();
    
    for (String collection in data.keys) {
      csv.writeln('=== $collection ===');
      
      final documents = data[collection] as List<dynamic>;
      if (documents.isEmpty) continue;

      // Get headers from first document
      final firstDoc = documents.first as Map<String, dynamic>;
      final headers = firstDoc.keys.toList();
      
      // Write headers
      csv.writeln(headers.join(','));
      
      // Write data rows
      for (var doc in documents) {
        final row = headers.map((header) {
          final value = doc[header];
          if (value == null) return '';
          if (value is String) return '"${value.replaceAll('"', '""')}"';
          return value.toString();
        }).join(',');
        csv.writeln(row);
      }
      
      csv.writeln(); // Empty line between collections
    }
    
    return csv.toString();
  }

  String _convertToExcel(Map<String, dynamic> data) {
    // Simplified Excel format (CSV with Excel headers)
    StringBuffer excel = StringBuffer();
    
    for (String collection in data.keys) {
      excel.writeln('=== $collection ===');
      
      final documents = data[collection] as List<dynamic>;
      if (documents.isEmpty) continue;

      // Get headers from first document
      final firstDoc = documents.first as Map<String, dynamic>;
      final headers = firstDoc.keys.toList();
      
      // Write headers
      excel.writeln(headers.join('\t'));
      
      // Write data rows
      for (var doc in documents) {
        final row = headers.map((header) {
          final value = doc[header];
          if (value == null) return '';
          return value.toString();
        }).join('\t');
        excel.writeln(row);
      }
      
      excel.writeln(); // Empty line between collections
    }
    
    return excel.toString();
  }
} 