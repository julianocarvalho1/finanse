import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../expenses/presentation/widgets/add_expense_modal.dart';
import '../../history/presentation/history_page.dart';
import '../../home/presentation/home_page.dart';
import '../../profile/presentation/profile_page.dart';
import '../../reports/presentation/reports_page.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  static const List<Widget> _pages = <Widget>[
    HomePage(),
    HistoryPage(),
    ReportsPage(),
    ProfilePage(),
  ];

  void _openAddExpense() {
    AddExpenseModal.show(context);
  }

  void _selectPage(int index) {
    if (_currentIndex == index) {
      return;
    }

    // Fecha qualquer mensagem antes de trocar de página.
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      extendBody: true,
      body: IndexedStack(index: _currentIndex, children: _pages),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: SizedBox.square(
        dimension: AppSpacing.floatingActionButtonSize,
        child: FloatingActionButton(
          onPressed: _openAddExpense,
          tooltip: 'Adicionar gasto',
          child: const Icon(Icons.add_rounded, size: 32),
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        color:
            theme.bottomNavigationBarTheme.backgroundColor ??
            theme.colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        notchMargin: AppSpacing.xs,
        padding: EdgeInsets.zero,
        shape: const CircularNotchedRectangle(),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: AppSpacing.bottomNavigationHeight,
            child: Row(
              children: <Widget>[
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
                const SizedBox(width: AppSpacing.bottomNavigationHeight),
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
    final ThemeData theme = Theme.of(context);
    final Color selectedColor = theme.colorScheme.primary;
    final Color unselectedColor = AppColors.textMuted(context);
    final Color itemColor = selected ? selectedColor : unselectedColor;

    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
            child: SizedBox.expand(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    transitionBuilder:
                        (Widget child, Animation<double> animation) {
                          return ScaleTransition(
                            scale: animation,
                            child: child,
                          );
                        },
                    child: Icon(
                      selected ? selectedIcon : icon,
                      key: ValueKey<bool>(selected),
                      color: itemColor,
                      size: 23,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.fade,
                    softWrap: false,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: itemColor,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
