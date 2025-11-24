import 'package:flutter/material.dart';
import 'package:gudang_app/features/management/widgets/racks_tab.dart';

class RackStorageScreen extends StatelessWidget {
  const RackStorageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Rak Penyimpanan',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: const RacksTab(), // Langsung menampilkan konten Rak
    );
  }
}