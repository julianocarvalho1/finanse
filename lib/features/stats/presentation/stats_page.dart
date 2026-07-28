import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../../../core/theme/app_colors.dart';
import '../../expenses/data/expense_repository.dart';
import '../../expenses/domain/expense.dart';
import '../../../../core/utils/expense_notifier.dart';
import '../../expenses/presentation/widgets/add_expense_modal.dart';

class CategoryStat {
  final String name;
  final double amount;
  final int count;
  final double percentage;
  final Map<String, dynamic> style;

  CategoryStat({
    required this.name,
    required this.amount,
    required this.count,
    required this.percentage,
    required this.style,
  });
}

class StatsPage extends StatefulWidget {
  const StatsPage({super.key});

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  bool _isLoading = true;
  List<CategoryStat> _categoryStats = [];
  double _periodTotal = 0.0;

  int _touchedIndex = -1;

  String _selectedPeriodLabel = 'Este mês';
  DateTimeRange? _customDateRange;

  // Adicionei "Mês retrasado" para você testar facilmente o estado vazio!
  final List<String> _periodOptions = [
    'Este mês',
    'Mês passado',
    'Mês retrasado',
    'Últimos 30 dias',
    'Este ano',
    'Período personalizado',
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
    expenseNotifier.addListener(_loadData);
  }

  @override
  void dispose() {
    expenseNotifier.removeListener(_loadData);
    super.dispose();
  }

  Future<void> _loadData() async {
    final repository = ExpenseRepository();
    final allExpenses = await repository.getAllExpenses();

    final now = DateTime.now();
    List<Expense> filtered = [];

    // Lógica de Filtro de Período
    for (var e in allExpenses) {
      if (_selectedPeriodLabel == 'Este mês') {
        if (e.date.year == now.year && e.date.month == now.month)
          filtered.add(e);
      } else if (_selectedPeriodLabel == 'Mês passado') {
        final prevMonth = DateTime(now.year, now.month - 1, 1);
        if (e.date.year == prevMonth.year && e.date.month == prevMonth.month)
          filtered.add(e);
      } else if (_selectedPeriodLabel == 'Mês retrasado') {
        final prevPrev = DateTime(now.year, now.month - 2, 1);
        if (e.date.year == prevPrev.year && e.date.month == prevPrev.month)
          filtered.add(e);
      } else if (_selectedPeriodLabel == 'Últimos 30 dias') {
        final thirtyDaysAgo = now.subtract(const Duration(days: 30));
        if (e.date.isAfter(thirtyDaysAgo) || DateUtils.isSameDay(e.date, now))
          filtered.add(e);
      } else if (_selectedPeriodLabel == 'Este ano') {
        if (e.date.year == now.year) filtered.add(e);
      } else if (_selectedPeriodLabel == 'Período personalizado' &&
          _customDateRange != null) {
        if (e.date.isAfter(
              _customDateRange!.start.subtract(const Duration(days: 1)),
            ) &&
            e.date.isBefore(
              _customDateRange!.end.add(const Duration(days: 1)),
            )) {
          filtered.add(e);
        }
      }
    }

    double total = 0;
    Map<String, List<Expense>> grouped = {};

    for (var e in filtered) {
      total += e.amount;
      if (!grouped.containsKey(e.categoryName)) grouped[e.categoryName] = [];
      grouped[e.categoryName]!.add(e);
    }

    List<CategoryStat> stats = [];
    grouped.forEach((category, expenses) {
      final catTotal = expenses.fold(0.0, (sum, item) => sum + item.amount);
      stats.add(
        CategoryStat(
          name: category,
          amount: catTotal,
          count: expenses.length,
          percentage: (catTotal / total) * 100,
          style: _getCategoryStyle(category),
        ),
      );
    });

    // Ordena do maior para o menor gasto
    stats.sort((a, b) => b.amount.compareTo(a.amount));

    if (mounted) {
      setState(() {
        _categoryStats = stats;
        _periodTotal = total;
        _isLoading = false;

        // Garante que o MAIOR gasto seja selecionado por padrão no gráfico
        _touchedIndex = stats.isNotEmpty ? 0 : -1;
      });
    }
  }

