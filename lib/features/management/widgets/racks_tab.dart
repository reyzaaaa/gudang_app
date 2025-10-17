import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gudang_app/main.dart';

// Provider untuk mengambil data rak beserta isinya
final masterRacksProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  return await supabase
      .from('racks')
      .select('*, items(item_code)')
      .order('rack_number', ascending: true);
});


class RacksTab extends ConsumerWidget {
  const RacksTab({super.key});

  Future<void> _showAddRackDialog(BuildContext context, WidgetRef ref) async {
    final formKey = GlobalKey<FormState>();
    final rackNumberController = TextEditingController();

    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Tambah Rak Baru'),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: rackNumberController,
              decoration: const InputDecoration(labelText: 'Nomor Rak (Contoh: A11)'),
              validator: (val) => (val == null || val.isEmpty) ? 'Wajib diisi' : null,
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Batal')),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  try {
                    await supabase.from('racks').insert({'rack_number': rackNumberController.text.trim().toUpperCase()});
                    ref.invalidate(masterRacksProvider); // Refresh daftar rak
                    if(context.mounted) Navigator.of(context).pop();
                  } catch (e) {
                    if(context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal: $e'), backgroundColor: Colors.red));
                  }
                }
              },
              child: const Text('Simpan'),
            )
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final racksAsyncValue = ref.watch(masterRacksProvider);

    return Scaffold(
      body: racksAsyncValue.when(
        data: (racks) {
          return RefreshIndicator(
            onRefresh: () => ref.refresh(masterRacksProvider.future),
            child: ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: racks.length,
              itemBuilder: (context, index) {
                final rack = racks[index];
                final item = rack['items'];
                final bool isKosong = rack['status'] == 'kosong';

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: ListTile(
                    leading: Icon(
                      Icons.inventory_2_outlined,
                      color: isKosong ? Colors.grey : Theme.of(context).primaryColor,
                    ),
                    title: Text(rack['rack_number'], style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                      isKosong ? 'Rak ini kosong' : 'Terisi: ${item?['item_code'] ?? 'N/A'}'
                    ),
                    trailing: Chip(
                      label: Text(isKosong ? 'Kosong' : 'Terisi'),
                      backgroundColor: isKosong ? Colors.grey.shade200 : Colors.green.shade100,
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddRackDialog(context, ref),
        tooltip: 'Tambah Rak',
        child: const Icon(Icons.add),
      ),
    );
  }
}