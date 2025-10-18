import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:gudang_app/main.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    required this.child,
    super.key,
  });

  final Widget child;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {

  int _calculateSelectedIndex(BuildContext context) {
    final String location = GoRouterState.of(context).matchedLocation;
    if (location.startsWith('/inbound')) return 0;
    if (location.startsWith('/outbound')) return 1;
    if (location.startsWith('/master-data')) return 2;
    return 0;
  }
  
  String _getAppBarTitle(int index) {
    switch (index) {
      case 0: return 'Penerimaan Barang';
      case 1: return 'Pengeluaran Barang';
      case 2: return 'Data Bahan Baku';
      default: return 'Dashboard';
    }
  }

  void _onDestinationSelected(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.go('/inbound');
        break;
      case 1:
        context.go('/outbound');
        break;
      case 2:
        context.go('/master-data');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final int selectedIndex = _calculateSelectedIndex(context);
        final String location = GoRouterState.of(context).matchedLocation;
        final theme = Theme.of(context);

        // Tentukan breakpoint untuk beralih antara tampilan mobile dan desktop
        const double mobileBreakpoint = 600;
        final bool isDesktop = constraints.maxWidth > mobileBreakpoint;

        final bool showFab = location == '/inbound' || location == '/outbound';
        final VoidCallback? fabAction = location == '/inbound' 
          ? () => context.go('/inbound/add') 
          : (location == '/outbound' ? () => context.go('/outbound/add') : null);

        return Scaffold(
          appBar: AppBar(
            backgroundColor: isDesktop ? Colors.blue.shade50 : Colors.white,
            elevation: 0,
            title: Text(
              _getAppBarTitle(selectedIndex),
              style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black87),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.logout_outlined, color: Colors.black54),
                tooltip: 'Logout',
                onPressed: () async {
                  await supabase.auth.signOut();
                  if (context.mounted) {
                    context.go('/login');
                  }
                },
              ),
              const SizedBox(width: 8),
            ],
          ),
          
          // Tampilan body akan berbeda antara desktop dan mobile
          body: isDesktop 
            ? _buildDesktopLayout(context, selectedIndex, theme) // Tampilan untuk layar lebar
            : widget.child, // Tampilan untuk layar sempit (HP)

          // Navigasi bawah hanya muncul di layar sempit (HP)
          bottomNavigationBar: isDesktop 
            ? null 
            : BottomNavigationBar(
                currentIndex: selectedIndex,
                onTap: (index) => _onDestinationSelected(index, context),
                items: const [
                  BottomNavigationBarItem(
                    icon: Icon(Icons.move_to_inbox_outlined),
                    activeIcon: Icon(Icons.move_to_inbox),
                    label: 'Penerimaan',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.outbox_outlined),
                    activeIcon: Icon(Icons.outbox),
                    label: 'Pengeluaran',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.inventory_2_outlined),
                    activeIcon: Icon(Icons.inventory_2),
                    label: 'Data Master',
                  ),
                ],
              ),
              
          floatingActionButton: showFab ? FloatingActionButton(
            onPressed: fabAction,
            child: const Icon(Icons.add),
          ) : null,
        );
      },
    );
  }

  // Widget untuk membangun layout versi Desktop/Layar Lebar
  Widget _buildDesktopLayout(BuildContext context, int selectedIndex, ThemeData theme) {
    return Container(
      color: Colors.blue.shade50, // Latar belakang utama
      child: Row(
        children: <Widget>[
          // Kita kembalikan ke NavigationRail standar karena lebih mudah diatur
          NavigationRail(
            selectedIndex: selectedIndex,
            onDestinationSelected: (index) => _onDestinationSelected(index, context),
            extended: true,
            minExtendedWidth: 240,
            backgroundColor: Colors.transparent, // Transparan agar menyatu dengan latar
            elevation: 0,
            useIndicator: true,
            indicatorShape: const StadiumBorder(),
            indicatorColor: theme.colorScheme.primary.withOpacity(0.1),
            groupAlignment: -0.8,
            selectedIconTheme: IconThemeData(color: theme.colorScheme.primary),
            selectedLabelTextStyle: TextStyle(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
            unselectedIconTheme: IconThemeData(color: Colors.grey.shade600),
            unselectedLabelTextStyle: TextStyle(
              color: Colors.grey.shade600,
              fontWeight: FontWeight.normal,
               fontSize: 14,
            ),
            destinations: const <NavigationRailDestination>[
              NavigationRailDestination(
                icon: Icon(Icons.move_to_inbox_outlined),
                selectedIcon: Icon(Icons.move_to_inbox),
                label: Text('Penerimaan Barang'),
                padding: EdgeInsets.symmetric(vertical: 8),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.outbox_outlined),
                selectedIcon: Icon(Icons.outbox),
                label: Text('Pengeluaran Barang'),
                padding: EdgeInsets.symmetric(vertical: 8),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.inventory_2_outlined),
                selectedIcon: Icon(Icons.inventory_2),
                label: Text('Data Bahan Baku'),
                padding: EdgeInsets.symmetric(vertical: 8),
              ),
            ],
          ),
          
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                 color: Colors.grey[100],
                 borderRadius: const BorderRadius.only(topLeft: Radius.circular(24))
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(24)),
                child: widget.child,
              ),
            ),
          ),
        ],
      ),
    );
  }
}