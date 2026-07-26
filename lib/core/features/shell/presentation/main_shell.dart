import 'package:flutter/material.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  static const List<Widget> _pages = [
    _PlaceholderPage(
      title: 'Início',
      description: 'Seu resumo financeiro aparecerá aqui.',
      icon: Icons.home_rounded,
    ),
    _PlaceholderPage(
      title: 'Histórico',
      description: 'Suas despesas serão organizadas por data.',
      icon: Icons.history_rounded,
    ),
    _PlaceholderPage(
      title: 'Relatórios',
      description: 'Seus resumos e gráficos aparecerão aqui.',
      icon: Icons.bar_chart_rounded,
    ),
    _PlaceholderPage(
      title: 'Perfil',
      description: 'Limite, categorias e configurações.',
      icon: Icons.person_rounded,
    ),
  ];

  void _openAddExpense() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (modalContext) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 36),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(28),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              const SizedBox(height: 24),
              const Icon(
                Icons.add_card_rounded,
                size: 44,
                color: Color(0xFF3DDC78),
              ),
              const SizedBox(height: 14),
              const Text(
                'Novo gasto',
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'O formulário de registro rápido será criado na próxima etapa.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    Navigator.of(modalContext).pop();
                  },
                  child: const Text('Fechar'),
                ),
              ),
            ],
          ),
        );
      },
    );
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

class _PlaceholderPage extends StatelessWidget {
  const _PlaceholderPage({
    required this.title,
    required this.description,
    required this.icon,
  });

  final String title;
  final String description;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 58,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 20),
              Text(
                title,
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                description,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}