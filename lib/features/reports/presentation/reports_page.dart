import 'package:fl_chart/fl_chart.dart';
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

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  static const List<String> _periodOptions = <String>[
    'Este mês',
    'Mês passado',
    'Mês retrasado',
    'Últimos 30 dias',
    'Este ano',
    'Período personalizado',
  ];

  final ExpenseRepository _repository = ExpenseRepository();

  late final NumberFormat _currencyFormatter;

  List<Expense> _periodExpenses = <Expense>[];
  List<_CategoryStat> _categoryStats = <_CategoryStat>[];

  String _selectedPeriod = 'Este mês';
  String? _selectedCategoryName;

  DateTimeRange? _customDateRange;

  double _periodTotal = 0;

  bool _isLoading = true;
  String? _errorMessage;

  int _loadRequestId = 0;

  @override
  void initState() {
    super.initState();

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
      final List<Expense> allExpenses = await _repository.getAllExpenses();

      final List<Expense> filteredExpenses =
          allExpenses.where(_matchesSelectedPeriod).toList(growable: false)
            ..sort((Expense first, Expense second) {
              return second.date.compareTo(first.date);
            });

      final double total = filteredExpenses.fold<double>(0, (
        double currentTotal,
        Expense expense,
      ) {
        return currentTotal + expense.amount;
      });

      final Map<String, List<Expense>> groupedExpenses =
          <String, List<Expense>>{};

      for (final Expense expense in filteredExpenses) {
        groupedExpenses.putIfAbsent(expense.categoryName, () => <Expense>[]);

        groupedExpenses[expense.categoryName]!.add(expense);
      }

      final List<_CategoryStat> categoryStats =
          groupedExpenses.entries
              .map((MapEntry<String, List<Expense>> entry) {
                final double categoryTotal = entry.value.fold<double>(0, (
                  double currentTotal,
                  Expense expense,
                ) {
                  return currentTotal + expense.amount;
                });

                final double percentage = total > 0
                    ? (categoryTotal / total) * 100
                    : 0;

                return _CategoryStat(
                  name: entry.key,
                  amount: categoryTotal,
                  count: entry.value.length,
                  percentage: percentage,
                  style: CategoryStyles.fromName(entry.key),
                );
              })
              .toList(growable: false)
            ..sort((_CategoryStat first, _CategoryStat second) {
              return second.amount.compareTo(first.amount);
            });

      if (!mounted || requestId != _loadRequestId) {
        return;
      }

      final bool selectedCategoryStillExists =
          _selectedCategoryName != null &&
          categoryStats.any((_CategoryStat stat) {
            return stat.name == _selectedCategoryName;
          });

      setState(() {
        _periodExpenses = filteredExpenses;
        _categoryStats = categoryStats;
        _periodTotal = total;

        if (!selectedCategoryStillExists) {
          _selectedCategoryName = null;
        }

        _isLoading = false;
        _errorMessage = null;
      });
    } catch (_) {
      if (!mounted || requestId != _loadRequestId) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = 'Não foi possível carregar os relatórios.';
      });
    }
  }

  bool _matchesSelectedPeriod(Expense expense) {
    final DateTime now = DateTime.now();
    final DateTime expenseDate = expense.date;

    late final DateTime start;
    late final DateTime endExclusive;

    switch (_selectedPeriod) {
      case 'Mês passado':
        start = DateTime(now.year, now.month - 1);

        endExclusive = DateTime(now.year, now.month);

      case 'Mês retrasado':
        start = DateTime(now.year, now.month - 2);

        endExclusive = DateTime(now.year, now.month - 1);

      case 'Últimos 30 dias':
        final DateTime today = DateUtils.dateOnly(now);

        start = today.subtract(const Duration(days: 29));

        endExclusive = today.add(const Duration(days: 1));

      case 'Este ano':
        start = DateTime(now.year);

        endExclusive = DateTime(now.year + 1);

      case 'Período personalizado':
        final DateTimeRange? range = _customDateRange;

        if (range == null) {
          return true;
        }

        start = DateUtils.dateOnly(range.start);

        endExclusive = DateUtils.dateOnly(
          range.end,
        ).add(const Duration(days: 1));

      case 'Este mês':
      default:
        start = DateTime(now.year, now.month);

        endExclusive = DateTime(now.year, now.month + 1);
    }

    return !expenseDate.isBefore(start) && expenseDate.isBefore(endExclusive);
  }

  Future<void> _showPeriodSelector() async {
    HapticFeedback.selectionClick();

    final String? selectedPeriod = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (BuildContext modalContext) {
        final ThemeData theme = Theme.of(modalContext);

        final double heightFactor =
            MediaQuery.orientationOf(modalContext) == Orientation.landscape
            ? 0.90
            : 0.72;

        return FractionallySizedBox(
          heightFactor: heightFactor,
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
                  child: Text(
                    'Selecionar período',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                const Divider(),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      AppSpacing.xs,
                      AppSpacing.md,
                      AppSpacing.xl,
                    ),
                    itemCount: _periodOptions.length,
                    separatorBuilder: (BuildContext context, int index) {
                      return const SizedBox(height: AppSpacing.xxs);
                    },
                    itemBuilder: (BuildContext context, int index) {
                      final String option = _periodOptions[index];

                      final bool selected = option == _selectedPeriod;

                      return ListTile(
                        selected: selected,
                        leading: Icon(
                          _periodIcon(option),
                          color: selected
                              ? theme.colorScheme.primary
                              : AppColors.textSecondary(modalContext),
                        ),
                        title: Text(
                          option,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: selected
                                ? theme.colorScheme.primary
                                : AppColors.textPrimary(modalContext),
                            fontWeight: selected
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                        trailing: selected
                            ? Icon(
                                Icons.check_circle_rounded,
                                color: theme.colorScheme.primary,
                              )
                            : const Icon(Icons.chevron_right_rounded),
                        onTap: () {
                          Navigator.of(modalContext).pop(option);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (selectedPeriod == null || !mounted) {
      return;
    }

    DateTimeRange? selectedCustomRange = _customDateRange;

    if (selectedPeriod == 'Período personalizado') {
      final DateTime now = DateTime.now();

      final DateTimeRange? pickedRange = await showDateRangePicker(
        context: context,
        initialDateRange: _customDateRange,
        firstDate: DateTime(2000),
        lastDate: DateTime(now.year + 10, 12, 31),
        helpText: 'Selecionar período do relatório',
        cancelText: 'Cancelar',
        confirmText: 'Confirmar',
        saveText: 'Aplicar',
      );

      if (pickedRange == null || !mounted) {
        return;
      }

      selectedCustomRange = pickedRange;
    }

    setState(() {
      _selectedPeriod = selectedPeriod;
      _customDateRange = selectedCustomRange;
      _selectedCategoryName = null;
    });

    await _loadData();
  }

  IconData _periodIcon(String period) {
    switch (period) {
      case 'Este mês':
        return Icons.calendar_today_rounded;

      case 'Mês passado':
        return Icons.history_rounded;

      case 'Mês retrasado':
        return Icons.history_toggle_off_rounded;

      case 'Últimos 30 dias':
        return Icons.date_range_rounded;

      case 'Este ano':
        return Icons.calendar_view_month_rounded;

      case 'Período personalizado':
        return Icons.edit_calendar_rounded;

      default:
        return Icons.calendar_month_rounded;
    }
  }

  String _periodTitle() {
    final DateTime now = DateTime.now();

    switch (_selectedPeriod) {
      case 'Mês passado':
        return _formattedMonth(DateTime(now.year, now.month - 1));

      case 'Mês retrasado':
        return _formattedMonth(DateTime(now.year, now.month - 2));

      case 'Período personalizado':
        final DateTimeRange? range = _customDateRange;

        if (range == null) {
          return 'Período personalizado';
        }

        final String start = DateFormat('dd/MM/yyyy').format(range.start);

        final String end = DateFormat('dd/MM/yyyy').format(range.end);

        return '$start até $end';

      case 'Este mês':
        return _formattedMonth(now);

      case 'Últimos 30 dias':
      case 'Este ano':
      default:
        return _selectedPeriod;
    }
  }

  String _formattedMonth(DateTime date) {
    final String month = DateFormat("MMMM 'de' yyyy", 'pt_BR').format(date);

    if (month.isEmpty) {
      return month;
    }

    return '${month[0].toUpperCase()}${month.substring(1)}';
  }

  _CategoryStat? get _selectedCategory {
    final String? selectedName = _selectedCategoryName;

    if (selectedName == null) {
      return null;
    }

    for (final _CategoryStat stat in _categoryStats) {
      if (stat.name == selectedName) {
        return stat;
      }
    }

    return null;
  }

  List<Expense> get _selectedCategoryExpenses {
    final String? selectedName = _selectedCategoryName;

    if (selectedName == null) {
      return <Expense>[];
    }

    return _periodExpenses
        .where((Expense expense) {
          return expense.categoryName == selectedName;
        })
        .toList(growable: false);
  }

  void _selectCategory(String categoryName) {
    HapticFeedback.selectionClick();

    setState(() {
      if (_selectedCategoryName == categoryName) {
        _selectedCategoryName = null;
      } else {
        _selectedCategoryName = categoryName;
      }
    });
  }

  void _clearSelectedCategory() {
    HapticFeedback.lightImpact();

    setState(() {
      _selectedCategoryName = null;
    });
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
                      color: categoryStyle.backgroundColor(),
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
                  value: DateFormat(
                    "dd 'de' MMMM 'de' yyyy, HH:mm",
                    'pt_BR',
                  ).format(expense.date),
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

                          _confirmDeleteExpense(expense);
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

  Future<void> _confirmDeleteExpense(Expense expense) async {
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
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
              ),
              child: const Text('Excluir'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    try {
      final Expense removedExpense = await _repository.deleteExpenseAndReturn(
        expense.id,
      );

      expenseNotifier.value++;

      if (!mounted) {
        return;
      }

      final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);

      messenger.clearSnackBars();

      messenger.showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 5),
          persist: false,
          dismissDirection: DismissDirection.down,
          actionOverflowThreshold: 1,
          content: const Text('Gasto excluído.', maxLines: 1),
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
                  const SnackBar(
                    duration: Duration(seconds: 3),
                    persist: false,
                    content: Text('Gasto restaurado.'),
                  ),
                );
              } catch (_) {
                if (!mounted) {
                  return;
                }

                _showErrorMessage('Não foi possível restaurar o gasto.');
              }
            },
          ),
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      _showErrorMessage('Não foi possível excluir o gasto.');
    }
  }

  void _showErrorMessage(String message) {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);

    messenger.clearSnackBars();

    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 4),
        persist: false,
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

  String _nonEmptyText(String? value, {required String fallback}) {
    final String normalizedValue = value?.trim() ?? '';

    if (normalizedValue.isEmpty) {
      return fallback;
    }

    return normalizedValue;
  }

  String _formatExpenseDate(DateTime date) {
    final DateTime now = DateTime.now();
    final DateTime yesterday = now.subtract(const Duration(days: 1));

    final String time = DateFormat('HH:mm').format(date);

    if (DateUtils.isSameDay(date, now)) {
      return 'Hoje, $time';
    }

    if (DateUtils.isSameDay(date, yesterday)) {
      return 'Ontem, $time';
    }

    if (date.year == now.year) {
      return DateFormat('dd MMM, HH:mm', 'pt_BR').format(date);
    }

    return DateFormat('dd MMM yyyy, HH:mm', 'pt_BR').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: theme.colorScheme.primary),
      );
    }

    if (_errorMessage != null) {
      return _ReportsErrorState(
        message: _errorMessage!,
        onRetry: () {
          _loadData();
        },
      );
    }

    final double topPadding = MediaQuery.paddingOf(context).top;

    return RefreshIndicator(
      onRefresh: () {
        return _loadData(showLoading: false);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          AppSpacing.pageHorizontal,
          topPadding + AppSpacing.xl,
          AppSpacing.pageHorizontal,
          AppSpacing.safeBottomPadding(context),
        ),
        children: <Widget>[
          _buildHeader(theme),
          const SizedBox(height: AppSpacing.xl),
          if (_categoryStats.isEmpty)
            _EmptyReportsState(
              periodTitle: _periodTitle(),
              onAddExpense: () {
                AddExpenseModal.show(context);
              },
            )
          else ...<Widget>[
            _buildSummaryCard(theme),
            const SizedBox(height: AppSpacing.xl),
            _buildChartCard(theme),
            if (_selectedCategory != null) ...<Widget>[
              const SizedBox(height: AppSpacing.lg),
              _buildSelectedCategoryCard(theme, _selectedCategory!),
            ],
            const SizedBox(height: AppSpacing.xxl),
            Text('Gastos por categoria', style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Da maior despesa para a menor.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.md),
            ..._categoryStats.map((_CategoryStat stat) {
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _CategoryCard(
                  stat: stat,
                  formattedAmount: _currencyFormatter.format(stat.amount),
                  selected: stat.name == _selectedCategoryName,
                  onTap: () {
                    _selectCategory(stat.name);
                  },
                ),
              );
            }),
            if (_selectedCategory != null) ...<Widget>[
              const SizedBox(height: AppSpacing.xl),
              _buildSelectedExpenses(theme),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Relatórios', style: theme.textTheme.headlineSmall),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                'Veja para onde seu dinheiro está indo.',
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Material(
          color: AppColors.surfaceSecondary(context),
          borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
          child: InkWell(
            onTap: _showPeriodSelector,
            borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    Icons.calendar_month_rounded,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 130),
                    child: Text(
                      _periodTitle(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xxs),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(ThemeData theme) {
    final _CategoryStat mainCategory = _categoryStats.first;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Total do período', style: theme.textTheme.bodyMedium),
            const SizedBox(height: AppSpacing.xs),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                _currencyFormatter.format(_periodTotal),
                style: theme.textTheme.displaySmall,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: <Widget>[
                Expanded(
                  child: _SummaryInformation(
                    icon: Icons.receipt_long_rounded,
                    label: 'Registros',
                    value: '${_periodExpenses.length}',
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _SummaryInformation(
                    icon: Icons.category_rounded,
                    label: 'Categorias',
                    value: '${_categoryStats.length}',
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _SummaryInformation(
                    icon: mainCategory.style.icon,
                    label: 'Principal',
                    value: mainCategory.name,
                    iconColor: mainCategory.style.color,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartCard(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Distribuição por categoria',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Toque em uma fatia ou categoria para ver detalhes.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              height: 250,
              child: Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  PieChart(
                    PieChartData(
                      borderData: FlBorderData(show: false),
                      sectionsSpace: 3,
                      centerSpaceRadius: 68,
                      pieTouchData: PieTouchData(
                        touchCallback:
                            (FlTouchEvent event, PieTouchResponse? response) {
                              if (!event.isInterestedForInteractions ||
                                  response == null ||
                                  response.touchedSection == null) {
                                return;
                              }

                              final int index =
                                  response.touchedSection!.touchedSectionIndex;

                              if (index < 0 || index >= _categoryStats.length) {
                                return;
                              }

                              final String categoryName =
                                  _categoryStats[index].name;

                              if (_selectedCategoryName != categoryName) {
                                HapticFeedback.selectionClick();

                                setState(() {
                                  _selectedCategoryName = categoryName;
                                });
                              }
                            },
                      ),
                      sections: _categoryStats
                          .asMap()
                          .entries
                          .map((MapEntry<int, _CategoryStat> entry) {
                            final _CategoryStat stat = entry.value;

                            final bool selected =
                                stat.name == _selectedCategoryName;

                            final bool showPercentage = stat.percentage >= 5;

                            return PieChartSectionData(
                              color: stat.style.color,
                              value: stat.amount,
                              radius: selected ? 48 : 40,
                              title: showPercentage
                                  ? '${stat.percentage.toStringAsFixed(0)}%'
                                  : '',
                              titleStyle: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            );
                          })
                          .toList(growable: false),
                    ),
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOut,
                  ),
                  SizedBox(
                    width: 128,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text('Total', style: theme.textTheme.bodySmall),
                        const SizedBox(height: AppSpacing.xxs),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            _currencyFormatter.format(_periodTotal),
                            maxLines: 1,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Percentuais abaixo de 5% aparecem apenas na lista.',
              style: theme.textTheme.labelSmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedCategoryCard(ThemeData theme, _CategoryStat stat) {
    return Card(
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          border: Border.all(
            color: stat.style.color.withValues(alpha: 0.55),
            width: 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: stat.style.backgroundColor(),
                    borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
                  ),
                  child: Icon(stat.style.icon, color: stat.style.color),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(stat.name, style: theme.textTheme.titleLarge),
                ),
                IconButton(
                  onPressed: _clearSelectedCategory,
                  tooltip: 'Fechar detalhes',
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: <Widget>[
                Expanded(
                  child: _SelectedCategoryMetric(
                    label: 'Total',
                    value: _currencyFormatter.format(stat.amount),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _SelectedCategoryMetric(
                    label: 'Percentual',
                    value: '${stat.percentage.toStringAsFixed(1)}%',
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _SelectedCategoryMetric(
                    label: 'Lançamentos',
                    value: '${stat.count}',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedExpenses(ThemeData theme) {
    final List<Expense> expenses = _selectedCategoryExpenses;

    final int displayedCount = expenses.length > 20 ? 20 : expenses.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Lançamentos de $_selectedCategoryName',
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          expenses.length > 20
              ? 'Mostrando os 20 lançamentos mais recentes.'
              : '${expenses.length} '
                    '${expenses.length == 1 ? 'lançamento' : 'lançamentos'} '
                    'neste período.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: AppSpacing.md),
        for (int index = 0; index < displayedCount; index++)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: _ReportExpenseCard(
              expense: expenses[index],
              formattedAmount: _currencyFormatter.format(
                expenses[index].amount,
              ),
              formattedDate: _formatExpenseDate(expenses[index].date),
              onTap: () {
                _showExpenseDetails(expenses[index]);
              },
            ),
          ),
      ],
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.stat,
    required this.formattedAmount,
    required this.selected,
    required this.onTap,
  });

  final _CategoryStat stat;
  final String formattedAmount;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
            border: Border.all(
              color: selected ? stat.style.color : Colors.transparent,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: stat.style.backgroundColor(),
                  borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
                ),
                child: Icon(stat.style.icon, color: stat.style.color, size: 24),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      stat.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      '${stat.percentage.toStringAsFixed(1)}% • '
                      '${stat.count} '
                      '${stat.count == 1 ? 'lançamento' : 'lançamentos'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: stat.percentage / 100,
                        minHeight: 5,
                        backgroundColor: AppColors.surfaceSecondary(context),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          stat.style.color,
                        ),
                      ),
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
                  Icon(
                    selected
                        ? Icons.expand_less_rounded
                        : Icons.chevron_right_rounded,
                    color: selected
                        ? stat.style.color
                        : AppColors.textMuted(context),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReportExpenseCard extends StatelessWidget {
  const _ReportExpenseCard({
    required this.expense,
    required this.formattedAmount,
    required this.formattedDate,
    required this.onTap,
  });

  final Expense expense;
  final String formattedAmount;
  final String formattedDate;
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
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: categoryStyle.backgroundColor(),
                  borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
                ),
                child: Icon(categoryStyle.icon, color: categoryStyle.color),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      description.isEmpty ? 'Sem descrição' : description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      formattedDate,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                formattedAmount,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryInformation extends StatelessWidget {
  const _SummaryInformation({
    required this.icon,
    required this.label,
    required this.value,
    this.iconColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surfaceSecondary(context),
        borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
      ),
      child: Column(
        children: <Widget>[
          Icon(icon, color: iconColor ?? theme.colorScheme.primary, size: 21),
          const SizedBox(height: AppSpacing.xs),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: theme.textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}

class _SelectedCategoryMetric extends StatelessWidget {
  const _SelectedCategoryMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceSecondary(context),
        borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
      ),
      child: Column(
        children: <Widget>[
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              maxLines: 1,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall,
          ),
        ],
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

class _EmptyReportsState extends StatelessWidget {
  const _EmptyReportsState({
    required this.periodTitle,
    required this.onAddExpense,
  });

  final String periodTitle;
  final VoidCallback onAddExpense;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          children: <Widget>[
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.pie_chart_outline_rounded,
                color: theme.colorScheme.primary,
                size: 34,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Ainda não existem gastos neste período.',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              periodTitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: onAddExpense,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Registrar primeiro gasto'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportsErrorState extends StatelessWidget {
  const _ReportsErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

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
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryStat {
  const _CategoryStat({
    required this.name,
    required this.amount,
    required this.count,
    required this.percentage,
    required this.style,
  });

  final String name;
  final double amount;
  final int count;
  final double percentage;
  final CategoryStyle style;
}
