import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gudang_app/main.dart';

// Provider untuk menyimpan state tanggal yang dipilih.
// Secara default, nilainya adalah hari ini.
final selectedDateProvider = StateProvider.autoDispose<DateTime>((ref) {
  // Mengambil waktu saat ini tanpa informasi jam, menit, detik
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
});

// Provider histori yang "mendengarkan" provider tanggal.
final inboundHistoryProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  
  // "Dengarkan" tanggal yang sedang dipilih.
  final selectedDate = ref.watch(selectedDateProvider);

  // Tentukan rentang waktu: dari awal hari (00:00) hingga akhir hari (23:59).
  final startDate = selectedDate;
  final endDate = startDate.add(const Duration(days: 1));

  // Ambil data dari Supabase dengan filter tanggal.
  final response = await supabase
      .from('transactions')
      .select('*, items(*)')
      .eq('type', 'inbound')
      // Tambahkan filter: tanggal transaksi harus lebih besar atau sama dengan awal hari...
      .gte('transaction_date', startDate.toIso8601String())
      // ...dan harus lebih kecil dari awal hari berikutnya.
      .lt('transaction_date', endDate.toIso8601String())
      .order('transaction_date', ascending: false);
  
  return response;
});