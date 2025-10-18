import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gudang_app/features/auth/screens/login_screen.dart';
import 'package:gudang_app/features/dashboard/screens/dashboard_screen.dart';
import 'package:gudang_app/features/global/screens/scanner_screen.dart';
import 'package:gudang_app/features/inbound/screens/add_inbound_screen.dart';
import 'package:gudang_app/features/inbound/screens/inbound_detail_screen.dart';
import 'package:gudang_app/features/inbound/screens/inbound_list_screen.dart';
import 'package:gudang_app/features/management/screens/master_data_screen.dart';
import 'package:gudang_app/features/outbound/screens/add_outbound_screen.dart';
import 'package:gudang_app/features/outbound/screens/outbound_detail_screen.dart';
import 'package:gudang_app/features/outbound/screens/outbound_list_screen.dart';
import 'package:gudang_app/features/outbound/screens/picking_screen.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

final supabase = Supabase.instance.client;

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final baseTextTheme = Theme.of(context).textTheme;

    return MaterialApp.router(
      title: 'Manajemen Gudang',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        // PERUBAHAN: Skema warna diubah menjadi biru muda
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFADC8FF), // Warna biru muda dari gambar
          brightness: Brightness.light,
          primary: const Color(0xFF005AC1),   // Biru yang lebih kuat untuk teks & ikon aktif
        ),
        textTheme: GoogleFonts.interTextTheme(baseTextTheme),
      ),
      routerConfig: _router,
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

class DataBahanBakuScreen extends StatelessWidget {
  const DataBahanBakuScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return const MasterDataScreen();
  }
}

final GoRouter _router = GoRouter(
  initialLocation: '/inbound',
  redirect: (context, state) {
    final session = supabase.auth.currentSession;
    final isLoggingIn = state.matchedLocation == '/login';
    if (session == null) {
      return isLoggingIn ? null : '/login';
    }
    if (isLoggingIn) {
      return '/inbound';
    }
    return null;
  },
  routes: [
    GoRoute(
      path: '/',
      redirect: (_, __) => '/inbound',
    ),
    GoRoute(
      path: '/scanner',
      pageBuilder: (context, state) => CustomTransitionPage(
        child: const ScannerScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
              .animate(animation),
          child: child,
        ),
      ),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    ShellRoute(
      builder: (context, state, child) {
        return DashboardScreen(child: child);
      },
      routes: [
        GoRoute(
          path: '/inbound',
          builder: (context, state) => const InboundListScreen(),
          routes: [
            GoRoute(
              path: 'add',
              pageBuilder: (context, state) => CustomTransitionPage<void>(
                key: state.pageKey,
                child: const AddInboundScreen(),
                transitionsBuilder:
                    (context, animation, secondaryAnimation, child) =>
                        FadeTransition(opacity: animation, child: child),
              ),
            ),
            GoRoute(
              path: ':transactionId',
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
        GoRoute(
          path: '/outbound',
          builder: (context, state) => const OutboundListScreen(),
          routes: [
            GoRoute(
              path: 'add',
              pageBuilder: (context, state) => CustomTransitionPage(
                child: const AddOutboundScreen(),
                transitionsBuilder: (context, anim, secAnim, child) =>
                    FadeTransition(opacity: anim, child: child),
              ),
            ),
            GoRoute(
              path: 'picking',
              builder: (context, state) {
                final transaction = state.extra as Map<String, dynamic>;
                return PickingScreen(transaction: transaction);
              },
            ),
            GoRoute(
              path: ':transactionId',
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
        GoRoute(
          path: '/master-data',
          builder: (context, state) => const DataBahanBakuScreen(),
        ),
      ],
    ),
  ],
);