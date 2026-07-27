import 'package:flutter/material.dart';
import '../../home/presentation/home_page.dart';
import '../../expenses/presentation/widgets/add_expense_modal.dart';
import '../../history/presentation/history_page.dart';
import '../../reports/presentation/reports_page.dart';
import '../../profile/presentation/profile_page.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  static const List<Widget> _pages = [
    HomePage(),     // 1. Tela de Início
    HistoryPage(),  // 2. Tela de Histórico
    ReportsPage(),  // 3. Tela de Relatórios
    ProfilePage(),  // 4. Nossa nova Tela de Perfil fechando o ciclo!
  ];

  void _openAddExpense() {
    AddExpenseModal.show(context);
  }

  void _selectPage(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      floatingActionButtonLocation:
      FloatingActionButtonLocation.centerDocked,
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddExpense,
        tooltip: 'Adicionar gasto',
        child: const Icon(
          Icons.add_rounded,
          size: 34,
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        height: 76,
        notchMargin: 9,
        padding: EdgeInsets.zero,
        shape: const CircularNotchedRectangle(),
        child: Row(
          children: [
            _NavigationItem(
              label: 'Início',
              icon: Icons.home_outlined,
              selectedIcon: Icons.home_rounded,
              selected: _currentIndex == 0,
              onTap: () => _selectPage(0),
            ),
            _NavigationItem(
              label: 'Histórico',
              icon: Icons.history_outlined,
              selectedIcon: Icons.history_rounded,
              selected: _currentIndex == 1,
              onTap: () => _selectPage(1),
            ),
            const SizedBox(width: 72),
            _NavigationItem(
              label: 'Relatórios',
              icon: Icons.bar_chart_outlined,
              selectedIcon: Icons.bar_chart_rounded,
              selected: _currentIndex == 2,
              onTap: () => _selectPage(2),
            ),
            _NavigationItem(
              label: 'Perfil',
              icon: Icons.person_outline_rounded,
              selectedIcon: Icons.person_rounded,
              selected: _currentIndex == 3,
              onTap: () => _selectPage(3),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavigationItem extends StatelessWidget {
  const _NavigationItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final selectedColor = Theme.of(context).colorScheme.primary;
    const unselectedColor = Color(0xFF738087);

    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              selected ? selectedIcon : icon,
              color: selected
                  ? selectedColor
                  : unselectedColor,
              size: 23,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              maxLines: 1,
              style: TextStyle(
                color: selected
                    ? selectedColor
                    : unselectedColor,
                fontSize: 10,
                fontWeight: selected
                    ? FontWeight.w700
                    : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
