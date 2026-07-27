import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../expenses/data/expense_repository.dart';
import '../../expenses/domain/expense.dart';
import '../../../../core/utils/expense_notifier.dart';
import '../../expenses/presentation/widgets/add_expense_modal.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final TextEditingController _searchController = TextEditingController();

  List<Expense> _allExpenses = [];
  List<Expense> _filteredExpenses = [];
  bool _isLoading = true;

  String _searchQuery = '';
  String _selectedPeriod = 'Este mês';
  String _selectedSort = 'Mais recente';
  final List<String> _selectedCategories = [];

  final List<String> _periods = ['Todos', 'Hoje', 'Esta semana', 'Este mês', 'Mês anterior'];
  final List<String> _sortOptions = ['Mais recente', 'Mais antigo', 'Maior valor', 'Menor valor'];
  final List<String> _allCategories = ['Alimentação', 'Transporte', 'Moradia', 'Compras', 'Saúde', 'Lazer', 'Contas', 'Outros'];

  @override
  void initState() {
    super.initState();
    _loadData();
    expenseNotifier.addListener(_loadData);
  }

  @override
  void dispose() {
    _searchController.dispose();
    expenseNotifier.removeListener(_loadData);
    super.dispose();
  }

  Future<void> _loadData() async {
    final repository = ExpenseRepository();
    final expenses = await repository.getAllExpenses();

    if (mounted) {
      setState(() {
        _allExpenses = expenses;
        _applyFilters();
        _isLoading = false;
      });
    }
  }

  void _applyFilters() {
    final now = DateTime.now();
    List<Expense> result = List.from(_allExpenses);

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result.where((e) {
        return e.categoryName.toLowerCase().contains(q) ||
            (e.description?.toLowerCase().contains(q) ?? false) ||
            e.amount.toString().contains(q);
      }).toList();
    }

    if (_selectedCategories.isNotEmpty) {
      result = result.where((e) => _selectedCategories.contains(e.categoryName)).toList();
    }

    result = result.where((e) {
      if (_selectedPeriod == 'Todos') return true;
      if (_selectedPeriod == 'Hoje') return DateUtils.isSameDay(e.date, now);
      if (_selectedPeriod == 'Esta semana') {
        final weekAgo = now.subtract(const Duration(days: 7));
        return e.date.isAfter(weekAgo) || DateUtils.isSameDay(e.date, now);
      }
      if (_selectedPeriod == 'Este mês') return e.date.year == now.year && e.date.month == now.month;
      if (_selectedPeriod == 'Mês anterior') {
        final prevMonth = DateTime(now.year, now.month - 1, 1);
        return e.date.year == prevMonth.year && e.date.month == prevMonth.month;
      }
      return true;
    }).toList();

    if (_selectedSort == 'Mais recente') {
      result.sort((a, b) => b.date.compareTo(a.date));
    } else if (_selectedSort == 'Mais antigo') {
      result.sort((a, b) => a.date.compareTo(b.date));
    } else if (_selectedSort == 'Maior valor') {
      result.sort((a, b) => b.amount.compareTo(a.amount));
    } else if (_selectedSort == 'Menor valor') {
      result.sort((a, b) => a.amount.compareTo(b.amount));
    }

    setState(() {
      _filteredExpenses = result;
    });
  }

  String _formatDateHeader(DateTime date) {
    final now = DateTime.now();
    if (date.year == now.year && date.month == now.month && date.day == now.day) return 'Hoje';

    final yesterday = now.subtract(const Duration(days: 1));
    if (date.year == yesterday.year && date.month == yesterday.month && date.day == yesterday.day) return 'Ontem';

    if (date.year == now.year) return DateFormat("dd 'de' MMM.", 'pt_BR').format(date);
    return DateFormat("dd 'de' MMM. yyyy", 'pt_BR').format(date);
  }

  String _formatItemTime(DateTime date) {
    final timeStr = DateFormat('HH:mm').format(date);
    final now = DateTime.now();

    if (date.year == now.year && date.month == now.month && date.day == now.day) return 'Hoje, $timeStr';

    final yesterday = now.subtract(const Duration(days: 1));
    if (date.year == yesterday.year && date.month == yesterday.month && date.day == yesterday.day) return 'Ontem, $timeStr';

    if (date.year == now.year) return '${DateFormat("dd MMM.", 'pt_BR').format(date)}, $timeStr';
    return '${DateFormat("dd/MM/yyyy").format(date)}, $timeStr';
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

  Future<void> _deleteExpense(Expense expense) async {
    final repository = ExpenseRepository();
    await repository.deleteExpense(expense.id);
    expenseNotifier.value++;

    if (!mounted) return;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: isDark ? AppColors.darkSurfaceSecondary : const Color(0xFF1A1D1F),
        content: const Text('Gasto excluído', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'Desfazer',
          textColor: primaryColor,
          onPressed: () async {
            await repository.insertExpense(expense);
            expenseNotifier.value++;
          },
        ),
      ),
    );
  }

  void _openFilters() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final bgColor = isDark ? AppColors.darkSurface : Colors.white;
    final textPrimary = isDark ? AppColors.darkTextPrimary : const Color(0xFF1A1D1F);
    final textSecondary = isDark ? AppColors.darkTextSecondary : const Color(0xFF535F66);
    final surfaceColor = isDark ? AppColors.darkSurfaceSecondary : const Color(0xFFF0F3F5);

    showModalBottomSheet(
      context: context,
      backgroundColor: bgColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (BuildContext context) {
        // O segredo está aqui: o StatefulBuilder PRECISA estar envelopando o conteúdo
        // para que o 'setModalState' exista e funcione corretamente.
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: isDark ? AppColors.darkBorder : const Color(0xFFE2E6E9), borderRadius: BorderRadius.circular(4)))),
                    const SizedBox(height: 24),
                    Text('Filtros e Ordenação', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: textPrimary)),
                    const SizedBox(height: 24),

                    Text('Período', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: textPrimary)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8, runSpacing: 8,
                      children: _periods.map((p) => ChoiceChip(
                        label: Text(p),
                        selected: _selectedPeriod == p,
                        selectedColor: primaryColor.withOpacity(0.15),
                        backgroundColor: surfaceColor,
                        labelStyle: TextStyle(
                            color: _selectedPeriod == p ? primaryColor : textSecondary,
                            fontWeight: _selectedPeriod == p ? FontWeight.bold : FontWeight.normal
                        ),
                        side: BorderSide.none,
                        // --- CORREÇÃO APLICADA AQUI COM CHAVES ---
                        onSelected: (val) {
                          setModalState(() {
                            _selectedPeriod = p;
                          });
                        },
                      )).toList(),
                    ),
                    const SizedBox(height: 24),

                    Text('Ordenação', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: textPrimary)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8, runSpacing: 8,
                      children: _sortOptions.map((s) => ChoiceChip(
                        label: Text(s),
                        selected: _selectedSort == s,
                        selectedColor: primaryColor.withOpacity(0.15),
                        backgroundColor: surfaceColor,
                        labelStyle: TextStyle(
                            color: _selectedSort == s ? primaryColor : textSecondary,
                            fontWeight: _selectedSort == s ? FontWeight.bold : FontWeight.normal
                        ),
                        side: BorderSide.none,
                        // --- CORREÇÃO APLICADA AQUI COM CHAVES ---
                        onSelected: (val) {
                          setModalState(() {
                            _selectedSort = s;
                          });
                        },
                      )).toList(),
                    ),
                    const SizedBox(height: 32),

                    SizedBox(
                      width: double.infinity, height: 56,
                      child: ElevatedButton(
                        onPressed: () {
                          _applyFilters();
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                        child: const Text('Aplicar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
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
                    _buildActionButton(Icons.edit_rounded, 'Editar', AppColors.blue, () {
                      Navigator.pop(context);
                      AddExpenseModal.show(context, expense: expense);
                    }),
                    _buildActionButton(Icons.delete_rounded, 'Excluir', AppColors.red, () {
                      Navigator.pop(context);
                      _deleteExpense(expense);
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

  List<Widget> _buildGroupedList(bool isDark, Color textPrimary, Color textSecondary, Color textMuted, Color surfaceColor, Color borderColor) {
    if (_filteredExpenses.isEmpty) {
      return [Padding(padding: const EdgeInsets.only(top: 40), child: Center(child: Text('Nenhum gasto encontrado.', style: TextStyle(color: textMuted))))];
    }

    final currencyFormatter = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    List<Widget> listWidgets = [];

    Map<String, List<Expense>> grouped = {};
    for (var e in _filteredExpenses) {
      final dateKey = DateTime(e.date.year, e.date.month, e.date.day).toIso8601String();
      if (!grouped.containsKey(dateKey)) grouped[dateKey] = [];
      grouped[dateKey]!.add(e);
    }

    grouped.forEach((dateKey, dayExpenses) {
      final date = DateTime.parse(dateKey);
      final double dayTotal = dayExpenses.fold(0.0, (sum, item) => sum + item.amount);

      listWidgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 24, bottom: 16),
            child: Row(
              children: [
                Text(_formatDateHeader(date), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: textPrimary)),
                Text('  —  ', style: TextStyle(color: textMuted)),
                Text(currencyFormatter.format(dayTotal), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textSecondary)),
              ],
            ),
          )
      );

      for (var expense in dayExpenses) {
        final style = _getCategoryStyle(expense.categoryName);
        final amountFormatted = currencyFormatter.format(expense.amount);
        final timeFormatted = _formatItemTime(expense.date);
        final description = (expense.description != null && expense.description!.trim().isNotEmpty) ? expense.description! : 'Sem descrição';

        listWidgets.add(
          Dismissible(
            key: Key(expense.id),
            direction: DismissDirection.endToStart,
            background: Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(color: AppColors.red, borderRadius: BorderRadius.circular(16)),
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 24),
              child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
            ),
            onDismissed: (_) => _deleteExpense(expense),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                onTap: () => _showExpenseDetails(expense, style, amountFormatted),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(8.0),
                  decoration: BoxDecoration(
                      color: surfaceColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderColor),
                      boxShadow: isDark ? [] : [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2))]
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48, height: 48,
                        decoration: BoxDecoration(color: style['color'].withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                        child: Icon(style['icon'], color: style['color'], size: 24),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(expense.categoryName, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: textPrimary)),
                            const SizedBox(height: 2),
                            Text(description, style: TextStyle(fontSize: 13, color: textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(amountFormatted, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: textPrimary)),
                          const SizedBox(height: 2),
                          Text(timeFormatted, style: TextStyle(fontSize: 12, color: textMuted)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }
    });

    return listWidgets;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppColors.darkTextPrimary : const Color(0xFF1A1D1F);
    final textSecondary = isDark ? AppColors.darkTextSecondary : const Color(0xFF535F66);
    final textMuted = isDark ? AppColors.darkTextMuted : const Color(0xFF8A959D);
    final surfaceColor = isDark ? AppColors.darkSurfaceSecondary : Colors.white;
    final searchBgColor = isDark ? AppColors.darkSurfaceSecondary : const Color(0xFFF0F3F5);
    final borderColor = isDark ? Colors.transparent : const Color(0xFFE2E6E9);
    final primaryColor = Theme.of(context).colorScheme.primary;

    // MÁGICA DA ROLAGEM: Pega o tamanho da barra de status
    final topPadding = MediaQuery.of(context).padding.top;

    return _isLoading
        ? Center(child: CircularProgressIndicator(color: primaryColor))
        : Column(
      children: [
        // Aplicamos o topPadding + margem de 24 aqui no container da barra de busca
        Padding(
          padding: EdgeInsets.fromLTRB(24, topPadding + 24, 24, 0),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(color: searchBgColor, borderRadius: BorderRadius.circular(16)),
                  child: TextField(
                    controller: _searchController,
                    textAlignVertical: TextAlignVertical.center,
                    onChanged: (val) {
                      setState(() {
                        _searchQuery = val;
                      });
                      _applyFilters();
                    },
                    style: TextStyle(color: textPrimary),
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      hintText: 'Buscar valor, categoria, descrição...',
                      hintStyle: TextStyle(color: textMuted, fontSize: 14),
                      prefixIcon: Icon(Icons.search_rounded, color: textMuted),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                        icon: Icon(Icons.close_rounded, color: textMuted, size: 20),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            _searchQuery = '';
                          });
                          _applyFilters();
                          FocusScope.of(context).unfocus();
                        },
                      )
                          : null,
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: _openFilters,
                child: Container(
                  height: 48, width: 48,
                  decoration: BoxDecoration(color: searchBgColor, borderRadius: BorderRadius.circular(16)),
                  child: Icon(Icons.tune_rounded, color: textPrimary),
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(left: 24, right: 24, top: 8, bottom: 120),
            children: _buildGroupedList(isDark, textPrimary, textSecondary, textMuted, surfaceColor, borderColor),
          ),
        ),
      ],
    );
  }
}