import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../data/reserve_repository.dart';
import '../domain/reserve_transaction.dart';

class ReserveHistoryPage extends StatefulWidget {
  const ReserveHistoryPage({super.key});

  @override
  State<ReserveHistoryPage> createState() => _ReserveHistoryPageState();
}

class _ReserveHistoryPageState extends State<ReserveHistoryPage> {
  final ReserveRepository _repository = ReserveRepository();

  late final NumberFormat _currencyFormatter;
  late final DateFormat _dateFormatter;

  bool _isLoading = true;
  String? _errorMessage;
  double _currentBalance = 0;
  List<ReserveTransaction> _transactions = <ReserveTransaction>[];

  @override
  void initState() {
    super.initState();

    _currencyFormatter = NumberFormat.currency(
      locale: 'pt_BR',
      symbol: 'R\$',
      decimalDigits: 2,
    );

    _dateFormatter = DateFormat("dd 'de' MMM 'de' yyyy, HH:mm", 'pt_BR');

    _loadHistory();
  }

  Future<void> _loadHistory() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final List<ReserveTransaction> transactions = await _repository
          .getTransactions();
      final double currentBalance = await _repository.getCurrentBalance();

      if (!mounted) {
        return;
      }

      setState(() {
        _transactions = transactions;
        _currentBalance = currentBalance;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = 'Não foi possível carregar o histórico da reserva.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Histórico da reserva')),
      body: RefreshIndicator(
        onRefresh: _loadHistory,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            AppSpacing.pageHorizontal,
            AppSpacing.lg,
            AppSpacing.pageHorizontal,
            AppSpacing.safeBottomPadding(context),
          ),
          children: <Widget>[
            _buildBalanceCard(theme),
            const SizedBox(height: AppSpacing.xl),
            Text('Movimentações', style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.md),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.xxl),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_errorMessage != null)
              _buildErrorState(theme)
            else if (_transactions.isEmpty)
              _buildEmptyState(theme)
            else
              ..._transactions.map((ReserveTransaction transaction) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: _ReserveHistoryCard(
                    transaction: transaction,
                    formattedDate: _dateFormatter.format(transaction.createdAt),
                    formattedAmount: _currencyFormatter.format(
                      transaction.amount,
                    ),
                    formattedBalance: _currencyFormatter.format(
                      transaction.balanceAfter,
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceCard(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: <Widget>[
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
              ),
              child: Icon(
                Icons.savings_outlined,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Saldo atual',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary(context),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    _currencyFormatter.format(_currentBalance),
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
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

  Widget _buildEmptyState(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          children: <Widget>[
            Icon(
              Icons.receipt_long_outlined,
              size: 44,
              color: AppColors.textMuted(context),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Nenhuma movimentação ainda',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'As adições, retiradas e ajustes da sua reserva aparecerão aqui.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          children: <Widget>[
            const Icon(Icons.error_outline_rounded, color: AppColors.error),
            const SizedBox(height: AppSpacing.sm),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton.icon(
              onPressed: _loadHistory,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReserveHistoryCard extends StatelessWidget {
  const _ReserveHistoryCard({
    required this.transaction,
    required this.formattedDate,
    required this.formattedAmount,
    required this.formattedBalance,
  });

  final ReserveTransaction transaction;
  final String formattedDate;
  final String formattedAmount;
  final String formattedBalance;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final _ReserveHistoryStyle style = _styleFor(transaction.type, theme);

    final String amountText;
    if (transaction.type == ReserveTransactionType.add) {
      amountText = '+ $formattedAmount';
    } else if (transaction.type == ReserveTransactionType.withdraw) {
      amountText = '- $formattedAmount';
    } else {
      amountText = formattedBalance;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: style.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
              ),
              child: Icon(style.icon, color: style.color, size: 21),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          style.title,
                          style: theme.textTheme.titleSmall,
                        ),
                      ),
                      Text(
                        amountText,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: style.color,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    formattedDate,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary(context),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    'Saldo após a movimentação: $formattedBalance',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textMuted(context),
                    ),
                  ),
                  if (transaction.originYearMonth != null) ...<Widget>[
                    const SizedBox(height: AppSpacing.xs),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xs,
                        vertical: AppSpacing.xxs,
                      ),
                      decoration: BoxDecoration(
                        color: style.color.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(
                          AppSpacing.buttonRadius,
                        ),
                      ),
                      child: Text(
                        'Resultado de ${_formatOriginMonth(transaction.originYearMonth!)}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: style.color,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                  if (transaction.note?.isNotEmpty ?? false) ...<Widget>[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      transaction.note!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontStyle: FontStyle.italic,
                        color: AppColors.textSecondary(context),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatOriginMonth(String yearMonth) {
    final List<String> parts = yearMonth.split('-');
    if (parts.length != 2) return yearMonth;
    final int? year = int.tryParse(parts[0]);
    final int? month = int.tryParse(parts[1]);
    if (year == null || month == null || month < 1 || month > 12) {
      return yearMonth;
    }
    return DateFormat("MMMM 'de' yyyy", 'pt_BR').format(DateTime(year, month));
  }

  _ReserveHistoryStyle _styleFor(ReserveTransactionType type, ThemeData theme) {
    switch (type) {
      case ReserveTransactionType.add:
        return const _ReserveHistoryStyle(
          title: 'Valor adicionado',
          icon: Icons.add_rounded,
          color: AppColors.success,
        );
      case ReserveTransactionType.withdraw:
        return const _ReserveHistoryStyle(
          title: 'Valor retirado',
          icon: Icons.remove_rounded,
          color: AppColors.error,
        );
      case ReserveTransactionType.adjust:
        return _ReserveHistoryStyle(
          title: 'Saldo ajustado',
          icon: Icons.tune_rounded,
          color: theme.colorScheme.primary,
        );
    }
  }
}

class _ReserveHistoryStyle {
  const _ReserveHistoryStyle({
    required this.title,
    required this.icon,
    required this.color,
  });

  final String title;
  final IconData icon;
  final Color color;
}
