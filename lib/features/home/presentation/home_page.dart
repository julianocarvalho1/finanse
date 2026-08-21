import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finanse/core/theme/app_colors.dart';
import 'package:finanse/core/theme/app_spacing.dart';
import 'package:finanse/core/utils/category_style.dart';
import 'package:finanse/core/utils/expense_notifier.dart';
import 'package:finanse/core/utils/financial_plan_notifier.dart';
import 'package:finanse/features/expenses/data/expense_repository.dart';
import 'package:finanse/features/expenses/domain/expense.dart';
import 'package:finanse/features/expenses/presentation/widgets/add_expense_modal.dart';
import 'package:finanse/features/incomes/data/income_repository.dart';
import 'package:finanse/features/incomes/presentation/incomes_page.dart';
import 'package:finanse/features/planning/data/monthly_plan_repository.dart';
import 'package:finanse/features/planning/domain/monthly_financial_summary.dart';
import 'package:finanse/features/planning/domain/monthly_plan.dart';
import 'package:finanse/features/reserve/data/reserve_repository.dart';
import 'package:finanse/features/reserve/domain/reserve_transaction.dart';
import 'package:finanse/features/reserve/presentation/reserve_history_page.dart';

enum _ReserveAction { add, withdraw, adjust, history }

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const List<String> _periods = <String>['Hoje', 'Semana', 'Mês'];

  final ExpenseRepository _repository = ExpenseRepository();
  final ReserveRepository _reserveRepository = ReserveRepository();
  final IncomeRepository _incomeRepository = IncomeRepository();
  final MonthlyPlanRepository _monthlyPlanRepository = MonthlyPlanRepository();

  late final NumberFormat _currencyFormatter;

  String _selectedPeriod = 'Hoje';
  String _userName = '';

  double _periodTotal = 0;
  double _previousPeriodTotal = 0;
  double _monthTotal = 0;
  double? _monthlyLimit;
  int _monthlyIncomeCents = 0;
  int _allocatedFromResultCents = 0;
  double _savingsReserve = 0;

  bool _showSavingsReserve = false;

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
    financialPlanNotifier.addListener(_handleFinancialPlanChanged);
    _loadData();
  }

  @override
  void dispose() {
    expenseNotifier.removeListener(_handleExpensesChanged);
    financialPlanNotifier.removeListener(_handleFinancialPlanChanged);
    super.dispose();
  }

  void _handleExpensesChanged() {
    _loadData(showLoading: false);
  }

  void _handleFinancialPlanChanged() {
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

      final double? savedLimit = preferences.getDouble('monthlyLimit');

      final DateTime currentMonth = DateTime.now();
      final monthlyPlan = await _monthlyPlanRepository.migrateLegacyLimit(
        month: currentMonth,
        legacyLimit: savedLimit,
      );
      if (savedLimit != null) {
        await preferences.remove('monthlyLimit');
      }

      final int monthlyIncomeCents = await _incomeRepository
          .getTotalCentsForMonth(currentMonth);
      final int allocatedFromResultCents = await _reserveRepository
          .getAllocatedCentsForMonth(MonthlyPlan.keyFor(currentMonth));

      final double legacyReserve = preferences.getDouble('savingsReserve') ?? 0;

      await _reserveRepository.migrateLegacyBalance(legacyReserve);
      final double savedReserve = await _reserveRepository.getCurrentBalance();

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
        _monthlyLimit = monthlyPlan?.spendingLimit;
        _monthlyIncomeCents = monthlyIncomeCents;
        _allocatedFromResultCents = allocatedFromResultCents;
        _savingsReserve = savedReserve >= 0 ? savedReserve : 0;
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

  double? _parseCurrencyInput(String input) {
    String normalized = input.trim().replaceAll('R\$', '').replaceAll(' ', '');

    if (normalized.isEmpty) {
      return null;
    }

    if (normalized.contains(',')) {
      normalized = normalized.replaceAll('.', '').replaceAll(',', '.');
    } else if ('.'.allMatches(normalized).length > 1) {
      normalized = normalized.replaceAll('.', '');
    }

    return double.tryParse(normalized);
  }

  Future<double?> _requestReserveValue({
    required String title,
    required String description,
    required String buttonLabel,
    required bool allowZero,
    double? initialValue,
  }) {
    String inputValue = initialValue == null
        ? ''
        : initialValue.toStringAsFixed(2).replaceAll('.', ',');

    String? errorMessage;

    return showDialog<double>(
      context: context,
      builder: (BuildContext dialogContext) {
        final ThemeData theme = Theme.of(dialogContext);

        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            void submitValue() {
              final double? value = _parseCurrencyInput(inputValue);

              final bool isInvalid =
                  value == null || (allowZero ? value < 0 : value <= 0);

              if (isInvalid) {
                setDialogState(() {
                  errorMessage = allowZero
                      ? 'Digite um valor válido.'
                      : 'Digite um valor maior que zero.';
                });
                return;
              }

              Navigator.of(dialogContext).pop(value);
            }

            return AlertDialog(
              title: Text(title),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(description, style: theme.textTheme.bodyMedium),
                  const SizedBox(height: AppSpacing.lg),
                  TextFormField(
                    initialValue: inputValue,
                    autofocus: true,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: <TextInputFormatter>[
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]')),
                    ],
                    decoration: InputDecoration(
                      prefixText: 'R\$ ',
                      hintText: '0,00',
                      errorText: errorMessage,
                    ),
                    onChanged: (String value) {
                      inputValue = value;

                      if (errorMessage != null) {
                        setDialogState(() {
                          errorMessage = null;
                        });
                      }
                    },
                    onFieldSubmitted: (_) {
                      submitValue();
                    },
                  ),
                ],
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                  },
                  child: const Text('Cancelar'),
                ),
                FilledButton(onPressed: submitValue, child: Text(buttonLabel)),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _defineMonthlyLimit() async {
    final double? newLimit = await _requestReserveValue(
      title: _monthlyLimit == null
          ? 'Definir limite mensal'
          : 'Alterar limite mensal',
      description: 'Informe o valor máximo que você planeja gastar por mês.',
      buttonLabel: 'Salvar limite',
      allowZero: false,
      initialValue: _monthlyLimit,
    );

    if (newLimit == null) {
      return;
    }

    await _monthlyPlanRepository.saveLimit(
      month: DateTime.now(),
      spendingLimitCents: (newLimit * 100).round(),
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _monthlyLimit = newLimit;
    });

    notifyFinancialPlanChanged();
  }

  Future<void> _persistReserveBalance(double value) async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    await preferences.setDouble('savingsReserve', value);

    if (!mounted) {
      return;
    }

    setState(() {
      _savingsReserve = value;
    });
  }

  Future<void> _addToReserve() async {
    final double? amount = await _requestReserveValue(
      title: 'Adicionar à reserva',
      description:
          'Informe quanto você guardou. O valor será somado ao total atual.',
      buttonLabel: 'Adicionar',
      allowZero: false,
    );

    if (amount == null) {
      return;
    }

    late final ReserveTransaction transaction;

    try {
      transaction = await _reserveRepository.addAmount(amount);
      await _persistReserveBalance(transaction.balanceAfter);
    } catch (_) {
      if (mounted) {
        _showErrorMessage('Não foi possível adicionar o valor à reserva.');
      }
      return;
    }

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${_currencyFormatter.format(amount)} adicionado à sua reserva.',
        ),
      ),
    );
  }

  Future<void> _withdrawFromReserve() async {
    final double? amount = await _requestReserveValue(
      title: 'Retirar da reserva',
      description:
          'Informe quanto foi retirado. O valor não pode ser maior que o saldo atual.',
      buttonLabel: 'Retirar',
      allowZero: false,
    );

    if (amount == null) {
      return;
    }

    if (amount > _savingsReserve) {
      _showErrorMessage('O valor informado é maior que a sua reserva atual.');
      return;
    }

    late final ReserveTransaction transaction;

    try {
      transaction = await _reserveRepository.withdrawAmount(amount);
      await _persistReserveBalance(transaction.balanceAfter);
    } catch (_) {
      if (mounted) {
        _showErrorMessage('Não foi possível registrar a retirada.');
      }
      return;
    }

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${_currencyFormatter.format(amount)} retirado da sua reserva.',
        ),
      ),
    );
  }

  Future<void> _adjustReserve() async {
    final double? newTotal = await _requestReserveValue(
      title: 'Ajustar reserva',
      description:
          'Informe o valor total aproximado que você possui guardado agora.',
      buttonLabel: 'Salvar',
      allowZero: true,
      initialValue: _savingsReserve,
    );

    if (newTotal == null || newTotal == _savingsReserve) {
      return;
    }

    late final ReserveTransaction transaction;

    try {
      transaction = await _reserveRepository.adjustBalance(newTotal);
      await _persistReserveBalance(transaction.balanceAfter);
    } catch (_) {
      if (mounted) {
        _showErrorMessage('Não foi possível ajustar a reserva.');
      }
      return;
    }

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Valor da reserva atualizado.')),
    );
  }

  Future<void> _openReserveHistory() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) {
          return const ReserveHistoryPage();
        },
      ),
    );

    if (mounted) {
      await _loadData(showLoading: false);
    }
  }

  Future<void> _openReserveActions() async {
    HapticFeedback.selectionClick();

    final _ReserveAction? action = await showModalBottomSheet<_ReserveAction>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext sheetContext) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Minha reserva',
                  style: Theme.of(sheetContext).textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Registre as movimentações sem misturar a reserva com os gastos mensais.',
                  style: Theme.of(sheetContext).textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.md),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.add_circle_outline_rounded),
                  title: const Text('Adicionar valor'),
                  subtitle: const Text('Somar um novo valor ao total guardado'),
                  onTap: () {
                    Navigator.of(sheetContext).pop(_ReserveAction.add);
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.remove_circle_outline_rounded),
                  title: const Text('Retirar valor'),
                  subtitle: Text(
                    _savingsReserve > 0
                        ? 'Registrar uma retirada da reserva'
                        : 'Não há saldo disponível para retirar',
                  ),
                  enabled: _savingsReserve > 0,
                  onTap: _savingsReserve > 0
                      ? () {
                          Navigator.of(
                            sheetContext,
                          ).pop(_ReserveAction.withdraw);
                        }
                      : null,
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.tune_rounded),
                  title: const Text('Ajustar total'),
                  subtitle: const Text('Corrigir o valor atual da reserva'),
                  onTap: () {
                    Navigator.of(sheetContext).pop(_ReserveAction.adjust);
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.history_rounded),
                  title: const Text('Ver histórico'),
                  subtitle: const Text(
                    'Consultar adições, retiradas e ajustes',
                  ),
                  onTap: () {
                    Navigator.of(sheetContext).pop(_ReserveAction.history);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted || action == null) {
      return;
    }

    switch (action) {
      case _ReserveAction.add:
        await _addToReserve();
        break;
      case _ReserveAction.withdraw:
        await _withdrawFromReserve();
        break;
      case _ReserveAction.adjust:
        await _adjustReserve();
        break;
      case _ReserveAction.history:
        await _openReserveHistory();
        break;
    }
  }

  Future<void> _openIncomes() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const IncomesPage()));
    if (mounted) {
      await _loadData(showLoading: false);
    }
  }

  Future<void> _allocateResultToReserve(int availableResultCents) async {
    if (availableResultCents <= 0) {
      return;
    }

    final double? amount = await _requestReserveValue(
      title: 'Destinar para a reserva',
      description:
          'Este registro não será contado como gasto. Ele apenas indica quanto do resultado do mês foi guardado.',
      buttonLabel: 'Destinar',
      allowZero: false,
      initialValue: availableResultCents / 100,
    );

    if (amount == null || !mounted) {
      return;
    }

    final int amountCents = (amount * 100).round();
    if (amountCents > availableResultCents) {
      final bool confirmed =
          await showDialog<bool>(
            context: context,
            builder: (BuildContext dialogContext) {
              return AlertDialog(
                icon: const Icon(
                  Icons.warning_amber_rounded,
                  color: AppColors.warning,
                ),
                title: const Text('Valor acima do resultado disponível'),
                content: Text(
                  'O resultado ainda disponível é ${_currencyFormatter.format(availableResultCents / 100)}. Deseja registrar mesmo assim?',
                ),
                actions: <Widget>[
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: const Text('Voltar'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(dialogContext, true),
                    child: const Text('Confirmar'),
                  ),
                ],
              );
            },
          ) ??
          false;
      if (!confirmed) {
        return;
      }
    }

    try {
      final DateTime now = DateTime.now();
      final ReserveTransaction transaction = await _reserveRepository.addAmount(
        amount,
        note: 'Destinação do resultado de ${MonthlyPlan.keyFor(now)}.',
        originYearMonth: MonthlyPlan.keyFor(now),
      );
      await _persistReserveBalance(transaction.balanceAfter);
      notifyFinancialPlanChanged();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Valor destinado à reserva sem alterar os gastos do mês.',
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        _showErrorMessage('Não foi possível registrar a destinação.');
      }
    }
  }

  Widget _buildFinancialOverview(
    ThemeData theme,
    MonthlyFinancialSummary summary,
  ) {
    final int? resultCents = summary.currentResultCents;
    final int availableForReserveCents = resultCents == null || resultCents <= 0
        ? 0
        : (resultCents - _allocatedFromResultCents).clamp(0, resultCents);

    final (Color, IconData, String) status = switch (summary.status) {
      MonthlyFinancialStatus.positive => (
        AppColors.success,
        Icons.trending_up_rounded,
        'Resultado positivo neste mês.',
      ),
      MonthlyFinancialStatus.attention => (
        AppColors.warning,
        Icons.info_outline_rounded,
        'Atenção ao uso do limite deste mês.',
      ),
      MonthlyFinancialStatus.limitExceeded => (
        AppColors.error,
        Icons.speed_rounded,
        'O limite mensal foi excedido.',
      ),
      MonthlyFinancialStatus.deficit => (
        AppColors.error,
        Icons.trending_down_rounded,
        'As despesas registradas superam a renda.',
      ),
      MonthlyFinancialStatus.neutral => (
        theme.colorScheme.primary,
        Icons.insights_outlined,
        'Cadastre sua renda para completar o planejamento.',
      ),
    };

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
                    'Planejamento do mês',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                TextButton.icon(
                  onPressed: _openIncomes,
                  icon: const Icon(Icons.payments_outlined, size: 19),
                  label: Text(summary.hasIncome ? 'Rendas' : 'Cadastrar renda'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            _FinancialValueRow(
              label: 'Renda total',
              value: summary.hasIncome
                  ? _currencyFormatter.format(summary.incomeTotalCents / 100)
                  : 'Não cadastrada',
            ),
            _FinancialValueRow(
              label: 'Limite definido',
              value: summary.hasLimit
                  ? _currencyFormatter.format(summary.spendingLimitCents! / 100)
                  : 'Não definido',
            ),
            _FinancialValueRow(
              label: 'Gastos realizados',
              value: _currencyFormatter.format(summary.spentCents / 100),
            ),
            if (summary.hasLimit)
              _FinancialValueRow(
                label: summary.overLimitCents > 0
                    ? 'Excesso do limite'
                    : 'Disponível no limite',
                value: _currencyFormatter.format(
                  (summary.overLimitCents > 0
                          ? summary.overLimitCents
                          : summary.availableWithinLimitCents!) /
                      100,
                ),
                valueColor: summary.overLimitCents > 0 ? AppColors.error : null,
              ),
            if (summary.plannedSurplusCents != null)
              _FinancialValueRow(
                label: 'Sobra planejada',
                value: _formatSignedCurrency(summary.plannedSurplusCents!),
                valueColor: summary.plannedSurplusCents! < 0
                    ? AppColors.warning
                    : AppColors.success,
              ),
            if (resultCents != null)
              _FinancialValueRow(
                label: resultCents < 0 ? 'Déficit atual' : 'Resultado atual',
                value: _formatSignedCurrency(resultCents),
                valueColor: resultCents < 0
                    ? AppColors.error
                    : AppColors.success,
                emphasize: true,
              ),
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: status.$1.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
              ),
              child: Row(
                children: <Widget>[
                  Icon(status.$2, color: status.$1, size: 20),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      status.$3,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: status.$1,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Estimativa baseada apenas nos dados informados manualmente no Finanse.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textMuted(context),
              ),
            ),
            if (availableForReserveCents > 0) ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () =>
                      _allocateResultToReserve(availableForReserveCents),
                  icon: const Icon(Icons.savings_outlined),
                  label: Text(
                    'Destinar até ${_currencyFormatter.format(availableForReserveCents / 100)} para a reserva',
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatSignedCurrency(int cents) {
    final String formatted = _currencyFormatter.format(cents.abs() / 100);
    return cents < 0 ? '-$formatted' : formatted;
  }

  Widget _buildSavingsReserveCard(ThemeData theme) {
    final String reserveText = _showSavingsReserve
        ? _currencyFormatter.format(_savingsReserve)
        : 'R\$ •••••';

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        onTap: _openReserveActions,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
                ),
                child: Icon(
                  Icons.savings_outlined,
                  color: theme.colorScheme.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Minha reserva',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: AppColors.textSecondary(context),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 160),
                      child: Text(
                        reserveText,
                        key: ValueKey<String>(reserveText),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: _showSavingsReserve
                    ? 'Ocultar valor'
                    : 'Mostrar valor',
                onPressed: () {
                  HapticFeedback.lightImpact();

                  setState(() {
                    _showSavingsReserve = !_showSavingsReserve;
                  });
                },
                icon: Icon(
                  _showSavingsReserve
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textMuted(context),
              ),
            ],
          ),
        ),
      ),
    );
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

    final double? monthlyLimit = _monthlyLimit;
    final bool hasMonthlyLimit = monthlyLimit != null && monthlyLimit > 0;

    final double rawLimitProgress = hasMonthlyLimit
        ? _monthTotal / monthlyLimit
        : 0;

    final double indicatorProgress = rawLimitProgress.clamp(0.0, 1.0);

    final _LimitStatus limitStatus = _getLimitStatus(
      rawLimitProgress,
      primaryColor,
    );

    final double limitDifference = hasMonthlyLimit
        ? monthlyLimit - _monthTotal
        : 0;

    final bool isOverLimit = hasMonthlyLimit && limitDifference < 0;

    final MonthlyFinancialSummary financialSummary = MonthlyFinancialSummary(
      incomeTotalCents: _monthlyIncomeCents,
      spendingLimitCents: hasMonthlyLimit ? (monthlyLimit * 100).round() : null,
      spentCents: (_monthTotal * 100).round(),
    );

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
          const SizedBox(height: AppSpacing.md),
          _buildFinancialOverview(theme, financialSummary),
          const SizedBox(height: AppSpacing.md),
          _buildSavingsReserveCard(theme),
          const SizedBox(height: AppSpacing.xxl),
          if (hasMonthlyLimit)
            _buildMonthlyLimit(
              theme: theme,
              mainText: limitMainText,
              rawProgress: rawLimitProgress,
              indicatorProgress: indicatorProgress,
              status: limitStatus,
              isOverLimit: isOverLimit,
            )
          else
            _buildMonthlyLimitNotDefined(theme),
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

  Widget _buildMonthlyLimitNotDefined(ThemeData theme) {
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
                Icon(
                  Icons.track_changes_rounded,
                  color: theme.colorScheme.primary,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Limite ainda não definido',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Defina quanto você planeja gastar por mês para acompanhar o valor disponível.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary(context),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _defineMonthlyLimit,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Definir limite'),
              ),
            ),
          ],
        ),
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
                IconButton(
                  tooltip: 'Alterar limite',
                  onPressed: _defineMonthlyLimit,
                  icon: const Icon(Icons.edit_outlined),
                ),
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
              '${_currencyFormatter.format(_monthlyLimit!)}',
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

class _FinancialValueRow extends StatelessWidget {
  const _FinancialValueRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: emphasize ? FontWeight.w700 : null,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Text(
            value,
            textAlign: TextAlign.end,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: valueColor,
              fontWeight: emphasize ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ],
      ),
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
