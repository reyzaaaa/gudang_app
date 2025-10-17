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
  // State baru untuk mengontrol status navigasi (terbuka/tertutup)
  bool _isNavExpanded = true;

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
    final String location = GoRouterState.of(context).matchedLocation;

    final bool showFab = location == '/inbound' || location == '/outbound';
    final VoidCallback? fabAction = location == '/inbound' 
      ? () => context.go('/inbound/add') 
      : (location == '/outbound' ? () => context.go('/outbound/add') : null);

    final navbarColor = Colors.blue.shade50;

    return Scaffold(
      backgroundColor: navbarColor,
      appBar: AppBar(
        backgroundColor: navbarColor,
        elevation: 0,
        // Tombol baru untuk membuka/menutup navigasi
        leading: IconButton(
          icon: Icon(_isNavExpanded ? Icons.menu_open : Icons.menu),
          onPressed: () {
            setState(() {
              _isNavExpanded = !_isNavExpanded;
            });
          },
        ),
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
      body: Row(
        children: <Widget>[
          // Panel navigasi sekarang dibungkus dengan AnimatedContainer
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            width: _isNavExpanded ? 256 : 96, // Lebar berubah sesuai state
            padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
            child: Column(
              children: [
                _NavButton(
                  label: 'Penerimaan Barang',
                  icon: Icons.move_to_inbox_outlined,
                  isSelected: selectedIndex == 0,
                  isExpanded: _isNavExpanded, // Kirim state ke tombol
                  onTap: () => _onDestinationSelected(0, context),
                ),
                const SizedBox(height: 12),
                _NavButton(
                  label: 'Pengeluaran Barang',
                  icon: Icons.outbox_outlined,
                  isSelected: selectedIndex == 1,
                  isExpanded: _isNavExpanded,
                  onTap: () => _onDestinationSelected(1, context),
                ),
                const SizedBox(height: 12),
                _NavButton(
                  label: 'Data Bahan Baku',
                  icon: Icons.inventory_2_outlined,
                  isSelected: selectedIndex == 2,
                  isExpanded: _isNavExpanded,
                  onTap: () => _onDestinationSelected(2, context),
                ),
              ],
            ),
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
      floatingActionButton: showFab ? FloatingActionButton(
        onPressed: fabAction,
        child: const Icon(Icons.add),
      ) : null,
    );
  }
}

// Widget tombol navigasi sekarang menerima parameter isExpanded
class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.isExpanded, // Parameter baru
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final bool isExpanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Color backgroundColor = isSelected ? theme.colorScheme.primary.withOpacity(0.15) : Colors.white;
    final Color foregroundColor = isSelected ? theme.colorScheme.primary : Colors.grey.shade700;

    return Card(
      elevation: isSelected ? 2 : 1,
      shadowColor: isSelected ? theme.colorScheme.primary.withOpacity(0.2) : Colors.black.withOpacity(0.1),
      color: backgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isSelected ? BorderSide(color: theme.colorScheme.primary, width: 1.5) : BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
            child: isExpanded
              // Tampilan saat navigasi terbuka (expanded)
              ? Row(
                  key: const ValueKey('expanded'),
                  children: [
                    Icon(icon, color: foregroundColor),
                    const SizedBox(width: 16.0),
                    Expanded(
                      child: Text(
                        label,
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: foregroundColor,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ],
                )
              // Tampilan saat navigasi tertutup (collapsed)
              : Row(
                  key: const ValueKey('collapsed'),
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [Icon(icon, color: foregroundColor)],
                ),
          ),
        ),
      ),
    );
  }
}