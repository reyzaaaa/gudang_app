import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gudang_app/features/inbound/providers/inbound_providers.dart';
import 'package:gudang_app/main.dart'; // Untuk akses supabase
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class InboundListScreen extends ConsumerStatefulWidget {
  const InboundListScreen({super.key});

  @override
  ConsumerState<InboundListScreen> createState() => _InboundListScreenState();
}

class _InboundListScreenState extends ConsumerState<InboundListScreen> {
  final _formKey = GlobalKey<FormState>();
  final _tanggalController = TextEditingController();
  final _kodeBarangController = TextEditingController(); // Controller utk Autocomplete
  final _namaBarangController = TextEditingController();
  final _qtyController = TextEditingController();
  String? _selectedUnit;
  int? _selectedItemId;
  final List<String> _units = ['Kg', 'Roll', 'Pcs', 'Box', 'Liter'];
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
    _qtyController.dispose();
    super.dispose();
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    _tanggalController.text = DateFormat('yyyy-MM-dd').format(DateTime.now());
    _kodeBarangController.clear();
    _namaBarangController.clear();
    _qtyController.clear();
    if (mounted) {
      setState(() {
        _selectedItemId = null;
        _selectedUnit = null;
        _isSaving = false;
      });
    }
  }

  Future<void> _selectDate() async {
    DateTime? picked = await showDatePicker(
        context: context,
        initialDate: DateTime.now(),
        firstDate: DateTime(2020),
        lastDate: DateTime(2101), // Memungkinkan memilih tanggal di masa depan
        locale: const Locale('id', 'ID'));
    if (picked != null) {
      setState(() {
        _tanggalController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  Future<void> _showAddNewItemDialog() async {
    final dialogFormKey = GlobalKey<FormState>();
    final newCodeController = TextEditingController();
    final newNameController = TextEditingController();
    String? newUnit;

    final newItem = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        bool isSaving = false;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Tambah Barang Baru'),
              content: Form(
                key: dialogFormKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      TextFormField(
                        controller: newCodeController,
                        decoration:
                            const InputDecoration(labelText: 'Kode Barang Baru'),
                        validator: (value) =>
                            (value == null || value.isEmpty)
                                ? 'Wajib diisi'
                                : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: newNameController,
                        decoration:
                            const InputDecoration(labelText: 'Nama Barang'),
                        validator: (value) =>
                            (value == null || value.isEmpty)
                                ? 'Wajib diisi'
                                : null,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(labelText: 'Unit'),
                        items: _units
                            .map((String unit) => DropdownMenuItem<String>(
                                value: unit, child: Text(unit)))
                            .toList(),
                        onChanged: (value) => newUnit = value,
                        validator: (value) =>
                            value == null ? 'Pilih unit' : null,
                      ),
                    ],
                  ),
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('Batal'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                isSaving
                    ? const CircularProgressIndicator()
                    : ElevatedButton(
                        child: const Text('Simpan'),
                        onPressed: () async {
                          if (dialogFormKey.currentState!.validate()) {
                            setDialogState(() => isSaving = true);
                            try {
                              final result = await supabase
                                  .from('items')
                                  .insert({
                                    'item_code': newCodeController.text.trim().toUpperCase(), // Simpan uppercase
                                    'item_name': newNameController.text.trim(),
                                    'unit': newUnit,
                                  })
                                  .select()
                                  .single();
                              if (mounted) Navigator.of(context).pop(result);
                            } on PostgrestException catch (error) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text(
                                          'Gagal: ${error.message.contains("duplicate key") ? "Kode barang sudah ada." : error.message}'),
                                      backgroundColor: Colors.red),
                                );
                              }
                            } finally {
                              setDialogState(() => isSaving = false);
                            }
                          }
                        },
                      ),
              ],
            );
          },
        );
      },
    );

    if (newItem != null && mounted) {
      setState(() {
        _selectedItemId = newItem['id'];
        _kodeBarangController.text = newItem['item_code']; // Update controller autocomplete
        _namaBarangController.text = newItem['item_name'];
        _selectedUnit = newItem['unit'];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Barang baru berhasil dibuat!'),
            backgroundColor: Colors.green),
      );
    }
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isSaving = true);
      try {
        final pickedDate =
            DateFormat('yyyy-MM-dd').parse(_tanggalController.text);
        final now = DateTime.now();
        final finalDateTime = DateTime(pickedDate.year, pickedDate.month,
            pickedDate.day, now.hour, now.minute, now.second);

        await supabase.from('transactions').insert({
          'item_id': _selectedItemId,
          'type': 'inbound',
          'quantity': int.parse(_qtyController.text),
          'transaction_date': finalDateTime.toIso8601String(),
          'user_id': supabase.auth.currentUser!.id,
          // status 'pending' ditambahkan otomatis oleh database
        });

        ref.invalidate(inboundHistoryProvider);
        _resetForm();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Transaksi berhasil disimpan!'),
              backgroundColor: Colors.green));
        }
      } catch (error) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Gagal menyimpan: $error'),
              backgroundColor: Colors.red));
      } finally {
        if (mounted) setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedDate = ref.watch(selectedDateProvider);
    final selectedDateNotifier = ref.read(selectedDateProvider.notifier);
    final historyAsyncValue = ref.watch(inboundHistoryProvider);
    final theme = Theme.of(context);

    // Langsung return Column, tanpa Scaffold
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // --- Bagian Form Input ---
        Padding(
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
                    Text("Input Penerimaan Baru", style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    // Baris Tanggal & Kode Barang
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: _tanggalController,
                            decoration: InputDecoration(
                              labelText: 'Tanggal',
                              suffixIcon: IconButton(icon: const Icon(Icons.calendar_today, size: 20), onPressed: _selectDate, padding: EdgeInsets.zero, constraints: const BoxConstraints()),
                              isDense: true,
                            ), readOnly: true,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 3,
                          child: Autocomplete<Map<String, dynamic>>(
                             displayStringForOption: (option) => option['item_code'],
                             optionsBuilder: (value) async {
                               if (value.text.isEmpty) {
                                 if (_selectedItemId != null) {
                                   WidgetsBinding.instance.addPostFrameCallback((_) { // Schedule state update
                                     if (mounted) {
                                       setState(() {
                                         _selectedItemId = null;
                                         _namaBarangController.clear();
                                         _selectedUnit = null;
                                       });
                                     }
                                   });
                                 }
                                 return const Iterable.empty();
                               }
                               final response = await supabase.from('items').select().ilike('item_code', '%${value.text}%');
                               return response;
                             },
                             onSelected: (selection) {
                                final String unitFromDb = selection['unit'] ?? '';
                                String normalizedUnit = '';
                                if (unitFromDb.isNotEmpty) {
                                  normalizedUnit = unitFromDb[0].toUpperCase() + unitFromDb.substring(1).toLowerCase();
                                }
                                final bool unitExists = _units.contains(normalizedUnit);

                                setState(() {
                                  _selectedItemId = selection['id'];
                                  _namaBarangController.text = selection['item_name'];
                                  _selectedUnit = unitExists ? normalizedUnit : null;
                                });
                             },
                             fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                               _kodeBarangController.addListener(() { if (controller.text != _kodeBarangController.text) controller.value = _kodeBarangController.value; });
                               controller.addListener(() { if (controller.text != _kodeBarangController.text) _kodeBarangController.value = controller.value; });
                               return TextFormField(
                                 controller: controller,
                                 focusNode: focusNode,
                                 decoration: InputDecoration(
                                   labelText: 'Kode Barang',
                                   isDense: true,
                                   suffixIcon: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.search, size: 20),
                                        IconButton(
                                          icon: const Icon(Icons.add_box_outlined, size: 20),
                                          tooltip: 'Tambah Barang Baru',
                                          onPressed: _showAddNewItemDialog,
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                        ),
                                      ],
                                   ),
                                 ),
                                 validator: (v) => _selectedItemId == null ? 'Pilih!' : null,
                               );
                             },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Field Nama Barang
                    TextFormField(controller: _namaBarangController, readOnly: true, decoration: const InputDecoration(labelText: 'Nama Barang', isDense: true, filled: false, border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none)),
                    const SizedBox(height: 8),
                    // Baris Qty & Unit
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: TextFormField(controller: _qtyController, decoration: const InputDecoration(labelText: 'Qty', isDense: true), keyboardType: TextInputType.number, validator: (v) => (v == null || v.isEmpty || int.tryParse(v) == null || int.parse(v) <= 0) ? 'Qty!' : null)),
                        const SizedBox(width: 8),
                        Expanded(child: DropdownButtonFormField<String>(value: _selectedUnit, items: _units.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(), onChanged: (v) => setState(() => _selectedUnit = v), decoration: const InputDecoration(labelText: 'Unit', isDense: true), validator: (v) => v == null ? 'Pilih!' : null)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Tombol Simpan
                    ElevatedButton.icon(
                      onPressed: _isSaving ? null : _submitForm,
                      icon: _isSaving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save),
                      label: Text(_isSaving ? 'Menyimpan...' : 'Simpan Transaksi'),
                       style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        // --- Bagian Histori ---
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 16, 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'HISTORI PENERIMAAN',
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
                      Icon(Icons.inbox_outlined, size: 80, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'Tidak ada transaksi pada tanggal ini.',
                        style: TextStyle(fontSize: 18, color: Colors.black54),
                      ),
                    ],
                  ),
                );
              }
              return RefreshIndicator(
                onRefresh: () => ref.refresh(inboundHistoryProvider.future),
                child: ListView.builder(
                  padding: const EdgeInsets.only(top: 8, bottom: 8), // Adjusted padding
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
                          context.go('/inbound/${trx['id']}');
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: status == 'pending' ? Colors.orange.shade100 : Colors.green.shade100,
                                child: Icon(
                                  status == 'pending' ? Icons.pending_actions_outlined : Icons.check_circle_outline,
                                  color: status == 'pending' ? Colors.orange.shade800 : Colors.green.shade800,
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
                                    '+${trx['quantity']} ${item != null ? item['unit'] : ''}',
                                    style: TextStyle(
                                      color: Colors.green.shade800,
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