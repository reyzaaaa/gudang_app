import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gudang_app/features/outbound/providers/outbound_providers.dart';
import 'package:gudang_app/main.dart';

class PickingScreen extends ConsumerStatefulWidget {
  const PickingScreen({super.key, required this.transaction});
  final Map<String, dynamic> transaction;

  @override
  ConsumerState<PickingScreen> createState() => _PickingScreenState();
}

class _PickingScreenState extends ConsumerState<PickingScreen> {
  Queue<Map<String, dynamic>>? _pickingPlan;
  final List<String> _scannedCodes = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _generatePickingPlan();
  }

  Future<void> _generatePickingPlan() async {
    final item = widget.transaction['items'];
    if (item == null) {
      setState(() => _errorMessage = 'Item tidak ditemukan.');
      return;
    }

    try {
      final List<dynamic> locations = await supabase.rpc('get_picking_list', params: {'p_item_id': item['id']});
      if (locations.isEmpty) {
        setState(() => _errorMessage = 'Stok barang ini tidak ditemukan di rak manapun.');
        return;
      }
      
      final needed = widget.transaction['quantity'] as int;
      final plan = Queue<Map<String, dynamic>>();
      int collected = 0;

      for (var loc in locations) {
        final qtyOnRack = loc['quantity_on_rack'] as int;
        for (int i = 0; i < qtyOnRack; i++) {
          plan.add({
            'location_id': loc['location_id'],
            'rack_number': loc['rack_number'],
            'item_code': item['item_code'],
          });
          collected++;
          if (collected >= needed) break;
        }
        if (collected >= needed) break;
      }

      if (collected < needed) {
        setState(() => _errorMessage = 'Stok tidak mencukupi. Hanya tersedia $collected dari $needed yang dibutuhkan.');
        return;
      }
      
      setState(() {
        _pickingPlan = plan;
        _isLoading = false;
      });

    } catch (e) {
      setState(() => _errorMessage = 'Gagal membuat rencana: $e');
    }
  }

  Future<void> _scanItem() async {
    if (_pickingPlan == null || _pickingPlan!.isEmpty) return;

    final currentTarget = _pickingPlan!.first;
    final expectedBarcode = '${currentTarget['rack_number']}${currentTarget['item_code']}';

    final scannedCode = await context.push<String>('/scanner');
    if (scannedCode == null) return;

    if (scannedCode == expectedBarcode) {
      try {
        // PERUBAHAN: Mengirim transaction_id ke fungsi RPC
        await supabase.rpc('decrement_stock_from_rack', params: {
          'p_location_id': currentTarget['location_id'],
          'p_outbound_transaction_id': widget.transaction['id'],
        });
        
        setState(() {
          _scannedCodes.add(scannedCode);
          _pickingPlan!.removeFirst();
        });

        if (_pickingPlan!.isEmpty) {
          await _completeOutboundTransaction();
        }

      } catch (e) {
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal mengurangi stok: $e'), backgroundColor: Colors.red));
      }
    } else {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Barcode tidak sesuai dengan item/lokasi yang seharusnya diambil!'), backgroundColor: Colors.red));
    }
  }

  Future<void> _completeOutboundTransaction() async {
    try {
      await supabase.from('transactions').update({'status': 'completed'}).eq('id', widget.transaction['id']);
      await supabase.rpc('decrement_total_stock', params: {
        'p_item_id': widget.transaction['item_id'],
        'p_quantity_to_remove': widget.transaction['quantity'],
      });
      ref.invalidate(outboundHistoryProvider);
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pengambilan barang selesai!'), backgroundColor: Colors.green));
        context.pop();
      }
    } catch(e) {
       if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal menyelesaikan transaksi: $e'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.transaction['items'];
    final totalQty = widget.transaction['quantity'];
    
    return Scaffold(
      appBar: AppBar(title: const Text('Pengambilan Barang')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 18), textAlign: TextAlign.center),
              ))
              : Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item?['item_name'] ?? 'N/A', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              Text('Kode: ${item?['item_code'] ?? 'N/A'}'),
                              const Divider(height: 24),
                              Text('LOKASI PENGAMBILAN SAAT INI:', style: Theme.of(context).textTheme.labelLarge),
                              Text(_pickingPlan!.isEmpty ? '-' : _pickingPlan!.first['rack_number'], style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor)),
                            ],
                          ),
                        ),
                      ),
                      Column(
                        children: [
                          Text('Status Scan:', style: Theme.of(context).textTheme.titleMedium),
                          Text('${_scannedCodes.length} / $totalQty', textAlign: TextAlign.center, style: Theme.of(context).textTheme.displayMedium?.copyWith(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      ElevatedButton.icon(
                        onPressed: (_pickingPlan?.isEmpty ?? true) ? null : _scanItem,
                        icon: const Icon(Icons.qr_code_scanner),
                        label: const Text('Scan Barcode Barang'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}