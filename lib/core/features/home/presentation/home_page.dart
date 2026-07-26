import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

class HomePage extends StatelessWidget {
  const HomePage({
    required this.onAddExpense,
    super.key,
  });

  final VoidCallback onAddExpense;

  @override
  Widget build(BuildContext context) {
    final isDark =
        Theme.of(context).brightness == Brightness.dark;

    final textPrimary = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;

    final textSecondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          20,
          18,
          20,
          120,
        ),
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.menu_rounded),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bom dia! 👋',
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 21,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Aqui está o resumo do seu dia.',
                      style: TextStyle(
                        color: textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () {},
                icon: const Icon(
                  Icons.notifications_none_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          _SummaryCard(
            textPrimary: textPrimary,
            textSecondary: textSecondary,
          ),
          const SizedBox(height: 14),
          _MonthlyLimitCard(
            textPrimary: textPrimary,
            textSecondary: textSecondary,
          ),
          const SizedBox(height: 22),
          Text(
            'Categorias frequentes',
            style: TextStyle(
              color: textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 92,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: const [
                _CategoryShortcut(
                  title: 'Alimentação',
                  icon: Icons.restaurant_rounded,
                  color: AppColors.primary,
                ),
                _CategoryShortcut(
                  title: 'Transporte',
                  icon: Icons.directions_car_rounded,
                  color: AppColors.blue,
                ),
                _CategoryShortcut(
                  title: 'Compras',
                  icon: Icons.shopping_bag_rounded,
                  color: AppColors.orange,
                ),
                _CategoryShortcut(
                  title: 'Saúde',
                  icon: Icons.favorite_rounded,
                  color: AppColors.pink,
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Últimos gastos',
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton(
                onPressed: () {},
                child: const Text('Ver todos'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _EmptyExpensesCard(
            onAddExpense: onAddExpense,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.textPrimary,
    required this.textSecondary,
  });

  final Color textPrimary;
  final Color textSecondary;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Gasto hoje',
              style: TextStyle(
                color: textSecondary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'R\$ 0,00',
              style: TextStyle(
                color: textPrimary,
                fontSize: 30,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                const Icon(
                  Icons.calendar_today_outlined,
                  color: AppColors.primary,
                  size: 17,
                ),
                const SizedBox(width: 8),
                Text(
                  'Nenhum gasto registrado hoje',
                  style: TextStyle(
                    color: textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthlyLimitCard extends StatelessWidget {
  const _MonthlyLimitCard({
    required this.textPrimary,
    required this.textSecondary,
  });

  final Color textPrimary;
  final Color textSecondary;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Limite mensal',
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                const Icon(
                  Icons.chevron_right_rounded,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Configure seu limite mensal',
              style: TextStyle(
                color: textSecondary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(50),
              child: const LinearProgressIndicator(
                value: 0,
                minHeight: 8,
                backgroundColor: AppColors.darkSurfaceSecondary,
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppColors.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryShortcut extends StatelessWidget {
  const _CategoryShortcut({
    required this.title,
    required this.icon,
    required this.color,
  });

  final String title;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 90,
      margin: const EdgeInsets.only(right: 10),
      child: Card(
        child: InkWell(
          onTap: () {},
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 12,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  color: color,
                  size: 25,
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyExpensesCard extends StatelessWidget {
  const _EmptyExpensesCard({
    required this.onAddExpense,
    required this.textPrimary,
    required this.textSecondary,
  });

  final VoidCallback onAddExpense;
  final Color textPrimary;
  final Color textSecondary;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: AppColors.primarySoft,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.receipt_long_outlined,
                color: AppColors.primary,
                size: 31,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Seu dia ainda não possui gastos',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              'Registre uma despesa para começar a acompanhar seu dia.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onAddExpense,
              icon: const Icon(Icons.add_rounded),
              label: const Text(
                'Registrar meu primeiro gasto',
              ),
            ),
          ],
        ),
      ),
    );
  }
}