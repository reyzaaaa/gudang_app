import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gudang_app/features/auth/providers/auth_providers.dart'; // Import provider role
import 'package:gudang_app/features/outbound/providers/outbound_providers.dart';
import 'package:gudang_app/main.dart'; // Untuk akses supabase
import 'package:intl/intl.dart';

class OutboundListScreen extends ConsumerStatefulWidget {
  const OutboundListScreen({super.key});

  @override
  ConsumerState<OutboundListScreen> createState() => _OutboundListScreenState();
}

class _OutboundListScreenState extends ConsumerState<OutboundListScreen> {
  final _formKey = GlobalKey<FormState>();
  final _tanggalController = TextEditingController();
  final _kodeBarangController = TextEditingController();
  final _namaBarangController = TextEditingController();
  final _unitController = TextEditingController();
  final _qtyController = TextEditingController();
  int? _selectedItemId;
  int? _selectedItemStock;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _resetForm();
  }

  @override
  void dispose() {
    _tanggalController.dispose();
    _kodeBarangController.dispose();
    _namaBarangController.dispose();
    _unitController.dispose();
    _qtyController.dispose();
    super.dispose();
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    _tanggalController.text = DateFormat('yyyy-MM-dd').format(DateTime.now());
    _kodeBarangController.clear();
    _namaBarangController.clear();
    _unitController.clear();
    _qtyController.clear();
    if (mounted) {
      setState(() {
        _selectedItemId = null;
        _selectedItemStock = null;
        _isSaving = false;
      });
    }
  }

  Future<void> _selectDate() async {
    DateTime? picked = await showDatePicker(
        context: context,
        initialDate: DateTime.now(),
        firstDate: DateTime(2020),
        lastDate: DateTime(2101),
        locale: const Locale('id', 'ID'));
    if (picked != null) {
      setState(() {
        _tanggalController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isSaving = true);
      try {
        final pickedDate = DateFormat('yyyy-MM-dd').parse(_tanggalController.text);
        final now = DateTime.now();
        final finalDateTime = DateTime(pickedDate.year, pickedDate.month, pickedDate.day, now.hour, now.minute, now.second);

        await supabase.from('transactions').insert({
          'item_id': _selectedItemId,
          'type': 'outbound',
          'quantity': int.parse(_qtyController.text),
          'transaction_date': finalDateTime.toIso8601String(),
          'user_id': supabase.auth.currentUser!.id,
          // status 'pending' ditambahkan otomatis oleh database
        });
        ref.invalidate(outboundHistoryProvider);
        _resetForm();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Permintaan berhasil dibuat!'), backgroundColor: Colors.green));
        }
      } catch (e) {
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal: $e'), backgroundColor: Colors.red));
      } finally {
        if(mounted) setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedDate = ref.watch(selectedDateOutboundProvider);
    final selectedDateNotifier = ref.read(selectedDateOutboundProvider.notifier);
    final historyAsyncValue = ref.watch(outboundHistoryProvider);
    final theme = Theme.of(context);
    final bool isStaff = ref.watch(isStaffProvider); // Cek peran user

    // Langsung return Column, tanpa Scaffold dan FAB
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // --- Bagian Form Input (Conditional Visibility) ---
        Visibility(
          visible: !isStaff,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Card(
               elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Buat Permintaan Baru", style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      // Field Tanggal
                      TextFormField(
                        controller: _tanggalController,
                        readOnly: true,
                        decoration: InputDecoration(
                          labelText: 'Tanggal Permintaan',
                          isDense: true,
                          suffixIcon: IconButton(icon: const Icon(Icons.calendar_today, size: 20), onPressed: _selectDate, padding: EdgeInsets.zero, constraints: const BoxConstraints()),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Autocomplete Nama Barang
                       Autocomplete<Map<String, dynamic>>(
                         displayStringForOption: (option) => option['item_name'],
                         optionsBuilder: (value) async {
                           if (value.text.isEmpty) {
                             if (_selectedItemStock != null) {
                                WidgetsBinding.instance.addPostFrameCallback((_) {
                                   if (mounted) {
                                     setState(() {
                                        _selectedItemId = null;
                                        _kodeBarangController.clear();
                                        _namaBarangController.clear();
                                        _unitController.clear();
                                        _selectedItemStock = null;
                                     });
                                   }
                                });
                             }
                             return const Iterable.empty();
                           }
                           final response = await supabase.from('items').select('id, item_code, item_name, unit, total_stok').ilike('item_name', '%${value.text}%');
                           return response;
                         },
                         onSelected: (selection) {
                           setState(() {
                             _selectedItemId = selection['id'];
                             _kodeBarangController.text = selection['item_code'];
                             _namaBarangController.text = selection['item_name'];
                             _unitController.text = selection['unit'];
                             _selectedItemStock = selection['total_stok'] ?? 0;
                           });
                         },
                         fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
                            _namaBarangController.addListener(() { if (controller.text != _namaBarangController.text) controller.value = _namaBarangController.value; });
                            controller.addListener(() { if (controller.text != _namaBarangController.text) _namaBarangController.value = controller.value; });
                           return TextFormField(
                             controller: controller,
                             focusNode: focusNode,
                             decoration: const InputDecoration(
                               labelText: 'Nama Barang (Cari)',
                               isDense: true,
                               suffixIcon: Icon(Icons.search, size: 20)),
                             validator: (val) => _selectedItemId == null ? 'Pilih!' : null,
                           );
                         },
                       ),
                      const SizedBox(height: 8),
                      // Tampilkan Kode Barang
                      Visibility(
                        visible: _selectedItemId != null,
                        child: Text('Kode: ${_kodeBarangController.text}', style: TextStyle(color: Colors.grey.shade600)),
                      ),
                      // Tampilkan Stok Tersedia
                      Visibility(
                        visible: _selectedItemStock != null,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            'Stok Tersedia: ${_selectedItemStock ?? 0}',
                            style: TextStyle( color: (_selectedItemStock ?? 0) > 0 ? Colors.green.shade800 : Colors.red.shade800, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Baris Qty & Unit
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: TextFormField(controller: _qtyController, decoration: const InputDecoration(labelText: 'Qty', isDense: true), keyboardType: TextInputType.number, validator: (val) {
                             if (val == null || val.isEmpty) return 'Qty!';
                             final reqQty = int.tryParse(val);
                             if (reqQty == null || reqQty <= 0) return '> 0!';
                             if (_selectedItemStock != null) {
                               if (_selectedItemStock == 0) return 'Stok 0!';
                               if (reqQty > _selectedItemStock!) return 'Over!';
                             } return null;
                          })),
                          const SizedBox(width: 8),
                          Expanded(child: TextFormField(controller: _unitController, readOnly: true, decoration: const InputDecoration(labelText: 'Unit', isDense: true, filled: false, border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none))),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Tombol Buat Permintaan
                      ElevatedButton.icon(
                        onPressed: _isSaving ? null : _submitForm,
                        icon: _isSaving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.send),
                        label: Text(_isSaving ? 'Membuat...' : 'Buat Permintaan'),
                        style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        // --- Bagian Histori ---
        Padding(
          padding: EdgeInsets.fromLTRB(24, isStaff ? 16 : 16, 16, 10), // Adjust padding
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'HISTORI PENGELUARAN',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
              ),
              TextButton.icon(
                onPressed: () async {
                  final pickedDate = await showDatePicker(
                     context: context,
                     initialDate: selectedDate,
                     firstDate: DateTime(2020),
                     lastDate: DateTime.now(),
                     locale: const Locale('id', 'ID'),
                  );
                  if (pickedDate != null) {
                    selectedDateNotifier.state = pickedDate;
                  }
                },
                icon: const Icon(Icons.calendar_month_outlined),
                label: Text(DateFormat('d MMM yyyy', 'id_ID').format(selectedDate)),
              ),
            ],
          ),
        ),
        const Divider(height: 1, thickness: 1, indent: 24, endIndent: 24),
        // --- Daftar Histori ---
        Expanded(
          child: historyAsyncValue.when(
            data: (transactions) {
              if (transactions.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.outbox_outlined, size: 80, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'Tidak ada permintaan pada tanggal ini.',
                        style: TextStyle(fontSize: 18, color: Colors.black54),
                      ),
                    ],
                  ),
                );
              }
              return RefreshIndicator(
                onRefresh: () => ref.refresh(outboundHistoryProvider.future),
                child: ListView.builder(
                  padding: const EdgeInsets.only(top: 8, bottom: 8),
                  itemCount: transactions.length,
                  itemBuilder: (context, index) {
                    final trx = transactions[index];
                    final item = trx['items'];
                    final date = DateTime.parse(trx['transaction_date']);
                    final formattedDate =
                        DateFormat('d MMMM yyyy, HH:mm', 'id_ID').format(date);
                    final status = trx['status'] ?? 'pending';

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey.shade200)),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          if (status == 'pending') {
                            GoRouter.of(context).go('/outbound/picking', extra: trx);
                          } else {
                            GoRouter.of(context).go('/outbound/${trx['id']}');
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: status == 'pending' ? Colors.orange.shade100 : Colors.red.shade100,
                                child: Icon(
                                  status == 'pending' ? Icons.pending_actions_outlined : Icons.arrow_upward,
                                  color: status == 'pending' ? Colors.orange.shade800 : Colors.red.shade800,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item != null ? item['item_name'] : 'Barang Dihapus',
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Kode: ${item != null ? item['item_code'] : 'N/A'}\n$formattedDate',
                                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '-${trx['quantity']} ${item != null ? item['unit'] : ''}',
                                    style: const TextStyle(
                                      color: Colors.red,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Chip(
                                    label: Text(status == 'pending' ? 'Pending' : 'Selesai'),
                                    backgroundColor: status == 'pending' ? Colors.orange.shade100 : Colors.green.shade100,
                                    labelStyle: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: status == 'pending' ? Colors.orange.shade800 : Colors.green.shade800,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(child: Text('Terjadi Error: $error')),
          ),
        ),
      ],
    );
  }
}