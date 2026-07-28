import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/category_style.dart';
import '../../../../core/utils/expense_notifier.dart';
import '../../expenses/data/expense_repository.dart';
import '../../expenses/domain/expense.dart';
import '../../expenses/presentation/widgets/add_expense_modal.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const List<String> _periods = <String>['Hoje', 'Semana', 'Mês'];

  final ExpenseRepository _repository = ExpenseRepository();

  late final NumberFormat _currencyFormatter;

  String _selectedPeriod = 'Hoje';
  String _userName = '';

  double _periodTotal = 0;
  double _previousPeriodTotal = 0;
  double _monthTotal = 0;
  double _monthlyLimit = 2000;

  int _periodCount = 0;
  int _loadRequestId = 0;

  List<Expense> _recentExpenses = <Expense>[];

  bool _isLoading = true;
  String? _errorMessage;

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
    final int currentRequestId = ++_loadRequestId;

    if (showLoading && mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final SharedPreferences preferences =
          await SharedPreferences.getInstance();

      final double savedLimit = preferences.getDouble('monthlyLimit') ?? 2000;

      final String savedUserName =
          preferences.getString('userName')?.trim() ?? '';

      final List<Expense> periodExpenses = await _repository
          .getExpensesForPeriod(_selectedPeriod);

      final List<Expense> monthExpenses = await _repository
          .getExpensesForPeriod('Mês');

      final double previousPeriodTotal = await _getPreviousPeriodTotal(
        _selectedPeriod,
      );

      final double periodTotal = periodExpenses.fold<double>(0, (
        double total,
        Expense expense,
      ) {
        return total + expense.amount;
      });

      final double monthTotal = monthExpenses.fold<double>(0, (
        double total,
        Expense expense,
      ) {
        return total + expense.amount;
      });

      if (!mounted || currentRequestId != _loadRequestId) {
        return;
      }

      setState(() {
        _monthlyLimit = savedLimit > 0 ? savedLimit : 2000;
        _userName = savedUserName;

        _periodTotal = periodTotal;
        _previousPeriodTotal = previousPeriodTotal;
        _monthTotal = monthTotal;
        _periodCount = periodExpenses.length;

        _recentExpenses = periodExpenses.take(5).toList(growable: false);

        _isLoading = false;
        _errorMessage = null;
      });
    } catch (_) {
      if (!mounted || currentRequestId != _loadRequestId) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = 'Não foi possível carregar seu resumo financeiro.';
      });
    }
  }

  Future<double> _getPreviousPeriodTotal(String period) async {
    final DateTime now = DateTime.now();

    switch (period) {
      case 'Hoje':
        final DateTime todayStart = DateTime(now.year, now.month, now.day);

        final DateTime yesterdayStart = todayStart.subtract(
          const Duration(days: 1),
        );

        final Duration elapsedToday = now.difference(todayStart);

        DateTime yesterdayEquivalentEnd = yesterdayStart.add(elapsedToday);

        if (!yesterdayEquivalentEnd.isAfter(yesterdayStart)) {
          yesterdayEquivalentEnd = yesterdayStart.add(
            const Duration(microseconds: 1),
          );
        }

        return _repository.getTotalBetween(
          start: yesterdayStart,
          endExclusive: yesterdayEquivalentEnd,
        );

      case 'Semana':
        final DateTime currentWeekStart = DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(const Duration(days: 6));

        final DateTime previousWeekStart = currentWeekStart.subtract(
          const Duration(days: 7),
        );

        return _repository.getTotalBetween(
          start: previousWeekStart,
          endExclusive: currentWeekStart,
        );

      case 'Mês':
        final DateTime previousMonthStart = DateTime(now.year, now.month - 1);

        final int previousMonthLastDay = DateTime(now.year, now.month, 0).day;

        DateTime previousMonthEquivalentEnd;

        if (now.day > previousMonthLastDay) {
          previousMonthEquivalentEnd = DateTime(now.year, now.month);
        } else {
          previousMonthEquivalentEnd = DateTime(
            previousMonthStart.year,
            previousMonthStart.month,
            now.day,
            now.hour,
            now.minute,
            now.second,
            now.millisecond,
            now.microsecond,
          );
        }

        if (!previousMonthEquivalentEnd.isAfter(previousMonthStart)) {
          previousMonthEquivalentEnd = previousMonthStart.add(
            const Duration(microseconds: 1),
          );
        }

        return _repository.getTotalBetween(
          start: previousMonthStart,
          endExclusive: previousMonthEquivalentEnd,
        );

      default:
        return 0;
    }
  }

  void _selectPeriod(String period) {
    if (_selectedPeriod == period) {
      return;
    }

    HapticFeedback.selectionClick();

    setState(() {
      _selectedPeriod = period;
    });

    _loadData();
  }

  String _greeting() {
    final int hour = DateTime.now().hour;

    if (hour >= 5 && hour < 12) {
      return 'Bom dia';
    }

    if (hour >= 12 && hour < 18) {
      return 'Boa tarde';
    }

    return 'Boa noite';
  }

  String _periodTitle() {
    switch (_selectedPeriod) {
      case 'Semana':
        return 'Gasto nos últimos 7 dias';

      case 'Mês':
        return 'Gasto neste mês';

      case 'Hoje':
      default:
        return 'Gasto hoje';
    }
  }

  String _comparisonPeriodLabel() {
    switch (_selectedPeriod) {
      case 'Semana':
        return 'os 7 dias anteriores';

      case 'Mês':
        return 'o mês anterior no mesmo período';

      case 'Hoje':
      default:
        return 'ontem até ${DateFormat('HH:mm').format(DateTime.now())}';
    }
  }

  String _recentExpensesTitle() {
    switch (_selectedPeriod) {
      case 'Semana':
        return 'Últimos gastos da semana';

      case 'Mês':
        return 'Últimos gastos do mês';

      case 'Hoje':
      default:
        return 'Últimos gastos de hoje';
    }
  }

  void _openAddExpense() {
    AddExpenseModal.show(context);
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
                    width: 64,
                    height: 64,
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
                  label: 'Data',
                  value: _formatFullDate(expense.date),
                ),
                if (expense.description != null &&
                    expense.description!.trim().isNotEmpty)
                  _ExpenseDetailRow(
                    icon: Icons.edit_note_rounded,
                    label: 'Descrição',
                    value: expense.description!.trim(),
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
            'O gasto de ${_currencyFormatter.format(expense.amount)} '
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
          content: const Text('Gasto excluído.'),
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
      return DateFormat("dd MMM, HH:mm", 'pt_BR').format(date);
    }

    return DateFormat("dd MMM yyyy, HH:mm", 'pt_BR').format(date);
  }

  String _formatFullDate(DateTime date) {
    return DateFormat("dd 'de' MMMM 'de' yyyy, HH:mm", 'pt_BR').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color primaryColor = theme.colorScheme.primary;

    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: primaryColor));
    }

    if (_errorMessage != null) {
      return _ErrorState(message: _errorMessage!, onRetry: _loadData);
    }

    final double rawLimitProgress = _monthlyLimit > 0
        ? _monthTotal / _monthlyLimit
        : 0;

    final double indicatorProgress = rawLimitProgress.clamp(0.0, 1.0);

    final _LimitStatus limitStatus = _getLimitStatus(
      rawLimitProgress,
      primaryColor,
    );

    final double limitDifference = _monthlyLimit - _monthTotal;

    final bool isOverLimit = limitDifference < 0;

    final String limitMainText = isOverLimit
        ? '${_currencyFormatter.format(limitDifference.abs())} '
              'acima do limite'
        : '${_currencyFormatter.format(limitDifference)} '
              'disponíveis';

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
          _buildPeriodSelector(theme),
          const SizedBox(height: AppSpacing.xl),
          _buildSummaryCard(theme),
          const SizedBox(height: AppSpacing.xxl),
          _buildMonthlyLimit(
            theme: theme,
            mainText: limitMainText,
            rawProgress: rawLimitProgress,
            indicatorProgress: indicatorProgress,
            status: limitStatus,
            isOverLimit: isOverLimit,
          ),
          const SizedBox(height: AppSpacing.xxl),
          _buildRecentExpenses(theme),
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
              Text(
                _userName.isEmpty
                    ? '${_greeting()}! 👋'
                    : '${_greeting()}, $_userName! 👋',
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                'Aqui está seu resumo financeiro.',
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPeriodSelector(ThemeData theme) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xs,
      children: _periods
          .map((String period) {
            final bool selected = _selectedPeriod == period;

            return ChoiceChip(
              label: Text(period),
              selected: selected,
              showCheckmark: false,
              onSelected: (_) {
                _selectPeriod(period);
              },
              labelStyle: theme.textTheme.labelMedium?.copyWith(
                color: selected
                    ? theme.colorScheme.primary
                    : AppColors.textSecondary(context),
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            );
          })
          .toList(growable: false),
    );
  }

  Widget _buildSummaryCard(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    _periodTitle(),
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xxs,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSecondary(context),
                    borderRadius: BorderRadius.circular(
                      AppSpacing.buttonRadius,
                    ),
                  ),
                  child: Text(
                    '$_periodCount '
                    '${_periodCount == 1 ? 'registro' : 'registros'}',
                    style: theme.textTheme.labelSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                _currencyFormatter.format(_periodTotal),
                style: theme.textTheme.displaySmall,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _buildComparison(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildComparison(ThemeData theme) {
    if (_previousPeriodTotal <= 0) {
      final String message = _periodTotal <= 0
          ? 'Ainda não há gastos para comparar.'
          : 'Não há registros em ${_comparisonPeriodLabel()}.';

      return Row(
        children: <Widget>[
          Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: AppColors.textMuted(context),
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(child: Text(message, style: theme.textTheme.bodySmall)),
        ],
      );
    }

    final double difference = _periodTotal - _previousPeriodTotal;

    final double percentage = (difference.abs() / _previousPeriodTotal) * 100;

    final bool spentLess = difference < 0;
    final bool spentMore = difference > 0;

    final Color comparisonColor;

    final IconData comparisonIcon;

    final String comparisonText;

    if (!spentLess && !spentMore) {
      comparisonColor = AppColors.information;
      comparisonIcon = Icons.horizontal_rule_rounded;
      comparisonText = 'Mesmo valor de ${_comparisonPeriodLabel()}.';
    } else if (spentLess) {
      comparisonColor = AppColors.success;
      comparisonIcon = Icons.trending_down_rounded;
      comparisonText =
          '${percentage.toStringAsFixed(0)}% abaixo de '
          '${_comparisonPeriodLabel()}.';
    } else {
      comparisonColor = AppColors.warning;
      comparisonIcon = Icons.trending_up_rounded;
      comparisonText =
          '${percentage.toStringAsFixed(0)}% acima de '
          '${_comparisonPeriodLabel()}.';
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: comparisonColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
      ),
      child: Row(
        children: <Widget>[
          Icon(comparisonIcon, size: 19, color: comparisonColor),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              comparisonText,
              style: theme.textTheme.bodySmall?.copyWith(
                color: comparisonColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyLimit({
    required ThemeData theme,
    required String mainText,
    required double rawProgress,
    required double indicatorProgress,
    required _LimitStatus status,
    required bool isOverLimit,
  }) {
    final int percentage = (rawProgress * 100).round();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'Limite mensal',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                Icon(status.icon, color: status.color),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              mainText,
              style: theme.textTheme.titleLarge?.copyWith(
                color: isOverLimit
                    ? AppColors.error
                    : AppColors.textPrimary(context),
              ),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              'de um limite de '
              '${_currencyFormatter.format(_monthlyLimit)}',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: <Widget>[
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: indicatorProgress,
                      minHeight: 9,
                      backgroundColor: AppColors.surfaceSecondary(context),
                      valueColor: AlwaysStoppedAnimation<Color>(status.color),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Text(
                  '$percentage%',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: status.color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: status.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
              ),
              child: Row(
                children: <Widget>[
                  Icon(status.icon, size: 18, color: status.color),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      status.text,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: status.color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentExpenses(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(_recentExpensesTitle(), style: theme.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.md),
        if (_recentExpenses.isEmpty)
          _EmptyExpensesState(
            selectedPeriod: _selectedPeriod,
            onAddExpense: _openAddExpense,
          )
        else
          ..._recentExpenses.map((Expense expense) {
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _ExpenseCard(
                expense: expense,
                formattedAmount: _currencyFormatter.format(expense.amount),
                formattedDate: _formatExpenseDate(expense.date),
                onTap: () {
                  _showExpenseDetails(expense);
                },
              ),
            );
          }),
      ],
    );
  }

  _LimitStatus _getLimitStatus(double progress, Color primaryColor) {
    if (progress < 0.70) {
      return _LimitStatus(
        color: primaryColor,
        icon: Icons.check_circle_outline_rounded,
        text: 'Situação normal.',
      );
    }

    if (progress < 0.90) {
      return const _LimitStatus(
        color: AppColors.warning,
        icon: Icons.info_outline_rounded,
        text: 'Atenção: você já utilizou mais de 70% do limite.',
      );
    }

    if (progress < 1) {
      return const _LimitStatus(
        color: AppColors.error,
        icon: Icons.warning_amber_rounded,
        text: 'Alerta: você está próximo de atingir o limite.',
      );
    }

    if (progress == 1) {
      return const _LimitStatus(
        color: AppColors.error,
        icon: Icons.error_outline_rounded,
        text: 'Limite mensal atingido.',
      );
    }

    return const _LimitStatus(
      color: AppColors.error,
      icon: Icons.error_outline_rounded,
      text: 'Limite mensal excedido.',
    );
  }
}

class _ExpenseCard extends StatelessWidget {
  const _ExpenseCard({
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
                      description.isEmpty ? expense.categoryName : description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      description.isEmpty
                          ? formattedDate
                          : '${expense.categoryName} • $formattedDate',
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

class _EmptyExpensesState extends StatelessWidget {
  const _EmptyExpensesState({
    required this.selectedPeriod,
    required this.onAddExpense,
  });

  final String selectedPeriod;
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
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.receipt_long_outlined,
                color: theme.colorScheme.primary,
                size: 30,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Nenhum gasto em ${selectedPeriod.toLowerCase()}.',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Registre seu primeiro gasto para acompanhar '
              'seu resumo financeiro.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: onAddExpense,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Registrar gasto'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

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
              size: 48,
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

class _LimitStatus {
  const _LimitStatus({
    required this.color,
    required this.icon,
    required this.text,
  });

  final Color color;
  final IconData icon;
  final String text;
}
