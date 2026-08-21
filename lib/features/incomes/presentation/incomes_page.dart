import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/currency_input_formatter.dart';
import '../../../core/utils/financial_plan_notifier.dart';
import '../../planning/data/monthly_plan_repository.dart';
import '../../planning/domain/monthly_plan.dart';
import '../data/income_repository.dart';
import '../domain/income.dart';

class IncomesPage extends StatefulWidget {
  const IncomesPage({super.key, this.initialMonth});

  final DateTime? initialMonth;

  @override
  State<IncomesPage> createState() => _IncomesPageState();
}

class _IncomesPageState extends State<IncomesPage> {
  final IncomeRepository _repository = IncomeRepository();
  final MonthlyPlanRepository _planRepository = MonthlyPlanRepository();
  final NumberFormat _currency = NumberFormat.currency(
    locale: 'pt_BR',
    symbol: 'R\$',
  );

  late DateTime _selectedMonth;
  List<Income> _incomes = <Income>[];
  MonthlyPlan? _plan;
  MonthlyPlan? _previousPlanSuggestion;
  bool _isLoading = true;
  String? _errorMessage;

  int get _totalCents => _incomes.fold<int>(
    0,
    (int total, Income income) => total + income.amountCents,
  );

  @override
  void initState() {
    super.initState();
    final DateTime initialMonth = widget.initialMonth ?? DateTime.now();
    _selectedMonth = DateTime(initialMonth.year, initialMonth.month);
    _loadIncomes();
  }

