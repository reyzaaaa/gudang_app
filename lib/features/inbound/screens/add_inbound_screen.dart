import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gudang_app/features/inbound/providers/inbound_providers.dart';
import 'package:gudang_app/main.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AddInboundScreen extends ConsumerStatefulWidget {
  const AddInboundScreen({super.key});

  @override
  ConsumerState<AddInboundScreen> createState() => _AddInboundScreenState();
}

class _AddInboundScreenState extends ConsumerState<AddInboundScreen> {
  final _formKey = GlobalKey<FormState>();
  final _tanggalController = TextEditingController();
  final _kodeBarangController = TextEditingController();
  final _namaBarangController = TextEditingController();
  final _qtyController = TextEditingController();
  
  String? _selectedUnit;
  int? _selectedItemId;
  final List<String> _units = ['Kg', 'Roll', 'Pcs', 'Box', 'Liter'];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tanggalController.text = DateFormat('yyyy-MM-dd').format(DateTime.now());
  }

  @override
  void dispose() {
    _tanggalController.dispose();
    _kodeBarangController.dispose();
    _namaBarangController.dispose();
    _qtyController.dispose();
    super.dispose();
  }
  
  Future<void> _selectDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
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
                        decoration: const InputDecoration(labelText: 'Kode Barang Baru'),
                        validator: (value) => (value == null || value.isEmpty) ? 'Wajib diisi' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: newNameController,
                        decoration: const InputDecoration(labelText: 'Nama Barang'),
                        validator: (value) => (value == null || value.isEmpty) ? 'Wajib diisi' : null,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(labelText: 'Unit'),
                        items: _units.map((String unit) => DropdownMenuItem<String>(value: unit, child: Text(unit))).toList(),
                        onChanged: (value) => newUnit = value,
                        validator: (value) => value == null ? 'Pilih unit' : null,
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
                isSaving ? const CircularProgressIndicator() : ElevatedButton(
                  child: const Text('Simpan'),
                  onPressed: () async {
                    if (dialogFormKey.currentState!.validate()) {
                      setDialogState(() => isSaving = true);
                      try {
                        final result = await supabase
                            .from('items')
                            .insert({
                              'item_code': newCodeController.text.trim(),
                              'item_name': newNameController.text.trim(),
                              'unit': newUnit,
                            })
                            .select()
                            .single();
                        if (mounted) Navigator.of(context).pop(result);
                      } on PostgrestException catch (error) {
                         if(mounted){
                           ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Gagal: ${error.message.contains("duplicate key") ? "Kode barang sudah ada." : error.message}'), 
                                backgroundColor: Colors.red
                              ),
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
        _kodeBarangController.text = newItem['item_code'];
        _namaBarangController.text = newItem['item_name'];
        _selectedUnit = newItem['unit'];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Barang baru berhasil dibuat!'), backgroundColor: Colors.green),
      );
    }
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
       if (_selectedItemId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pilih barang yang valid dari daftar.'), backgroundColor: Colors.orange),
        );
        return;
      }

      setState(() => _isLoading = true);

      try {
        // ================================================================
        // PERBAIKAN: Menggabungkan tanggal dari picker dengan waktu saat ini
        // ================================================================
        // 1. Ambil tanggal yang dipilih dari controller
        final pickedDate = DateFormat('yyyy-MM-dd').parse(_tanggalController.text);
        // 2. Ambil waktu (jam, menit, detik) saat ini
        final now = DateTime.now();
        // 3. Gabungkan menjadi satu DateTime yang lengkap
        final finalDateTime = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          now.hour,
          now.minute,
          now.second,
        );
        // ================================================================

        await supabase.from('transactions').insert({
          'item_id': _selectedItemId,
          'type': 'inbound',
          'quantity': int.parse(_qtyController.text),
          // PERBAIKAN DI SINI: Gunakan DateTime yang sudah lengkap
          'transaction_date': finalDateTime.toIso8601String(), 
          'user_id': supabase.auth.currentUser!.id,
        });

        ref.invalidate(inboundHistoryProvider);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Transaksi penerimaan berhasil disimpan!'), backgroundColor: Colors.green),
          );
          context.pop();
        }
        
      } catch (error) {
        if(mounted){
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal menyimpan: $error'), backgroundColor: Colors.red),
          );
        }
      } finally {
        if(mounted){
          setState(() => _isLoading = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Input Penerimaan Barang'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _tanggalController,
                decoration: InputDecoration(
                  labelText: 'Tanggal',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.calendar_today),
                    onPressed: _selectDate,
                  ),
                ),
                readOnly: true,
              ),
              const SizedBox(height: 16),
              Autocomplete<Map<String, dynamic>>(
                displayStringForOption: (option) => option['item_code'],
                optionsBuilder: (TextEditingValue textEditingValue) async {
                  if (textEditingValue.text.isEmpty) {
                    return const Iterable<Map<String, dynamic>>.empty();
                  }
                  final response = await supabase
                      .from('items')
                      .select()
                      .ilike('item_code', '%${textEditingValue.text}%');
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
                    _kodeBarangController.text = selection['item_code'];
                    _namaBarangController.text = selection['item_name'];
                    _selectedUnit = unitExists ? normalizedUnit : null;
                  });
                },
                fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                  _kodeBarangController.addListener(() {
                    if (controller.text != _kodeBarangController.text) {
                      controller.text = _kodeBarangController.text;
                    }
                  });
                  return TextFormField(
                    controller: controller,
                    focusNode: focusNode,
                    decoration: InputDecoration(
                      labelText: 'Kode Barang (Ketik untuk mencari)',
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.search),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.add_box_outlined),
                            tooltip: 'Tambah Barang Baru',
                            onPressed: _showAddNewItemDialog,
                          ),
                        ],
                      ),
                    ),
                    validator: (value) {
                       if (value == null || value.isEmpty) return 'Wajib diisi';
                       if (_selectedItemId == null) return 'Pilih barang dari daftar atau buat baru';
                       return null;
                    },
                  );
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _namaBarangController,
                decoration: const InputDecoration(labelText: 'Nama Barang', filled: false),
                readOnly: true,
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
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Wajib diisi';
                        if (int.tryParse(value) == null || int.parse(value) <= 0) {
                          return 'Angka > 0';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedUnit,
                      decoration: const InputDecoration(labelText: 'Unit'),
                      items: _units.map((String unit) {
                        return DropdownMenuItem<String>(
                          value: unit,
                          child: Text(unit),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedUnit = value;
                        });
                      },
                      validator: (value) => value == null ? 'Pilih unit' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton.icon(
                      onPressed: _submitForm,
                      icon: const Icon(Icons.save),
                      label: const Text('Simpan Transaksi'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16)
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}