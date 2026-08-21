import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/currency_input_formatter.dart';
import '../../../core/utils/expense_notifier.dart';
import '../../../core/utils/financial_plan_notifier.dart';
import '../../history/presentation/history_page.dart';
import '../../incomes/presentation/incomes_page.dart';
import '../../reserve/data/reserve_repository.dart';
import '../data/financial_evolution_service.dart';
import '../domain/financial_evolution.dart';

class FinancialEvolutionPage extends StatefulWidget {
  const FinancialEvolutionPage({super.key});

  @override
  State<FinancialEvolutionPage> createState() => _FinancialEvolutionPageState();
}

class _FinancialEvolutionPageState extends State<FinancialEvolutionPage> {
  final FinancialEvolutionService _service = FinancialEvolutionService();
  final ReserveRepository _reserveRepository = ReserveRepository();
  final NumberFormat _currency = NumberFormat.currency(
    locale: 'pt_BR',
    symbol: 'R\$',
  );

  int _periodMonths = 6;
  FinancialEvolution? _evolution;
  bool _isLoading = true;
  String? _errorMessage;
  int _loadRequestId = 0;

  DateTime get _currentMonth {
    final DateTime now = DateTime.now();
    return DateTime(now.year, now.month);
  }

  @override
  void initState() {
    super.initState();
    expenseNotifier.addListener(_handleDataChanged);
    financialPlanNotifier.addListener(_handleDataChanged);
    _loadData();
  }

  @override
  void dispose() {
    expenseNotifier.removeListener(_handleDataChanged);
    financialPlanNotifier.removeListener(_handleDataChanged);
    super.dispose();
  }

