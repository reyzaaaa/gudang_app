import 'package:flutter/material.dart';
import 'package:gudang_app/features/management/widgets/items_tab.dart';
import 'package:gudang_app/features/management/widgets/racks_tab.dart';

class MasterDataScreen extends StatelessWidget {
  const MasterDataScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // DefaultTabController akan mengelola state dari TabBar dan TabBarView
    return DefaultTabController(
      length: 2, // Jumlah tab
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          // Gunakan AppBar dari Scaffold untuk menempatkan TabBar
          toolbarHeight: 0, // Sembunyikan AppBar default
          bottom: const TabBar(
            tabs: [
              Tab(text: 'BAHAN BAKU'),
              Tab(text: 'RAK PENYIMPANAN'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            // Konten untuk tab pertama
            ItemsTab(),
            // Konten untuk tab kedua
            RacksTab(),
          ],
        ),
      ),
    );
  }
}