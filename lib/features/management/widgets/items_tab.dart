import 'dart:async';
import 'dart:io';
import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gudang_app/main.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:universal_html/html.dart' as html;

// Provider untuk menampung query pencarian
final itemSearchQueryProvider = StateProvider<String>((ref) => '');

// Provider data yang "mendengarkan" provider pencarian
final masterItemsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final searchQuery = ref.watch(itemSearchQueryProvider);
  return await supabase.rpc('search_items_with_locations', params: {'p_search_query': searchQuery});
});

class ItemsTab extends ConsumerStatefulWidget {
  const ItemsTab({super.key});

  @override
  ConsumerState<ItemsTab> createState() => _ItemsTabState();
}

class _ItemsTabState extends ConsumerState<ItemsTab> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  bool _isExporting = false;

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }
  
  // Fungsi ekspor ke Excel yang platform-aware (web & mobile)
  Future<void> _exportToExcel(List<Map<String, dynamic>> data) async {
    if (_isExporting) return;
    setState(() => _isExporting = true);
    
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Membuat file Excel...'), backgroundColor: Colors.blue));

    // Logika Pembuatan Excel (sama untuk semua platform)
    final excel = Excel.createExcel();
    final Sheet sheet = excel[excel.getDefaultSheet()!];
    final headers = ['Kode Barang', 'Nama Barang', 'Total Stok', 'Unit', 'Posisi Rak'];
    sheet.appendRow(headers.map((header) => TextCellValue(header)).toList());
    for (final item in data) {
      final row = [
        TextCellValue(item['item_code'] ?? ''),
        TextCellValue(item['item_name'] ?? ''),
        IntCellValue(item['total_stok'] ?? 0),
        TextCellValue(item['unit'] ?? ''),
        TextCellValue(item['rack_positions'] ?? '-'),
      ];
      sheet.appendRow(row);
    }
    
    final fileBytes = excel.save();
    final String fileName = 'Export_Bahan_Baku_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx';

    // Logika Penyimpanan Berdasarkan Platform
    if (kIsWeb) {
      // LOGIKA UNTUK WEB (memicu download)
      if (fileBytes != null) {
        final blob = html.Blob([fileBytes], 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
        final url = html.Url.createObjectUrlFromBlob(blob);
        html.Url.revokeObjectUrl(url);
      }
    } else {
      // LOGIKA UNTUK MOBILE / DESKTOP (menyimpan file)
      final status = await Permission.storage.request();
      if (!mounted) return;

      if (status.isGranted) {
        try {
          final Directory? dir = await getDownloadsDirectory();
          if (dir == null) throw Exception('Tidak dapat menemukan direktori Downloads.');
          final String path = '${dir.path}/$fileName';
          
          if (fileBytes != null) {
            File(path).writeAsBytesSync(fileBytes);
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Berhasil disimpan di folder Downloads: $fileName'), duration: const Duration(seconds: 5), backgroundColor: Colors.green));
          }
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal menyimpan file: $e'), backgroundColor: Colors.red));
        }
      } else if (status.isPermanentlyDenied) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Izin penyimpanan ditolak permanen. Harap aktifkan di pengaturan aplikasi.'),
            action: SnackBarAction(label: 'Buka Pengaturan', onPressed: openAppSettings),
            duration: Duration(seconds: 5),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Izin penyimpanan diperlukan untuk menyimpan file.'), backgroundColor: Colors.orange));
      }
    }
    
    if(mounted) {
      setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final itemsAsyncValue = ref.watch(masterItemsProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Cari berdasarkan nama atau kode...',
                    prefixIcon: const Icon(Icons.search),
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onChanged: (value) {
                    if (_debounce?.isActive ?? false) _debounce!.cancel();
                    _debounce = Timer(const Duration(milliseconds: 500), () {
                      ref.read(itemSearchQueryProvider.notifier).state = value;
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              itemsAsyncValue.when(
                data: (data) => IconButton(
                  onPressed: data.isEmpty || _isExporting ? null : () => _exportToExcel(data),
                  icon: _isExporting ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 3)) : const Icon(Icons.file_download_outlined),
                  tooltip: 'Simpan ke Excel',
                ),
                loading: () => const SizedBox.shrink(),
                error: (e, s) => IconButton(icon: const Icon(Icons.error_outline, color: Colors.red), tooltip: 'Gagal memuat', onPressed: (){}),
              ),
            ],
          ),
        ),
        Expanded(
          child: itemsAsyncValue.when(
            data: (items) {
              if (items.isEmpty) {
                return Center(child: Text(_searchController.text.isEmpty ? 'Tidak ada data master barang.' : 'Data tidak ditemukan.'));
              }
              return RefreshIndicator(
                onRefresh: () async {
                  _searchController.clear();
                  ref.read(itemSearchQueryProvider.notifier).state = '';
                },
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item['item_name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(height: 4),
                            Text('Kode: ${item['item_code']}', style: const TextStyle(color: Colors.grey)),
                            const Divider(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Unit: ${item['unit']}'),
                                Text('Total Stok: ${item['total_stok']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.inventory_2_outlined, size: 16, color: Colors.grey.shade600),
                                const SizedBox(width: 8),
                                Expanded(child: Text('Lokasi: ${item['rack_positions']}', style: TextStyle(color: Colors.grey.shade700))),
                              ],
                            )
                          ],
                        ),
                      ),
                    );
                  },
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Center(child: Text('Gagal memuat data: $err')),
          ),
        ),
      ],
    );
  }
}