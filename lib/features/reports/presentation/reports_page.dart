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

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  bool _isLoading = true;
  List<CategoryStat> _categoryStats = [];

  List<Expense> _currentPeriodExpenses = [];

  double _periodTotal = 0.0;

  int _touchedIndex = -1;

  String _selectedPeriodLabel = 'Este mês';
  DateTimeRange? _customDateRange;

  final List<String> _periodOptions = [
    'Este mês',
    'Mês passado',
    'Mês retrasado',
    'Últimos 30 dias',
    'Este ano',
    'Período personalizado'
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

    for (var e in allExpenses) {
      if (_selectedPeriodLabel == 'Este mês') {
        if (e.date.year == now.year && e.date.month == now.month) filtered.add(e);
      } else if (_selectedPeriodLabel == 'Mês passado') {
        final prevMonth = DateTime(now.year, now.month - 1, 1);
        if (e.date.year == prevMonth.year && e.date.month == prevMonth.month) filtered.add(e);
      } else if (_selectedPeriodLabel == 'Mês retrasado') {
        final prevPrev = DateTime(now.year, now.month - 2, 1);
        if (e.date.year == prevPrev.year && e.date.month == prevPrev.month) filtered.add(e);
      } else if (_selectedPeriodLabel == 'Últimos 30 dias') {
        final thirtyDaysAgo = now.subtract(const Duration(days: 30));
        if (e.date.isAfter(thirtyDaysAgo) || DateUtils.isSameDay(e.date, now)) filtered.add(e);
      } else if (_selectedPeriodLabel == 'Este ano') {
        if (e.date.year == now.year) filtered.add(e);
      } else if (_selectedPeriodLabel == 'Período personalizado' && _customDateRange != null) {
        if (e.date.isAfter(_customDateRange!.start.subtract(const Duration(days: 1))) &&
            e.date.isBefore(_customDateRange!.end.add(const Duration(days: 1)))) {
          filtered.add(e);
        }
      }
    }

    filtered.sort((a, b) => b.date.compareTo(a.date));

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

    stats.sort((a, b) => b.amount.compareTo(a.amount));

    if (mounted) {
      setState(() {
        _categoryStats = stats;
        _currentPeriodExpenses = filtered;
        _periodTotal = total;
        _isLoading = false;
        _touchedIndex = -1;
      });
    }
  }

  Map<String, dynamic> _getCategoryStyle(String categoryName) {
    switch (categoryName) {
      case 'Alimentação': return {'icon': Icons.restaurant_rounded, 'color': AppColors.primary};
      case 'Transporte': return {'icon': Icons.directions_car_rounded, 'color': AppColors.blue};
      case 'Moradia': return {'icon': Icons.home_rounded, 'color': AppColors.orange};
      case 'Compras': return {'icon': Icons.shopping_bag_rounded, 'color': AppColors.pink};
      case 'Saúde': return {'icon': Icons.favorite_rounded, 'color': AppColors.red};
      case 'Lazer': return {'icon': Icons.sports_esports_rounded, 'color': AppColors.purple};
      case 'Contas': return {'icon': Icons.receipt_rounded, 'color': AppColors.blue};
      default: return {'icon': Icons.more_horiz_rounded, 'color': const Color(0xFF8A959D)};
    }
  }

  String _getDynamicPeriodTitle() {
    if (_selectedPeriodLabel == 'Este mês') {
      String month = DateFormat("MMMM 'de' yyyy", 'pt_BR').format(DateTime.now());
      return '${month[0].toUpperCase()}${month.substring(1)}';
    } else if (_selectedPeriodLabel == 'Mês passado') {
      final prev = DateTime(DateTime.now().year, DateTime.now().month - 1, 1);
      String month = DateFormat("MMMM 'de' yyyy", 'pt_BR').format(prev);
      return '${month[0].toUpperCase()}${month.substring(1)}';
    } else if (_selectedPeriodLabel == 'Mês retrasado') {
      final prev = DateTime(DateTime.now().year, DateTime.now().month - 2, 1);
      String month = DateFormat("MMMM 'de' yyyy", 'pt_BR').format(prev);
      return '${month[0].toUpperCase()}${month.substring(1)}';
    } else if (_selectedPeriodLabel == 'Período personalizado' && _customDateRange != null) {
      final start = DateFormat('dd/MM').format(_customDateRange!.start);
      final end = DateFormat('dd/MM').format(_customDateRange!.end);
      return '$start até $end';
    }
    return _selectedPeriodLabel;
  }

  void _showPeriodSelector() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final bgColor = isDark ? AppColors.darkSurface : Colors.white;
    final textPrimary = isDark ? AppColors.darkTextPrimary : const Color(0xFF1A1D1F);
    final borderColor = isDark ? AppColors.darkBorder : const Color(0xFFE2E6E9);

    showModalBottomSheet(
      context: context,
      backgroundColor: bgColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 40, height: 4, decoration: BoxDecoration(color: borderColor, borderRadius: BorderRadius.circular(4))),
                const SizedBox(height: 16),
                Text('Selecione o período', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: textPrimary)),
                const SizedBox(height: 16),
                ..._periodOptions.map((option) {
                  final isSelected = _selectedPeriodLabel == option;
                  return ListTile(
                    title: Text(
                      option,
                      style: TextStyle(
                        color: isSelected ? primaryColor : textPrimary,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                    trailing: isSelected ? Icon(Icons.check_circle_rounded, color: primaryColor) : null,
                    onTap: () async {
                      Navigator.pop(context);
                      if (option == 'Período personalizado') {
                        final DateTimeRange? picked = await showDateRangePicker(
                          context: context,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                          builder: (context, child) => Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: isDark
                                  ? ColorScheme.dark(primary: primaryColor, onPrimary: Colors.black, surface: AppColors.darkSurface, onSurface: AppColors.darkTextPrimary)
                                  : ColorScheme.light(primary: primaryColor, onPrimary: Colors.white, surface: Colors.white, onSurface: const Color(0xFF1A1D1F)),
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

  void _showExpenseDetails(Expense expense, Map<String, dynamic> style, String amountFormatted) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkSurface : Colors.white;
    final textPrimary = isDark ? AppColors.darkTextPrimary : const Color(0xFF1A1D1F);
    final textSecondary = isDark ? AppColors.darkTextSecondary : const Color(0xFF535F66);
    final borderColor = isDark ? AppColors.darkBorder : const Color(0xFFE2E6E9);

    showModalBottomSheet(
      context: context,
      backgroundColor: bgColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 40, height: 4, decoration: BoxDecoration(color: borderColor, borderRadius: BorderRadius.circular(4))),
                const SizedBox(height: 24),
                Icon(style['icon'], color: style['color'], size: 48),
                const SizedBox(height: 16),
                Text(amountFormatted, style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: textPrimary)),
                Text(expense.categoryName, style: TextStyle(fontSize: 16, color: textSecondary)),
                if (expense.description != null && expense.description!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text('"${expense.description}"', style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic, color: textSecondary)),
                ],
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        AddExpenseModal.show(context, expense: expense);
                      },
                      child: Column(
                        children: [
                          Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: AppColors.blue.withOpacity(0.15), shape: BoxShape.circle), child: const Icon(Icons.edit_rounded, color: AppColors.blue)),
                          const SizedBox(height: 8),
                          const Text('Editar', style: TextStyle(color: AppColors.blue, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () async {
                        Navigator.pop(context);
                        await ExpenseRepository().deleteExpense(expense.id);
                        expenseNotifier.value++;
                      },
                      child: Column(
                        children: [
                          Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: AppColors.red.withOpacity(0.15), shape: BoxShape.circle), child: const Icon(Icons.delete_rounded, color: AppColors.red)),
                          const SizedBox(height: 8),
                          const Text('Excluir', style: TextStyle(color: AppColors.red, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final textPrimary = isDark ? AppColors.darkTextPrimary : const Color(0xFF1A1D1F);
    final textSecondary = isDark ? AppColors.darkTextSecondary : const Color(0xFF535F66);
    final textMuted = isDark ? AppColors.darkTextMuted : const Color(0xFF8A959D);
    final surfaceColor = isDark ? AppColors.darkSurfaceSecondary : Colors.white;
    final iconBgColor = isDark ? AppColors.darkSurfaceSecondary : const Color(0xFFF0F3F5);
    final borderColor = isDark ? Colors.transparent : const Color(0xFFE2E6E9);
    final cardShadow = isDark ? Colors.transparent : Colors.black.withOpacity(0.04);

    // MÁGICA DA ROLAGEM: Pega o tamanho da barra de status
    final topPadding = MediaQuery.of(context).padding.top;

    return _isLoading
        ? Center(child: CircularProgressIndicator(color: primaryColor))
        : Column(
      children: [
        // Aplicamos o topPadding + margem de 24 aqui no container do filtro
        Padding(
          padding: EdgeInsets.only(top: topPadding + 24, bottom: 16),
          child: InkWell(
            onTap: _showPeriodSelector,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _getDynamicPeriodTitle(),
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: textPrimary),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.keyboard_arrow_down_rounded, color: textSecondary),
                ],
              ),
            ),
          ),
        ),

        if (_categoryStats.isEmpty)
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(color: iconBgColor, shape: BoxShape.circle),
                    child: Icon(Icons.pie_chart_outline_rounded, size: 48, color: textMuted),
                  ),
                  const SizedBox(height: 24),
                  Text('Ainda não existem gastos\nneste período.', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: textSecondary)),
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    onPressed: () => AddExpenseModal.show(context),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Registrar primeiro gasto', style: TextStyle(fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(left: 24, right: 24, bottom: 100),
              children: [
                SizedBox(
                  height: 260,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      PieChart(
                        PieChartData(
                          pieTouchData: PieTouchData(
                            touchCallback: (FlTouchEvent event, pieTouchResponse) {
                              setState(() {
                                if (!event.isInterestedForInteractions || pieTouchResponse == null || pieTouchResponse.touchedSection == null) {
                                  return;
                                }

                                final index = pieTouchResponse.touchedSection!.touchedSectionIndex;
                                if (index >= 0 && index < _categoryStats.length) {
                                  _touchedIndex = index;
                                  HapticFeedback.selectionClick();
                                }
                              });
                            },
                          ),
                          borderData: FlBorderData(show: false),
                          sectionsSpace: 4,
                          centerSpaceRadius: 75,
                          sections: _categoryStats.asMap().entries.map((entry) {
                            final index = entry.key;
                            final stat = entry.value;
                            final isTouched = index == _touchedIndex;
                            final showTitle = stat.percentage >= 5.0;

                            return PieChartSectionData(
                              color: stat.style['color'],
                              value: stat.amount,
                              title: '${stat.percentage.toStringAsFixed(0)}%',
                              showTitle: showTitle,
                              radius: isTouched ? 45.0 : 35.0,
                              titleStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
                            );
                          }).toList(),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Total', style: TextStyle(fontSize: 14, color: textSecondary)),
                          Text(
                            currencyFormatter.format(_periodTotal).replaceAll('R\$', '').trim(),
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: textPrimary),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                if (_touchedIndex != -1 && _touchedIndex < _categoryStats.length) ...[
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                        color: surfaceColor,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: _categoryStats[_touchedIndex].style['color'].withOpacity(0.5), width: 2),
                        boxShadow: isDark ? [] : [BoxShadow(color: cardShadow, blurRadius: 10, offset: const Offset(0, 4))]
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(_categoryStats[_touchedIndex].style['icon'], color: _categoryStats[_touchedIndex].style['color']),
                                const SizedBox(width: 12),
                                Text(
                                  _categoryStats[_touchedIndex].name,
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: textPrimary),
                                ),
                              ],
                            ),
                            GestureDetector(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                setState(() {
                                  _touchedIndex = -1;
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(color: iconBgColor, shape: BoxShape.circle),
                                child: Icon(Icons.close_rounded, color: textMuted, size: 20),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(currencyFormatter.format(_categoryStats[_touchedIndex].amount), style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: textPrimary)),
                                const SizedBox(height: 4),
                                Text('${_categoryStats[_touchedIndex].count} lançamentos', style: TextStyle(fontSize: 13, color: textSecondary)),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(color: _categoryStats[_touchedIndex].style['color'].withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                              child: Text(
                                '${_categoryStats[_touchedIndex].percentage.toStringAsFixed(1)}% do período',
                                style: TextStyle(fontWeight: FontWeight.w700, color: _categoryStats[_touchedIndex].style['color']),
                              ),
                            )
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                ],

                if (_touchedIndex == -1) ...[
                  Text('Top Despesas', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textPrimary)),
                  const SizedBox(height: 16),

                  ..._categoryStats.map((stat) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                            color: surfaceColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: borderColor),
                            boxShadow: [
                              BoxShadow(color: cardShadow, blurRadius: 8, offset: const Offset(0, 2))
                            ]
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 48, height: 48,
                              decoration: BoxDecoration(color: stat.style['color'].withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                              child: Icon(stat.style['icon'], color: stat.style['color']),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(stat.name, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: textPrimary)),
                                  const SizedBox(height: 2),
                                  Text('${stat.percentage.toStringAsFixed(1)}%', style: TextStyle(fontSize: 13, color: textSecondary)),
                                ],
                              ),
                            ),
                            Text(currencyFormatter.format(stat.amount), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: textPrimary)),
                          ],
                        ),
                      ),
                    );
                  }),
                ] else ...[
                  Text('Lançamentos de ${_categoryStats[_touchedIndex].name}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textPrimary)),
                  const SizedBox(height: 16),

                  ..._currentPeriodExpenses.where((e) => e.categoryName == _categoryStats[_touchedIndex].name).map((expense) {
                    final style = _getCategoryStyle(expense.categoryName);
                    final amountFormatted = currencyFormatter.format(expense.amount);
                    final description = (expense.description != null && expense.description!.isNotEmpty) ? expense.description! : 'Sem descrição';
                    final dateFormatted = DateFormat("dd MMM. HH:mm", 'pt_BR').format(expense.date);

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: InkWell(
                        onTap: () => _showExpenseDetails(expense, style, amountFormatted),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                              color: surfaceColor,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: borderColor),
                              boxShadow: [
                                BoxShadow(color: cardShadow, blurRadius: 8, offset: const Offset(0, 2))
                              ]
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 48, height: 48,
                                decoration: BoxDecoration(color: style['color'].withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                                child: Icon(style['icon'], color: style['color']),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(description, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
                                    const SizedBox(height: 2),
                                    Text(dateFormatted, style: TextStyle(fontSize: 13, color: textSecondary)),
                                  ],
                                ),
                              ),
                              Text(amountFormatted, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: textPrimary)),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ]
              ],
            ),
          ),
      ],
    );
  }
}