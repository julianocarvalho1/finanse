import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/financial_evolution.dart';

class MonthlyResultDistributionCard extends StatelessWidget {
  MonthlyResultDistributionCard({
    required this.snapshot,
    required this.monthLabel,
    super.key,
  });

  final MonthlyEvolutionSnapshot snapshot;
  final String monthLabel;

  final NumberFormat _currency = NumberFormat.currency(
    locale: 'pt_BR',
    symbol: 'R\$',
  );
  final NumberFormat _percent = NumberFormat.decimalPercentPattern(
    locale: 'pt_BR',
    decimalDigits: 0,
  );

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final int? resultCents = snapshot.resultCents;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Distribuição da sobra', style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              monthLabel,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textMuted(context),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            if (resultCents == null)
              _DistributionNotice(
                icon: Icons.account_balance_wallet_outlined,
                color: AppColors.information,
                message:
                    'Cadastre a renda deste mês para calcular e distribuir a sobra.',
              )
            else if (resultCents <= 0)
              _DistributionNotice(
                icon: Icons.info_outline_rounded,
                color: resultCents < 0
                    ? AppColors.error
                    : AppColors.information,
                message: resultCents < 0
                    ? 'O mês está com resultado negativo de ${_currency.format(resultCents.abs() / 100)} e não possui sobra para distribuir.'
                    : 'Não houve resultado positivo para distribuir neste mês.',
              )
            else ...<Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Expanded(
                    child: Text(
                      'Resultado do mês',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                  Text(
                    _currency.format(resultCents / 100),
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: AppColors.success,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              _DistributionBar(
                goalsCents: snapshot.allocatedToGoalsCents,
                reserveCents: snapshot.allocatedToReserveCents,
                availableCents: snapshot.availableToReserveCents,
                semanticsLabel:
                    'Distribuição do resultado: ${_currency.format(snapshot.allocatedToGoalsCents / 100)} para metas, ${_currency.format(snapshot.allocatedToReserveCents / 100)} para a reserva e ${_currency.format(snapshot.availableToReserveCents / 100)} ainda livre.',
              ),
              const SizedBox(height: AppSpacing.md),
              _DistributionEntry(
                color: AppColors.purple,
                label: 'Metas',
                value: _currency.format(snapshot.allocatedToGoalsCents / 100),
                percent: _formatPercent(
                  snapshot.allocatedToGoalsCents,
                  resultCents,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              _DistributionEntry(
                color: AppColors.information,
                label: 'Reserva',
                value: _currency.format(snapshot.allocatedToReserveCents / 100),
                percent: _formatPercent(
                  snapshot.allocatedToReserveCents,
                  resultCents,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              _DistributionEntry(
                color: AppColors.success,
                label: 'Livre',
                value: _currency.format(snapshot.availableToReserveCents / 100),
                percent: _formatPercent(
                  snapshot.availableToReserveCents,
                  resultCents,
                ),
              ),
              if (snapshot.overallocatedCents > 0) ...<Widget>[
                const SizedBox(height: AppSpacing.md),
                _DistributionNotice(
                  icon: Icons.warning_amber_rounded,
                  color: AppColors.warning,
                  message:
                      'As destinações registradas superam o resultado atual em ${_currency.format(snapshot.overallocatedCents / 100)}. Revise as correções deste mês.',
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              Text(
                'O resultado é a renda menos os gastos. Metas e reserva não são contabilizadas como novas despesas.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textMuted(context),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatPercent(int cents, int resultCents) {
    if (cents <= 0 || resultCents <= 0) {
      return _percent.format(0);
    }
    return _percent.format(cents / resultCents);
  }
}

class _DistributionBar extends StatelessWidget {
  const _DistributionBar({
    required this.goalsCents,
    required this.reserveCents,
    required this.availableCents,
    required this.semanticsLabel,
  });

  final int goalsCents;
  final int reserveCents;
  final int availableCents;
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final List<Widget> segments = <Widget>[
      if (goalsCents > 0)
        Expanded(
          flex: goalsCents,
          child: const SizedBox.expand(
            child: ColoredBox(color: AppColors.purple),
          ),
        ),
      if (reserveCents > 0)
        Expanded(
          flex: reserveCents,
          child: const SizedBox.expand(
            child: ColoredBox(color: AppColors.information),
          ),
        ),
      if (availableCents > 0)
        Expanded(
          flex: availableCents,
          child: const SizedBox.expand(
            child: ColoredBox(color: AppColors.success),
          ),
        ),
    ];

    return Semantics(
      label: semanticsLabel,
      excludeSemantics: true,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: SizedBox(
          height: AppSpacing.sm,
          child: ColoredBox(
            color: AppColors.surfaceSecondary(context),
            child: Row(children: segments),
          ),
        ),
      ),
    );
  }
}

class _DistributionEntry extends StatelessWidget {
  const _DistributionEntry({
    required this.color,
    required this.label,
    required this.value,
    required this.percent,
  });

  final Color color;
  final String label;
  final String value;
  final String percent;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Row(
      children: <Widget>[
        Container(
          width: AppSpacing.sm,
          height: AppSpacing.sm,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
        Text(
          percent,
          style: theme.textTheme.bodySmall?.copyWith(
            color: AppColors.textMuted(context),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _DistributionNotice extends StatelessWidget {
  const _DistributionNotice({
    required this.icon,
    required this.color,
    required this.message,
  });

  final IconData icon;
  final Color color;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: AppSpacing.lg, color: color),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(message, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}