  Map<String, dynamic> _getCategoryStyle(String categoryName) {
    switch (categoryName) {
      case 'Alimentação':
        return {'icon': Icons.restaurant_rounded, 'color': AppColors.primary};
      case 'Transporte':
        return {'icon': Icons.directions_car_rounded, 'color': AppColors.blue};
      case 'Moradia':
        return {'icon': Icons.home_rounded, 'color': AppColors.orange};
      case 'Compras':
        return {'icon': Icons.shopping_bag_rounded, 'color': AppColors.pink};
      case 'Saúde':
        return {'icon': Icons.favorite_rounded, 'color': AppColors.red};
      case 'Lazer':
        return {
          'icon': Icons.sports_esports_rounded,
          'color': AppColors.purple,
        };
      case 'Contas':
        return {'icon': Icons.receipt_rounded, 'color': AppColors.blue};
      default:
        return {
          'icon': Icons.more_horiz_rounded,
          'color': AppColors.darkTextMuted,
        };
    }
  }

  String _getDynamicPeriodTitle() {
    if (_selectedPeriodLabel == 'Este mês') {
      String month = DateFormat(
        "MMMM 'de' yyyy",
        'pt_BR',
      ).format(DateTime.now());
      return '${month[0].toUpperCase()}${month.substring(1)}';
    } else if (_selectedPeriodLabel == 'Mês passado') {
      final prev = DateTime(DateTime.now().year, DateTime.now().month - 1, 1);
      String month = DateFormat("MMMM 'de' yyyy", 'pt_BR').format(prev);
      return '${month[0].toUpperCase()}${month.substring(1)}';
    } else if (_selectedPeriodLabel == 'Mês retrasado') {
      final prev = DateTime(DateTime.now().year, DateTime.now().month - 2, 1);
      String month = DateFormat("MMMM 'de' yyyy", 'pt_BR').format(prev);
      return '${month[0].toUpperCase()}${month.substring(1)}';
    } else if (_selectedPeriodLabel == 'Período personalizado' &&
        _customDateRange != null) {
      final start = DateFormat('dd/MM').format(_customDateRange!.start);
      final end = DateFormat('dd/MM').format(_customDateRange!.end);
      return '$start até $end';
    }
    return _selectedPeriodLabel;
  }

