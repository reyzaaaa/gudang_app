import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    // Optimasi untuk scan lebih cepat
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
  );
  
  // Flag untuk memastikan kita hanya memproses satu barcode per sesi
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pindai Barcode')),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: (capture) async {
              // Jika sudah ada barcode yang diproses, abaikan yang lain
              if (_isProcessing) return;

              // Ambil barcode pertama yang terdeteksi
              final barcode = capture.barcodes.first;

              // Pastikan nilainya tidak kosong
              if (barcode.rawValue != null) {
                // 1. Set flag agar tidak ada proses ganda
                setState(() {
                  _isProcessing = true;
                });
                
                // 2. Berhentikan kamera. Ini adalah langkah kunci untuk mencegah error.
                await _controller.stop();
                
                // 3. Tampilkan efek visual singkat (opsional tapi bagus untuk UX)
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Kode terdeteksi: ${barcode.rawValue}'),
                      backgroundColor: Colors.green,
                      duration: const Duration(milliseconds: 700),
                    )
                  );
                }
                
                // Beri jeda sesaat agar user melihat feedback
                await Future.delayed(const Duration(milliseconds: 800));

                // 4. Kembali ke halaman sebelumnya dengan membawa hasil scan
                if (mounted) {
                  Navigator.of(context).pop(barcode.rawValue);
                }
              }
            },
          ),
          // Overlay visual untuk area scan
          Center(
            child: Container(
              width: MediaQuery.of(context).size.width * 0.7,
              height: MediaQuery.of(context).size.width * 0.45,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    // Pastikan controller di-dispose saat halaman ditutup
    _controller.dispose();
    super.dispose();
  }
}