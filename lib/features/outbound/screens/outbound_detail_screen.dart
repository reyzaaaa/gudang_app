import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gudang_app/main.dart';
import 'package:intl/intl.dart';

// Menggunakan provider yang sama dari inbound detail screen
import 'package:gudang_app/features/inbound/screens/inbound_detail_screen.dart';

class OutboundDetailScreen extends ConsumerWidget {
  const OutboundDetailScreen({super.key, required this.transactionId});
  final int transactionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionAsyncValue = ref.watch(singleTransactionProvider(transactionId));

    return Scaffold(
      appBar: AppBar(title: const Text('Rincian Permintaan Keluar')),
      body: transactionAsyncValue.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (transaction) => _OutboundDetailView(
          key: ValueKey(transaction['id']),
          transaction: transaction
        ),
      ),
    );
  }
}

class _OutboundDetailView extends StatefulWidget {
  const _OutboundDetailView({super.key, required this.transaction});
  final Map<String, dynamic> transaction;

  @override
  State<_OutboundDetailView> createState() => _OutboundDetailViewState();
}

class _OutboundDetailViewState extends State<_OutboundDetailView> {
  List<String>? _sourceRacks;
  bool _isLoadingRacks = true;

  @override
  void initState() {
    super.initState();
    _fetchSourceRacks();
  }

  Future<void> _fetchSourceRacks() async {
    try {
      final response = await supabase
          .from('picking_log')
          .select('racks(rack_number)')
          .eq('outbound_transaction_id', widget.transaction['id']);

      if (mounted && response.isNotEmpty) {
        final locations = response
            .map((e) => e['racks']?['rack_number'] as String? ?? 'N/A')
            .toSet()
            .toList();
        setState(() {
          _sourceRacks = locations;
        });
      }
    } catch (e) {
      // Handle error
    } finally {
      if(mounted) setState(() => _isLoadingRacks = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.transaction['items'];
    final date = DateTime.parse(widget.transaction['transaction_date']);
    final formattedDate = DateFormat('EEEE, d MMMM yyyy, HH:mm', 'id_ID').format(date);
    final status = widget.transaction['status'] ?? 'pending';

    return ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildDetailCard(
            context,
            item != null ? item['item_name'] : 'Barang Dihapus',
            [
              _buildDetailRow(Icons.qr_code_2, 'Kode Barang', item != null ? item['item_code'] : 'N/A'),
              _buildDetailRow(Icons.category_outlined, 'Unit', item != null ? item['unit'] : 'N/A'),
              _buildDetailRow(Icons.shopping_cart_checkout, 'Kuantitas Keluar', '-${widget.transaction['quantity']}', color: Colors.red),
              _buildDetailRow(Icons.calendar_today_outlined, 'Tanggal Transaksi', formattedDate),
              _buildDetailRow(
                status == 'pending' ? Icons.pending : Icons.check_circle,
                'Status',
                status == 'pending' ? 'Pending' : 'Selesai',
              ),
               _buildDetailRow(
                Icons.inventory_2_outlined,
                'Diambil dari Rak',
                _isLoadingRacks
                    ? 'Memuat...'
                    : (_sourceRacks?.join(', ') ?? 'Data tidak tersedia'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Card(
            color: Colors.green.shade50,
            child: ListTile(
              leading: Icon(Icons.check_circle, color: Colors.green.shade800),
              title: Text('Pengambilan Selesai', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade900)),
              subtitle: const Text('Stok barang telah dikurangi.'),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: null,
            icon: const Icon(Icons.print_outlined),
            label: const Text('Cetak Barcode (Nonaktif)'),
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

  Widget _buildDetailRow(IconData icon, String label, String value, {Color? color}) {
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
                color: color ?? (isStatus ? statusColor : null),
                fontWeight: isStatus ? FontWeight.bold : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}