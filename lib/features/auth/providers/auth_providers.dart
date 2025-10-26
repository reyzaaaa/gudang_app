import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gudang_app/main.dart'; // Akses supabase client

final userRoleProvider = StateProvider<String?>((ref) {
  final user = supabase.auth.currentUser;

  // Cek apakah user ada (appMetadata diasumsikan tidak null jika user ada)
  if (user != null) {
    // PERBAIKAN 1: Hapus pengecekan 'user.appMetadata != null'
    // PERBAIKAN 2: Hapus '!' setelah appMetadata
    return user.appMetadata['role'] as String? ?? 'admin';
  }

  // Jika tidak ada user, default ke admin
  return 'admin';
});

final isStaffProvider = Provider<bool>((ref) {
  final role = ref.watch(userRoleProvider);
  return role == 'staff';
});