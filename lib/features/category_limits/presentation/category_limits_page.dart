import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/currency_input_formatter.dart';
import '../../../core/utils/financial_plan_notifier.dart';
import '../../planning/data/monthly_plan_repository.dart';
import '../../planning/domain/monthly_plan.dart';
import '../data/category_limit_repository.dart';
import '../domain/category_limit.dart';

class CategoryLimitsPage extends StatefulWidget {
  const CategoryLimitsPage({super.key, this.initialMonth});

  final DateTime? initialMonth;

  @override
  State<CategoryLimitsPage> createState() => _CategoryLimitsPageState();
}

class _CategoryLimitsPageState extends State<CategoryLimitsPage> {
  final CategoryLimitRepository _repository = CategoryLimitRepository();
  final MonthlyPlanRepository _planRepository = MonthlyPlanRepository();
  final NumberFormat _currency = NumberFormat.currency(
    locale: 'pt_BR',
    symbol: 'R\$',
  );

  late DateTime _selectedMonth;
  List<CategoryLimitSummary> _summaries = <CategoryLimitSummary>[];
  MonthlyPlan? _plan;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final DateTime month = widget.initialMonth ?? DateTime.now();
    _selectedMonth = DateTime(month.year, month.month);
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }
    try {
      final List<Object?> values = await Future.wait<Object?>(<Future<Object?>>[
        _repository.getSummariesForMonth(_selectedMonth),
        _planRepository.getPlanForMonth(_selectedMonth),
      ]);
      if (!mounted) return;
      setState(() {
        _summaries = values[0]! as List<CategoryLimitSummary>;
        _plan = values[1] as MonthlyPlan?;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Não foi possível carregar os limites por categoria.';
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
    _load();
  }

  Future<void> _openForm([CategoryLimit? limit]) async {
    final Set<String> categories = <String>{
      ..._standardCategories,
      ..._summaries.map((CategoryLimitSummary item) => item.categoryName),
    };
    final bool changed = await _CategoryLimitFormSheet.show(
      context,
      repository: _repository,
      month: _selectedMonth,
      categories: categories.toList(growable: false),
      limit: limit,
      generalLimitCents: _plan?.spendingLimitCents,
    );
    if (changed) {
      notifyFinancialPlanChanged();
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<CategoryLimitSummary> configured = _summaries
        .where((CategoryLimitSummary item) => item.limit != null)
        .toList(growable: false);
    final List<CategoryLimitSummary> comparisons = _summaries
        .where(
          (CategoryLimitSummary item) =>
              item.spentCents > 0 || item.previousSpentCents > 0,
        )
        .toList(growable: false);
    final int categoryTotal = configured.fold<int>(
      0,
      (int total, CategoryLimitSummary item) => total + item.limit!.limitCents,
    );
    final String monthLabel = toBeginningOfSentenceCase(
      DateFormat("MMMM 'de' yyyy", 'pt_BR').format(_selectedMonth),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Limites por categoria')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openForm,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Definir limite'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
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
                            monthLabel,
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
                    const Divider(),
                    _SummaryRow(
                      label: 'Limite geral',
                      value: _plan == null
                          ? 'Não definido'
                          : _currency.format(_plan!.spendingLimit),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    _SummaryRow(
                      label: 'Distribuído nas categorias',
                      value: _currency.format(categoryTotal / 100),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      _plan == null
                          ? 'Os limites por categoria ajudam a acompanhar seus gastos, mas não substituem o limite geral.'
                          : 'A soma das categorias nunca pode ultrapassar o limite geral.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textMuted(context),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text('Categorias configuradas', style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(AppSpacing.xxl),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_errorMessage != null)
              _CategoryMessage(
                text: _errorMessage!,
                action: 'Tentar novamente',
                onPressed: _load,
              )
            else if (configured.isEmpty)
              _CategoryMessage(
                text:
                    'Nenhum limite por categoria foi definido neste mês. Comece pelas áreas que você quer acompanhar mais de perto.',
                action: 'Definir primeiro limite',
                onPressed: _openForm,
              )
            else
              ...configured.map((CategoryLimitSummary summary) {
                return _CategoryLimitCard(
                  summary: summary,
                  currency: _currency,
                  onTap: () => _openForm(summary.limit),
                );
              }),
            if (!_isLoading && comparisons.isNotEmpty) ...<Widget>[
              const SizedBox(height: AppSpacing.xl),
              Text(
                'Comparação com o mês anterior',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              Card(
                child: Column(
                  children: <Widget>[
                    for (int index = 0; index < comparisons.length; index++)
                      Column(
                        children: <Widget>[
                          ListTile(
                            leading: Icon(
                              _categoryIcon(comparisons[index].categoryName),
                              color: _categoryColor(
                                comparisons[index].categoryName,
                              ),
                            ),
                            title: Text(comparisons[index].categoryName),
                            subtitle: Text(
                              _comparisonText(comparisons[index], _currency),
                            ),
                            trailing: Text(
                              _currency.format(
                                comparisons[index].spentCents / 100,
                              ),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (index < comparisons.length - 1)
                            const Divider(height: 1, indent: 56),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CategoryLimitFormSheet extends StatefulWidget {
  const _CategoryLimitFormSheet({
    required this.repository,
    required this.month,
    required this.categories,
    required this.generalLimitCents,
    this.limit,
  });

  final CategoryLimitRepository repository;
  final DateTime month;
  final List<String> categories;
  final int? generalLimitCents;
  final CategoryLimit? limit;

  static Future<bool> show(
    BuildContext context, {
    required CategoryLimitRepository repository,
    required DateTime month,
    required List<String> categories,
    required int? generalLimitCents,
    CategoryLimit? limit,
  }) async {
    return await showModalBottomSheet<bool>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          builder: (_) => _CategoryLimitFormSheet(
            repository: repository,
            month: month,
            categories: categories,
            generalLimitCents: generalLimitCents,
            limit: limit,
          ),
        ) ??
        false;
  }

  @override
  State<_CategoryLimitFormSheet> createState() =>
      _CategoryLimitFormSheetState();
}

class _CategoryLimitFormSheetState extends State<_CategoryLimitFormSheet> {
  static const int _maximumCents = 999999999;
  final TextEditingController _amountController = TextEditingController();
  late String _category;
  late int _warningPercent;
  int _amountCents = 0;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _category = widget.limit?.categoryName ?? widget.categories.first;
    _warningPercent = widget.limit?.warningPercent ?? 70;
    _amountCents = widget.limit?.limitCents ?? 0;
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
    super.dispose();
  }

  void _readAmount() {
    final int value =
        int.tryParse(
          _amountController.text.replaceAll(RegExp(r'[^0-9]'), ''),
        ) ??
        0;
    if (value != _amountCents && mounted) setState(() => _amountCents = value);
  }

  Future<void> _save() async {
    if (_amountCents <= 0 || _isSaving) return;
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });
    try {
      await widget.repository.saveLimit(
        month: widget.month,
        categoryName: _category,
        limitCents: _amountCents,
        warningPercent: _warningPercent,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _errorMessage = _categoryError(error);
      });
    }
  }

  Future<void> _delete() async {
    final CategoryLimit? limit = widget.limit;
    if (limit == null || _isSaving) return;
    final bool confirmed =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) => AlertDialog(
            title: const Text('Remover limite?'),
            content: Text(
              'O acompanhamento de ${limit.categoryName} ficará sem limite neste mês. Os gastos não serão apagados.',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Remover'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    await widget.repository.deleteLimit(widget.month, limit.categoryName);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
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
              widget.limit == null ? 'Definir limite' : 'Editar limite',
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.xl),
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'Categoria'),
              items: widget.categories
                  .map(
                    (String category) => DropdownMenuItem<String>(
                      value: category,
                      child: Text(category),
                    ),
                  )
                  .toList(growable: false),
              onChanged: widget.limit == null
                  ? (String? value) {
                      if (value != null) setState(() => _category = value);
                    }
                  : null,
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _amountController,
              autofocus: widget.limit == null,
              keyboardType: TextInputType.number,
              inputFormatters: <TextInputFormatter>[
                CurrencyInputFormatter(maximumValueInCents: _maximumCents),
              ],
              decoration: InputDecoration(
                labelText: 'Limite da categoria',
                prefixText: 'R\$ ',
                helperText: widget.generalLimitCents == null
                    ? 'O limite geral ainda não foi definido.'
                    : 'Limite geral: ${NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$').format(widget.generalLimitCents! / 100)}',
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<int>(
              initialValue: _warningPercent,
              decoration: const InputDecoration(
                labelText: 'Avisar a partir de',
              ),
              items: _warningOptions
                  .map(
                    (int value) => DropdownMenuItem<int>(
                      value: value,
                      child: Text('$value% do limite'),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (int? value) {
                if (value != null) setState(() => _warningPercent = value);
              },
            ),
            if (_errorMessage != null) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              Text(
                _errorMessage!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.error,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              onPressed: !_isSaving && _amountCents > 0 ? _save : null,
              child: Text(_isSaving ? 'Salvando...' : 'Salvar limite'),
            ),
            if (widget.limit != null)
              TextButton(
                onPressed: _isSaving ? null : _delete,
                child: const Text('Remover limite'),
              ),
          ],
        ),
      ),
    );
  }
}

class _CategoryLimitCard extends StatelessWidget {
  const _CategoryLimitCard({
    required this.summary,
    required this.currency,
    required this.onTap,
  });

  final CategoryLimitSummary summary;
  final NumberFormat currency;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final CategoryLimit limit = summary.limit!;
    final Color statusColor = _statusColor(summary.status);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    CircleAvatar(
                      backgroundColor: _categoryColor(
                        summary.categoryName,
                      ).withValues(alpha: 0.14),
                      foregroundColor: _categoryColor(summary.categoryName),
                      child: Icon(_categoryIcon(summary.categoryName)),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            summary.categoryName,
                            style: theme.textTheme.titleMedium,
                          ),
                          Text(
                            _statusLabel(summary.status),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: statusColor,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.edit_outlined),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                LinearProgressIndicator(
                  value: (summary.progress ?? 0).clamp(0, 1),
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(99),
                  color: statusColor,
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        '${currency.format(summary.spentCents / 100)} gastos',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Text('de ${currency.format(limit.limitCents / 100)}'),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Alerta em ${limit.warningPercent}% · ${_comparisonText(summary, currency)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textMuted(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(child: Text(label)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _CategoryMessage extends StatelessWidget {
  const _CategoryMessage({
    required this.text,
    required this.action,
    required this.onPressed,
  });

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
            Icon(
              Icons.category_outlined,
              size: 42,
              color: AppColors.textMuted(context),
            ),
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

const List<String> _standardCategories = <String>[
  'Alimentação',
  'Transporte',
  'Moradia',
  'Compras',
  'Saúde',
  'Lazer',
  'Contas',
  'Outros',
];

const List<int> _warningOptions = <int>[50, 60, 70, 80, 90, 100];

String _comparisonText(CategoryLimitSummary summary, NumberFormat currency) {
  if (summary.previousSpentCents == 0 && summary.spentCents == 0) {
    return 'sem gastos nos dois meses';
  }
  if (summary.previousSpentCents == 0) {
    return 'sem gasto no mês anterior';
  }
  final int difference = summary.differenceCents;
  if (difference == 0) return 'igual ao mês anterior';
  return '${currency.format(difference.abs() / 100)} ${difference < 0 ? 'a menos' : 'a mais'} que no mês anterior';
}

String _categoryError(Object error) {
  if (error is StateError || error is ArgumentError) {
    return error.toString().replaceFirst(
      RegExp(r'^(Bad state|Invalid argument): '),
      '',
    );
  }
  return 'Não foi possível salvar o limite.';
}

Color _statusColor(CategoryLimitStatus status) => switch (status) {
  CategoryLimitStatus.comfortable => AppColors.success,
  CategoryLimitStatus.attention => AppColors.warning,
  CategoryLimitStatus.exceeded => AppColors.error,
  CategoryLimitStatus.unconfigured => AppColors.information,
};

String _statusLabel(CategoryLimitStatus status) => switch (status) {
  CategoryLimitStatus.comfortable => 'Dentro do planejado',
  CategoryLimitStatus.attention => 'Atenção ao limite',
  CategoryLimitStatus.exceeded => 'Limite ultrapassado',
  CategoryLimitStatus.unconfigured => 'Sem limite',
};

Color _categoryColor(String category) => switch (category) {
  'Alimentação' => AppColors.food,
  'Transporte' => AppColors.transport,
  'Moradia' => AppColors.housing,
  'Compras' => AppColors.shopping,
  'Saúde' => AppColors.health,
  'Lazer' => AppColors.leisure,
  'Contas' => AppColors.bills,
  _ => AppColors.other,
};

IconData _categoryIcon(String category) => switch (category) {
  'Alimentação' => Icons.restaurant_outlined,
  'Transporte' => Icons.directions_car_outlined,
  'Moradia' => Icons.home_outlined,
  'Compras' => Icons.shopping_bag_outlined,
  'Saúde' => Icons.medical_services_outlined,
  'Lazer' => Icons.sports_esports_outlined,
  'Contas' => Icons.receipt_long_outlined,
  _ => Icons.more_horiz_rounded,
};
