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
    final int selectedIndex = _calculateSelectedIndex(context);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        shape: Border(
          bottom: BorderSide(color: Colors.grey.shade300, width: 1),
        ),
        title: Text(
          _getAppBarTitle(selectedIndex),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_outlined),
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
      body: Row(
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
          VerticalDivider(thickness: 1, width: 1, color: Colors.grey.shade300),
          Expanded(
            child: Container(
              color: Colors.grey[100],
              child: widget.child,
            ),
          ),
        ],
      ),
    );
  }
}