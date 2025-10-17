import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class VerifyScanScreen extends StatefulWidget {
  const VerifyScanScreen({super.key, required this.transactionData});

  final Map<String, dynamic> transactionData;

  @override
  State<VerifyScanScreen> createState() => _VerifyScanScreenState();
}

class _VerifyScanScreenState extends State<VerifyScanScreen> {
  int _scannedCount = 0;
  late int _totalQty;
  late String _itemCode;
  late String _itemName;

  @override
  void initState() {
    super.initState();
    _totalQty = widget.transactionData['quantity'];
    _itemCode = widget.transactionData['item_code'];
    _itemName = widget.transactionData['item_name'];
  }

  Future<void> _scanBarcode() async {
    // Memanggil halaman scanner dan menunggu hasilnya
    final scannedCode = await context.push<String>('/scanner');

    if (scannedCode != null && mounted) {
      if (scannedCode == _itemCode) {
        setState(() {
          _scannedCount++;
        });
        
        // Cek jika semua sudah di-scan
        if (_scannedCount == _totalQty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Verifikasi berhasil! Lanjut ke penempatan rak.'), backgroundColor: Colors.green),
          );
          // Otomatis lanjut ke halaman penempatan rak
          context.go('/inbound/place', extra: widget.transactionData);
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: Barcode tidak sesuai!'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verifikasi Barang Masuk'),
        automaticallyImplyLeading: false, // Sembunyikan tombol kembali
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_itemName, style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 8),
                    Text('Kode: $_itemCode'),
                    Text('Total Qty: $_totalQty'),
                  ],
                ),
              ),
            ),
            Column(
              children: [
                Text(
                  'Status Pindai:',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  '$_scannedCount / $_totalQty',
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            ElevatedButton.icon(
              onPressed: _scannedCount < _totalQty ? _scanBarcode : null,
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Scan Barcode Barang'),
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
            ),
          ],
        ),
      ),
    );
  }
}