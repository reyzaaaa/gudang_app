import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gudang_app/features/auth/providers/auth_providers.dart'; // Import provider role
import 'package:gudang_app/main.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// --- Provider ---
final masterRacksProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final data = await supabase
      .from('racks')
      .select('*, items(item_code)')
      .order('rack_number', ascending: true);

  // Lakukan pengurutan alami
  data.sort((a, b) {
     final regex = RegExp(r'([A-Za-z]+)([0-9]+)');
     final matchA = regex.firstMatch(a['rack_number'] ?? '');
     final matchB = regex.firstMatch(b['rack_number'] ?? '');
     if (matchA != null && matchB != null) {
       final prefixA = matchA.group(1); final prefixB = matchB.group(1);
       final numA = int.tryParse(matchA.group(2) ?? '0') ?? 0; final numB = int.tryParse(matchB.group(2) ?? '0') ?? 0;
       final prefixCompare = prefixA?.compareTo(prefixB ?? '') ?? 0;
       if (prefixCompare != 0) return prefixCompare;
       return numA.compareTo(numB);
     }
     return (a['rack_number'] ?? '').compareTo(b['rack_number'] ?? '');
  });
  return data;
});

// --- Widget Tab ---
class RacksTab extends ConsumerStatefulWidget {
  const RacksTab({super.key});

  @override
  ConsumerState<RacksTab> createState() => _RacksTabState();
}

class _RacksTabState extends ConsumerState<RacksTab> {
  final _addRackFormKey = GlobalKey<FormState>();
  final _rackNumberController = TextEditingController();
  bool _isSavingRack = false;

  @override
  void dispose() {
    _rackNumberController.dispose();
    super.dispose();
  }

  // Fungsi Simpan Rak Baru
  Future<void> _saveNewRack() async {
    if (_addRackFormKey.currentState!.validate()) {
      setState(() => _isSavingRack = true);
      try {
        await supabase.from('racks').insert({'rack_number': _rackNumberController.text.trim().toUpperCase()});
        ref.invalidate(masterRacksProvider);
        _addRackFormKey.currentState?.reset();
        _rackNumberController.clear();
         if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rak baru berhasil disimpan.'), backgroundColor: Colors.green));
         }
      } on PostgrestException catch (e) {
         if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(content: Text('Gagal: ${e.message.contains("duplicate key") ? "Nomor rak sudah ada." : e.message}'), backgroundColor: Colors.red),
           );
         }
      } finally {
         if (mounted) {
           setState(() => _isSavingRack = false);
         }
      }
    }
  }

  // Fungsi Hapus Rak
  Future<void> _deleteRack(int rackId, String rackNumber, bool isOccupied) async {
     if (isOccupied) {
       await showDialog(
         context: context,
         builder: (context) => AlertDialog(
           title: const Text('Peringatan'),
           content: Text('Rak "$rackNumber" sedang terisi. Mengosongkan rak mungkin diperlukan sebelum menghapus. Tetap hapus?'),
           actions: [
             TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Batal')),
             TextButton(
               onPressed: () async {
                 Navigator.of(context).pop();
                 await _confirmAndDeleteRack(rackId, rackNumber);
               },
               style: TextButton.styleFrom(foregroundColor: Colors.red),
               child: const Text('Tetap Hapus'),
             ),
           ],
         ),
       );
     } else {
        await _confirmAndDeleteRack(rackId, rackNumber);
     }
  }

  Future<void> _confirmAndDeleteRack(int rackId, String rackNumber) async {
     final confirm = await showDialog<bool>(
       context: context,
       builder: (context) => AlertDialog(
         title: const Text('Konfirmasi Hapus'),
         content: Text('Anda yakin ingin menghapus Rak "$rackNumber"?'),
         actions: [
           TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Batal')),
           TextButton(
             onPressed: () => Navigator.of(context).pop(true),
             style: TextButton.styleFrom(foregroundColor: Colors.red),
             child: const Text('Hapus'),
           ),
         ],
       ),
     );

     if (confirm == true) {
       try {
         await supabase.from('racks').delete().eq('id', rackId);
         ref.invalidate(masterRacksProvider);
         if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Rak "$rackNumber" berhasil dihapus.'), backgroundColor: Colors.green));
         }
       } catch (e) {
          if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal menghapus rak: $e'), backgroundColor: Colors.red));
          }
       }
     }
  }

  @override
  Widget build(BuildContext context) {
    final racksAsyncValue = ref.watch(masterRacksProvider);
    final theme = Theme.of(context);
    final bool isStaff = ref.watch(isStaffProvider); // Cek peran

    return Column(
      children: [
        // --- Form Input Rak Baru (Hanya Admin) ---
        Visibility(
          visible: !isStaff,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _addRackFormKey,
                  child: Column(
                     crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                       Text("Tambah Rak Baru", style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                       const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _rackNumberController,
                              decoration: const InputDecoration(labelText: 'Nomor Rak (Contoh: A11)', isDense: true),
                              textCapitalization: TextCapitalization.characters,
                              validator: (val) => (val == null || val.isEmpty) ? 'Wajib diisi' : null,
                            ),
                          ),
                          const SizedBox(width: 16),
                          ElevatedButton.icon(
                            onPressed: _isSavingRack ? null : _saveNewRack,
                            icon: _isSavingRack ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.add_circle_outline, size: 18),
                            label: Text(_isSavingRack ? 'Menyimpan...' : 'Tambah Rak'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
         Padding(
           padding: EdgeInsets.fromLTRB(24.0, isStaff ? 16.0 : 16.0, 24.0, 10.0),
           child: Text(
             'DAFTAR RAK PENYIMPANAN',
             style: Theme.of(context).textTheme.titleLarge?.copyWith(
                   fontWeight: FontWeight.bold,
                   color: Colors.black87,
                 ),
           ),
         ),
         const Divider(height: 1, thickness: 1, indent: 24, endIndent: 24),
        // --- Daftar Rak ---
        Expanded(
          child: racksAsyncValue.when(
            data: (racks) {
              if (racks.isEmpty) { return const Center(child: Text('Belum ada data rak.')); }

              return RefreshIndicator(
                onRefresh: () async { ref.invalidate(masterRacksProvider); },
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                  itemCount: racks.length,
                  itemBuilder: (context, index) {
                    final rack = racks[index];
                    final item = rack['items'];
                    final bool isKosong = rack['status'] == 'kosong';

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey.shade200)
                      ),
                      child: ListTile(
                        leading: Icon(
                          Icons.inventory_2_outlined,
                          color: isKosong ? Colors.grey.shade600 : Theme.of(context).primaryColor,
                        ),
                        title: Text(rack['rack_number'], style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(
                          isKosong ? 'Rak ini kosong' : 'Terisi: ${item?['item_code'] ?? 'N/A'}'
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Chip(
                              label: Text(isKosong ? 'Kosong' : 'Terisi'),
                              backgroundColor: isKosong ? Colors.grey.shade200 : Colors.green.shade100,
                              labelStyle: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isKosong ? Colors.grey.shade700 : Colors.green.shade800,
                              ),
                            ),
                            if (!isStaff) // Tampilkan tombol hapus jika bukan staff
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                tooltip: 'Hapus Rak',
                                onPressed: () => _deleteRack(rack['id'], rack['rack_number'], !isKosong),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Center(child: Text('Error: $err')),
          ),
        ),
      ],
    );
  }
}