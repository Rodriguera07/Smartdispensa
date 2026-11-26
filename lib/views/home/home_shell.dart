import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../viewmodels/shopping_list_viewmodel.dart';
import '../../widgets/common_widgets.dart' show ScanGlowFab;
import '../../widgets/gradient_background.dart';
import '../profile/profile_view.dart';
import '../reports/reports_view.dart';
import '../scanner/scanner_view.dart';
import '../shopping/shopping_list_view.dart';
import 'dashboard_view.dart';

/// Estrutura principal: 4 abas + botão central "Escanear Nota Fiscal".
///
/// Usa `IndexedStack` para preservar o estado (posição de rolagem, filtros)
/// de cada aba ao alternar entre elas.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _tabs = <Widget>[
    DashboardView(),
    ShoppingListView(),
    ReportsView(),
    ProfileView(),
  ];

  void _go(int i) => setState(() => _index = i);

  @override
  Widget build(BuildContext context) {
    final pending =
        context.select<ShoppingListViewModel, int>((s) => s.pendingCount);

    return Scaffold(
      extendBody: true,
      body: GradientBackground(
        child: IndexedStack(index: _index, children: _tabs),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(top: 18),
        child: ScanGlowFab(onPressed: () => ScannerView.open(context)),
      ),
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 10,
        height: 76,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Row(
          children: [
            _NavItem(
              icon: Icons.home_rounded,
              label: 'Início',
              selected: _index == 0,
              onTap: () => _go(0),
            ),
            _NavItem(
              icon: Icons.shopping_cart_rounded,
              label: 'Lista',
              badge: pending,
              selected: _index == 1,
              onTap: () => _go(1),
            ),
            const SizedBox(width: 84), // espaço do FAB
            _NavItem(
              icon: Icons.insights_rounded,
              label: 'Relatórios',
              selected: _index == 2,
              onTap: () => _go(2),
            ),
            _NavItem(
              icon: Icons.person_rounded,
              label: 'Perfil',
              selected: _index == 3,
              onTap: () => _go(3),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.badge = 0,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int badge;

  @override
  Widget build(BuildContext context) {
    final color =
        selected ? context.colors.primary : context.colors.onSurfaceVariant;
    return Expanded(
      child: Semantics(
        selected: selected,
        button: true,
        label: badge > 0 ? '$label, $badge itens' : label,
        excludeSemantics: true,
        child: InkResponse(
          onTap: onTap,
          radius: 40,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Badge(
                isLabelVisible: badge > 0,
                label: Text('$badge'),
                child: AnimatedScale(
                  scale: selected ? 1.12 : 1,
                  duration: const Duration(milliseconds: 180),
                  child: Icon(icon, color: color, size: 28),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.fade,
                softWrap: false,
                style: context.text.labelMedium?.copyWith(
                  color: color,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
