import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/category_style.dart';
import '../../../core/utils/expense_notifier.dart';
import '../data/recurring_expense_repository.dart';
import '../data/recurring_notification_scheduler.dart';
import '../domain/recurring_expense.dart';
import 'recurring_expense_notifier.dart';
import 'widgets/recurring_expense_form.dart';

class RecurringExpensesPage extends StatefulWidget {
  const RecurringExpensesPage({super.key});

  @override
  State<RecurringExpensesPage> createState() {
    return _RecurringExpensesPageState();
  }
}

class _RecurringExpensesPageState extends State<RecurringExpensesPage> {
  final RecurringExpenseRepository _repository = RecurringExpenseRepository();
  final RecurringNotificationScheduler _notificationScheduler =
      RecurringNotificationScheduler.instance;
  late final NumberFormat _currencyFormatter;

  List<RecurringExpense> _recurringExpenses = <RecurringExpense>[];

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

    recurringExpenseNotifier.addListener(_handleRecurringExpensesChanged);

    _loadRecurringExpenses();
  }

  @override
  void dispose() {
    recurringExpenseNotifier.removeListener(_handleRecurringExpensesChanged);

    super.dispose();
  }

  void _handleRecurringExpensesChanged() {
    _loadRecurringExpenses(showLoading: false);
  }

  Future<void> _loadRecurringExpenses({bool showLoading = true}) async {
    final int requestId = ++_loadRequestId;

    if (showLoading && mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final List<RecurringExpense> recurringExpenses = await _repository
          .getAllRecurringExpenses();

      if (!mounted || requestId != _loadRequestId) {
        return;
      }

      setState(() {
        _recurringExpenses = recurringExpenses;
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (_) {
      if (!mounted || requestId != _loadRequestId) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = 'Não foi possível carregar as despesas recorrentes.';
      });
    }
  }

  List<RecurringExpense> get _dueRecurringExpenses {
    final DateTime now = DateTime.now();

    return _recurringExpenses
        .where((RecurringExpense recurringExpense) {
          return recurringExpense.isDueAt(now);
        })
        .toList(growable: false);
  }

  List<RecurringExpense> get _upcomingRecurringExpenses {
    final DateTime now = DateTime.now();

    return _recurringExpenses
        .where((RecurringExpense recurringExpense) {
          return recurringExpense.isActive && !recurringExpense.isDueAt(now);
        })
        .toList(growable: false);
  }

  List<RecurringExpense> get _pausedRecurringExpenses {
    return _recurringExpenses
        .where((RecurringExpense recurringExpense) {
          return !recurringExpense.isActive;
        })
        .toList(growable: false);
  }

  double get _activeRecurringTotal {
    return _recurringExpenses
        .where((RecurringExpense recurringExpense) {
          return recurringExpense.isActive;
        })
        .fold<double>(0, (
          double currentTotal,
          RecurringExpense recurringExpense,
        ) {
          return currentTotal + recurringExpense.amount;
        });
  }

  Future<void> _openRecurringExpenseForm({
    RecurringExpense? recurringExpense,
  }) async {
    HapticFeedback.selectionClick();

    await RecurringExpenseForm.show(
      context,
      recurringExpense: recurringExpense,
    );
  }

  Future<void> _confirmRegistration(RecurringExpense recurringExpense) async {
    HapticFeedback.mediumImpact();

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        final ThemeData theme = Theme.of(dialogContext);

        return AlertDialog(
          icon: Icon(
            Icons.check_circle_outline_rounded,
            color: theme.colorScheme.primary,
          ),
          title: const Text('Registrar este gasto?'),
          content: Text(
            'Será criado um gasto de '
            '${_currencyFormatter.format(recurringExpense.amount)} '
            'em ${recurringExpense.categoryName}. '
            'A próxima data será atualizada automaticamente.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancelar'),
            ),
            FilledButton.icon(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              icon: const Icon(Icons.done_rounded),
              label: const Text('Registrar'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    await _registerRecurringExpense(recurringExpense);
  }

  Future<void> _registerRecurringExpense(
    RecurringExpense recurringExpense,
  ) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);

    messenger.clearSnackBars();

    try {
      final RecurringRegistrationResult result = await _repository
          .registerRecurringExpense(recurringExpenseId: recurringExpense.id);

      bool reminderUpdated = true;

      try {
        await _notificationScheduler.synchronizeRecurringExpense(
          result.updatedRecurringExpense,
        );
      } catch (_) {
        reminderUpdated = false;
      }

      expenseNotifier.value++;
      recurringExpenseNotifier.notify();

      if (!mounted) {
        return;
      }

      messenger.showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 6),
          persist: false,
          dismissDirection: DismissDirection.down,
          actionOverflowThreshold: 1,
          content: Row(
            children: <Widget>[
              Icon(
                reminderUpdated
                    ? Icons.check_circle_rounded
                    : Icons.warning_amber_rounded,
                color: Colors.white,
                size: 22,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  reminderUpdated
                      ? '${_currencyFormatter.format(result.expense.amount)} '
                            'registrado em ${result.expense.categoryName}.'
                      : 'Gasto registrado, mas o próximo lembrete '
                            'não pôde ser atualizado.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          action: SnackBarAction(
            label: 'Desfazer',
            onPressed: () {
              _undoRegistration(result);
            },
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      final String message = error is StateError
          ? error.message.toString()
          : 'Não foi possível registrar o gasto.';

      _showErrorMessage(message);
    }
  }

  Future<void> _undoRegistration(RecurringRegistrationResult result) async {
    try {
      await _repository.undoRegistration(result);

      bool reminderRestored = true;

      try {
        await _notificationScheduler.synchronizeRecurringExpense(
          result.previousRecurringExpense,
        );
      } catch (_) {
        reminderRestored = false;
      }

      expenseNotifier.value++;
      recurringExpenseNotifier.notify();

      if (!mounted) {
        return;
      }

      final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);

      messenger.clearSnackBars();

      messenger.showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 5),
          persist: false,
          content: Row(
            children: <Widget>[
              Icon(
                reminderRestored
                    ? Icons.undo_rounded
                    : Icons.warning_amber_rounded,
                color: Colors.white,
                size: 22,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  reminderRestored
                      ? 'Registro desfeito. O gasto foi removido '
                            'e o lembrete anterior foi restaurado.'
                      : 'Registro desfeito, mas o lembrete '
                            'não pôde ser restaurado.',
                ),
              ),
            ],
          ),
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      _showErrorMessage('Não foi possível desfazer o registro.');
    }
  }

  Future<void> _confirmUndoLastRegistration(
    RecurringExpense recurringExpense,
  ) async {
    HapticFeedback.selectionClick();

    final bool? shouldUndo = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          icon: const Icon(Icons.undo_rounded),
          title: const Text('Desfazer último pagamento?'),
          content: Text(
            'O último gasto de '
            '${_currencyFormatter.format(recurringExpense.amount)} '
            'será removido e o vencimento anterior será restaurado.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancelar'),
            ),
            FilledButton.icon(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              icon: const Icon(Icons.undo_rounded),
              label: const Text('Desfazer'),
            ),
          ],
        );
      },
    );

    if (shouldUndo != true || !mounted) {
      return;
    }

    await _undoLastRegistration(recurringExpense);
  }

  Future<void> _undoLastRegistration(RecurringExpense recurringExpense) async {
    try {
      final RecurringExpense restoredRecurringExpense = await _repository
          .undoLastRegistration(recurringExpenseId: recurringExpense.id);

      bool reminderRestored = true;

      try {
        await _notificationScheduler.synchronizeRecurringExpense(
          restoredRecurringExpense,
        );
      } catch (_) {
        reminderRestored = false;
      }

      expenseNotifier.value++;
      recurringExpenseNotifier.notify();

      if (!mounted) {
        return;
      }

      final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);

      messenger.clearSnackBars();

      messenger.showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 5),
          persist: false,
          content: Row(
            children: <Widget>[
              Icon(
                reminderRestored
                    ? Icons.undo_rounded
                    : Icons.warning_amber_rounded,
                color: Colors.white,
                size: 22,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  reminderRestored
                      ? 'Último pagamento desfeito. O gasto foi removido '
                            'e o vencimento anterior foi restaurado.'
                      : 'Pagamento desfeito, mas o lembrete '
                            'não pôde ser restaurado.',
                ),
              ),
            ],
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      final String message = error is StateError
          ? error.message.toString()
          : 'Não foi possível desfazer o último pagamento.';

      _showErrorMessage(message);
    }
  }

  Future<void> _toggleActiveState(RecurringExpense recurringExpense) async {
    HapticFeedback.selectionClick();

    final bool newActiveState = !recurringExpense.isActive;

    try {
      final RecurringExpense updatedExpense = await _repository
          .setRecurringExpenseActive(
            id: recurringExpense.id,
            isActive: newActiveState,
          );

      bool reminderUpdated = true;

      try {
        await _notificationScheduler.synchronizeRecurringExpense(
          updatedExpense,
        );
      } catch (_) {
        reminderUpdated = false;
      }

      recurringExpenseNotifier.notify();

      if (!mounted) {
        return;
      }

      final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);

      messenger.clearSnackBars();

      messenger.showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 5),
          persist: false,
          content: Row(
            children: <Widget>[
              Icon(
                reminderUpdated
                    ? newActiveState
                          ? Icons.play_circle_rounded
                          : Icons.pause_circle_rounded
                    : Icons.warning_amber_rounded,
                color: Colors.white,
                size: 22,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  reminderUpdated
                      ? newActiveState
                            ? 'Despesa recorrente reativada e '
                                  'lembrete atualizado.'
                            : 'Despesa recorrente pausada e '
                                  'lembrete cancelado.'
                      : newActiveState
                      ? 'Recorrência reativada, mas o lembrete '
                            'não pôde ser criado.'
                      : 'Recorrência pausada, mas não foi possível '
                            'confirmar o cancelamento do lembrete.',
                ),
              ),
            ],
          ),
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      _showErrorMessage(
        newActiveState
            ? 'Não foi possível reativar a recorrência.'
            : 'Não foi possível pausar a recorrência.',
      );
    }
  }

  Future<void> _confirmDelete(RecurringExpense recurringExpense) async {
    HapticFeedback.mediumImpact();

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          icon: const Icon(
            Icons.delete_outline_rounded,
            color: AppColors.error,
          ),
          title: const Text('Excluir despesa recorrente?'),
          content: Text(
            '${recurringExpense.categoryName} será removida das '
            'recorrências. Os gastos já registrados continuarão '
            'no histórico.',
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

    await _deleteRecurringExpense(recurringExpense);
  }

  Future<void> _deleteRecurringExpense(
    RecurringExpense recurringExpense,
  ) async {
    try {
      final RecurringExpense removedExpense = await _repository
          .deleteRecurringExpenseAndReturn(recurringExpense.id);

      bool reminderCancelled = true;

      try {
        await _notificationScheduler.cancelRecurringExpense(removedExpense.id);
      } catch (_) {
        reminderCancelled = false;
      }

      recurringExpenseNotifier.notify();

      if (!mounted) {
        return;
      }

      final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);

      messenger.clearSnackBars();

      messenger.showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 6),
          persist: false,
          dismissDirection: DismissDirection.down,
          actionOverflowThreshold: 1,
          content: Row(
            children: <Widget>[
              Icon(
                reminderCancelled
                    ? Icons.delete_outline_rounded
                    : Icons.warning_amber_rounded,
                color: Colors.white,
                size: 22,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  reminderCancelled
                      ? 'Despesa recorrente e lembrete excluídos.'
                      : 'Recorrência excluída, mas não foi possível '
                            'confirmar o cancelamento do lembrete.',
                ),
              ),
            ],
          ),
          action: SnackBarAction(
            label: 'Desfazer',
            onPressed: () {
              _restoreDeletedRecurringExpense(removedExpense);
            },
          ),
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      _showErrorMessage('Não foi possível excluir a recorrência.');
    }
  }

  Future<void> _restoreDeletedRecurringExpense(
    RecurringExpense recurringExpense,
  ) async {
    try {
      await _repository.saveRecurringExpense(recurringExpense);

      bool reminderRestored = true;

      try {
        await _notificationScheduler.synchronizeRecurringExpense(
          recurringExpense,
        );
      } catch (_) {
        reminderRestored = false;
      }

      recurringExpenseNotifier.notify();

      if (!mounted) {
        return;
      }

      final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);

      messenger.clearSnackBars();

      messenger.showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 5),
          persist: false,
          content: Row(
            children: <Widget>[
              Icon(
                reminderRestored
                    ? Icons.restore_rounded
                    : Icons.warning_amber_rounded,
                color: Colors.white,
                size: 22,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  reminderRestored
                      ? 'Despesa recorrente e lembrete restaurados.'
                      : 'Recorrência restaurada, mas o lembrete '
                            'não pôde ser recriado.',
                ),
              ),
            ],
          ),
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      _showErrorMessage('Não foi possível restaurar a recorrência.');
    }
  }

  void _showRecurringExpenseDetails(RecurringExpense recurringExpense) {
    final CategoryStyle categoryStyle = CategoryStyles.fromName(
      recurringExpense.categoryName,
    );

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (BuildContext modalContext) {
        final ThemeData theme = Theme.of(modalContext);

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.pageHorizontal,
            AppSpacing.sm,
            AppSpacing.pageHorizontal,
            AppSpacing.xl +
                MediaQuery.of(modalContext).viewPadding.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Center(
                child: Container(
                  width: 68,
                  height: 68,
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
                  _currencyFormatter.format(recurringExpense.amount),
                  style: theme.textTheme.displaySmall,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Center(
                child: Text(
                  recurringExpense.categoryName,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: categoryStyle.color,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              _RecurringDetailRow(
                icon: Icons.repeat_rounded,
                label: 'Frequência',
                value: recurringExpense.frequencyLabel,
              ),
              _RecurringDetailRow(
                icon: Icons.event_rounded,
                label: 'Próxima data',
                value: _formatFullDate(recurringExpense.nextDate),
              ),
              _RecurringDetailRow(
                icon: recurringExpense.isActive
                    ? Icons.notifications_active_rounded
                    : Icons.pause_circle_outline_rounded,
                label: 'Situação',
                value: recurringExpense.isActive ? 'Ativa' : 'Pausada',
              ),
              _RecurringDetailRow(
                icon: Icons.receipt_long_rounded,
                label: 'Registros realizados',
                value: '${recurringExpense.registeredCount}',
              ),
              if (recurringExpense.lastRegisteredAt != null)
                _RecurringDetailRow(
                  icon: Icons.history_rounded,
                  label: 'Último registro',
                  value: _formatFullDate(recurringExpense.lastRegisteredAt!),
                ),
              _RecurringDetailRow(
                icon: Icons.edit_note_rounded,
                label: 'Descrição',
                value: _nonEmptyText(
                  recurringExpense.description,
                  fallback: 'Sem descrição',
                ),
              ),
              if (recurringExpense.notes != null &&
                  recurringExpense.notes!.trim().isNotEmpty)
                _RecurringDetailRow(
                  icon: Icons.notes_rounded,
                  label: 'Observação',
                  value: recurringExpense.notes!.trim(),
                ),
              _RecurringDetailRow(
                icon: Icons.account_balance_wallet_rounded,
                label: 'Forma de pagamento',
                value: _nonEmptyText(
                  recurringExpense.paymentMethod,
                  fallback: 'Não informada',
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(modalContext).pop();

                        _openRecurringExpenseForm(
                          recurringExpense: recurringExpense,
                        );
                      },
                      icon: const Icon(Icons.edit_rounded),
                      label: const Text('Editar'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: recurringExpense.isActive
                          ? () {
                              Navigator.of(modalContext).pop();

                              _confirmRegistration(recurringExpense);
                            }
                          : null,
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('Registrar'),
                    ),
                  ),
                ],
              ),
              if (recurringExpense.canUndoLastRegistration) ...<Widget>[
                const SizedBox(height: AppSpacing.sm),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(modalContext).pop();

                      _confirmUndoLastRegistration(recurringExpense);
                    },
                    icon: const Icon(Icons.undo_rounded),
                    label: const Text('Desfazer último pagamento'),
                  ),
                ),
              ],
            ],
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
        duration: const Duration(seconds: 5),
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

  String _formatFullDate(DateTime date) {
    return DateFormat("dd 'de' MMMM 'de' yyyy, HH:mm", 'pt_BR').format(date);
  }

  String _formatShortDate(DateTime date) {
    return DateFormat("dd MMM yyyy, HH:mm", 'pt_BR').format(date);
  }

  String _nonEmptyText(String? value, {required String fallback}) {
    final String normalizedValue = value?.trim() ?? '';

    if (normalizedValue.isEmpty) {
      return fallback;
    }

    return normalizedValue;
  }

  String _statusText(RecurringExpense recurringExpense) {
    if (!recurringExpense.isActive) {
      return 'Pausada';
    }

    final DateTime now = DateTime.now();
    final int daysUntil = recurringExpense.daysUntil(now);

    if (recurringExpense.isOverdueAt(now)) {
      final int overdueDays = daysUntil.abs();

      if (overdueDays == 1) {
        return 'Atrasada há 1 dia';
      }

      return 'Atrasada há $overdueDays dias';
    }

    if (daysUntil == 0) {
      if (recurringExpense.nextDate.isAfter(now)) {
        return 'Hoje às '
            '${DateFormat('HH:mm').format(recurringExpense.nextDate)}';
      }

      return 'Pendente hoje';
    }

    if (daysUntil == 1) {
      return 'Amanhã';
    }

    return 'Em $daysUntil dias';
  }

  Color _statusColor(BuildContext context, RecurringExpense recurringExpense) {
    if (!recurringExpense.isActive) {
      return AppColors.textMuted(context);
    }

    if (recurringExpense.isOverdueAt(DateTime.now())) {
      return AppColors.error;
    }

    if (recurringExpense.isDueAt(DateTime.now())) {
      return Theme.of(context).colorScheme.primary;
    }

    return AppColors.textSecondary(context);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Despesas recorrentes')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _openRecurringExpenseForm();
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nova recorrência'),
      ),
      body: _buildBody(theme),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return _RecurringErrorState(
        message: _errorMessage!,
        onRetry: () {
          _loadRecurringExpenses();
        },
      );
    }

    if (_recurringExpenses.isEmpty) {
      return _EmptyRecurringState(
        onCreate: () {
          _openRecurringExpenseForm();
        },
      );
    }

    final List<RecurringExpense> dueExpenses = _dueRecurringExpenses;

    final List<RecurringExpense> upcomingExpenses = _upcomingRecurringExpenses;

    final List<RecurringExpense> pausedExpenses = _pausedRecurringExpenses;

    return RefreshIndicator(
      onRefresh: () {
        return _loadRecurringExpenses(showLoading: false);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          AppSpacing.pageHorizontal,
          AppSpacing.lg,
          AppSpacing.pageHorizontal,
          AppSpacing.safeBottomPadding(context) + 72,
        ),
        children: <Widget>[
          _buildSummaryCard(theme, dueCount: dueExpenses.length),
          if (dueExpenses.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.xl),
            _RecurringSectionTitle(
              title: 'Pendentes',
              subtitle: 'Confirme os gastos que já foram pagos.',
              count: dueExpenses.length,
              icon: Icons.notification_important_rounded,
              color: AppColors.error,
            ),
            const SizedBox(height: AppSpacing.md),
            ...dueExpenses.map((RecurringExpense recurringExpense) {
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _buildRecurringCard(recurringExpense),
              );
            }),
          ],
          if (upcomingExpenses.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.xl),
            _RecurringSectionTitle(
              title: 'Próximas',
              subtitle: 'Pagamentos programados para os próximos dias.',
              count: upcomingExpenses.length,
              icon: Icons.upcoming_rounded,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: AppSpacing.md),
            ...upcomingExpenses.map((RecurringExpense recurringExpense) {
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _buildRecurringCard(recurringExpense),
              );
            }),
          ],
          if (pausedExpenses.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.xl),
            _RecurringSectionTitle(
              title: 'Pausadas',
              subtitle: 'Não aparecem entre os pagamentos pendentes.',
              count: pausedExpenses.length,
              icon: Icons.pause_circle_outline_rounded,
              color: AppColors.textMuted(context),
            ),
            const SizedBox(height: AppSpacing.md),
            ...pausedExpenses.map((RecurringExpense recurringExpense) {
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _buildRecurringCard(recurringExpense),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryCard(ThemeData theme, {required int dueCount}) {
    final int activeCount = _recurringExpenses.where((
      RecurringExpense recurringExpense,
    ) {
      return recurringExpense.isActive;
    }).length;

    final int pausedCount = _recurringExpenses.length - activeCount;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Resumo das recorrências', style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Soma dos valores ativos cadastrados',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                _currencyFormatter.format(_activeRecurringTotal),
                style: theme.textTheme.displaySmall,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: <Widget>[
                Expanded(
                  child: _RecurringSummaryMetric(
                    label: 'Pendentes',
                    value: '$dueCount',
                    icon: Icons.notification_important_rounded,
                    color: dueCount > 0
                        ? AppColors.error
                        : theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _RecurringSummaryMetric(
                    label: 'Ativas',
                    value: '$activeCount',
                    icon: Icons.notifications_active_rounded,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _RecurringSummaryMetric(
                    label: 'Pausadas',
                    value: '$pausedCount',
                    icon: Icons.pause_circle_outline_rounded,
                    color: AppColors.textMuted(context),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecurringCard(RecurringExpense recurringExpense) {
    return _RecurringExpenseCard(
      recurringExpense: recurringExpense,
      formattedAmount: _currencyFormatter.format(recurringExpense.amount),
      formattedDate: _formatShortDate(recurringExpense.nextDate),
      statusText: _statusText(recurringExpense),
      statusColor: _statusColor(context, recurringExpense),
      onTap: () {
        _showRecurringExpenseDetails(recurringExpense);
      },
      onRegister: recurringExpense.isActive
          ? () {
              _confirmRegistration(recurringExpense);
            }
          : null,
      onEdit: () {
        _openRecurringExpenseForm(recurringExpense: recurringExpense);
      },
      onToggleActive: () {
        _toggleActiveState(recurringExpense);
      },
      onDelete: () {
        _confirmDelete(recurringExpense);
      },
    );
  }
}

class _RecurringExpenseCard extends StatelessWidget {
  const _RecurringExpenseCard({
    required this.recurringExpense,
    required this.formattedAmount,
    required this.formattedDate,
    required this.statusText,
    required this.statusColor,
    required this.onTap,
    required this.onRegister,
    required this.onEdit,
    required this.onToggleActive,
    required this.onDelete,
  });

  final RecurringExpense recurringExpense;
  final String formattedAmount;
  final String formattedDate;
  final String statusText;
  final Color statusColor;

  final VoidCallback onTap;
  final VoidCallback? onRegister;
  final VoidCallback onEdit;
  final VoidCallback onToggleActive;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    final CategoryStyle categoryStyle = CategoryStyles.fromName(
      recurringExpense.categoryName,
    );

    final String description = recurringExpense.description?.trim() ?? '';

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: categoryStyle.backgroundColor(),
                      borderRadius: BorderRadius.circular(
                        AppSpacing.inputRadius,
                      ),
                    ),
                    child: Icon(categoryStyle.icon, color: categoryStyle.color),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          recurringExpense.categoryName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall,
                        ),
                        if (description.isNotEmpty) ...<Widget>[
                          const SizedBox(height: AppSpacing.xxs),
                          Text(
                            description,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                        const SizedBox(height: AppSpacing.xs),
                        Text(formattedDate, style: theme.textTheme.bodySmall),
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
                      Text(
                        recurringExpense.frequencyLabel,
                        style: theme.textTheme.labelSmall,
                      ),
                    ],
                  ),
                  PopupMenuButton<_RecurringMenuAction>(
                    tooltip: 'Mais opções',
                    onSelected: (_RecurringMenuAction action) {
                      switch (action) {
                        case _RecurringMenuAction.edit:
                          onEdit();

                        case _RecurringMenuAction.toggleActive:
                          onToggleActive();

                        case _RecurringMenuAction.delete:
                          onDelete();
                      }
                    },
                    itemBuilder: (BuildContext popupContext) {
                      return <PopupMenuEntry<_RecurringMenuAction>>[
                        const PopupMenuItem<_RecurringMenuAction>(
                          value: _RecurringMenuAction.edit,
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(Icons.edit_rounded),
                            title: Text('Editar'),
                          ),
                        ),
                        PopupMenuItem<_RecurringMenuAction>(
                          value: _RecurringMenuAction.toggleActive,
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              recurringExpense.isActive
                                  ? Icons.pause_circle_outline_rounded
                                  : Icons.play_circle_outline_rounded,
                            ),
                            title: Text(
                              recurringExpense.isActive ? 'Pausar' : 'Reativar',
                            ),
                          ),
                        ),
                        const PopupMenuDivider(),
                        const PopupMenuItem<_RecurringMenuAction>(
                          value: _RecurringMenuAction.delete,
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              Icons.delete_outline_rounded,
                              color: AppColors.error,
                            ),
                            title: Text(
                              'Excluir',
                              style: TextStyle(color: AppColors.error),
                            ),
                          ),
                        ),
                      ];
                    },
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.xs,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.11),
                        borderRadius: BorderRadius.circular(
                          AppSpacing.inputRadius,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(
                            recurringExpense.isActive
                                ? Icons.schedule_rounded
                                : Icons.pause_circle_outline_rounded,
                            color: statusColor,
                            size: 17,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Expanded(
                            child: Text(
                              statusText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: statusColor,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (onRegister != null) ...<Widget>[
                    const SizedBox(width: AppSpacing.sm),
                    FilledButton.icon(
                      onPressed: onRegister,
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: const Text('Registrar'),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecurringSectionTitle extends StatelessWidget {
  const _RecurringSectionTitle({
    required this.title,
    required this.subtitle,
    required this.count,
    required this.icon,
    required this.color,
  });

  final String title;
  final String subtitle;
  final int count;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.11),
            borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
          ),
          child: Icon(icon, color: color, size: 21),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Flexible(
                    child: Text(title, style: theme.textTheme.titleMedium),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xs,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.11),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$count',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(subtitle, style: theme.textTheme.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}

class _RecurringSummaryMetric extends StatelessWidget {
  const _RecurringSummaryMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

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
          Icon(icon, color: color, size: 21),
          const SizedBox(height: AppSpacing.xs),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
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

class _RecurringDetailRow extends StatelessWidget {
  const _RecurringDetailRow({
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

class _EmptyRecurringState extends StatelessWidget {
  const _EmptyRecurringState({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.repeat_rounded,
                color: theme.colorScheme.primary,
                size: 40,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Nenhuma despesa recorrente',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Cadastre contas, assinaturas e outros gastos '
              'que se repetem. O aplicativo manterá a próxima '
              'data organizada para você.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.xl),
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Criar primeira recorrência'),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecurringErrorState extends StatelessWidget {
  const _RecurringErrorState({required this.message, required this.onRetry});

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
              size: 52,
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

enum _RecurringMenuAction { edit, toggleActive, delete }
