import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gudang_app/features/auth/screens/login_screen.dart';
import 'package:gudang_app/features/dashboard/screens/dashboard_screen.dart';
import 'package:gudang_app/features/global/screens/scanner_screen.dart';
import 'package:gudang_app/features/inbound/screens/inbound_detail_screen.dart';
import 'package:gudang_app/features/inbound/screens/inbound_list_screen.dart';
import 'package:gudang_app/features/management/screens/master_data_screen.dart';
import 'package:gudang_app/features/outbound/screens/outbound_detail_screen.dart';
import 'package:gudang_app/features/outbound/screens/outbound_list_screen.dart';
import 'package:gudang_app/features/outbound/screens/picking_screen.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// --- Kredensial Supabase (Diambil dari Environment Variables saat Build) ---
const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const String supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID', null);
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );
  runApp(const ProviderScope(child: MyApp()));
}

// --- Instance Supabase Client ---
final supabase = Supabase.instance.client;

// --- Aplikasi Utama ---
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final baseTextTheme = Theme.of(context).textTheme;

    return MaterialApp.router(
      title: 'Manajemen Gudang',
      debugShowCheckedModeBanner: false,
      // --- Tema Aplikasi ---
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFADC8FF), // Biru Muda
          brightness: Brightness.light,
          primary: const Color(0xFF005AC1),   // Biru Aktif
        ),
        textTheme: GoogleFonts.interTextTheme(baseTextTheme),
      ),
      // --- Konfigurasi Navigasi ---
      routerConfig: _router,
      // --- Konfigurasi Lokalisasi ---
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('id', 'ID'),
        Locale('en', 'US'),
      ],
      locale: const Locale('id', 'ID'),
    );
  }
}

// --- Placeholder untuk Halaman Master Data ---
class DataBahanBakuScreen extends StatelessWidget {
  const DataBahanBakuScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return const MasterDataScreen();
  }
}

// --- Konfigurasi GoRouter ---
final GoRouter _router = GoRouter(
  initialLocation: '/inbound', // Halaman awal setelah login
  // --- Logika Redirect ---
  redirect: (context, state) {
    final session = supabase.auth.currentSession;
    final isLoggingIn = state.matchedLocation == '/login';
    if (session == null) { // Jika belum login
      return isLoggingIn ? null : '/login'; // Arahkan ke login jika belum di sana
    }
    if (isLoggingIn) { // Jika sudah login tapi mencoba ke /login
      return '/inbound'; // Arahkan ke dashboard
    }
    return null; // Biarkan navigasi berjalan normal
  },
  // --- Daftar Rute ---
  routes: [
    GoRoute(
      path: '/', // Root path
      redirect: (_, __) => '/inbound', // Otomatis redirect ke /inbound
    ),
    GoRoute(
      path: '/scanner', // Halaman pemindai
      pageBuilder: (context, state) => CustomTransitionPage(
        child: const ScannerScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            SlideTransition( // Animasi muncul dari bawah
          position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero).animate(animation),
          child: child,
        ),
      ),
    ),
    GoRoute(
      path: '/login', // Halaman login
      builder: (context, state) => const LoginScreen(),
    ),
    // --- Rute Utama di dalam Dashboard (Menggunakan ShellRoute) ---
    ShellRoute(
      builder: (context, state, child) {
        return DashboardScreen(child: child); // Dashboard sebagai 'bingkai'
      },
      routes: [
        // --- Modul Penerimaan Barang ---
        GoRoute(
          path: '/inbound',
          builder: (context, state) => const InboundListScreen(), // Halaman daftar & input
          routes: [
            // Rute 'add' sudah dihapus
            GoRoute(
              path: ':transactionId', // Halaman detail (menggunakan ID dari URL)
              builder: (context, state) {
                final transactionId = int.tryParse(state.pathParameters['transactionId'] ?? '');
                if (transactionId == null) {
                  return const Scaffold(body: Center(child: Text('ID Transaksi tidak valid')));
                }
                return InboundDetailScreen(transactionId: transactionId);
              },
            ),
          ],
        ),
        // --- Modul Pengeluaran Barang ---
        GoRoute(
          path: '/outbound',
          builder: (context, state) => const OutboundListScreen(), // Halaman daftar & input
          routes: [
            // Rute 'add' sudah dihapus
            GoRoute(
              path: 'picking', // Halaman pengambilan barang
              builder: (context, state) {
                // Halaman picking masih butuh data transaksi awal
                final transaction = state.extra as Map<String, dynamic>;
                return PickingScreen(transaction: transaction);
              },
            ),
            GoRoute(
              path: ':transactionId', // Halaman detail (menggunakan ID dari URL)
              builder: (context, state) {
                final transactionId = int.tryParse(state.pathParameters['transactionId'] ?? '');
                 if (transactionId == null) {
                  return const Scaffold(body: Center(child: Text('ID Transaksi tidak valid')));
                }
                return OutboundDetailScreen(transactionId: transactionId);
              },
            ),
          ],
        ),
        // --- Modul Data Master ---
        GoRoute(
          path: '/master-data',
          builder: (context, state) => const DataBahanBakuScreen(), // Menunjuk ke widget placeholder
        ),
      ],
    ),
  ],
);