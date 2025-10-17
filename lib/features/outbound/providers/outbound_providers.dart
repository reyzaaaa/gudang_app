import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gudang_app/main.dart';

final selectedDateOutboundProvider = StateProvider.autoDispose<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
});

final outboundHistoryProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final selectedDate = ref.watch(selectedDateOutboundProvider);
  final startDate = selectedDate;
  final endDate = startDate.add(const Duration(days: 1));

  final response = await supabase
      .from('transactions')
      .select('*, items(*)')
      .eq('type', 'outbound') // Filter untuk transaksi keluar
      .gte('transaction_date', startDate.toIso8601String())
      .lt('transaction_date', endDate.toIso8601String())
      .order('transaction_date', ascending: false);
  
  return response;
});