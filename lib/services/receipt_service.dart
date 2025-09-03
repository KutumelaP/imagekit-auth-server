import 'package:intl/intl.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class ReceiptService {
  static Future<Uint8List?> generateSellerStatement({
    required String sellerName,
    required String sellerEmail,
    required DateTime from,
    required DateTime to,
    required List<Map<String, dynamic>> moneyInEntries, // gross, commission, net, createdAt, orderNumber
    required List<Map<String, dynamic>> moneyOutEntries, // net/amount, createdAt, id, status
    double startingBalance = 0.0,
    String statementNumber = '',
    Map<String, dynamic>? bankDetails,
    String brandName = 'Food Marketplace Platform',
  }) async {
    try {
      final pdf = pw.Document();

      final periodLabel = '${DateFormat('MMM dd, yyyy').format(from)} - ${DateFormat('MMM dd, yyyy').format(to)}';

      // Compute totals
      double totalIn = 0;
      double totalFees = 0;
      double totalOut = 0;
      for (final e in moneyInEntries) {
        totalIn += (e['gross'] ?? e['amount'] ?? 0).toDouble();
        totalFees += (e['commission'] ?? 0).toDouble();
      }
      for (final e in moneyOutEntries) {
        totalOut += (e['net'] ?? e['amount'] ?? 0).toDouble();
      }

      // Build running balance transactions
      final List<Map<String, dynamic>> txs = [];
      for (final e in moneyInEntries) {
        final gross = (e['gross'] ?? e['amount'] ?? 0).toDouble();
        final comm = (e['commission'] ?? 0).toDouble();
        final net = (e['net'] ?? (gross - comm)).toDouble();
        txs.add({
          'createdAt': e['createdAt'],
          'date': _fmtDate(e['createdAt']),
          'description': 'Sale ${e['orderNumber'] ?? e['orderId'] ?? ''}',
          'in': net,
          'out': 0.0,
        });
      }
      for (final e in moneyOutEntries) {
        final amt = (e['net'] ?? e['amount'] ?? 0).toDouble();
        txs.add({
          'createdAt': e['createdAt'],
          'date': _fmtDate(e['createdAt']),
          'description': 'Payout ${e['id'] ?? ''} ${((e['status'] ?? '') as String).toUpperCase()}',
          'in': 0.0,
          'out': amt,
        });
      }
      txs.sort((a, b) {
        final ad = _toDate(a['createdAt']);
        final bd = _toDate(b['createdAt']);
        return ad.compareTo(bd);
      });
      double running = startingBalance;
      final runningRows = <List<String>>[];
      for (final t in txs) {
        running += (t['in'] as double) - (t['out'] as double);
        runningRows.add([
          t['date'] as String,
          t['description'] as String,
          (t['in'] as double) == 0.0 ? '' : 'R${(t['in'] as double).toStringAsFixed(2)}',
          (t['out'] as double) == 0.0 ? '' : 'R${(t['out'] as double).toStringAsFixed(2)}',
          'R${running.toStringAsFixed(2)}',
        ]);
      }

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(24),
          build: (context) => [
            // Header
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: PdfColors.blue800,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('SELLER STATEMENT', style: pw.TextStyle(color: PdfColors.white, fontSize: 22, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 6),
                      pw.Text(brandName, style: pw.TextStyle(color: PdfColors.white, fontSize: 12)),
                    ],
                  ),
                  pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                    pw.Text(periodLabel, style: pw.TextStyle(color: PdfColors.white, fontSize: 12)),
                    if (statementNumber.isNotEmpty) pw.Text('Statement #: $statementNumber', style: pw.TextStyle(color: PdfColors.white, fontSize: 10)),
                  ]),
                ],
              ),
            ),

            pw.SizedBox(height: 16),

            // Seller Info and Summary
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Seller', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                        pw.Text(sellerName, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
                        if (sellerEmail.isNotEmpty)
                          pw.Text(sellerEmail, style: const pw.TextStyle(fontSize: 10)),
                        if (bankDetails != null) ...[
                          pw.SizedBox(height: 8),
                          pw.Text('Bank Details', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                          pw.Text('${bankDetails['accountHolder'] ?? ''}', style: const pw.TextStyle(fontSize: 10)),
                          pw.Text('${bankDetails['bankName'] ?? ''} - ${bankDetails['accountType'] ?? ''}', style: const pw.TextStyle(fontSize: 10)),
                          pw.Text('Acc: ${bankDetails['accountNumber'] ?? ''}  Branch: ${bankDetails['branchCode'] ?? ''}', style: const pw.TextStyle(fontSize: 10)),
                        ],
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 12),
                  pw.Container(
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.white,
                      borderRadius: pw.BorderRadius.circular(8),
                      border: pw.Border.all(color: PdfColors.grey300),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        _buildDetailRow('Opening Balance (before period)', 'R${startingBalance.toStringAsFixed(2)}'),
                        _buildDetailRow('Money In (sales)', 'R${totalIn.toStringAsFixed(2)}'),
                        _buildDetailRow('Platform Fees', 'R${totalFees.toStringAsFixed(2)}'),
                        _buildDetailRow('Money Out (payouts)', 'R${totalOut.toStringAsFixed(2)}'),
                        pw.Divider(),
                        _buildDetailRow('Net Movement', 'R${(totalIn - totalFees - totalOut).toStringAsFixed(2)}'),
                        _buildDetailRow('Ending Balance', 'R${(startingBalance + totalIn - totalFees - totalOut).toStringAsFixed(2)}'),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            pw.SizedBox(height: 16),

            pw.Text('Running Balance', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
            pw.SizedBox(height: 6),
            _buildTable(
              headers: ['Date', 'Description', 'In', 'Out', 'Balance'],
              rows: runningRows,
            ),

            pw.SizedBox(height: 16),

            // Money In Table
            pw.Text('Money In (Sales)', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.green800)),
            pw.SizedBox(height: 6),
            _buildTable(
              headers: ['Date', 'Order', 'Gross', 'Commission', 'Net'],
              rows: moneyInEntries.map((e) {
                final dateStr = _fmtDate(e['createdAt']);
                final order = (e['orderNumber'] ?? e['orderId'] ?? '').toString();
                final gross = (e['gross'] ?? e['amount'] ?? 0).toDouble();
                final comm = (e['commission'] ?? 0).toDouble();
                final net = (e['net'] ?? (gross - comm)).toDouble();
                return [dateStr, order, 'R${gross.toStringAsFixed(2)}', 'R${comm.toStringAsFixed(2)}', 'R${net.toStringAsFixed(2)}'];
              }).toList(),
              totals: ['Totals', '', 'R${totalIn.toStringAsFixed(2)}', 'R${totalFees.toStringAsFixed(2)}', 'R${(totalIn - totalFees).toStringAsFixed(2)}'],
            ),

            pw.SizedBox(height: 16),

            // Money Out Table
            pw.Text('Money Out (Payouts)', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.red800)),
            pw.SizedBox(height: 6),
            _buildTable(
              headers: ['Date', 'Payout ID', 'Amount', 'Status'],
              rows: moneyOutEntries.map((e) {
                final dateStr = _fmtDate(e['createdAt']);
                final id = (e['id'] ?? '').toString();
                final amount = (e['net'] ?? e['amount'] ?? 0).toDouble();
                final status = (e['status'] ?? '').toString();
                return [dateStr, id, 'R${amount.toStringAsFixed(2)}', status.toUpperCase()];
              }).toList(),
              totals: ['Totals', '', 'R${totalOut.toStringAsFixed(2)}', ''],
            ),

            pw.SizedBox(height: 16),

            pw.Text('Notes', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
            pw.SizedBox(height: 4),
            pw.Text(
              'This statement summarizes completed order earnings (money in) and payout requests (money out) for the selected period. "Opening Balance" is the carryover before the period and is calculated as: current available balance minus in‑period money in plus in‑period money out. If VAT applies, platform fees may be VAT inclusive.',
              style: const pw.TextStyle(fontSize: 10),
            ),
          ],
        ),
      );

      final bytes = await pdf.save();
      return bytes;
    } catch (e) {
      print('Error generating seller statement: $e');
      return null;
    }
  }

  static Future<Uint8List?> generateSellerStatementCsv({
    required String sellerName,
    required DateTime from,
    required DateTime to,
    required List<Map<String, dynamic>> moneyInEntries,
    required List<Map<String, dynamic>> moneyOutEntries,
    double startingBalance = 0.0,
  }) async {
    try {
      final List<Map<String, dynamic>> txs = [];
      for (final e in moneyInEntries) {
        final gross = (e['gross'] ?? e['amount'] ?? 0).toDouble();
        final comm = (e['commission'] ?? 0).toDouble();
        final net = (e['net'] ?? (gross - comm)).toDouble();
        txs.add({
          'createdAt': e['createdAt'],
          'type': 'IN',
          'reference': (e['orderNumber'] ?? e['orderId'] ?? '').toString(),
          'gross': gross,
          'commission': comm,
          'in': net,
          'out': 0.0,
        });
      }
      for (final e in moneyOutEntries) {
        final amt = (e['net'] ?? e['amount'] ?? 0).toDouble();
        txs.add({
          'createdAt': e['createdAt'],
          'type': 'OUT',
          'reference': (e['id'] ?? '').toString(),
          'gross': 0.0,
          'commission': 0.0,
          'in': 0.0,
          'out': amt,
        });
      }
      txs.sort((a, b) => _toDate(a['createdAt']).compareTo(_toDate(b['createdAt'])));
      double running = startingBalance;
      final rows = <List<String>>[];
      rows.add(['Seller', sellerName]);
      rows.add(['Period', '${DateFormat('yyyy-MM-dd').format(from)} to ${DateFormat('yyyy-MM-dd').format(to)}']);
      rows.add(['Starting Balance', startingBalance.toStringAsFixed(2)]);
      rows.add([]);
      rows.add(['Date','Type','Reference','Gross','Commission','In','Out','Balance']);
      for (final t in txs) {
        running += (t['in'] as double) - (t['out'] as double);
        rows.add([
          DateFormat('yyyy-MM-dd HH:mm').format(_toDate(t['createdAt'])),
          t['type'] as String,
          t['reference'] as String,
          (t['gross'] as double).toStringAsFixed(2),
          (t['commission'] as double).toStringAsFixed(2),
          (t['in'] as double).toStringAsFixed(2),
          (t['out'] as double).toStringAsFixed(2),
          running.toStringAsFixed(2),
        ]);
      }
      final csv = rows.map((r) => r.map((c) => _csvEscape(c)).join(',')).join('\n');
      return Uint8List.fromList(csv.codeUnits);
    } catch (e) {
      print('Error generating seller statement CSV: $e');
      return null;
    }
  }

  static Future<Uint8List?> generatePayoutReceipt({
    required Map<String, dynamic> payoutData,
    required String sellerName,
    required String sellerEmail,
  }) async {
    try {
      final pdf = pw.Document();
      
      // Add receipt page
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) => _buildReceiptPage(
            payoutData: payoutData,
            sellerName: sellerName,
            sellerEmail: sellerEmail,
          ),
        ),
      );

      final bytes = await pdf.save();
      return bytes;
    } catch (e) {
      print('Error generating receipt: $e');
      return null;
    }
  }

  static pw.Widget _buildReceiptPage({
    required Map<String, dynamic> payoutData,
    required String sellerName,
    required String sellerEmail,
  }) {
    final currentDate = DateFormat('MMM dd, yyyy HH:mm').format(DateTime.now());
    final grossAmount = 'R${(payoutData['gross'] ?? 0).toStringAsFixed(2)}';
    final commissionAmount = 'R${(payoutData['commission'] ?? 0).toStringAsFixed(2)}';
    final netAmount = 'R${(payoutData['net'] ?? 0).toStringAsFixed(2)}';
    final commissionRate = '${(payoutData['commissionPct'] ?? 0).toStringAsFixed(1)}%';
    final footerText = 'Generated on $currentDate';
    
    return pw.Container(
      padding: const pw.EdgeInsets.all(20),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Header
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: PdfColors.blue800,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(
              children: [
                pw.Text(
                  'PAYOUT RECEIPT',
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  'Food Marketplace Platform',
                  style: pw.TextStyle(
                    fontSize: 16,
                    color: PdfColors.white,
                  ),
                ),
              ],
            ),
          ),
          
          pw.SizedBox(height: 20),
          
          // Seller Info
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Row(
              children: [
                pw.Text(
                  'Seller:',
                  style: pw.TextStyle(fontSize: 20),
                ),
                pw.SizedBox(width: 12),
                pw.Text(
                  sellerName,
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue800,
                  ),
                ),
              ],
            ),
          ),
          
          pw.SizedBox(height: 20),
          
          // Transaction Flow Section
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Transaction Flow',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue800,
                  ),
                ),
                pw.SizedBox(height: 16),
                
                // Money In Section
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.green50,
                    borderRadius: pw.BorderRadius.circular(6),
                    border: pw.Border.all(color: PdfColors.green300),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        children: [
                          pw.Text(
                            '💰 MONEY IN (From Buyers)',
                            style: pw.TextStyle(
                              fontSize: 14,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.green800,
                            ),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 8),
                      _buildDetailRow('Total Sales:', grossAmount),
                      pw.Text(
                        'This is the total amount customers paid for your products',
                        style: pw.TextStyle(
                          fontSize: 10,
                          color: PdfColors.grey600,
                          fontStyle: pw.FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
                
                pw.SizedBox(height: 12),
                
                // Money Out Section
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.red50,
                    borderRadius: pw.BorderRadius.circular(6),
                    border: pw.Border.all(color: PdfColors.red300),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        children: [
                          pw.Text(
                            '💸 MONEY OUT (Platform Fees)',
                            style: pw.TextStyle(
                              fontSize: 14,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.red800,
                            ),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 8),
                      _buildDetailRow('Platform Commission:', commissionAmount),
                      _buildDetailRow('Commission Rate:', commissionRate),
                      pw.Text(
                        'This covers payment processing, hosting, support, and platform maintenance',
                        style: pw.TextStyle(
                          fontSize: 10,
                          color: PdfColors.grey600,
                          fontStyle: pw.FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
                
                pw.SizedBox(height: 12),
                
                // Net Amount Section
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.blue50,
                    borderRadius: pw.BorderRadius.circular(6),
                    border: pw.Border.all(color: PdfColors.blue300),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        children: [
                          pw.Text(
                            '💳 YOUR PAYOUT',
                            style: pw.TextStyle(
                              fontSize: 14,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.blue800,
                            ),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 8),
                      _buildDetailRow('Net Amount:', netAmount),
                      pw.Text(
                        'This is your money after platform fees - transferred to your bank account',
                        style: pw.TextStyle(
                          fontSize: 10,
                          color: PdfColors.grey600,
                          fontStyle: pw.FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          pw.SizedBox(height: 20),
          
          // Payout Details
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Payout Information',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue800,
                  ),
                ),
                pw.SizedBox(height: 16),
                _buildDetailRow('Receipt Number:', payoutData['id'] ?? 'N/A'),
                _buildDetailRow('Date:', currentDate),
                _buildDetailRow('Status:', payoutData['status'] ?? 'Completed'),
                _buildDetailRow('Reference:', payoutData['reference'] ?? 'N/A'),
              ],
            ),
          ),
          
          pw.SizedBox(height: 30),
          
          // Footer
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(
              children: [
                pw.Text(
                  'Thank you for using our platform!',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue800,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  footerText,
                  style: pw.TextStyle(
                    fontSize: 12,
                    color: PdfColors.grey600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildTable({
    required List<String> headers,
    required List<List<String>> rows,
    List<String>? totals,
  }) {
    final data = <List<String>>[...rows];
    if (totals != null) {
      data.add(totals);
    }

    final columnWidths = <int, pw.TableColumnWidth>{
      0: pw.FlexColumnWidth(2),
      1: pw.FlexColumnWidth(2),
      2: pw.FlexColumnWidth(1.5),
      3: pw.FlexColumnWidth(1.5),
    };
    if (headers.length > 4) {
      columnWidths[4] = pw.FlexColumnWidth(1.5);
    }

    final cellAlignments = <int, pw.Alignment>{
      2: pw.Alignment.centerRight,
      3: pw.Alignment.centerRight,
    };
    if (headers.length > 4) {
      cellAlignments[4] = pw.Alignment.centerRight;
    }

    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: data,
      border: null,
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
      cellAlignment: pw.Alignment.centerLeft,
      columnWidths: columnWidths,
      cellAlignments: cellAlignments,
      cellStyle: const pw.TextStyle(fontSize: 10),
      rowDecoration: const pw.BoxDecoration(color: PdfColors.white),
    );
  }

  static String _fmtDate(dynamic ts) {
    try {
      if (ts is DateTime) return DateFormat('yyyy-MM-dd HH:mm').format(ts);
      // Firestore Timestamp-like
      final dynamic maybe = ts;
      if (maybe != null && maybe.toString().contains('Timestamp')) {
        // Best-effort, call toDate if available
        final toDate = (maybe as dynamic).toDate?.call();
        if (toDate is DateTime) return DateFormat('yyyy-MM-dd HH:mm').format(toDate);
      }
    } catch (_) {}
    return '';
  }

  static DateTime _toDate(dynamic ts) {
    try {
      if (ts is DateTime) return ts;
      final dynamic maybe = ts;
      final toDate = (maybe as dynamic).toDate?.call();
      if (toDate is DateTime) return toDate;
    } catch (_) {}
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  static String _csvEscape(String s) {
    if (s.contains(',') || s.contains('\n') || s.contains('"')) {
      return '"' + s.replaceAll('"', '""') + '"';
    }
    return s;
  }

  static pw.Widget _buildDetailRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 120,
            child: pw.Text(
              label,
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }

  static Future<void> openPDF(File file) async {
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => await file.readAsBytes(),
    );
  }
}
