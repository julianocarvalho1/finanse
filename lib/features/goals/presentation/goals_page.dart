import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/currency_input_formatter.dart';
import '../../../core/utils/financial_plan_notifier.dart';
import '../../expenses/data/expense_repository.dart';
import '../../incomes/data/income_repository.dart';
import '../../planning/domain/monthly_plan.dart';
import '../../reserve/data/reserve_repository.dart';
import '../data/goal_repository.dart';
import '../domain/goal_progress.dart';
import '../domain/goal_transaction.dart';
import '../domain/savings_goal.dart';

class GoalsPage extends StatefulWidget {
  const GoalsPage({super.key});

  @override
  State<GoalsPage> createState() => _GoalsPageState();
}

class _GoalsPageState extends State<GoalsPage> {
  final GoalRepository _repository = GoalRepository();
  final NumberFormat _currency = NumberFormat.currency(
    locale: 'pt_BR',
    symbol: 'R\$',
  );

  List<GoalProgress> _goals = <GoalProgress>[];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadGoals();
  }

  Future<void> _loadGoals() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }
    try {
      final List<GoalProgress> goals = await _repository.getGoalsWithProgress();
      if (!mounted) return;
      setState(() {
        _goals = goals;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Não foi possível carregar as metas.';
      });
    }
  }

  Future<void> _openGoalForm([SavingsGoal? goal]) async {
    final bool changed = await _GoalFormSheet.show(
      context,
      repository: _repository,
      goal: goal,
    );
    if (changed) {
      notifyFinancialPlanChanged();
      await _loadGoals();
    }
  }

  Future<void> _openGoal(GoalProgress progress) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) =>
            _GoalDetailsPage(goalId: progress.goal.id, repository: _repository),
      ),
    );
    await _loadGoals();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final int savedCents = _goals.fold<int>(
      0,
      (int total, GoalProgress progress) => total + progress.savedCents,
    );
    final int activeCount = _goals
        .where(
          (GoalProgress item) => item.goal.status == SavingsGoalStatus.active,
        )
        .length;

    return Scaffold(
      appBar: AppBar(title: const Text('Metas financeiras')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openGoalForm,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nova meta'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadGoals,
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
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Evolução das metas',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      _currency.format(savedCents / 100),
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '$activeCount ${activeCount == 1 ? 'meta ativa' : 'metas ativas'} · valores informados manualmente',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textMuted(context),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(AppSpacing.xxl),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_errorMessage != null)
              _GoalMessage(
                icon: Icons.error_outline_rounded,
                text: _errorMessage!,
                action: 'Tentar novamente',
                onPressed: _loadGoals,
              )
            else if (_goals.isEmpty)
              _GoalMessage(
                icon: Icons.flag_outlined,
                text:
                    'Crie uma meta para acompanhar quanto já foi destinado e quanto falta. Os aportes não entram como gastos.',
                action: 'Criar primeira meta',
                onPressed: _openGoalForm,
              )
            else
              ..._goals.map((GoalProgress progress) {
                final SavingsGoal goal = progress.goal;
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Card(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => _openGoal(progress),
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                Expanded(
                                  child: Text(
                                    goal.name,
                                    style: theme.textTheme.titleMedium,
                                  ),
                                ),
                                _GoalStatusChip(status: goal.status),
                                const SizedBox(width: AppSpacing.xs),
                                const Icon(Icons.chevron_right_rounded),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.md),
                            LinearProgressIndicator(
                              value: progress.progress,
                              minHeight: 8,
                              borderRadius: BorderRadius.circular(99),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Row(
                              children: <Widget>[
                                Expanded(
                                  child: Text(
                                    '${_currency.format(progress.savedCents / 100)} guardados',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                Text(
                                  '${(progress.progress * 100).round()}% de ${_currency.format(goal.target)}',
                                  style: theme.textTheme.bodySmall,
                                ),
                              ],
                            ),
                            if (goal.deadline != null) ...<Widget>[
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                'Prazo: ${DateFormat('dd/MM/yyyy').format(goal.deadline!)}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: AppColors.textMuted(context),
                                ),
                              ),
                            ],
                          ],
                        ),
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

class _GoalDetailsPage extends StatefulWidget {
  const _GoalDetailsPage({required this.goalId, required this.repository});

  final String goalId;
  final GoalRepository repository;

  @override
  State<_GoalDetailsPage> createState() => _GoalDetailsPageState();
}

class _GoalDetailsPageState extends State<_GoalDetailsPage> {
  final NumberFormat _currency = NumberFormat.currency(
    locale: 'pt_BR',
    symbol: 'R\$',
  );
  GoalProgress? _progress;
  List<GoalTransaction> _transactions = <GoalTransaction>[];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final GoalProgress? progress = await widget.repository.getGoalProgress(
        widget.goalId,
      );
      final List<GoalTransaction> transactions = await widget.repository
          .getTransactions(widget.goalId);
      if (!mounted) return;
      setState(() {
        _progress = progress;
        _transactions = transactions;
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<int> _availableThisMonth() async {
    final DateTime month = DateTime.now();
    final DateTime start = DateTime(month.year, month.month);
    final DateTime end = DateTime(month.year, month.month + 1);
    final List<int> values = await Future.wait<int>(<Future<int>>[
      IncomeRepository().getTotalCentsForMonth(month),
      ExpenseRepository()
          .getTotalBetween(start: start, endExclusive: end)
          .then((double value) => (value * 100).round()),
      ReserveRepository().getAllocatedCentsForMonth(MonthlyPlan.keyFor(month)),
      widget.repository.getAllocatedCentsForMonth(MonthlyPlan.keyFor(month)),
    ]);
    return math.max(values[0] - values[1] - values[2] - values[3], 0);
  }

  Future<void> _record({required bool withdrawal}) async {
    int? maximumCents;
    if (withdrawal) {
      maximumCents = _progress?.savedCents ?? 0;
    } else {
      maximumCents = await _availableThisMonth();
    }
    if (!mounted) return;
    if (maximumCents <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            withdrawal
                ? 'Esta meta ainda não possui valor para retirar.'
                : 'Não há sobra disponível neste mês para destinar.',
          ),
        ),
      );
      return;
    }

    final ({int cents, String? note})? result = await _GoalValueDialog.show(
      context,
      title: withdrawal ? 'Retirar da meta' : 'Destinar para a meta',
      maximumCents: maximumCents,
      helperText: withdrawal
          ? 'Disponível na meta: ${_currency.format(maximumCents / 100)}'
          : 'Sobra disponível no mês: ${_currency.format(maximumCents / 100)}',
    );
    if (result == null) return;

    try {
      if (withdrawal) {
        await widget.repository.withdraw(
          goalId: widget.goalId,
          amountCents: result.cents,
          note: result.note,
        );
      } else {
        await widget.repository.allocate(
          goalId: widget.goalId,
          amountCents: result.cents,
          originYearMonth: MonthlyPlan.keyFor(DateTime.now()),
          note: result.note,
        );
      }
      notifyFinancialPlanChanged();
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_messageFor(error))));
    }
  }

  Future<void> _editGoal() async {
    final SavingsGoal? goal = _progress?.goal;
    if (goal == null) return;
    final bool changed = await _GoalFormSheet.show(
      context,
      repository: widget.repository,
      goal: goal,
    );
    if (changed) {
      notifyFinancialPlanChanged();
      await _load();
    }
  }

  Future<void> _changeStatus(SavingsGoalStatus status) async {
    final SavingsGoal? goal = _progress?.goal;
    if (goal == null) return;
    await widget.repository.updateGoal(
      goal.copyWith(
        status: status,
        completedAt: status == SavingsGoalStatus.completed
            ? DateTime.now()
            : null,
        clearCompletedAt: status != SavingsGoalStatus.completed,
        updatedAt: DateTime.now(),
      ),
    );
    notifyFinancialPlanChanged();
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final GoalProgress? progress = _progress;
    return Scaffold(
      appBar: AppBar(
        title: Text(progress?.goal.name ?? 'Meta'),
        actions: <Widget>[
          if (progress != null)
            PopupMenuButton<String>(
              onSelected: (String action) {
                switch (action) {
                  case 'edit':
                    _editGoal();
                  case 'pause':
                    _changeStatus(SavingsGoalStatus.paused);
                  case 'resume':
                    _changeStatus(SavingsGoalStatus.active);
                  case 'complete':
                    _changeStatus(SavingsGoalStatus.completed);
                }
              },
              itemBuilder: (_) => <PopupMenuEntry<String>>[
                const PopupMenuItem<String>(
                  value: 'edit',
                  child: Text('Editar meta'),
                ),
                if (progress.goal.status == SavingsGoalStatus.active)
                  const PopupMenuItem<String>(
                    value: 'pause',
                    child: Text('Pausar'),
                  )
                else
                  const PopupMenuItem<String>(
                    value: 'resume',
                    child: Text('Reativar'),
                  ),
                if (progress.goal.status != SavingsGoalStatus.completed)
                  const PopupMenuItem<String>(
                    value: 'complete',
                    child: Text('Marcar como concluída'),
                  ),
              ],
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : progress == null
          ? const Center(child: Text('Meta não encontrada.'))
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.pageHorizontal),
              children: <Widget>[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                _currency.format(progress.savedCents / 100),
                                style: theme.textTheme.headlineMedium?.copyWith(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            _GoalStatusChip(status: progress.goal.status),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'de ${_currency.format(progress.goal.target)} · faltam ${_currency.format(progress.remainingCents / 100)}',
                        ),
                        const SizedBox(height: AppSpacing.md),
                        LinearProgressIndicator(
                          value: progress.progress,
                          minHeight: 10,
                          borderRadius: BorderRadius.circular(99),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text('${(progress.progress * 100).round()}% concluído'),
                        if (progress.goal.deadline != null) ...<Widget>[
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            'Prazo definido: ${DateFormat('dd/MM/yyyy').format(progress.goal.deadline!)}',
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: FilledButton.icon(
                        onPressed:
                            progress.goal.status == SavingsGoalStatus.active
                            ? () => _record(withdrawal: false)
                            : null,
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Destinar'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: progress.savedCents > 0
                            ? () => _record(withdrawal: true)
                            : null,
                        icon: const Icon(Icons.remove_rounded),
                        label: const Text('Retirar'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                Text('Histórico', style: theme.textTheme.titleMedium),
                const SizedBox(height: AppSpacing.sm),
                if (_transactions.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(AppSpacing.lg),
                      child: Text(
                        'Nenhuma movimentação ainda. O histórico será preservado mesmo se a meta for pausada ou concluída.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                else
                  ..._transactions.map((GoalTransaction transaction) {
                    final bool positive = transaction.changeCents > 0;
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: positive
                              ? AppColors.successSoft
                              : AppColors.errorSoft,
                          foregroundColor: positive
                              ? AppColors.success
                              : AppColors.error,
                          child: Icon(
                            positive
                                ? Icons.south_west_rounded
                                : Icons.north_east_rounded,
                          ),
                        ),
                        title: Text(
                          '${positive ? '+' : '-'} ${_currency.format(transaction.changeCents.abs() / 100)}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          '${_transactionLabel(transaction.type)} · ${DateFormat('dd/MM/yyyy').format(transaction.createdAt)}${transaction.note == null ? '' : '\n${transaction.note}'}',
                        ),
                        isThreeLine: transaction.note != null,
                      ),
                    );
                  }),
              ],
            ),
    );
  }
}

class _GoalFormSheet extends StatefulWidget {
  const _GoalFormSheet({required this.repository, this.goal});

  final GoalRepository repository;
  final SavingsGoal? goal;

  static Future<bool> show(
    BuildContext context, {
    required GoalRepository repository,
    SavingsGoal? goal,
  }) async {
    return await showModalBottomSheet<bool>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          builder: (_) => _GoalFormSheet(repository: repository, goal: goal),
        ) ??
        false;
  }

  @override
  State<_GoalFormSheet> createState() => _GoalFormSheetState();
}

class _GoalFormSheetState extends State<_GoalFormSheet> {
  static const int _maximumCents = 999999999;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _targetController = TextEditingController();
  DateTime? _deadline;
  int _targetCents = 0;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final SavingsGoal? goal = widget.goal;
    _nameController.text = goal?.name ?? '';
    _targetCents = goal?.targetCents ?? 0;
    _deadline = goal?.deadline;
    if (_targetCents > 0) {
      _targetController.text = NumberFormat.currency(
        locale: 'pt_BR',
        symbol: '',
      ).format(_targetCents / 100).trim();
    }
    _targetController.addListener(_readTarget);
  }

  @override
  void dispose() {
    _targetController.removeListener(_readTarget);
    _targetController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _readTarget() {
    final int value =
        int.tryParse(
          _targetController.text.replaceAll(RegExp(r'[^0-9]'), ''),
        ) ??
        0;
    if (value != _targetCents && mounted) setState(() => _targetCents = value);
  }

  Future<void> _pickDeadline() async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _deadline ?? now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 30, 12, 31),
      helpText: 'Prazo opcional da meta',
    );
    if (picked != null && mounted) setState(() => _deadline = picked);
  }

  Future<void> _save() async {
    final String name = _nameController.text.trim();
    if (name.isEmpty || _targetCents <= 0 || _isSaving) return;
    setState(() => _isSaving = true);
    try {
      final DateTime now = DateTime.now();
      final SavingsGoal? original = widget.goal;
      if (original == null) {
        await widget.repository.createGoal(
          SavingsGoal(
            id: const Uuid().v4(),
            name: name,
            targetCents: _targetCents,
            deadline: _deadline,
            status: SavingsGoalStatus.active,
            createdAt: now,
            updatedAt: now,
          ),
        );
      } else {
        await widget.repository.updateGoal(
          original.copyWith(
            name: name,
            targetCents: _targetCents,
            deadline: _deadline,
            clearDeadline: _deadline == null,
            updatedAt: now,
          ),
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível salvar a meta.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool canSave =
        !_isSaving &&
        _nameController.text.trim().isNotEmpty &&
        _targetCents > 0;
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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              widget.goal == null ? 'Nova meta' : 'Editar meta',
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.xl),
            TextField(
              controller: _nameController,
              autofocus: widget.goal == null,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Nome da meta',
                hintText: 'Ex.: Viagem, curso, computador',
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _targetController,
              keyboardType: TextInputType.number,
              inputFormatters: <TextInputFormatter>[
                CurrencyInputFormatter(maximumValueInCents: _maximumCents),
              ],
              decoration: const InputDecoration(
                labelText: 'Valor desejado',
                prefixText: 'R\$ ',
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_outlined),
              title: const Text('Prazo opcional'),
              subtitle: Text(
                _deadline == null
                    ? 'Sem data definida'
                    : DateFormat('dd/MM/yyyy').format(_deadline!),
              ),
              trailing: _deadline == null
                  ? null
                  : IconButton(
                      tooltip: 'Remover prazo',
                      onPressed: () => setState(() => _deadline = null),
                      icon: const Icon(Icons.close_rounded),
                    ),
              onTap: _pickDeadline,
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              onPressed: canSave ? _save : null,
              child: Text(_isSaving ? 'Salvando...' : 'Salvar meta'),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoalValueDialog {
  static Future<({int cents, String? note})?> show(
    BuildContext context, {
    required String title,
    required int maximumCents,
    required String helperText,
  }) async {
    final TextEditingController valueController = TextEditingController();
    final TextEditingController noteController = TextEditingController();
    String? error;
    final ({int cents, String? note})?
    result = await showDialog<({int cents, String? note})>(
      context: context,
      builder: (BuildContext dialogContext) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setDialogState) {
          void submit() {
            final int cents =
                int.tryParse(
                  valueController.text.replaceAll(RegExp(r'[^0-9]'), ''),
                ) ??
                0;
            if (cents <= 0 || cents > maximumCents) {
              setDialogState(() {
                error = cents > maximumCents
                    ? 'O valor ultrapassa o disponível.'
                    : 'Digite um valor maior que zero.';
              });
              return;
            }
            final String note = noteController.text.trim();
            Navigator.pop(dialogContext, (
              cents: cents,
              note: note.isEmpty ? null : note,
            ));
          }

          return AlertDialog(
            title: Text(title),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TextField(
                  controller: valueController,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: <TextInputFormatter>[
                    CurrencyInputFormatter(maximumValueInCents: maximumCents),
                  ],
                  decoration: InputDecoration(
                    labelText: 'Valor',
                    prefixText: 'R\$ ',
                    helperText: helperText,
                    errorText: error,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: noteController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Observação (opcional)',
                  ),
                ),
              ],
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancelar'),
              ),
              FilledButton(onPressed: submit, child: const Text('Confirmar')),
            ],
          );
        },
      ),
    );
    valueController.dispose();
    noteController.dispose();
    return result;
  }
}

