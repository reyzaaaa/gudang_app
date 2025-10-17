import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gudang_app/features/outbound/providers/outbound_providers.dart';
import 'package:intl/intl.dart';

class OutboundListScreen extends ConsumerWidget {
  const OutboundListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDate = ref.watch(selectedDateOutboundProvider);
    final selectedDateNotifier = ref.read(selectedDateOutboundProvider.notifier);
    final historyAsyncValue = ref.watch(outboundHistoryProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 16, 10),
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
                            context.go('/outbound/picking', extra: trx);
                          } else {
                            context.go('/outbound/${trx['id']}');
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