  Future<void> _loadIncomes() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final List<Income> incomes = await _repository.getIncomesForMonth(
        _selectedMonth,
      );
      final MonthlyPlan? plan = await _planRepository.getPlanForMonth(
        _selectedMonth,
      );
      final MonthlyPlan? previousPlan = plan == null
          ? await _planRepository.getPlanForMonth(
              DateTime(_selectedMonth.year, _selectedMonth.month - 1),
            )
          : null;
      if (!mounted) return;
      setState(() {
        _incomes = incomes;
        _plan = plan;
        _previousPlanSuggestion = previousPlan;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Não foi possível carregar as rendas.';
      });
    }
  }

  void _changeMonth(int offset) {
    setState(() {
      _selectedMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month + offset,
      );
    });
    _loadIncomes();
  }

  Future<void> _openForm([Income? income]) async {
    final bool changed = await IncomeFormSheet.show(
      context,
      repository: _repository,
      initialMonth: _selectedMonth,
      income: income,
    );
    if (changed) {
      notifyFinancialPlanChanged();
      await _loadIncomes();
    }
  }

  Future<void> _deleteIncome(Income income) async {
    final bool confirmed =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) {
            return AlertDialog(
              icon: const Icon(
                Icons.delete_outline_rounded,
                color: AppColors.error,
              ),
              title: const Text('Excluir renda?'),
              content: Text(
                income.recurrence == IncomeRecurrence.monthly
                    ? 'A renda mensal “${income.source}” deixará de aparecer em todos os meses.'
                    : 'A renda “${income.source}” será excluída deste mês.',
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Excluir'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!confirmed) return;

    try {
      await _repository.deleteIncome(income.id);
      notifyFinancialPlanChanged();
      await _loadIncomes();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível excluir a renda.')),
      );
    }
  }

  Future<void> _editLimit() async {
    final TextEditingController controller = TextEditingController(
      text: _plan == null
          ? ''
          : NumberFormat.currency(
              locale: 'pt_BR',
              symbol: '',
            ).format(_plan!.spendingLimit).trim(),
    );
    String? errorMessage;

    final int? cents = await showDialog<int>(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            void submit() {
              final int value =
                  int.tryParse(
                    controller.text.replaceAll(RegExp(r'[^0-9]'), ''),
                  ) ??
                  0;
              if (value <= 0) {
                setDialogState(() {
                  errorMessage = 'Digite um valor maior que zero.';
                });
                return;
              }
              Navigator.pop(dialogContext, value);
            }

            return AlertDialog(
              title: const Text('Limite do mês'),
              content: TextField(
                controller: controller,
                autofocus: true,
                keyboardType: TextInputType.number,
                inputFormatters: <TextInputFormatter>[
                  CurrencyInputFormatter(
                    maximumValueInCents:
                        _IncomeFormSheetState._maximumAmountInCents,
                  ),
                ],
                decoration: InputDecoration(
                  labelText: 'Quanto você planeja gastar?',
                  prefixText: 'R\$ ',
                  errorText: errorMessage,
                ),
                onSubmitted: (_) => submit(),
              ),
              actions: <Widget>[
                if (_plan != null)
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext, 0),
                    child: const Text('Remover limite'),
                  ),
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancelar'),
                ),
                FilledButton(onPressed: submit, child: const Text('Salvar')),
              ],
            );
          },
        );
      },
    );
    controller.dispose();

    if (cents == null) return;
    if (cents == 0) {
      await _planRepository.deletePlanForMonth(_selectedMonth);
    } else {
      await _planRepository.saveLimit(
        month: _selectedMonth,
        spendingLimitCents: cents,
      );
    }
    notifyFinancialPlanChanged();
    await _loadIncomes();
  }

  Future<void> _applyPreviousLimit() async {
    final MonthlyPlan? suggestion = _previousPlanSuggestion;
    if (suggestion == null) {
      return;
    }

    await _planRepository.saveLimit(
      month: _selectedMonth,
      spendingLimitCents: suggestion.spendingLimitCents,
    );
    notifyFinancialPlanChanged();
    await _loadIncomes();

    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Limite anterior aplicado a este mês.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String monthLabel = DateFormat(
      "MMMM 'de' yyyy",
      'pt_BR',
    ).format(_selectedMonth);

    return Scaffold(
      appBar: AppBar(title: const Text('Rendas')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openForm,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Adicionar renda'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadIncomes,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            AppSpacing.pageHorizontal,
            AppSpacing.md,
            AppSpacing.pageHorizontal,
            MediaQuery.paddingOf(context).bottom + 104,
          ),
          children: <Widget>[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        IconButton(
                          tooltip: 'Mês anterior',
                          onPressed: () => _changeMonth(-1),
                          icon: const Icon(Icons.chevron_left_rounded),
                        ),
                        Expanded(
                          child: Text(
                            toBeginningOfSentenceCase(monthLabel),
                            textAlign: TextAlign.center,
                            style: theme.textTheme.titleMedium,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Próximo mês',
                          onPressed: () => _changeMonth(1),
                          icon: const Icon(Icons.chevron_right_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Renda total planejada',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      _currency.format(_totalCents / 100),
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    const Divider(),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                'Limite de gastos',
                                style: theme.textTheme.bodySmall,
                              ),
                              const SizedBox(height: AppSpacing.xxs),
                              Text(
                                _plan == null
                                    ? 'Não definido'
                                    : _currency.format(_plan!.spendingLimit),
                                style: theme.textTheme.titleMedium,
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: _editLimit,
                          child: Text(_plan == null ? 'Definir' : 'Alterar'),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Valores informados manualmente, sem conexão bancária.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textMuted(context),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_plan == null && _previousPlanSuggestion != null) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.all(AppSpacing.md),
                  leading: CircleAvatar(
                    backgroundColor: AppColors.informationSoft,
                    foregroundColor: AppColors.information,
                    child: const Icon(Icons.lightbulb_outline_rounded),
                  ),
                  title: const Text('Usar o limite do mês anterior?'),
                  subtitle: Text(
                    '${_currency.format(_previousPlanSuggestion!.spendingLimit)} como ponto de partida. Nada será alterado sem sua confirmação.',
                  ),
                  trailing: TextButton(
                    onPressed: _applyPreviousLimit,
                    child: const Text('Usar'),
                  ),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            Text('Fontes de renda', style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.md),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(AppSpacing.xxl),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_errorMessage != null)
              _IncomeMessage(
                icon: Icons.error_outline_rounded,
                message: _errorMessage!,
                actionLabel: 'Tentar novamente',
                onAction: _loadIncomes,
              )
            else if (_incomes.isEmpty)
              _IncomeMessage(
                icon: Icons.account_balance_wallet_outlined,
                message:
                    'Nenhuma renda cadastrada para este mês. O controle de gastos continua funcionando normalmente.',
                actionLabel: 'Cadastrar renda',
                onAction: _openForm,
              )
            else
              ..._incomes.map((Income income) {
                final String dateLabel =
                    income.recurrence == IncomeRecurrence.monthly
                    ? 'Mensal desde ${DateFormat('MM/yyyy').format(income.date)}'
                    : DateFormat("dd 'de' MMMM", 'pt_BR').format(income.date);

                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Card(
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.xs,
                      ),
                      leading: CircleAvatar(
                        backgroundColor: theme.colorScheme.primary.withValues(
                          alpha: 0.12,
                        ),
                        foregroundColor: theme.colorScheme.primary,
                        child: const Icon(Icons.payments_outlined),
                      ),
                      title: Text(income.source),
                      subtitle: Text(dateLabel),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: <Widget>[
                          Text(
                            _currency.format(income.amount),
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          PopupMenuButton<String>(
                            padding: EdgeInsets.zero,
                            tooltip: 'Opções da renda',
                            onSelected: (String value) {
                              if (value == 'edit') {
                                _openForm(income);
                              } else {
                                _deleteIncome(income);
                              }
                            },
                            itemBuilder: (_) => const <PopupMenuEntry<String>>[
                              PopupMenuItem<String>(
                                value: 'edit',
                                child: Text('Editar'),
                              ),
                              PopupMenuItem<String>(
                                value: 'delete',
                                child: Text('Excluir'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class IncomeFormSheet extends StatefulWidget {
  const IncomeFormSheet({
    super.key,
    required this.repository,
    required this.initialMonth,
    this.income,
  });

  final IncomeRepository repository;
  final DateTime initialMonth;
  final Income? income;

  static Future<bool> show(
    BuildContext context, {
    required IncomeRepository repository,
    required DateTime initialMonth,
    Income? income,
  }) async {
    return await showModalBottomSheet<bool>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          builder: (BuildContext context) => IncomeFormSheet(
            repository: repository,
            initialMonth: initialMonth,
            income: income,
          ),
        ) ??
        false;
  }

  @override
  State<IncomeFormSheet> createState() => _IncomeFormSheetState();
}

class _IncomeFormSheetState extends State<IncomeFormSheet> {
  static const int _maximumAmountInCents = 999999999;
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _sourceController = TextEditingController();
  int _amountCents = 0;
  late DateTime _selectedDate;
  bool _isMonthly = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final Income? income = widget.income;
    _selectedDate =
        income?.date ??
        DateTime(
          widget.initialMonth.year,
          widget.initialMonth.month,
          DateTime.now().day.clamp(1, 28),
        );
    _sourceController.text = income?.source ?? '';
    _amountCents = income?.amountCents ?? 0;
    _isMonthly = income?.recurrence == IncomeRecurrence.monthly;
    if (_amountCents > 0) {
      _amountController.text = NumberFormat.currency(
        locale: 'pt_BR',
        symbol: '',
      ).format(_amountCents / 100).trim();
    }
    _amountController.addListener(_readAmount);
  }

  @override
  void dispose() {
    _amountController.removeListener(_readAmount);
    _amountController.dispose();
    _sourceController.dispose();
    super.dispose();
  }

  void _readAmount() {
    final int value =
        int.tryParse(
          _amountController.text.replaceAll(RegExp(r'[^0-9]'), ''),
        ) ??
        0;
    if (value != _amountCents && mounted) {
      setState(() => _amountCents = value);
    }
  }

  Future<void> _pickDate() async {
    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(DateTime.now().year + 20, 12, 31),
      helpText: 'Selecionar data da renda',
    );
    if (date != null && mounted) setState(() => _selectedDate = date);
  }

  Future<void> _save() async {
    final String source = _sourceController.text.trim();
    if (_amountCents <= 0 || source.isEmpty || _isSaving) return;
    setState(() => _isSaving = true);

    try {
      final DateTime now = DateTime.now();
      final Income? original = widget.income;
      final Income income = original == null
          ? Income(
              id: const Uuid().v4(),
              amountCents: _amountCents,
              source: source,
              date: _selectedDate,
              recurrence: _isMonthly
                  ? IncomeRecurrence.monthly
                  : IncomeRecurrence.none,
              createdAt: now,
              updatedAt: now,
            )
          : original.copyWith(
              amountCents: _amountCents,
              source: source,
              date: _selectedDate,
              recurrence: _isMonthly
                  ? IncomeRecurrence.monthly
                  : IncomeRecurrence.none,
              updatedAt: now,
            );

      if (original == null) {
        await widget.repository.insertIncome(income);
      } else {
        await widget.repository.updateIncome(income);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível salvar a renda.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool canSave =
        !_isSaving &&
        _amountCents > 0 &&
        _sourceController.text.trim().isNotEmpty;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.lg,
          AppSpacing.xl,
          AppSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              widget.income == null ? 'Adicionar renda' : 'Editar renda',
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.xl),
            TextField(
              controller: _amountController,
              autofocus: widget.income == null,
              keyboardType: TextInputType.number,
              inputFormatters: <TextInputFormatter>[
                CurrencyInputFormatter(
                  maximumValueInCents: _maximumAmountInCents,
                ),
              ],
              decoration: const InputDecoration(
                labelText: 'Valor',
                prefixText: 'R\$ ',
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _sourceController,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Fonte ou descrição',
                hintText: 'Ex.: Salário, trabalho extra',
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today_outlined),
              title: const Text('Data de início'),
              subtitle: Text(
                DateFormat(
                  "dd 'de' MMMM 'de' yyyy",
                  'pt_BR',
                ).format(_selectedDate),
              ),
              onTap: _pickDate,
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Repetir mensalmente'),
              subtitle: const Text(
                'A renda será considerada a partir do mês selecionado.',
              ),
              value: _isMonthly,
              onChanged: (bool value) => setState(() => _isMonthly = value),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              onPressed: canSave ? _save : null,
              child: Text(_isSaving ? 'Salvando...' : 'Salvar renda'),
            ),
          ],
        ),
      ),
    );
  }
}

class _IncomeMessage extends StatelessWidget {
  const _IncomeMessage({
    required this.icon,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          children: <Widget>[
            Icon(icon, size: 40, color: AppColors.textMuted(context)),
            const SizedBox(height: AppSpacing.md),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton(onPressed: onAction, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}