class _GoalStatusChip extends StatelessWidget {
  const _GoalStatusChip({required this.status});

  final SavingsGoalStatus status;

  @override
  Widget build(BuildContext context) {
    final (String, Color) presentation = switch (status) {
      SavingsGoalStatus.active => ('Ativa', AppColors.success),
      SavingsGoalStatus.paused => ('Pausada', AppColors.warning),
      SavingsGoalStatus.completed => ('Concluída', AppColors.information),
    };
    return Chip(
      label: Text(presentation.$1),
      labelStyle: TextStyle(
        color: presentation.$2,
        fontWeight: FontWeight.w700,
      ),
      backgroundColor: presentation.$2.withValues(alpha: 0.12),
      visualDensity: VisualDensity.compact,
      side: BorderSide.none,
    );
  }
}

class _GoalMessage extends StatelessWidget {
  const _GoalMessage({
    required this.icon,
    required this.text,
    required this.action,
    required this.onPressed,
  });

  final IconData icon;
  final String text;
  final String action;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          children: <Widget>[
            Icon(icon, size: 42, color: AppColors.textMuted(context)),
            const SizedBox(height: AppSpacing.md),
            Text(text, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton(onPressed: onPressed, child: Text(action)),
          ],
        ),
      ),
    );
  }
}

String _transactionLabel(GoalTransactionType type) => switch (type) {
  GoalTransactionType.allocation => 'Destinação da sobra mensal',
  GoalTransactionType.withdrawal => 'Retirada',
  GoalTransactionType.adjustment => 'Ajuste manual',
};

String _messageFor(Object error) {
  if (error is StateError || error is ArgumentError) {
    return error.toString().replaceFirst(
      RegExp(r'^(Bad state|Invalid argument): '),
      '',
    );
  }
  return 'Não foi possível registrar a movimentação.';
}
