import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gudang_app/features/outbound/providers/outbound_providers.dart';
import 'package:gudang_app/main.dart';
import 'package:intl/intl.dart';

class AddOutboundScreen extends ConsumerStatefulWidget {
  const AddOutboundScreen({super.key});

  @override
  ConsumerState<AddOutboundScreen> createState() => _AddOutboundScreenState();
}

class _AddOutboundScreenState extends ConsumerState<AddOutboundScreen> {
  final _formKey = GlobalKey<FormState>();
  final _namaBarangController = TextEditingController();
  final _unitController = TextEditingController();
  final _qtyController = TextEditingController();
  int? _selectedItemId;
  int? _selectedItemStock;
  bool _isLoading = false;

  @override
  void dispose() {
    _namaBarangController.dispose();
    _unitController.dispose();
    _qtyController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        await supabase.from('transactions').insert({
          'item_id': _selectedItemId,
          'type': 'outbound',
          'quantity': int.parse(_qtyController.text),
          // ================================================================
          // PERBAIKAN: Mengirim waktu real-time dari perangkat
          // ================================================================
          'transaction_date': DateTime.now().toIso8601String(),
        });

        ref.invalidate(outboundHistoryProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Permintaan berhasil dibuat!'), backgroundColor: Colors.green));
          context.pop();
        }
      } catch (e) {
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal: $e'), backgroundColor: Colors.red));
      } finally {
        if(mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Buat Permintaan Barang')),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: TextEditingController(text: DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(DateTime.now())),
                readOnly: true,
                decoration: const InputDecoration(labelText: 'Tanggal'),
              ),
              const SizedBox(height: 16),
              Autocomplete<Map<String, dynamic>>(
                displayStringForOption: (option) => option['item_code'],
                optionsBuilder: (value) async {
                  if (value.text.isEmpty) {
                    if (_selectedItemStock != null) {
                      setState(() => _selectedItemStock = null);
                    }
                    return const Iterable.empty();
                  }
                  final response = await supabase.from('items').select('id, item_code, item_name, unit, total_stok').ilike('item_code', '%${value.text}%');
                  return response;
                },
                onSelected: (selection) {
                  setState(() {
                    _selectedItemId = selection['id'];
                    _namaBarangController.text = selection['item_name'];
                    _unitController.text = selection['unit'];
                    _selectedItemStock = selection['total_stok'] ?? 0;
                  });
                },
                fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
                  return TextFormField(
                    controller: controller,
                    focusNode: focusNode,
                    decoration: const InputDecoration(labelText: 'Kode Barang (Ketik untuk mencari)'),
                    validator: (val) => _selectedItemId == null ? 'Pilih barang dari daftar' : null,
                  );
                },
              ),
              const SizedBox(height: 16),
              TextFormField(controller: _namaBarangController, readOnly: true, decoration: const InputDecoration(labelText: 'Nama Barang')),
              
              Visibility(
                visible: _selectedItemStock != null,
                child: Padding(
                  padding: const EdgeInsets.only(top: 8.0, left: 12.0),
                  child: Text(
                    'Stok Tersedia: ${_selectedItemStock ?? 0}',
                    style: TextStyle(
                      color: (_selectedItemStock ?? 0) > 0 ? Colors.green.shade800 : Colors.red.shade800,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _qtyController,
                      decoration: const InputDecoration(labelText: 'Qty'),
                      keyboardType: TextInputType.number,
                      validator: (val) {
                        if (val == null || val.isEmpty) return 'Wajib diisi';
                        final requestedQty = int.tryParse(val);
                        if (requestedQty == null || requestedQty <= 0) return 'Angka > 0';

                        if (_selectedItemStock != null) {
                          if (_selectedItemStock == 0) {
                            return 'Stok barang ini kosong!';
                          }
                          if (requestedQty > _selectedItemStock!) {
                            return 'Qty melebihi stok!';
                          }
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(child: TextFormField(controller: _unitController, readOnly: true, decoration: const InputDecoration(labelText: 'Unit'))),
                ],
              ),
              const SizedBox(height: 32),
              _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(
                    onPressed: _submitForm,
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                    child: const Text('Buat Permintaan'),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}