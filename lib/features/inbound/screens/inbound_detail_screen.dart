import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gudang_app/features/inbound/providers/inbound_providers.dart';
import 'package:gudang_app/main.dart';
import 'package:intl/intl.dart';
import 'package:barcode_widget/barcode_widget.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

final singleTransactionProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, int>((ref, id) async {
  final response = await supabase
      .from('transactions')
      .select('*, items(*)')
      .eq('id', id)
      .single();
  return response;
});

class InboundDetailScreen extends ConsumerWidget {
  const InboundDetailScreen({super.key, required this.transactionId});
  final int transactionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionAsyncValue = ref.watch(singleTransactionProvider(transactionId));

    return Scaffold(
      appBar: AppBar(title: const Text('Rincian Transaksi')),
      body: transactionAsyncValue.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (transaction) {
          return _InboundDetailView(
            key: ValueKey(transaction['id']),
            transaction: transaction,
          );
        },
      ),
    );
  }
}

class _InboundDetailView extends ConsumerStatefulWidget {
  const _InboundDetailView({super.key, required this.transaction});
  final Map<String, dynamic> transaction;

  @override
  ConsumerState<_InboundDetailView> createState() => _InboundDetailViewState();
}

class _InboundDetailViewState extends ConsumerState<_InboundDetailView> {
  late Map<String, dynamic> _currentTransaction;
  List<String> _scannedCodes = [];
  bool _isProcessing = false;
  List<String>? _allocatedRackNumbers;
  bool _isCheckingAllocation = true;

  @override
  void initState() {
    super.initState();
    _currentTransaction = widget.transaction;
    _checkExistingAllocation();
  }

  Future<void> _checkExistingAllocation() async {
    if ((_currentTransaction['status'] ?? 'pending') != 'pending') {
      setState(() => _isCheckingAllocation = false);
      return;
    }
    try {
      final response = await supabase
          .from('item_locations')
          .select('racks(rack_number)')
          .eq('transaction_id', _currentTransaction['id']);
      if (mounted && response.isNotEmpty && response.first['racks'] != null) {
        final existingRacks = response.map((e) => e['racks']['rack_number'] as String).toList();
        setState(() {
          _allocatedRackNumbers = existingRacks;
        });
      }
    } catch (e) {
      // Handle error
    } finally {
      if (mounted) {
        setState(() => _isCheckingAllocation = false);
      }
    }
  }

  Future<void> _allocateAndPrint() async {
    setState(() => _isProcessing = true);
    final item = _currentTransaction['items'];
    if (item == null) {
      setState(() => _isProcessing = false);
      return;
    }
    try {
      final List<dynamic> rackNumbersDynamic = await supabase.rpc('allocate_racks_per_item', params: {
        'p_item_id': item['id'],
        'p_quantity': _currentTransaction['quantity'],
        'p_transaction_id': _currentTransaction['id'],
      });
      final List<String> rackNumbers = rackNumbersDynamic.cast<String>();
      setState(() {
        _allocatedRackNumbers = rackNumbers;
      });
      await _printBarcodes(context, rackNumbers: rackNumbers);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal Alokasi Rak: $error'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _printBarcodes(BuildContext context, {required List<String> rackNumbers}) async {
    final pdf = pw.Document();
    final item = _currentTransaction['items'];
    if (item == null) return;
    final String itemCode = item['item_code'];
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) {
          final List<pw.Widget> qrCodeWidgets = [];
          for (final rackNumber in rackNumbers) {
            final String barcodeData = '$rackNumber$itemCode';
            qrCodeWidgets.add(
              pw.Container(
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey),
                  borderRadius: pw.BorderRadius.circular(5),
                ),
                child: pw.Column(
                  children: [
                    pw.BarcodeWidget(
                      barcode: Barcode.qrCode(),
                      data: barcodeData,
                      width: 80,
                      height: 80,
                    ),
                    pw.SizedBox(height: 5),
                    pw.Text(barcodeData, style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
              ),
            );
          }
          return [pw.Wrap(children: qrCodeWidgets, spacing: 15, runSpacing: 15)];
        },
      ),
    );
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  Future<void> _startVerification() async {
    final item = _currentTransaction['items'];
    final int totalQty = _currentTransaction['quantity'];
    if (item == null || _allocatedRackNumbers == null) return;
    final List<String> expectedCodes = _allocatedRackNumbers!.map((rack) => '$rack${item['item_code']}').toList();
    final scannedCode = await context.push<String>('/scanner');
    if (scannedCode == null) return;
    if (!expectedCodes.contains(scannedCode)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error: Barcode tidak dikenali untuk transaksi ini!'), backgroundColor: Colors.red));
      return;
    }
    if (_scannedCodes.contains(scannedCode)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Info: Barcode ini sudah pernah di-scan.'), backgroundColor: Colors.orange));
      return;
    }
    setState(() {
      _scannedCodes.add(scannedCode);
    });
    if (_scannedCodes.length == totalQty) {
      await _completeTransaction();
    }
  }