  void _handleDataChanged() {
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
      final FinancialEvolution evolution = await _service.load(
        referenceMonth: _currentMonth,
        monthCount: _periodMonths,
      );
      if (!mounted || requestId != _loadRequestId) {
        return;
      }
      setState(() {
        _evolution = evolution;
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (_) {
      if (!mounted || requestId != _loadRequestId) {
        return;
      }
      setState(() {
        _isLoading = false;
        _errorMessage = 'Não foi possível calcular sua evolução agora.';
      });
    }
  }

  Future<void> _changePeriod(int months) async {
    if (months == _periodMonths) {
      return;
    }
    HapticFeedback.selectionClick();
    setState(() {
      _periodMonths = months;
    });
    await _loadData();
  }

  Future<void> _openIncomes(DateTime month) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => IncomesPage(initialMonth: month)),
    );
    if (mounted) {
      await _loadData(showLoading: false);
    }
  }

  Future<void> _openExpenses(DateTime month) async {
    final String monthLabel = _monthName(month);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text('Gastos de $monthLabel')),
          body: HistoryPage(initialMonth: month),
        ),
      ),
    );
    if (mounted) {
      await _loadData(showLoading: false);
    }
  }

  Future<void> _showMonthActions(MonthlyEvolutionSnapshot snapshot) async {
    HapticFeedback.selectionClick();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (BuildContext sheetContext) {
        final ThemeData theme = Theme.of(sheetContext);
        final int? result = snapshot.resultCents;
        return SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.xs,
              AppSpacing.xl,
              MediaQuery.viewInsetsOf(sheetContext).bottom + AppSpacing.xl,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  _monthName(snapshot.month),
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  result == null
                      ? 'Cadastre a renda para calcular o resultado deste mês.'
                      : 'Resultado registrado: ${_signedCurrency(result)}.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.lg),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.account_balance_wallet_outlined),
                  title: const Text('Editar rendas e limite'),
                  subtitle: const Text('Corrigir o planejamento deste mês'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _openIncomes(snapshot.month);
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.receipt_long_outlined),
                  title: const Text('Corrigir gastos'),
                  subtitle: const Text('Abrir o histórico filtrado neste mês'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _openExpenses(snapshot.month);
                  },
                ),
                if (snapshot.availableToReserveCents > 0)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.savings_outlined),
                    title: const Text('Destinar para a reserva'),
                    subtitle: Text(
                      'Até ${_currency.format(snapshot.availableToReserveCents / 100)} ainda disponível',
                    ),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _allocateToReserve(snapshot);
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _allocateToReserve(MonthlyEvolutionSnapshot snapshot) async {
    final TextEditingController controller = TextEditingController(
      text: NumberFormat.currency(
        locale: 'pt_BR',
        symbol: '',
      ).format(snapshot.availableToReserveCents / 100).trim(),
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
              if (value <= 0 || value > snapshot.availableToReserveCents) {
                setDialogState(() {
                  errorMessage = value > snapshot.availableToReserveCents
                      ? 'O valor ultrapassa o resultado disponível.'
                      : 'Digite um valor maior que zero.';
                });
                return;
              }
              Navigator.pop(dialogContext, value);
            }

            return AlertDialog(
              title: const Text('Destinar para a reserva'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Resultado ainda disponível em ${_monthName(snapshot.month)}: ${_currency.format(snapshot.availableToReserveCents / 100)}.',
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    inputFormatters: <TextInputFormatter>[
                      CurrencyInputFormatter(
                        maximumValueInCents: snapshot.availableToReserveCents,
                      ),
                    ],
                    decoration: InputDecoration(
                      labelText: 'Valor que foi guardado',
                      prefixText: 'R\$ ',
                      errorText: errorMessage,
                    ),
                    onSubmitted: (_) => submit(),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'A destinação não será contada como gasto.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancelar'),
                ),
                FilledButton(onPressed: submit, child: const Text('Registrar')),
              ],
            );
          },
        );
      },
    );
    controller.dispose();

    if (cents == null || !mounted) {
      return;
    }

    try {
      await _reserveRepository.addAmount(
        cents / 100,
        note: 'Destinação do resultado de ${snapshot.yearMonth}.',
        originYearMonth: snapshot.yearMonth,
      );
      notifyFinancialPlanChanged();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Valor destinado para a reserva.')),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível registrar a destinação.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Evolução financeira')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? _EvolutionError(message: _errorMessage!, onRetry: _loadData)
          : _buildContent(theme, _evolution!),
    );
  }

  Widget _buildContent(ThemeData theme, FinancialEvolution evolution) {
    final List<MonthlyEvolutionSnapshot> newestFirst = evolution.months.reversed
        .toList(growable: false);

    return RefreshIndicator(
      onRefresh: () => _loadData(showLoading: false),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          AppSpacing.pageHorizontal,
          AppSpacing.md,
          AppSpacing.pageHorizontal,
          MediaQuery.paddingOf(context).bottom + AppSpacing.xxl,
        ),
        children: <Widget>[
          Text(
            'Acompanhe o que entrou, o que foi gasto e o que ficou preservado ao longo do tempo.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<int>(
              segments: const <ButtonSegment<int>>[
                ButtonSegment<int>(value: 6, label: Text('6 meses')),
                ButtonSegment<int>(value: 12, label: Text('12 meses')),
              ],
              selected: <int>{_periodMonths},
              onSelectionChanged: (Set<int> selection) {
                _changePeriod(selection.first);
              },
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _buildPeriodSummary(theme, evolution),
          const SizedBox(height: AppSpacing.lg),
          if (!evolution.hasAnyData)
            _EvolutionEmpty(onAddIncome: () => _openIncomes(_currentMonth))
          else ...<Widget>[
            _buildMoneyChart(theme, evolution),
            const SizedBox(height: AppSpacing.lg),
            _buildRateChart(theme, evolution),
            const SizedBox(height: AppSpacing.lg),
            _buildHighlights(theme, evolution),
          ],
          const SizedBox(height: AppSpacing.xxl),
          Text('Resumo de cada mês', style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Meses encerrados continuam editáveis e são recalculados automaticamente.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.md),
          ...newestFirst.map((MonthlyEvolutionSnapshot snapshot) {
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _buildMonthCard(theme, evolution, snapshot),
            );
          }),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Os valores são estimativas baseadas somente nos registros manuais do Finanse.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textMuted(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodSummary(ThemeData theme, FinancialEvolution evolution) {
    final int? result = evolution.accumulatedResultCents;
    final int missingIncomeMonths =
        evolution.months.length - evolution.monthsWithIncome.length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Resultado acumulado', style: theme.textTheme.bodyMedium),
            const SizedBox(height: AppSpacing.xs),
            Text(
              result == null ? 'Ainda não calculado' : _signedCurrency(result),
              style: theme.textTheme.headlineMedium?.copyWith(
                color: result == null
                    ? AppColors.textMuted(context)
                    : result < 0
                    ? AppColors.error
                    : AppColors.success,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: <Widget>[
                Expanded(
                  child: _CompactMetric(
                    label: 'Renda registrada',
                    value: _currency.format(evolution.totalIncomeCents / 100),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _CompactMetric(
                    label: 'Gastos realizados',
                    value: _currency.format(evolution.totalSpentCents / 100),
                  ),
                ),
              ],
            ),
            if (missingIncomeMonths > 0) ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              Text(
                missingIncomeMonths == evolution.months.length
                    ? 'Cadastre renda para calcular resultados e taxas.'
                    : '$missingIncomeMonths ${missingIncomeMonths == 1 ? 'mês ficou' : 'meses ficaram'} fora do resultado por não ter renda cadastrada.',
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

  Widget _buildMoneyChart(ThemeData theme, FinancialEvolution evolution) {
    final List<double> values = <double>[0];
    for (final MonthlyEvolutionSnapshot snapshot in evolution.months) {
      values
        ..add(snapshot.incomeCents / 100)
        ..add(snapshot.spentCents / 100)
        ..add((snapshot.resultCents ?? 0) / 100);
    }
    final double highest = values.reduce(math.max);
    final double lowest = values.reduce(math.min);
    final double maxY = highest <= 0 ? 1 : highest * 1.18;
    final double minY = lowest >= 0 ? 0 : lowest * 1.20;
    final double interval = math.max((maxY - minY) / 4, 1);
    final double rodWidth = _periodMonths == 6 ? 8 : 5;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Renda, gastos e resultado',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            const Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.xs,
              children: <Widget>[
                _ChartLegend(color: AppColors.information, label: 'Renda'),
                _ChartLegend(color: AppColors.warning, label: 'Gastos'),
                _ChartLegend(color: AppColors.success, label: 'Resultado'),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Semantics(
              label: _moneyChartDescription(evolution),
              child: ExcludeSemantics(
                child: SizedBox(
                  height: 280,
                  child: BarChart(
                    BarChartData(
                      minY: minY,
                      maxY: maxY,
                      alignment: BarChartAlignment.spaceAround,
                      groupsSpace: _periodMonths == 6 ? 12 : 4,
                      borderData: FlBorderData(show: false),
                      gridData: FlGridData(
                        drawVerticalLine: false,
                        horizontalInterval: interval,
                        getDrawingHorizontalLine: (_) => FlLine(
                          color: AppColors.border(context),
                          strokeWidth: 1,
                        ),
                      ),
                      extraLinesData: ExtraLinesData(
                        horizontalLines: <HorizontalLine>[
                          HorizontalLine(
                            y: 0,
                            color: AppColors.textMuted(context),
                            strokeWidth: 1,
                          ),
                        ],
                      ),
                      titlesData: _chartTitles(
                        evolution.months,
                        interval: interval,
                        sideLabel: _compactCurrency,
                      ),
                      barTouchData: BarTouchData(
                        touchTooltipData: BarTouchTooltipData(
                          fitInsideHorizontally: true,
                          fitInsideVertically: true,
                          getTooltipColor: (_) => AppColors.darkSurface,
                          getTooltipItem:
                              (
                                BarChartGroupData group,
                                int groupIndex,
                                BarChartRodData rod,
                                int rodIndex,
                              ) {
                                final MonthlyEvolutionSnapshot snapshot =
                                    evolution.months[groupIndex];
                                final String label = switch (rodIndex) {
                                  0 => 'Renda',
                                  1 => 'Gastos',
                                  _ => 'Resultado',
                                };
                                final String value =
                                    rodIndex == 2 &&
                                        snapshot.resultCents == null
                                    ? 'Não calculado'
                                    : _signedCurrency((rod.toY * 100).round());
                                return BarTooltipItem(
                                  '$label\n$value',
                                  const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                );
                              },
                        ),
                      ),
                      barGroups: <BarChartGroupData>[
                        for (
                          int index = 0;
                          index < evolution.months.length;
                          index++
                        )
                          BarChartGroupData(
                            x: index,
                            barsSpace: 2,
                            barRods: <BarChartRodData>[
                              BarChartRodData(
                                toY: evolution.months[index].incomeCents / 100,
                                width: rodWidth,
                                color: AppColors.information,
                                borderRadius: BorderRadius.circular(3),
                              ),
                              BarChartRodData(
                                toY: evolution.months[index].spentCents / 100,
                                width: rodWidth,
                                color: AppColors.warning,
                                borderRadius: BorderRadius.circular(3),
                              ),
                              BarChartRodData(
                                toY:
                                    (evolution.months[index].resultCents ?? 0) /
                                    100,
                                width: rodWidth,
                                color:
                                    evolution.months[index].resultCents == null
                                    ? AppColors.disabled(context)
                                    : evolution.months[index].resultCents! < 0
                                    ? AppColors.error
                                    : AppColors.success,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRateChart(ThemeData theme, FinancialEvolution evolution) {
    final List<double> rates = evolution.months
        .map((MonthlyEvolutionSnapshot month) => (month.savingsRate ?? 0) * 100)
        .toList(growable: false);
    final double lowest = <double>[0, ...rates].reduce(math.min);
    final double highest = <double>[100, ...rates].reduce(math.max);
    final double minY = lowest >= 0 ? 0 : lowest * 1.15;
    final double maxY = highest <= 0 ? 100 : highest * 1.10;
    final double interval = math.max((maxY - minY) / 4, 1);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Taxa de economia', style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Percentual da renda que não foi gasto em cada mês.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.lg),
            Semantics(
              label: _rateChartDescription(evolution),
              child: ExcludeSemantics(
                child: SizedBox(
                  height: 240,
                  child: BarChart(
                    BarChartData(
                      minY: minY,
                      maxY: maxY,
                      alignment: BarChartAlignment.spaceAround,
                      borderData: FlBorderData(show: false),
                      gridData: FlGridData(
                        drawVerticalLine: false,
                        horizontalInterval: interval,
                        getDrawingHorizontalLine: (_) => FlLine(
                          color: AppColors.border(context),
                          strokeWidth: 1,
                        ),
                      ),
                      extraLinesData: ExtraLinesData(
                        horizontalLines: <HorizontalLine>[
                          HorizontalLine(
                            y: 0,
                            color: AppColors.textMuted(context),
                            strokeWidth: 1,
                          ),
                        ],
                      ),
                      titlesData: _chartTitles(
                        evolution.months,
                        interval: interval,
                        sideLabel: (double value) => '${value.round()}%',
                      ),
                      barTouchData: BarTouchData(
                        touchTooltipData: BarTouchTooltipData(
                          fitInsideHorizontally: true,
                          fitInsideVertically: true,
                          getTooltipColor: (_) => AppColors.darkSurface,
                          getTooltipItem:
                              (
                                BarChartGroupData group,
                                int groupIndex,
                                BarChartRodData rod,
                                int rodIndex,
                              ) {
                                final MonthlyEvolutionSnapshot snapshot =
                                    evolution.months[groupIndex];
                                return BarTooltipItem(
                                  snapshot.savingsRate == null
                                      ? 'Sem renda cadastrada'
                                      : '${(snapshot.savingsRate! * 100).toStringAsFixed(1)}%',
                                  const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                );
                              },
                        ),
                      ),
                      barGroups: <BarChartGroupData>[
                        for (
                          int index = 0;
                          index < evolution.months.length;
                          index++
                        )
                          BarChartGroupData(
                            x: index,
                            barRods: <BarChartRodData>[
                              BarChartRodData(
                                toY: rates[index],
                                width: _periodMonths == 6 ? 22 : 12,
                                color:
                                    evolution.months[index].savingsRate == null
                                    ? AppColors.disabled(context)
                                    : rates[index] < 0
                                    ? AppColors.error
                                    : AppColors.primary,
                                borderRadius: BorderRadius.circular(5),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  FlTitlesData _chartTitles(
    List<MonthlyEvolutionSnapshot> months, {
    required double interval,
    required String Function(double value) sideLabel,
  }) {
    return FlTitlesData(
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 54,
          interval: interval,
          getTitlesWidget: (double value, TitleMeta meta) {
            return SideTitleWidget(
              meta: meta,
              space: AppSpacing.xs,
              child: Text(
                sideLabel(value),
                style: Theme.of(context).textTheme.labelSmall,
              ),
            );
          },
        ),
      ),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 34,
          getTitlesWidget: (double value, TitleMeta meta) {
            final int index = value.round();
            if (index < 0 || index >= months.length) {
              return const SizedBox.shrink();
            }
            return SideTitleWidget(
              meta: meta,
              space: AppSpacing.xs,
              child: Text(
                DateFormat(
                  'MMM',
                  'pt_BR',
                ).format(months[index].month).replaceAll('.', ''),
                style: Theme.of(context).textTheme.labelSmall,
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHighlights(ThemeData theme, FinancialEvolution evolution) {
    final MonthlyEvolutionSnapshot? highest = evolution.highestResultMonth;
    final MonthlyEvolutionSnapshot? lowest = evolution.lowestResultMonth;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Destaques do período', style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.md),
            _HighlightRow(
              icon: Icons.arrow_upward_rounded,
              color: AppColors.success,
              label: 'Maior resultado',
              value: highest == null
                  ? 'Ainda não calculado'
                  : '${_monthName(highest.month)} · ${_signedCurrency(highest.resultCents!)}',
            ),
            const SizedBox(height: AppSpacing.sm),
            _HighlightRow(
              icon: Icons.arrow_downward_rounded,
              color: AppColors.information,
              label: 'Menor resultado',
              value: lowest == null
                  ? 'Ainda não calculado'
                  : '${_monthName(lowest.month)} · ${_signedCurrency(lowest.resultCents!)}',
            ),
            const SizedBox(height: AppSpacing.sm),
            _HighlightRow(
              icon: Icons.functions_rounded,
              color: AppColors.warning,
              label: 'Média mensal',
              value: evolution.averageResultCents == null
                  ? 'Ainda não calculada'
                  : _signedCurrency(evolution.averageResultCents!),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthCard(
    ThemeData theme,
    FinancialEvolution evolution,
    MonthlyEvolutionSnapshot snapshot,
  ) {
    final MonthlyEvolutionComparison? comparison = evolution.comparisonFor(
      snapshot,
    );
    final int? result = snapshot.resultCents;
    final bool isClosed = snapshot.isClosedAt(_currentMonth);

    return Card(
      child: InkWell(
        onTap: () => _showMonthActions(snapshot),
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      _monthName(snapshot.month),
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xxs,
                    ),
                    decoration: BoxDecoration(
                      color: isClosed
                          ? AppColors.informationSoft
                          : AppColors.successSoft,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      isClosed ? 'Encerrado' : 'Em andamento',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: isClosed
                            ? AppColors.information
                            : AppColors.success,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: <Widget>[
                  Expanded(
                    child: _CompactMetric(
                      label: 'Renda',
                      value: snapshot.incomeCents > 0
                          ? _currency.format(snapshot.incomeCents / 100)
                          : 'Não cadastrada',
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _CompactMetric(
                      label: 'Limite',
                      value: snapshot.spendingLimitCents == null
                          ? 'Não definido'
                          : _currency.format(
                              snapshot.spendingLimitCents! / 100,
                            ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: <Widget>[
                  Expanded(
                    child: _CompactMetric(
                      label: 'Gastos',
                      value: _currency.format(snapshot.spentCents / 100),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _CompactMetric(
                      label: 'Resultado',
                      value: result == null
                          ? 'Não calculado'
                          : _signedCurrency(result),
                      valueColor: result == null
                          ? null
                          : result < 0
                          ? AppColors.error
                          : AppColors.success,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Divider(color: AppColors.border(context)),
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: <Widget>[
                  Icon(
                    Icons.compare_arrows_rounded,
                    size: 18,
                    color: AppColors.textMuted(context),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      _comparisonText(comparison),
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
              if (snapshot.allocatedToReserveCents > 0) ...<Widget>[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '${_currency.format(snapshot.allocatedToReserveCents / 100)} destinado à reserva neste mês.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textMuted(context),
                  ),
                ),
              ],
              if (snapshot.allocatedToGoalsCents > 0) ...<Widget>[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '${_currency.format(snapshot.allocatedToGoalsCents / 100)} destinado às metas neste mês.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textMuted(context),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _comparisonText(MonthlyEvolutionComparison? comparison) {
    if (comparison == null) {
      return 'Primeiro mês do período selecionado.';
    }
    final int? difference = comparison.resultDifferenceCents;
    if (difference == null) {
      return 'Cadastre renda nos dois meses para comparar o resultado.';
    }
    if (difference == 0) {
      return 'Resultado igual ao mês anterior.';
    }
    return 'Resultado ${_currency.format(difference.abs() / 100)} ${difference > 0 ? 'maior' : 'menor'} que no mês anterior.';
  }

  String _moneyChartDescription(FinancialEvolution evolution) {
    return evolution.months
        .map((MonthlyEvolutionSnapshot month) {
          final String result = month.resultCents == null
              ? 'resultado não calculado'
              : 'resultado ${_signedCurrency(month.resultCents!)}';
          return '${_monthName(month.month)}: renda ${_currency.format(month.incomeCents / 100)}, gastos ${_currency.format(month.spentCents / 100)}, $result';
        })
        .join('. ');
  }

  String _rateChartDescription(FinancialEvolution evolution) {
    return evolution.months
        .map((MonthlyEvolutionSnapshot month) {
          final double? rate = month.savingsRate;
          return rate == null
              ? '${_monthName(month.month)}: taxa não calculada'
              : '${_monthName(month.month)}: ${(rate * 100).toStringAsFixed(1)} por cento';
        })
        .join('. ');
  }

  String _monthName(DateTime month) {
    return toBeginningOfSentenceCase(
      DateFormat("MMMM 'de' yyyy", 'pt_BR').format(month),
    );
  }

  String _signedCurrency(int cents) {
    final String formatted = _currency.format(cents.abs() / 100);
    return cents < 0 ? '-$formatted' : formatted;
  }

  String _compactCurrency(double value) {
    final double absolute = value.abs();
    final String sign = value < 0 ? '-' : '';
    if (absolute >= 1000000) {
      return '$sign${(absolute / 1000000).toStringAsFixed(1)} mi';
    }
    if (absolute >= 1000) {
      return '$sign${(absolute / 1000).toStringAsFixed(0)} mil';
    }
    return '$sign${absolute.toStringAsFixed(0)}';
  }
}

class _CompactMetric extends StatelessWidget {
  const _CompactMetric({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: theme.textTheme.bodySmall),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          value,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleSmall?.copyWith(
            color: valueColor,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _ChartLegend extends StatelessWidget {
  const _ChartLegend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _HighlightRow extends StatelessWidget {
  const _HighlightRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Row(
      children: <Widget>[
        CircleAvatar(
          radius: 20,
          backgroundColor: color.withValues(alpha: 0.14),
          foregroundColor: color,
          child: Icon(icon, size: 20),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(label, style: theme.textTheme.bodySmall),
              Text(
                value,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EvolutionEmpty extends StatelessWidget {
  const _EvolutionEmpty({required this.onAddIncome});

  final VoidCallback onAddIncome;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          children: <Widget>[
            Icon(
              Icons.insights_outlined,
              size: 52,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Sua evolução aparecerá aqui',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Cadastre uma renda, um limite ou um gasto. O Finanse montará o histórico automaticamente.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: onAddIncome,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Começar pelas rendas'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EvolutionError extends StatelessWidget {
  const _EvolutionError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
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
            Text(message, textAlign: TextAlign.center),
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
