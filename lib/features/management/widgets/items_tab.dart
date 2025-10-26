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
import 'package:supabase_flutter/supabase_flutter.dart';

// --- Provider ---
final itemSearchQueryProvider = StateProvider<String>((ref) => '');
final masterItemsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final searchQuery = ref.watch(itemSearchQueryProvider);
  return await supabase.rpc('search_items_with_locations', params: {'p_search_query': searchQuery});
});

// --- Widget Tab ---
class ItemsTab extends ConsumerStatefulWidget {
  const ItemsTab({super.key});

  @override
  ConsumerState<ItemsTab> createState() => _ItemsTabState();
}

class _ItemsTabState extends ConsumerState<ItemsTab> {
  final _addItemFormKey = GlobalKey<FormState>();
  final _newCodeController = TextEditingController();
  final _newNameController = TextEditingController();
  final List<String> _units = ['Kg', 'Roll', 'Pcs', 'Box', 'Liter'];
  String? _newUnit;
  bool _isSavingItem = false;

  final _searchController = TextEditingController();
  Timer? _debounce;
  bool _isExporting = false;

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    _newCodeController.dispose();
    _newNameController.dispose();
    super.dispose();
  }

  // Fungsi Ekspor Excel
  Future<void> _exportToExcel(List<Map<String, dynamic>> data) async {
     if (_isExporting) return;
     setState(() => _isExporting = true);

     // PERBAIKAN: Cek mounted sebelum SnackBar awal
     if (!mounted) return;
     ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Membuat file Excel...'), backgroundColor: Colors.blue));

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

     if (kIsWeb) {
       if (fileBytes != null) {
         final blob = html.Blob([fileBytes], 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
         final url = html.Url.createObjectUrlFromBlob(blob);
         // PERBAIKAN: Hapus variabel 'anchor'
         html.AnchorElement(href: url)
           ..setAttribute("download", fileName)
           ..click();
         html.Url.revokeObjectUrl(url);
         // Tambahkan pesan sukses untuk web jika perlu (opsional)
          if (mounted) {
             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Download dimulai...'), backgroundColor: Colors.green));
          }
       }
     } else {
       final status = await Permission.storage.request();
       // PERBAIKAN: Cek mounted setelah await
       if (!mounted) return;

       if (status.isGranted) {
         try {
           final Directory? dir = await getDownloadsDirectory();
           if (dir == null) throw Exception('Tidak dapat menemukan direktori Downloads.');
           final String path = '${dir.path}/$fileName';

           if (fileBytes != null) {
             File(path).writeAsBytesSync(fileBytes);
             // PERBAIKAN: Cek mounted sebelum SnackBar sukses
             if (!mounted) return;
             ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Berhasil disimpan di folder Downloads: $fileName'), duration: const Duration(seconds: 5), backgroundColor: Colors.green));
           }
         } catch (e) {
           // PERBAIKAN: Cek mounted sebelum SnackBar error
           if (!mounted) return;
           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal menyimpan file: $e'), backgroundColor: Colors.red));
         }
       } else {
         // PERBAIKAN: Cek mounted sebelum SnackBar izin
         if (!mounted) return;
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Izin penyimpanan diperlukan.'), backgroundColor: Colors.orange));
         // Pertimbangkan menambahkan openAppSettings jika ditolak permanen
         if (status.isPermanentlyDenied) {
            openAppSettings();
         }
       }
     }

     if(mounted) {
       setState(() => _isExporting = false);
     }
  }

  // Fungsi Simpan Item Baru
  Future<void> _saveNewItem() async {
    if (_addItemFormKey.currentState!.validate()) {
      setState(() => _isSavingItem = true);
      try {
        await supabase.from('items').insert({
          'item_code': _newCodeController.text.trim().toUpperCase(),
          'item_name': _newNameController.text.trim(),
          'unit': _newUnit,
        });
        ref.invalidate(masterItemsProvider);
        _addItemFormKey.currentState?.reset();
        _newCodeController.clear();
        _newNameController.clear();
        setState(() => _newUnit = null);
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bahan baku baru berhasil disimpan.'), backgroundColor: Colors.green));
        }
      } on PostgrestException catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal: ${e.message.contains("duplicate key") ? "Kode barang sudah ada." : e.message}'), backgroundColor: Colors.red),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isSavingItem = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final itemsAsyncValue = ref.watch(masterItemsProvider);
    final theme = Theme.of(context);

    return Column(
      children: [
        // --- Form Input Item Baru ---
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _addItemFormKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Tambah Bahan Baku Baru", style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _newCodeController,
                      decoration: const InputDecoration(labelText: 'Kode Barang Baru', isDense: true),
                      textCapitalization: TextCapitalization.characters,
                      validator: (value) => (value == null || value.isEmpty) ? 'Wajib diisi' : null,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _newNameController,
                      decoration: const InputDecoration(labelText: 'Nama Barang', isDense: true),
                      validator: (value) => (value == null || value.isEmpty) ? 'Wajib diisi' : null,
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _newUnit,
                      decoration: const InputDecoration(labelText: 'Unit', isDense: true),
                      items: _units.map((String unit) => DropdownMenuItem<String>(value: unit, child: Text(unit))).toList(),
                      onChanged: (value) => setState(() => _newUnit = value),
                      validator: (value) => value == null ? 'Pilih unit' : null,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _isSavingItem ? null : _saveNewItem,
                      icon: _isSavingItem ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.add_circle_outline),
                      label: Text(_isSavingItem ? 'Menyimpan...' : 'Tambah Bahan Baku'),
                      style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
                    )
                  ],
                ),
              ),
            ),
          ),
        ),

        // --- Baris Pencarian & Ekspor ---
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                     hintText: 'Cari berdasarkan nama atau kode...',
                     prefixIcon: const Icon(Icons.search),
                     isDense: true,
                     contentPadding: const EdgeInsets.symmetric(vertical: 10.0),
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
                 error: (e, s) => IconButton(icon: const Icon(Icons.error_outline), tooltip: 'Gagal Memuat', onPressed: (){}),
              ),
            ],
          ),
        ),
        // --- Daftar Barang ---
        Expanded(
          child: itemsAsyncValue.when(
            data: (items) {
              if (items.isEmpty) { return Center(child: Text(_searchController.text.isEmpty ? 'Belum ada data bahan baku.' : 'Data tidak ditemukan.')); }
              return RefreshIndicator(
                onRefresh: () async {
                   _searchController.clear();
                   ref.read(itemSearchQueryProvider.notifier).state = '';
                   ref.invalidate(masterItemsProvider);
                },
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey.shade200)
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item['item_name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(height: 4),
                            Text('Kode: ${item['item_code']}', style: TextStyle(color: Colors.grey.shade700)),
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
                                Icon(Icons.location_on_outlined, size: 16, color: Colors.grey.shade600),
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