  Future<void> _completeTransaction() async {
    final item = _currentTransaction['items'];
    if (item == null) return;
    try {
      final updatedTransaction = await supabase
          .from('transactions')
          .update({'status': 'completed'})
          .eq('id', _currentTransaction['id'])
          .select('*, items(*)')
          .single();
      await supabase.rpc('increment_stock', params: {
        'item_id_to_update': item['id'],
        'quantity_to_add': _currentTransaction['quantity'],
      });
      ref.invalidate(inboundHistoryProvider);
      if (mounted) {
        setState(() {
          _currentTransaction = updatedTransaction;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Verifikasi Selesai! Stok barang telah diperbarui.'), backgroundColor: Colors.green),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyelesaikan transaksi: $error'), backgroundColor: Colors.red),
        );
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final item = _currentTransaction['items'];
    final date = DateTime.parse(_currentTransaction['transaction_date']);
    final formattedDate = DateFormat('EEEE, d MMMM yyyy, HH:mm', 'id_ID').format(date);
    final status = _currentTransaction['status'] ?? 'pending';
    final int totalQty = _currentTransaction['quantity'];
    return _isCheckingAllocation
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              _buildDetailCard(context, item != null ? item['item_name'] : 'Barang Dihapus', [
                _buildDetailRow(Icons.qr_code_2, 'Kode Barang', item != null ? item['item_code'] : 'N/A'),
                _buildDetailRow(Icons.category_outlined, 'Unit', item != null ? item['unit'] : 'N/A'),
                _buildDetailRow(Icons.add_shopping_cart, 'Kuantitas Diterima', '+${_currentTransaction['quantity']}'),
                _buildDetailRow(Icons.calendar_today_outlined, 'Tanggal Transaksi', formattedDate),
                _buildDetailRow(
                  status == 'pending' ? Icons.pending : Icons.check_circle,
                  'Status',
                  status == 'pending' ? 'Pending' : 'Selesai',
                ),
              ]),
              const SizedBox(height: 24),
              if (status == 'pending')
                _buildPendingActions(context, totalQty)
              else
                _buildCompletedView(context),
            ],
          );
  }

  Widget _buildPendingActions(BuildContext context, int totalQty) {
    if (_allocatedRackNumbers == null) {
      return ElevatedButton.icon(
        onPressed: _isProcessing ? null : _allocateAndPrint,
        icon: _isProcessing ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.inventory_2_outlined),
        label: Text(_isProcessing ? 'Mencari Rak...' : 'Alokasikan Rak & Cetak Barcode'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).primaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      );
    } else {
      final int scannedCount = _scannedCodes.length;
      return Card(
        elevation: 0,
        color: Theme.of(context).primaryColor.withOpacity(0.1),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Text("Alokasi Rak: ${_allocatedRackNumbers!.join(', ')}", style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold), textAlign: TextAlign.center,),
              const SizedBox(height: 16),
              Text("Status Scan: $scannedCount / $totalQty", style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              if (scannedCount > 0 && scannedCount < totalQty)
                LinearProgressIndicator(value: scannedCount / totalQty, minHeight: 8, borderRadius: BorderRadius.circular(4)),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _startVerification,
                icon: const Icon(Icons.qr_code_scanner_outlined),
                label: Text(scannedCount > 0 ? 'Lanjutkan Scan' : 'Mulai Verifikasi Scan'),
                 style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  Widget _buildCompletedView(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          color: Colors.green.shade50,
          child: ListTile(
            leading: Icon(Icons.check_circle, color: Colors.green.shade800),
            title: Text('Verifikasi & Penempatan Selesai', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade900)),
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: null,
          icon: const Icon(Icons.print_outlined),
          label: const Text('Cetak Ulang Barcode (Nonaktif)'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.grey.shade300,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailCard(BuildContext context, String title, List<Widget> children) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const Divider(height: 24),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    final bool isStatus = label == 'Status';
    final Color statusColor = value.startsWith('Pending') ? Colors.orange.shade800 : Colors.green.shade800;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: isStatus ? statusColor : Colors.grey[600], size: 20),
          const SizedBox(width: 16),
          Text('$label:', style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                color: isStatus ? statusColor : null,
                fontWeight: isStatus ? FontWeight.bold : null
              )
            )
          ),
        ],
      ),
    );
  }
}