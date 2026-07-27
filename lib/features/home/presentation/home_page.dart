import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../expenses/presentation/widgets/add_expense_modal.dart';

import '../../../../core/theme/app_colors.dart';
import '../../expenses/data/expense_repository.dart';
import '../../expenses/domain/expense.dart';
import '../../../../core/utils/expense_notifier.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _selectedPeriod = 'Hoje';

  double _periodTotal = 0.0;
  int _periodCount = 0;
  double _monthTotal = 0.0;
  List<Expense> _recentExpenses = [];
  bool _isLoading = true;
  double _monthlyLimit = 2000.0;

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
    final prefs = await SharedPreferences.getInstance();
    final savedLimit = prefs.getDouble('monthlyLimit') ?? 2000.0;
    final repository = ExpenseRepository();

    final periodExpenses = await repository.getExpensesForPeriod(_selectedPeriod);
    final pTotal = periodExpenses.fold(0.0, (sum, item) => sum + item.amount);

    final monthExpenses = await repository.getExpensesForPeriod('Mês');
    final mTotal = monthExpenses.fold(0.0, (sum, item) => sum + item.amount);

    if (mounted) {
      setState(() {
        _monthlyLimit = savedLimit;
        _periodTotal = pTotal;
        _periodCount = periodExpenses.length;
        _monthTotal = mTotal;
        _recentExpenses = periodExpenses.take(5).toList();
        _isLoading = false;
      });
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) {
      return 'Bom dia,';
    } else if (hour >= 12 && hour < 18) {
      return 'Boa tarde,';
    } else {
      return 'Boa noite,';
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

  void _showExpenseDetails(Expense expense, Map<String, dynamic> style, String amountFormatted, bool isDark) {
    final bgColor = isDark ? AppColors.darkSurface : Colors.white;
    final textPrimary = isDark ? AppColors.darkTextPrimary : const Color(0xFF1A1D1F);
    final textSecondary = isDark ? AppColors.darkTextSecondary : const Color(0xFF535F66);

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
                Container(width: 40, height: 4, decoration: BoxDecoration(color: isDark ? AppColors.darkBorder : Colors.grey[300], borderRadius: BorderRadius.circular(4))),
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
                    _buildActionButton(Icons.edit_rounded, 'Editar', AppColors.blue, () {
                      Navigator.pop(context);
                      AddExpenseModal.show(context, expense: expense);
                    }),
                    _buildActionButton(Icons.delete_rounded, 'Excluir', AppColors.red, () async {
                      Navigator.pop(context);
                      await ExpenseRepository().deleteExpense(expense.id);
                      expenseNotifier.value++;
                    }),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionButton(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: color.withOpacity(0.15), shape: BoxShape.circle), child: Icon(icon, color: color)),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    final isDark = Theme.of(context).brightness == Brightness.dark;

    final textPrimary = isDark ? AppColors.darkTextPrimary : const Color(0xFF1A1D1F);
    final textSecondary = isDark ? AppColors.darkTextSecondary : const Color(0xFF535F66);
    final textMuted = isDark ? AppColors.darkTextMuted : const Color(0xFF8A959D);

    final surfaceColor = isDark ? AppColors.darkSurfaceSecondary : Colors.white;
    final borderColor = isDark ? AppColors.darkBorder : const Color(0xFFE2E6E9);
    final cardShadow = isDark ? Colors.transparent : Colors.black.withOpacity(0.05);
    final primaryColor = Theme.of(context).colorScheme.primary;

    final double percentUsed = _monthlyLimit > 0 ? (_monthTotal / _monthlyLimit).clamp(0.0, 1.0) : 1.0;
    final double difference = _monthlyLimit - _monthTotal;
    final bool isOverLimit = difference < 0;
    final double displayAvailable = isOverLimit ? difference.abs() : difference;
    final String availableLabel = isOverLimit ? 'excedidos' : 'disponíveis';
    final Color availableColor = isOverLimit ? AppColors.red : textPrimary;

    Color progressColor;
    String statusText;

    if (percentUsed < 0.7) {
      progressColor = primaryColor;
      statusText = 'Situação normal';
    } else if (percentUsed < 0.9) {
      progressColor = AppColors.orange;
      statusText = 'Atenção';
    } else {
      progressColor = AppColors.red;
      statusText = 'Alerta: Limite atingido';
    }

    // MÁGICA DA ROLAGEM: Pega o tamanho da barra de status
    final topPadding = MediaQuery.of(context).padding.top;

    return _isLoading
        ? Center(child: CircularProgressIndicator(color: primaryColor))
        : ListView(
      // Aplicamos o topPadding + margem de 24 no ListView
      padding: EdgeInsets.only(left: 24, right: 24, top: topPadding + 24, bottom: 100),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_getGreeting()} Lucas! 👋',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: textPrimary),
                ),
                const SizedBox(height: 4),
                Text('Aqui está o resumo financeiro.', style: TextStyle(fontSize: 14, color: textSecondary)),
              ],
            ),
            IconButton(icon: Icon(Icons.notifications_none_rounded, color: textPrimary), onPressed: () {}),
          ],
        ),
        const SizedBox(height: 24),

        Row(
          children: ['Hoje', 'Semana', 'Mês'].map((period) {
            final isSelected = _selectedPeriod == period;
            return GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                setState(() { _selectedPeriod = period; _isLoading = true; });
                _loadData();
              },
              child: Container(
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? primaryColor.withOpacity(0.15) : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isSelected ? primaryColor : borderColor),
                ),
                child: Text(
                  period,
                  style: TextStyle(color: isSelected ? primaryColor : textSecondary, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 24),

        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: borderColor),
              boxShadow: [
                BoxShadow(color: cardShadow, blurRadius: 10, offset: const Offset(0, 4))
              ]
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Gasto $_selectedPeriod', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: textSecondary)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurface : const Color(0xFFF0F3F5),
                        borderRadius: BorderRadius.circular(12)
                    ),
                    child: Text('$_periodCount registros', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textMuted)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(currencyFormatter.format(_periodTotal), style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: textPrimary)),
            ],
          ),
        ),
        const SizedBox(height: 32),

        Text('Limite mensal', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textPrimary)),
        const SizedBox(height: 12),
        Text('${currencyFormatter.format(displayAvailable)} $availableLabel', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: availableColor)),
        const SizedBox(height: 4),
        Text('de ${currencyFormatter.format(_monthlyLimit)}', style: TextStyle(fontSize: 13, color: textMuted)),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                    value: percentUsed,
                    backgroundColor: isDark ? AppColors.darkSurfaceSecondary : const Color(0xFFE2E6E9),
                    valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                    minHeight: 8
                ),
              ),
            ),
            const SizedBox(width: 16),
            Text('${(percentUsed * 100).toInt()}%', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: progressColor)),
          ],
        ),
        const SizedBox(height: 8),
        Text(statusText, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: progressColor)),
        const SizedBox(height: 32),

        Text('Últimos gastos', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textPrimary)),
        const SizedBox(height: 16),

        if (_recentExpenses.isEmpty)
          Padding(padding: const EdgeInsets.only(top: 24), child: Center(child: Text('Nenhum gasto em $_selectedPeriod.', style: TextStyle(color: textMuted))))
        else
          ..._recentExpenses.map((expense) {
            final style = _getCategoryStyle(expense.categoryName);
            final timeFormatted = DateFormat('HH:mm').format(expense.date);
            final amountFormatted = currencyFormatter.format(expense.amount);
            final displayTitle = (expense.description != null && expense.description!.isNotEmpty) ? expense.description! : expense.categoryName;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                onTap: () => _showExpenseDetails(expense, style, amountFormatted, isDark),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: surfaceColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isDark ? Colors.transparent : borderColor),
                      boxShadow: [
                        BoxShadow(color: cardShadow, blurRadius: 8, offset: const Offset(0, 2))
                      ]
                  ),
                  child: Row(
                    children: [
                      Container(width: 48, height: 48, decoration: BoxDecoration(color: style['color'].withOpacity(0.15), borderRadius: BorderRadius.circular(16)), child: Icon(style['icon'], color: style['color'], size: 24)),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(displayTitle, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 2),
                            Text(expense.categoryName, style: TextStyle(fontSize: 13, color: textSecondary)),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(amountFormatted, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: textPrimary)),
                          const SizedBox(height: 2),
                          Text(timeFormatted, style: TextStyle(fontSize: 13, color: textSecondary)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }
}