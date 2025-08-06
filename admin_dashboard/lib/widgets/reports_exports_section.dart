import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'dart:html' as html;

class ReportsExportsSection extends StatefulWidget {
  @override
  State<ReportsExportsSection> createState() => _ReportsExportsSectionState();
}

class _ReportsExportsSectionState extends State<ReportsExportsSection> {
  String _reportType = 'orders';
  DateTime? _startDate;
  DateTime? _endDate;
  List<Map<String, dynamic>> _previewData = [];
  bool _loading = false;

  final _reportTypes = const {
    'orders': 'Orders',
    'products': 'Products',
    'users': 'Users',
    'sellers': 'Sellers',
    'returns': 'Returns/Refunds',
  };

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2022),
      lastDate: DateTime.now().add(Duration(days: 1)),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
    );
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }

  Future<void> _fetchPreview() async {
    setState(() => _loading = true);
    Query query;
    switch (_reportType) {
      case 'orders':
        query = FirebaseFirestore.instance.collection('orders');
        break;
      case 'products':
        query = FirebaseFirestore.instance.collection('products');
        break;
      case 'users':
        query = FirebaseFirestore.instance.collection('users');
        break;
      case 'sellers':
        query = FirebaseFirestore.instance.collection('users').where('role', isEqualTo: 'seller');
        break;
      case 'returns':
        query = FirebaseFirestore.instance.collection('returns');
        break;
      default:
        query = FirebaseFirestore.instance.collection('orders');
    }
    if (_startDate != null && _endDate != null) {
      query = query.where('createdAt', isGreaterThanOrEqualTo: _startDate).where('createdAt', isLessThanOrEqualTo: _endDate);
    }
    final snap = await query.limit(100).get();
    _previewData = snap.docs.map((d) => d.data() as Map<String, dynamic>).toList();
    setState(() => _loading = false);
  }

  void _exportCSV() async {
    if (_previewData.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No data to export.')));
      return;
    }
    final headers = _previewData.first.keys.toList();
    final rows = _previewData.map((row) => headers.map((h) => '"${row[h] ?? ''}"').join(',')).toList();
    final csv = StringBuffer();
    csv.writeln(headers.join(','));
    for (final row in rows) {
      csv.writeln(row);
    }
    final bytes = utf8.encode(csv.toString());
    final blob = html.Blob([bytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', '${_reportType}_report.csv')
      ..click();
    html.Url.revokeObjectUrl(url);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('CSV exported.')));
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                DropdownButton<String>(
                  value: _reportType,
                  items: _reportTypes.entries
                      .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                      .toList(),
                  onChanged: (v) => setState(() => _reportType = v ?? 'orders'),
                ),
                const SizedBox(width: 16),
                OutlinedButton.icon(
                  icon: Icon(Icons.date_range),
                  label: Text(_startDate != null && _endDate != null
                      ? '${DateFormat.yMd().format(_startDate!)} - ${DateFormat.yMd().format(_endDate!)}'
                      : 'Pick Date Range'),
                  onPressed: _pickDateRange,
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  icon: Icon(Icons.preview),
                  label: Text('Preview'),
                  onPressed: _fetchPreview,
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  icon: Icon(Icons.download),
                  label: Text('Export CSV'),
                  onPressed: _exportCSV,
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (_loading) const Center(child: CircularProgressIndicator()),
            if (!_loading && _previewData.isNotEmpty)
              Expanded(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Text(
                        'Tip: You can scroll horizontally to see more columns.',
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6), fontStyle: FontStyle.italic, fontSize: 13),
                      ),
                    ),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: _previewData.first.keys
                            .map((k) => DataColumn(label: Text(k)))
                            .toList(),
                        rows: _previewData
                            .map((row) => DataRow(
                                  cells: row.values
                                      .map((v) => DataCell(Text(v.toString().length > 40 ? v.toString().substring(0, 40) + '...' : v.toString())))
                                      .toList(),
                                ))
                            .toList(),
                      ),
                    ),
                  ],
                ),
              ),
            if (!_loading && _previewData.isEmpty)
              const Text('No data to preview. Choose a report type and date range.'),
          ],
        ),
      ),
    );
  }
} 