  void _showPeriodSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.darkSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.darkBorder,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Selecione o período',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.darkTextPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                ..._periodOptions.map((option) {
                  final isSelected = _selectedPeriodLabel == option;
                  return ListTile(
                    title: Text(
                      option,
                      style: TextStyle(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.darkTextPrimary,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                    trailing: isSelected
                        ? const Icon(
                            Icons.check_circle_rounded,
                            color: AppColors.primary,
                          )
                        : null,
                    onTap: () async {
                      Navigator.pop(context);
                      if (option == 'Período personalizado') {
                        final DateTimeRange? picked = await showDateRangePicker(
                          context: context,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                          builder: (context, child) => Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: const ColorScheme.dark(
                                primary: AppColors.primary,
                                onPrimary: Colors.black,
                                surface: AppColors.darkSurface,
                                onSurface: AppColors.darkTextPrimary,
                              ),
                            ),
                            child: child!,
                          ),
                        );
                        if (picked != null) {
                          setState(() {
                            _customDateRange = picked;
                            _selectedPeriodLabel = option;
                            _isLoading = true;
                          });
                          _loadData();
                        }
                      } else {
                        setState(() {
                          _selectedPeriodLabel = option;
                          _isLoading = true;
                        });
                        _loadData();
                      }
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(
      locale: 'pt_BR',
      symbol: 'R\$',
    );

    return SafeArea(
      child: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : Column(
              children: [
                // MENU DO TOPO
                Padding(
                  padding: const EdgeInsets.only(top: 24, bottom: 16),
                  child: InkWell(
                    onTap: _showPeriodSelector,
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _getDynamicPeriodTitle(),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.darkTextPrimary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: AppColors.darkTextSecondary,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // ESTADO VAZIO OU CONTEÚDO
                if (_categoryStats.isEmpty)
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: const BoxDecoration(
                              color: AppColors.darkSurfaceSecondary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.pie_chart_outline_rounded,
                              size: 48,
                              color: AppColors.darkTextMuted,
                            ),
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'Ainda não existem gastos\nneste período.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              color: AppColors.darkTextSecondary,
                            ),
                          ),
                          const SizedBox(height: 32),
                          ElevatedButton.icon(
                            onPressed: () => AddExpenseModal.show(context),
                            icon: const Icon(Icons.add_rounded),
                            label: const Text(
                              'Registrar primeiro gasto',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: AppColors.darkBackground,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 16,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.only(
                        left: 24,
                        right: 24,
                        bottom: 100,
                      ),
                      children: [
                        // GRÁFICO (DONUT)
                        SizedBox(
                          height: 260, // Um pouco maior para caber bem
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              PieChart(
                                PieChartData(
                                  pieTouchData: PieTouchData(
                                    touchCallback: (FlTouchEvent event, pieTouchResponse) {
                                      setState(() {
                                        // IGNORA cliques fora do gráfico para o card não piscar/sumir
                                        if (!event
                                                .isInterestedForInteractions ||
                                            pieTouchResponse == null ||
                                            pieTouchResponse.touchedSection ==
                                                null) {
                                          return;
                                        }

                                        final index = pieTouchResponse
                                            .touchedSection!
                                            .touchedSectionIndex;
                                        // Atualiza apenas se for um clique válido numa fatia
                                        if (index >= 0 &&
                                            index < _categoryStats.length) {
                                          _touchedIndex = index;
                                          HapticFeedback.selectionClick();
                                        }
                                      });
                                    },
                                  ),
                                  borderData: FlBorderData(show: false),
                                  sectionsSpace: 4,
                                  centerSpaceRadius:
                                      75, // O SEGREDO DO DONUT: Raio central grande!
                                  sections: _categoryStats.asMap().entries.map((
                                    entry,
                                  ) {
                                    final index = entry.key;
                                    final stat = entry.value;
                                    final isTouched = index == _touchedIndex;

                                    // AQUI ESTÁ A CORREÇÃO: Usar a propriedade nativa showTitle
                                    final showTitle = stat.percentage >= 5.0;

                                    return PieChartSectionData(
                                      color: stat.style['color'],
                                      value: stat.amount,
                                      title:
                                          '${stat.percentage.toStringAsFixed(0)}%',
                                      showTitle:
                                          showTitle, // DESLIGA OS < 5% DEFINITIVAMENTE
                                      radius: isTouched
                                          ? 45.0
                                          : 35.0, // A fatia cresce se tocada
                                      titleStyle: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),

                              // Texto Central do Donut
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text(
                                    'Total',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: AppColors.darkTextSecondary,
                                    ),
                                  ),
                                  Text(
                                    currencyFormatter
                                        .format(_periodTotal)
                                        .replaceAll('R\$', '')
                                        .trim(),
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.darkTextPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),

                        // CARD DE INTERAÇÃO DO GRÁFICO
                        if (_touchedIndex != -1 &&
                            _touchedIndex < _categoryStats.length) ...[
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: AppColors.darkSurfaceSecondary,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: _categoryStats[_touchedIndex]
                                    .style['color']
                                    .withOpacity(0.5),
                                width: 2,
                              ),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      _categoryStats[_touchedIndex]
                                          .style['icon'],
                                      color: _categoryStats[_touchedIndex]
                                          .style['color'],
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      _categoryStats[_touchedIndex].name,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.darkTextPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          currencyFormatter.format(
                                            _categoryStats[_touchedIndex]
                                                .amount,
                                          ),
                                          style: const TextStyle(
                                            fontSize: 24,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.darkTextPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${_categoryStats[_touchedIndex].count} lançamentos',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            color: AppColors.darkTextSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _categoryStats[_touchedIndex]
                                            .style['color']
                                            .withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        '${_categoryStats[_touchedIndex].percentage.toStringAsFixed(1)}% do período',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: _categoryStats[_touchedIndex]
                                              .style['color'],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 32),
                        ],

                        // LISTA RANKING (MAIOR PRO MENOR)
                        const Text(
                          'Top Despesas',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.darkTextPrimary,
                          ),
                        ),
                        const SizedBox(height: 16),

                        ..._categoryStats.map((stat) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Row(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: stat.style['color'].withOpacity(
                                      0.15,
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Icon(
                                    stat.style['icon'],
                                    color: stat.style['color'],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        stat.name,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.darkTextPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${stat.percentage.toStringAsFixed(1)}%',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: AppColors.darkTextSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  currencyFormatter.format(stat.amount),
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.darkTextPrimary,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}
