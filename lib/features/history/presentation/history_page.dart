import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'package:finanse/core/theme/app_colors.dart';
import 'package:finanse/core/theme/app_spacing.dart';
import 'package:finanse/core/utils/category_style.dart';
import 'package:finanse/core/utils/expense_notifier.dart';
import 'package:finanse/features/expenses/data/expense_repository.dart';
import 'package:finanse/features/expenses/domain/expense.dart';
import 'package:finanse/features/expenses/presentation/widgets/add_expense_modal.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key, this.initialMonth});

  final DateTime? initialMonth;

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  static const List<String> _defaultCategories = <String>[
    'Alimentação',
    'Transporte',
    'Moradia',
    'Compras',
    'Saúde',
    'Lazer',
    'Contas',
    'Outros',
  ];

  final ExpenseRepository _repository = ExpenseRepository();
  final TextEditingController _searchController = TextEditingController();

  late final NumberFormat _currencyFormatter;

  List<Expense> _allExpenses = <Expense>[];
  List<Expense> _filteredExpenses = <Expense>[];

  String _searchQuery = '';
  String _selectedPeriod = 'Todos';
  String _selectedSort = 'Mais recente';

  Set<String> _selectedCategories = <String>{};
  DateTimeRange? _customDateRange;

  bool _isLoading = true;
  String? _errorMessage;

  int _loadRequestId = 0;

  @override
  void initState() {
    super.initState();

    final DateTime? initialMonth = widget.initialMonth;
    if (initialMonth != null) {
      final DateTime start = DateTime(initialMonth.year, initialMonth.month);
      _selectedPeriod = 'Personalizado';
      _customDateRange = DateTimeRange(
        start: start,
        end: DateTime(start.year, start.month + 1, 0),
      );
    }

    _currencyFormatter = NumberFormat.currency(
      locale: 'pt_BR',
      symbol: 'R\$',
      decimalDigits: 2,
    );

    expenseNotifier.addListener(_handleExpensesChanged);

    _loadData();
  }

  @override
  void dispose() {
    expenseNotifier.removeListener(_handleExpensesChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _handleExpensesChanged() {
    _loadData(showLoading: false);
  }

  Future<void> _loadData({bool showLoading = true}) async {
    final int requestId = ++_loadRequestId;

    if (showLoading && mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final List<Expense> loadedExpenses = await _repository.getAllExpenses();

      if (!mounted || requestId != _loadRequestId) {
        return;
      }

      // O repositório retorna uma lista de tamanho fixo.
      // Criamos uma cópia modificável para permitir exclusões locais.
      final List<Expense> expenses = List<Expense>.from(
        loadedExpenses,
        growable: true,
      );

      setState(() {
        _allExpenses = expenses;
        _filteredExpenses = _filterAndSortExpenses(expenses);
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (error, stackTrace) {
      debugPrint(
        'Erro ao carregar o histórico: '
        '$error\n$stackTrace',
      );

      if (!mounted || requestId != _loadRequestId) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = 'Não foi possível carregar o histórico de gastos.';
      });
    }
  }

  List<Expense> _filterAndSortExpenses(List<Expense> source) {
    List<Expense> result = List<Expense>.from(source);

    final String normalizedQuery = _normalizeText(_searchQuery);

    final String queryDigits = _searchQuery.replaceAll(RegExp(r'[^0-9]'), '');

    if (normalizedQuery.isNotEmpty) {
      result = result
          .where((Expense expense) {
            final String category = _normalizeText(expense.categoryName);

            final String description = _normalizeText(
              expense.description ?? '',
            );

            final String notes = _normalizeText(expense.notes ?? '');

            final String paymentMethod = _normalizeText(
              expense.paymentMethod ?? '',
            );

            final String formattedAmount = _normalizeText(
              _currencyFormatter.format(expense.amount),
            );

            final String amountInCents = (expense.amount * 100)
                .round()
                .toString();

            final bool matchesText =
                category.contains(normalizedQuery) ||
                description.contains(normalizedQuery) ||
                notes.contains(normalizedQuery) ||
                paymentMethod.contains(normalizedQuery) ||
                formattedAmount.contains(normalizedQuery);

            final bool matchesAmount =
                queryDigits.isNotEmpty && amountInCents.contains(queryDigits);

            return matchesText || matchesAmount;
          })
          .toList(growable: false);
    }

    if (_selectedCategories.isNotEmpty) {
      result = result
          .where((Expense expense) {
            return _selectedCategories.contains(expense.categoryName);
          })
          .toList(growable: false);
    }

    result = result.where(_matchesSelectedPeriod).toList(growable: false);

    switch (_selectedSort) {
      case 'Mais antigo':
        result.sort((Expense first, Expense second) {
          return first.date.compareTo(second.date);
        });

      case 'Maior valor':
        result.sort((Expense first, Expense second) {
          final int amountComparison = second.amount.compareTo(first.amount);

          if (amountComparison != 0) {
            return amountComparison;
          }

          return second.date.compareTo(first.date);
        });

      case 'Menor valor':
        result.sort((Expense first, Expense second) {
          final int amountComparison = first.amount.compareTo(second.amount);

          if (amountComparison != 0) {
            return amountComparison;
          }

          return second.date.compareTo(first.date);
        });

      case 'Mais recente':
      default:
        result.sort((Expense first, Expense second) {
          return second.date.compareTo(first.date);
        });
    }

    return result;
  }

  bool _matchesSelectedPeriod(Expense expense) {
    final DateTime now = DateTime.now();
    final DateTime expenseDay = DateUtils.dateOnly(expense.date);

    switch (_selectedPeriod) {
      case 'Hoje':
        return DateUtils.isSameDay(expense.date, now);

      case 'Esta semana':
        final DateTime today = DateUtils.dateOnly(now);

        final DateTime weekStart = today.subtract(
          Duration(days: today.weekday - DateTime.monday),
        );

        final DateTime nextWeekStart = weekStart.add(const Duration(days: 7));

        return !expenseDay.isBefore(weekStart) &&
            expenseDay.isBefore(nextWeekStart);

      case 'Este mês':
        return expense.date.year == now.year && expense.date.month == now.month;

      case 'Mês anterior':
        final DateTime previousMonth = DateTime(now.year, now.month - 1);

        return expense.date.year == previousMonth.year &&
            expense.date.month == previousMonth.month;

      case 'Personalizado':
        final DateTimeRange? range = _customDateRange;

        if (range == null) {
          return true;
        }

        final DateTime start = DateUtils.dateOnly(range.start);

        final DateTime endExclusive = DateUtils.dateOnly(
          range.end,
        ).add(const Duration(days: 1));

        return !expense.date.isBefore(start) &&
            expense.date.isBefore(endExclusive);

      case 'Todos':
      default:
        return true;
    }
  }

  void _refreshFilters() {
    setState(() {
      _filteredExpenses = _filterAndSortExpenses(_allExpenses);
    });
  }

  void _onSearchChanged(String value) {
    _searchQuery = value;
    _refreshFilters();
  }

  void _clearSearch() {
    _searchController.clear();
    _searchQuery = '';

    FocusScope.of(context).unfocus();

    _refreshFilters();
  }

  void _clearAllFilters() {
    HapticFeedback.selectionClick();

    _searchController.clear();

    setState(() {
      _searchQuery = '';
      _selectedPeriod = 'Todos';
      _selectedSort = 'Mais recente';
      _selectedCategories = <String>{};
      _customDateRange = null;
      _filteredExpenses = _filterAndSortExpenses(_allExpenses);
    });

    FocusScope.of(context).unfocus();
  }

  Future<void> _openFilters() async {
    HapticFeedback.selectionClick();

    final _HistoryFilterResult? result =
        await showModalBottomSheet<_HistoryFilterResult>(
          context: context,
          isScrollControlled: true,
          useSafeArea: false,
          builder: (BuildContext modalContext) {
            return _HistoryFilterSheet(
              initialPeriod: _selectedPeriod,
              initialSort: _selectedSort,
              initialCategories: _selectedCategories,
              initialCustomRange: _customDateRange,
              availableCategories: _availableCategories,
            );
          },
        );

    if (result == null || !mounted) {
      return;
    }

    setState(() {
      _selectedPeriod = result.period;
      _selectedSort = result.sort;
      _selectedCategories = result.categories;
      _customDateRange = result.customDateRange;
      _filteredExpenses = _filterAndSortExpenses(_allExpenses);
    });
  }

  List<String> get _availableCategories {
    final Set<String> categories = <String>{
      ..._defaultCategories,
      ..._allExpenses.map((Expense expense) => expense.categoryName),
    };

    final List<String> sortedCategories = categories
        .where((String category) => category.trim().isNotEmpty)
        .toList(growable: false);

    sortedCategories.sort((String first, String second) {
      return _normalizeText(first).compareTo(_normalizeText(second));
    });

    return sortedCategories;
  }

  int get _activeFilterCount {
    int count = 0;

    if (_selectedPeriod != 'Todos') {
      count++;
    }

    if (_selectedSort != 'Mais recente') {
      count++;
    }

    if (_selectedCategories.isNotEmpty) {
      count++;
    }

    return count;
  }

  bool get _hasAnyFilter {
    return _searchQuery.trim().isNotEmpty ||
        _selectedPeriod != 'Todos' ||
        _selectedSort != 'Mais recente' ||
        _selectedCategories.isNotEmpty;
  }

  String get _filterSummary {
    final List<String> parts = <String>[_selectedPeriod];

    if (_selectedPeriod == 'Personalizado' && _customDateRange != null) {
      final String start = DateFormat(
        'dd/MM/yy',
      ).format(_customDateRange!.start);

      final String end = DateFormat('dd/MM/yy').format(_customDateRange!.end);

      parts[0] = '$start até $end';
    }

    if (_selectedCategories.isNotEmpty) {
      parts.add(
        '${_selectedCategories.length} '
        '${_selectedCategories.length == 1 ? 'categoria' : 'categorias'}',
      );
    }

    if (_selectedSort != 'Mais recente') {
      parts.add(_selectedSort);
    }

    return parts.join(' • ');
  }

  List<_HistoryListEntry> _buildListEntries() {
    if (_filteredExpenses.isEmpty) {
      return <_HistoryListEntry>[];
    }

    final Map<DateTime, List<Expense>> groupedExpenses =
        <DateTime, List<Expense>>{};

    for (final Expense expense in _filteredExpenses) {
      final DateTime date = DateUtils.dateOnly(expense.date);

      groupedExpenses.putIfAbsent(date, () => <Expense>[]);

      groupedExpenses[date]!.add(expense);
    }

    final List<DateTime> dates = groupedExpenses.keys.toList();

    if (_selectedSort == 'Mais antigo') {
      dates.sort();
    } else {
      dates.sort((DateTime first, DateTime second) {
        return second.compareTo(first);
      });
    }

    final List<_HistoryListEntry> entries = <_HistoryListEntry>[];

    for (final DateTime date in dates) {
      final List<Expense> expenses = groupedExpenses[date]!;

      switch (_selectedSort) {
        case 'Mais antigo':
          expenses.sort((Expense first, Expense second) {
            return first.date.compareTo(second.date);
          });

        case 'Maior valor':
          expenses.sort((Expense first, Expense second) {
            final int comparison = second.amount.compareTo(first.amount);

            if (comparison != 0) {
              return comparison;
            }

            return second.date.compareTo(first.date);
          });

        case 'Menor valor':
          expenses.sort((Expense first, Expense second) {
            final int comparison = first.amount.compareTo(second.amount);

            if (comparison != 0) {
              return comparison;
            }

            return second.date.compareTo(first.date);
          });

        case 'Mais recente':
        default:
          expenses.sort((Expense first, Expense second) {
            return second.date.compareTo(first.date);
          });
      }

      final double dailyTotal = expenses.fold<double>(0, (
        double total,
        Expense expense,
      ) {
        return total + expense.amount;
      });

      entries.add(
        _HistoryDayHeaderEntry(
          date: date,
          total: dailyTotal,
          count: expenses.length,
        ),
      );

      entries.addAll(
        expenses.map((Expense expense) {
          return _HistoryExpenseEntry(expense: expense);
        }),
      );
    }

    return entries;
  }

  Future<bool> _confirmDeleteDialog(Expense expense) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          icon: const Icon(
            Icons.delete_outline_rounded,
            color: AppColors.error,
          ),
          title: const Text('Excluir gasto?'),
          content: Text(
            'O gasto de '
            '${_currencyFormatter.format(expense.amount)} '
            'em ${expense.categoryName} será excluído.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              style: TextButton.styleFrom(foregroundColor: AppColors.error),
              child: const Text('Excluir'),
            ),
          ],
        );
      },
    );

    return confirmed == true;
  }

  Future<void> _deleteExpense(
    Expense expense, {
    bool requireConfirmation = true,
  }) async {
    if (requireConfirmation) {
      final bool confirmed = await _confirmDeleteDialog(expense);

      if (!confirmed || !mounted) {
        return;
      }
    }

    // Remove imediatamente da tela para que o Dismissible
    // não permaneça na árvore depois da animação.
    setState(() {
      _allExpenses = _allExpenses
          .where((Expense item) => item.id != expense.id)
          .toList(growable: true);

      _filteredExpenses = _filterAndSortExpenses(_allExpenses);
    });

    try {
      final Expense removedExpense = await _repository.deleteExpenseAndReturn(
        expense.id,
      );

      // Atualiza Início, Histórico e Relatórios.
      expenseNotifier.value++;

      if (!mounted) {
        return;
      }

      final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);

      messenger
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 5),
            content: Text(
              'Gasto de '
              '${_currencyFormatter.format(expense.amount)} '
              'excluído.',
            ),
            action: SnackBarAction(
              label: 'Desfazer',
              onPressed: () async {
                try {
                  await _repository.saveExpense(removedExpense);

                  expenseNotifier.value++;

                  if (!mounted) {
                    return;
                  }

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Gasto restaurado.')),
                  );
                } catch (error, stackTrace) {
                  debugPrint(
                    'Erro ao restaurar gasto: '
                    '$error\n$stackTrace',
                  );

                  if (!mounted) {
                    return;
                  }

                  _showErrorMessage('Não foi possível restaurar o gasto.');
                }
              },
            ),
          ),
        );
    } catch (error, stackTrace) {
      debugPrint(
        'Erro ao excluir gasto: '
        '$error\n$stackTrace',
      );

      // Restaura a lista diretamente do banco caso a exclusão falhe.
      await _loadData(showLoading: false);

      if (!mounted) {
        return;
      }

      _showErrorMessage('Não foi possível excluir o gasto.');
    }
  }

  void _showExpenseDetails(Expense expense) {
    final CategoryStyle categoryStyle = CategoryStyles.fromName(
      expense.categoryName,
    );

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext modalContext) {
        final ThemeData theme = Theme.of(modalContext);

        return SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.sm,
              AppSpacing.xl,
              AppSpacing.xl,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border(modalContext),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Center(
                  child: Container(
                    width: 66,
                    height: 66,
                    decoration: BoxDecoration(
                      color: categoryStyle.color.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      categoryStyle.icon,
                      color: categoryStyle.color,
                      size: 32,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Center(
                  child: Text(
                    _currencyFormatter.format(expense.amount),
                    style: theme.textTheme.displaySmall,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Center(
                  child: Text(
                    expense.categoryName,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: categoryStyle.color,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                _ExpenseDetailRow(
                  icon: Icons.calendar_today_rounded,
                  label: 'Data e horário',
                  value: _formatFullDate(expense.date),
                ),
                _ExpenseDetailRow(
                  icon: Icons.edit_note_rounded,
                  label: 'Descrição',
                  value: _nonEmptyText(
                    expense.description,
                    fallback: 'Sem descrição',
                  ),
                ),
                if (expense.notes != null && expense.notes!.trim().isNotEmpty)
                  _ExpenseDetailRow(
                    icon: Icons.notes_rounded,
                    label: 'Observação',
                    value: expense.notes!.trim(),
                  ),
                if (expense.paymentMethod != null &&
                    expense.paymentMethod!.trim().isNotEmpty)
                  _ExpenseDetailRow(
                    icon: Icons.account_balance_wallet_rounded,
                    label: 'Forma de pagamento',
                    value: expense.paymentMethod!.trim(),
                  ),
                if (expense.isRecurring)
                  const _ExpenseDetailRow(
                    icon: Icons.repeat_rounded,
                    label: 'Recorrência',
                    value: 'Gasto recorrente',
                  ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(modalContext).pop();

                          AddExpenseModal.show(context, expense: expense);
                        },
                        icon: const Icon(Icons.edit_rounded),
                        label: const Text('Editar'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () {
                          Navigator.of(modalContext).pop();

                          _deleteExpense(expense);
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.error,
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.delete_outline_rounded),
                        label: const Text('Excluir'),
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

  void _showErrorMessage(String message) {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);

    messenger.clearSnackBars();

    messenger.showSnackBar(
      SnackBar(
        backgroundColor: AppColors.error,
        content: Row(
          children: <Widget>[
            const Icon(Icons.error_outline_rounded, color: Colors.white),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(message, style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateHeader(DateTime date) {
    final DateTime now = DateTime.now();

    if (DateUtils.isSameDay(date, now)) {
      return 'Hoje';
    }

    final DateTime yesterday = now.subtract(const Duration(days: 1));

    if (DateUtils.isSameDay(date, yesterday)) {
      return 'Ontem';
    }

    if (date.year == now.year) {
      return DateFormat("dd 'de' MMM.", 'pt_BR').format(date);
    }

    return DateFormat("dd 'de' MMM. 'de' yyyy", 'pt_BR').format(date);
  }

  String _formatFullDate(DateTime date) {
    return DateFormat("dd 'de' MMMM 'de' yyyy, HH:mm", 'pt_BR').format(date);
  }

  String _nonEmptyText(String? value, {required String fallback}) {
    final String normalizedValue = value?.trim() ?? '';

    if (normalizedValue.isEmpty) {
      return fallback;
    }

    return normalizedValue;
  }

  String _normalizeText(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('à', 'a')
        .replaceAll('â', 'a')
        .replaceAll('ã', 'a')
        .replaceAll('ä', 'a')
        .replaceAll('é', 'e')
        .replaceAll('è', 'e')
        .replaceAll('ê', 'e')
        .replaceAll('ë', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ì', 'i')
        .replaceAll('î', 'i')
        .replaceAll('ï', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ò', 'o')
        .replaceAll('ô', 'o')
        .replaceAll('õ', 'o')
        .replaceAll('ö', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ù', 'u')
        .replaceAll('û', 'u')
        .replaceAll('ü', 'u')
        .replaceAll('ç', 'c');
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color primaryColor = theme.colorScheme.primary;

    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: primaryColor));
    }

    if (_errorMessage != null) {
      return _HistoryErrorState(message: _errorMessage!, onRetry: _loadData);
    }

    final List<_HistoryListEntry> entries = _buildListEntries();

    final double topPadding = MediaQuery.paddingOf(context).top;

    return Column(
      children: <Widget>[
        Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.pageHorizontal,
            topPadding + AppSpacing.xl,
            AppSpacing.pageHorizontal,
            0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text('Histórico', style: theme.textTheme.headlineSmall),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          '${_filteredExpenses.length} '
                          '${_filteredExpenses.length == 1 ? 'gasto encontrado' : 'gastos encontrados'}',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  _FilterButton(
                    activeFilterCount: _activeFilterCount,
                    onPressed: _openFilters,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                controller: _searchController,
                textInputAction: TextInputAction.search,
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: 'Buscar categoria, descrição, observação ou valor',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _searchQuery.isEmpty
                      ? null
                      : IconButton(
                          onPressed: _clearSearch,
                          tooltip: 'Limpar busca',
                          icon: const Icon(Icons.close_rounded),
                        ),
                ),
              ),
              if (_hasAnyFilter) ...<Widget>[
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        _filterSummary,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: primaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _clearAllFilters,
                      child: const Text('Limpar'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () {
              return _loadData(showLoading: false);
            },
            child: entries.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(
                      AppSpacing.pageHorizontal,
                      AppSpacing.xxl,
                      AppSpacing.pageHorizontal,
                      AppSpacing.safeBottomPadding(context),
                    ),
                    children: <Widget>[
                      _EmptyHistoryState(
                        hasFilters: _hasAnyFilter,
                        onClearFilters: _clearAllFilters,
                      ),
                    ],
                  )
                : ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: EdgeInsets.fromLTRB(
                      AppSpacing.pageHorizontal,
                      AppSpacing.sm,
                      AppSpacing.pageHorizontal,
                      AppSpacing.safeBottomPadding(context),
                    ),
                    itemCount: entries.length,
                    itemBuilder: (BuildContext context, int index) {
                      final _HistoryListEntry entry = entries[index];

                      if (entry is _HistoryDayHeaderEntry) {
                        return _DayHeader(
                          title: _formatDateHeader(entry.date),
                          total: _currencyFormatter.format(entry.total),
                          count: entry.count,
                        );
                      }

                      final Expense expense =
                          (entry as _HistoryExpenseEntry).expense;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: Dismissible(
                          key: ValueKey<String>(expense.id),
                          direction: DismissDirection.endToStart,
                          confirmDismiss: (DismissDirection direction) {
                            return _confirmDeleteDialog(expense);
                          },
                          onDismissed: (DismissDirection direction) {
                            _deleteExpense(expense, requireConfirmation: false);
                          },
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(
                              right: AppSpacing.xl,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.error,
                              borderRadius: BorderRadius.circular(
                                AppSpacing.cardRadius,
                              ),
                            ),
                            child: const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                Icon(
                                  Icons.delete_outline_rounded,
                                  color: Colors.white,
                                ),
                                SizedBox(height: AppSpacing.xxs),
                                Text(
                                  'Excluir',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          child: _HistoryExpenseCard(
                            expense: expense,
                            formattedAmount: _currencyFormatter.format(
                              expense.amount,
                            ),
                            formattedTime: DateFormat(
                              'HH:mm',
                            ).format(expense.date),
                            onTap: () {
                              _showExpenseDetails(expense);
                            },
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}

class _HistoryExpenseCard extends StatelessWidget {
  const _HistoryExpenseCard({
    required this.expense,
    required this.formattedAmount,
    required this.formattedTime,
    required this.onTap,
  });

  final Expense expense;
  final String formattedAmount;
  final String formattedTime;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    final CategoryStyle categoryStyle = CategoryStyles.fromName(
      expense.categoryName,
    );

    final String description = expense.description?.trim() ?? '';

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Row(
            children: <Widget>[
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: categoryStyle.color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
                ),
                child: Icon(
                  categoryStyle.icon,
                  color: categoryStyle.color,
                  size: 24,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      expense.categoryName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      description.isEmpty ? 'Sem descrição' : description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Text(
                    formattedAmount,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(formattedTime, style: theme.textTheme.labelSmall),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({
    required this.title,
    required this.total,
    required this.count,
  });

  final String title;
  final String total;
  final int count;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg, bottom: AppSpacing.sm),
      child: Row(
        children: <Widget>[
          Expanded(child: Text(title, style: theme.textTheme.titleMedium)),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text(total, style: theme.textTheme.titleSmall),
              const SizedBox(height: 2),
              Text(
                '$count ${count == 1 ? 'registro' : 'registros'}',
                style: theme.textTheme.labelSmall,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({
    required this.activeFilterCount,
    required this.onPressed,
  });

  final int activeFilterCount;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Theme.of(context).colorScheme.primary;

    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        IconButton(
          onPressed: onPressed,
          tooltip: 'Filtros e ordenação',
          icon: const Icon(Icons.tune_rounded),
        ),
        if (activeFilterCount > 0)
          Positioned(
            right: 1,
            top: 1,
            child: Container(
              constraints: const BoxConstraints(minWidth: 19, minHeight: 19),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 5),
              decoration: BoxDecoration(
                color: primaryColor,
                shape: BoxShape.circle,
              ),
              child: Text(
                '$activeFilterCount',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimary,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _HistoryFilterSheet extends StatefulWidget {
  const _HistoryFilterSheet({
    required this.initialPeriod,
    required this.initialSort,
    required this.initialCategories,
    required this.initialCustomRange,
    required this.availableCategories,
  });

  final String initialPeriod;
  final String initialSort;
  final Set<String> initialCategories;
  final DateTimeRange? initialCustomRange;
  final List<String> availableCategories;

  @override
  State<_HistoryFilterSheet> createState() {
    return _HistoryFilterSheetState();
  }
}

class _HistoryFilterSheetState extends State<_HistoryFilterSheet> {
  static const List<String> _periods = <String>[
    'Todos',
    'Hoje',
    'Esta semana',
    'Este mês',
    'Mês anterior',
    'Personalizado',
  ];

  static const List<String> _sortOptions = <String>[
    'Mais recente',
    'Mais antigo',
    'Maior valor',
    'Menor valor',
  ];

  late String _period;
  late String _sort;
  late Set<String> _categories;

  DateTimeRange? _customDateRange;

  @override
  void initState() {
    super.initState();

    _period = widget.initialPeriod;
    _sort = widget.initialSort;
    _categories = Set<String>.from(widget.initialCategories);
    _customDateRange = widget.initialCustomRange;
  }

  Future<void> _selectPeriod(String period) async {
    if (period != 'Personalizado') {
      setState(() {
        _period = period;
      });

      return;
    }

    final DateTime now = DateTime.now();

    final DateTimeRange? selectedRange = await showDateRangePicker(
      context: context,
      initialDateRange: _customDateRange,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 10, 12, 31),
      helpText: 'Selecionar período',
      cancelText: 'Cancelar',
      confirmText: 'Confirmar',
      saveText: 'Aplicar',
    );

    if (selectedRange == null || !mounted) {
      return;
    }

    setState(() {
      _period = 'Personalizado';
      _customDateRange = selectedRange;
    });
  }

  void _toggleCategory(String category, bool selected) {
    setState(() {
      if (selected) {
        _categories.add(category);
      } else {
        _categories.remove(category);
      }
    });
  }

  void _clearFilters() {
    HapticFeedback.selectionClick();

    setState(() {
      _period = 'Todos';
      _sort = 'Mais recente';
      _categories.clear();
      _customDateRange = null;
    });
  }

  void _applyFilters() {
    Navigator.of(context).pop(
      _HistoryFilterResult(
        period: _period,
        sort: _sort,
        categories: Set<String>.from(_categories),
        customDateRange: _customDateRange,
      ),
    );
  }

  String get _customRangeLabel {
    final DateTimeRange? range = _customDateRange;

    if (range == null) {
      return 'Escolher datas';
    }

    final String start = DateFormat('dd/MM/yyyy').format(range.start);

    final String end = DateFormat('dd/MM/yyyy').format(range.end);

    return '$start até $end';
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color primaryColor = theme.colorScheme.primary;

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.88,
      child: SafeArea(
        top: false,
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.sm,
                AppSpacing.xl,
                AppSpacing.md,
              ),
              child: Column(
                children: <Widget>[
                  Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border(context),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          'Filtros e ordenação',
                          style: theme.textTheme.titleLarge,
                        ),
                      ),
                      TextButton(
                        onPressed: _clearFilters,
                        child: const Text('Limpar'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Período', style: theme.textTheme.titleSmall),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: _periods
                          .map((String period) {
                            return ChoiceChip(
                              label: Text(period),
                              selected: _period == period,
                              showCheckmark: false,
                              onSelected: (bool selected) {
                                if (selected) {
                                  _selectPeriod(period);
                                }
                              },
                            );
                          })
                          .toList(growable: false),
                    ),
                    if (_period == 'Personalizado') ...<Widget>[
                      const SizedBox(height: AppSpacing.sm),
                      OutlinedButton.icon(
                        onPressed: () {
                          _selectPeriod('Personalizado');
                        },
                        icon: const Icon(Icons.date_range_rounded),
                        label: Text(_customRangeLabel),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.xxl),
                    Text('Categorias', style: theme.textTheme.titleSmall),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      _categories.isEmpty
                          ? 'Todas as categorias estão incluídas.'
                          : '${_categories.length} selecionadas.',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: widget.availableCategories
                          .map((String category) {
                            final CategoryStyle categoryStyle =
                                CategoryStyles.fromName(category);

                            final bool selected = _categories.contains(
                              category,
                            );

                            return FilterChip(
                              avatar: Icon(
                                categoryStyle.icon,
                                size: 17,
                                color: selected
                                    ? primaryColor
                                    : categoryStyle.color,
                              ),
                              label: Text(category),
                              selected: selected,
                              onSelected: (bool value) {
                                _toggleCategory(category, value);
                              },
                            );
                          })
                          .toList(growable: false),
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    Text('Ordenação', style: theme.textTheme.titleSmall),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: _sortOptions
                          .map((String sortOption) {
                            return ChoiceChip(
                              label: Text(sortOption),
                              selected: _sort == sortOption,
                              showCheckmark: false,
                              onSelected: (bool selected) {
                                if (!selected) {
                                  return;
                                }

                                setState(() {
                                  _sort = sortOption;
                                });
                              },
                            );
                          })
                          .toList(growable: false),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: FilledButton.icon(
                onPressed: _applyFilters,
                icon: const Icon(Icons.check_rounded),
                label: const Text('Aplicar filtros'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExpenseDetailRow extends StatelessWidget {
  const _ExpenseDetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.surfaceSecondary(context),
              borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
            ),
            child: Icon(icon, size: 20),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(label, style: theme.textTheme.labelSmall),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  value,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.textPrimary(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyHistoryState extends StatelessWidget {
  const _EmptyHistoryState({
    required this.hasFilters,
    required this.onClearFilters,
  });

  final bool hasFilters;
  final VoidCallback onClearFilters;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          children: <Widget>[
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                hasFilters
                    ? Icons.search_off_rounded
                    : Icons.receipt_long_outlined,
                color: theme.colorScheme.primary,
                size: 32,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              hasFilters
                  ? 'Nenhum gasto corresponde à busca.'
                  : 'Nenhum gasto registrado.',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              hasFilters
                  ? 'Tente alterar a busca ou remover alguns filtros.'
                  : 'Os gastos registrados aparecerão aqui, organizados por dia.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
            if (hasFilters) ...<Widget>[
              const SizedBox(height: AppSpacing.lg),
              OutlinedButton.icon(
                onPressed: onClearFilters,
                icon: const Icon(Icons.filter_alt_off_rounded),
                label: const Text('Limpar busca e filtros'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _HistoryErrorState extends StatelessWidget {
  const _HistoryErrorState({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function({bool showLoading}) onRetry;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.error_outline_rounded,
              color: AppColors.error,
              size: 50,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: () {
                onRetry(showLoading: true);
              },
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryFilterResult {
  const _HistoryFilterResult({
    required this.period,
    required this.sort,
    required this.categories,
    required this.customDateRange,
  });

  final String period;
  final String sort;
  final Set<String> categories;
  final DateTimeRange? customDateRange;
}

abstract class _HistoryListEntry {
  const _HistoryListEntry();
}

class _HistoryDayHeaderEntry extends _HistoryListEntry {
  const _HistoryDayHeaderEntry({
    required this.date,
    required this.total,
    required this.count,
  });

  final DateTime date;
  final double total;
  final int count;
}

class _HistoryExpenseEntry extends _HistoryListEntry {
  const _HistoryExpenseEntry({required this.expense});

  final Expense expense;
}
