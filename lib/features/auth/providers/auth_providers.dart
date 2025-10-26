import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gudang_app/main.dart'; // Akses supabase client
import 'package:supabase_flutter/supabase_flutter.dart'; // Import Supabase types

// Provider yang mendengarkan perubahan status otentikasi Supabase
final authStateProvider = StreamProvider<AuthState>((ref) {
  return supabase.auth.onAuthStateChange;
});

// Provider userRoleProvider yang bergantung pada authStateProvider
final userRoleProvider = StateProvider<String?>((ref) {
  // "Dengarkan" event terbaru dari stream otentikasi
  final authState = ref.watch(authStateProvider);

  // Coba dapatkan user dari event stream
  final user = authState.when(
    data: (data) => data.session?.user, // Ambil user jika ada sesi
    loading: () => null,                // Belum ada data saat loading
    error: (_, __) => null,             // Tidak ada user jika error
  );

  // Cek apakah user ada DAN metadata tidak kosong
  if (user != null && user.appMetadata.isNotEmpty) {
      // Ambil nilai 'role'. Jika key 'role' tidak ada, kembalikan null.
      return user.appMetadata['role'] as String? ?? null;
  }

  // Jika tidak ada user atau metadata kosong, kembalikan null
  return null;
});

// Provider isStaffProvider diubah sedikit untuk lebih aman menangani null
final isStaffProvider = Provider<bool>((ref) {
  final role = ref.watch(userRoleProvider);
  // Pastikan role tidak null DAN bernilai 'staff'
  return role != null && role == 'staff';
});