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
        final theme = Theme.of(context);

        const double mobileBreakpoint = 700;
        final bool isDesktop = constraints.maxWidth > mobileBreakpoint;

        // ===============================================
        // VARIABEL showFab DAN fabAction DIHAPUS DARI SINI
        // ===============================================

        const mobileNavbarColor = Color(0xFFD6E4FF);

        return Scaffold(
          appBar: AppBar(
            backgroundColor: isDesktop ? Colors.white : mobileNavbarColor,
            elevation: 0,
            shape: isDesktop ? Border(bottom: BorderSide(color: Colors.grey.shade300, width: 1)) : null,
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
          
          body: isDesktop 
            ? _buildDesktopLayout(context, selectedIndex, theme)
            : Container(color: Colors.white, child: widget.child), 

          bottomNavigationBar: isDesktop 
            ? null 
            : BottomNavigationBar(
                backgroundColor: mobileNavbarColor,
                elevation: 0,
                type: BottomNavigationBarType.fixed,
                currentIndex: selectedIndex,
                onTap: (index) => _onDestinationSelected(index, context),
                selectedItemColor: theme.colorScheme.primary,
                unselectedItemColor: Colors.grey.shade700,
                items: const [
                  BottomNavigationBarItem(
                    icon: Icon(Icons.move_to_inbox_outlined),
                    label: 'Penerimaan',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.outbox_outlined),
                    label: 'Pengeluaran',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.inventory_2_outlined),
                    label: 'Data Master',
                  ),
                ],
              ),
              
          // ===============================================
          // floatingActionButton DIHAPUS DARI SINI
          // ===============================================
          
        );
      },
    );
  }

  Widget _buildDesktopLayout(BuildContext context, int selectedIndex, ThemeData theme) {
    return Row(
      children: <Widget>[
        NavigationRail(
          selectedIndex: selectedIndex,
          onDestinationSelected: (index) => _onDestinationSelected(index, context),
          extended: true,
          minExtendedWidth: 240,
          backgroundColor: Colors.white,
          useIndicator: true,
          indicatorShape: const StadiumBorder(),
          indicatorColor: theme.colorScheme.primary.withOpacity(0.1),
          groupAlignment: -0.8,
          selectedIconTheme: IconThemeData(color: theme.colorScheme.primary),
          unselectedIconTheme: IconThemeData(color: Colors.grey.shade600),
          destinations: const <NavigationRailDestination>[
            NavigationRailDestination(
              icon: Icon(Icons.move_to_inbox_outlined),
              label: Text('Penerimaan Barang'),
            ),
            NavigationRailDestination(
              icon: Icon(Icons.outbox_outlined),
              label: Text('Pengeluaran Barang'),
            ),
            NavigationRailDestination(
              icon: Icon(Icons.inventory_2_outlined),
              label: Text('Data Bahan Baku'),
            ),
          ],
        ),
        VerticalDivider(thickness: 1, width: 1, color: Colors.grey.shade300),
        Expanded(
          child: Container(
            color: Colors.grey[50],
            child: widget.child,
          ),
        ),
      ],
    );
  }
}