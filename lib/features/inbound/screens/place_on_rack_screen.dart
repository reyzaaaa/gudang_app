import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:gudang_app/main.dart'; // Untuk akses supabase

class PlaceOnRackScreen extends StatefulWidget {
  const PlaceOnRackScreen({super.key, required this.transactionData});
  final Map<String, dynamic> transactionData;

  @override
  State<PlaceOnRackScreen> createState() => _PlaceOnRackScreenState();
}

class _PlaceOnRackScreenState extends State<PlaceOnRackScreen> {
  Map<String, dynamic>? _recommendedRack;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchRecommendedRack();
  }

  Future<void> _fetchRecommendedRack() async {
    try {
      final response = await supabase
          .from('racks')
          .select()
          .eq('status', 'kosong')
          .order('rack_number', ascending: true)
          .limit(1)
          .single();
      setState(() {
        _recommendedRack = response;
      });
    } catch (error) {
       setState(() {
        _errorMessage = "Tidak ada rak kosong tersedia.";
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _scanAndPlace() async {
    final scannedRackCode = await context.push<String>('/scanner');
    
    if (scannedRackCode != null && _recommendedRack != null) {
      if (scannedRackCode == _recommendedRack!['rack_number']) {
        try {
          // 1. Masukkan ke item_locations untuk menambah stok
          await supabase.from('item_locations').insert({
            'item_id': widget.transactionData['item_id'],
            'rack_id': _recommendedRack!['id'],
            'quantity': widget.transactionData['quantity'],
          });

          // 2. Update status rak menjadi 'terisi'
          await supabase
              .from('racks')
              .update({'status': 'terisi'})
              .eq('id', _recommendedRack!['id']);

          if(mounted) {
             ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Barang berhasil ditempatkan di Rak ${_recommendedRack!['rack_number']}!'), backgroundColor: Colors.green),
            );
            // Selesai, kembali ke halaman utama
            context.go('/inbound');
          }

        } catch (error) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Gagal menyimpan ke rak: $error'), backgroundColor: Colors.red),
            );
          }
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: Barcode rak tidak sesuai dengan yang direkomendasikan!'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Penempatan Barang'),
        automaticallyImplyLeading: false,
      ),
      body: Padding(
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
                    Text(widget.transactionData['item_name'], style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 8),
                    Text('Kode: ${widget.transactionData['item_code']}'),
                    Text('Qty untuk Ditempatkan: ${widget.transactionData['quantity']}'),
                  ],
                ),
              ),
            ),
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    Text(
                      'Letakkan Barang di Rak Tujuan:',
                       style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 16),
                    if (_isLoading)
                      const CircularProgressIndicator()
                    else if (_errorMessage != null)
                       Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 24, fontWeight: FontWeight.bold))
                    else if (_recommendedRack != null)
                      Text(
                        _recommendedRack!['rack_number'],
                        style: Theme.of(context).textTheme.displayMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.blue.shade800),
                      )
                  ],
                ),
              ),
            ),
            ElevatedButton.icon(
              onPressed: _recommendedRack != null ? _scanAndPlace : null,
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Scan Lokasi Rak & Selesaikan'),
               style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
            ),
          ],
        ),
      ),
    );
  }
}