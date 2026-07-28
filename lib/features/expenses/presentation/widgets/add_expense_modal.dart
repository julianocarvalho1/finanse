import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/category_style.dart';
import '../../../../core/utils/expense_notifier.dart';
import '../../data/expense_repository.dart';
import '../../domain/expense.dart';

class AddExpenseModal extends StatefulWidget {
  const AddExpenseModal({super.key, this.expenseToEdit});

  final Expense? expenseToEdit;

  static void show(BuildContext context, {Expense? expense}) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: false,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (BuildContext modalContext) {
        return AnimatedPadding(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(modalContext).bottom,
          ),
          child: AddExpenseModal(expenseToEdit: expense),
        );
      },
    );
  }

  @override
  State<AddExpenseModal> createState() {
    return _AddExpenseModalState();
  }
}

class _AddExpenseModalState extends State<AddExpenseModal> {
  static const int _maximumAmountInCents = 99999999;

  static const List<String> _defaultCategories = <String>[
    'Alimentação',
    'Transporte',
    'Moradia',
    'Compras',
    'Saúde',
    'Lazer',
    'Contas',
    'Outros',
  ];

  final ExpenseRepository _repository = ExpenseRepository();

  final TextEditingController _descriptionController = TextEditingController();

  final TextEditingController _notesController = TextEditingController();

  final FocusNode _descriptionFocusNode = FocusNode();

  late final NumberFormat _currencyFormatter;
  late final List<String> _categories;

  int _amountInCents = 0;
  String _selectedCategory = 'Alimentação';
  DateTime _selectedDateTime = DateTime.now();

  bool _showDetails = false;
  bool _isSaving = false;

  Expense? get _originalExpense => widget.expenseToEdit;

  bool get _isEditing => _originalExpense != null;

  double get _amount {
    return _amountInCents / 100;
  }

  bool get _canSave {
    return !_isSaving &&
        _amountInCents > 0 &&
        _selectedCategory.trim().isNotEmpty;
  }

  @override
  void initState() {
    super.initState();

    _currencyFormatter = NumberFormat.currency(
      locale: 'pt_BR',
      symbol: 'R\$',
      decimalDigits: 2,
    );

    _categories = List<String>.from(_defaultCategories);

    final Expense? expense = _originalExpense;

    if (expense == null) {
      return;
    }

    _amountInCents = (expense.amount * 100).round();
    _selectedCategory = expense.categoryName;
    _selectedDateTime = expense.date;

    _descriptionController.text = expense.description?.trim() ?? '';

    _notesController.text = expense.notes?.trim() ?? '';

    if (!_categories.contains(_selectedCategory)) {
      _categories.add(_selectedCategory);
    }

    _showDetails = true;
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _notesController.dispose();
    _descriptionFocusNode.dispose();
    super.dispose();
  }

  void _onNumberPressed(String value) {
    if (_isSaving) {
      return;
    }

    HapticFeedback.selectionClick();

    setState(() {
      if (value == '00') {
        if (_amountInCents == 0) {
          return;
        }

        final int newValue = _amountInCents * 100;

        if (newValue <= _maximumAmountInCents) {
          _amountInCents = newValue;
        }

        return;
      }

      final int? digit = int.tryParse(value);

      if (digit == null) {
        return;
      }

      final int newValue = (_amountInCents * 10) + digit;

      if (newValue <= _maximumAmountInCents) {
        _amountInCents = newValue;
      }
    });
  }

  void _onBackspacePressed() {
    if (_isSaving) {
      return;
    }

    HapticFeedback.selectionClick();

    setState(() {
      _amountInCents ~/= 10;
    });
  }

  void _clearAmount() {
    if (_isSaving || _amountInCents == 0) {
      return;
    }

    HapticFeedback.mediumImpact();

    setState(() {
      _amountInCents = 0;
    });
  }

  void _selectCategory(String categoryName) {
    if (_isSaving || categoryName == _selectedCategory) {
      return;
    }

    HapticFeedback.selectionClick();

    setState(() {
      _selectedCategory = categoryName;
    });
  }

  void _showDetailsAndFocusDescription() {
    setState(() {
      _showDetails = true;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      _descriptionFocusNode.requestFocus();
    });
  }

  void _showDetailsWithoutFocus() {
    if (_showDetails) {
      return;
    }

    setState(() {
      _showDetails = true;
    });
  }

  void _hideDetails() {
    FocusScope.of(context).unfocus();

    setState(() {
      _showDetails = false;
    });
  }

  Future<void> _pickDate() async {
    final DateTime initialDate = DateTime(
      _selectedDateTime.year,
      _selectedDateTime.month,
      _selectedDateTime.day,
    );

    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
      helpText: 'Selecionar data do gasto',
      cancelText: 'Cancelar',
      confirmText: 'Confirmar',
    );

    if (pickedDate == null || !mounted) {
      return;
    }

    setState(() {
      _selectedDateTime = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        _selectedDateTime.hour,
        _selectedDateTime.minute,
      );
    });
  }

  Future<void> _pickTime() async {
    final TimeOfDay initialTime = TimeOfDay.fromDateTime(_selectedDateTime);

    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: initialTime,
      helpText: 'Selecionar horário do gasto',
      cancelText: 'Cancelar',
      confirmText: 'Confirmar',
    );

    if (pickedTime == null || !mounted) {
      return;
    }

    setState(() {
      _selectedDateTime = DateTime(
        _selectedDateTime.year,
        _selectedDateTime.month,
        _selectedDateTime.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
  }

  Future<void> _saveExpense() async {
    if (!_canSave) {
      return;
    }

    FocusScope.of(context).unfocus();

    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);

    final NavigatorState navigator = Navigator.of(context);

    final Expense? previousExpense = _originalExpense;
    final DateTime now = DateTime.now();

    final Expense savedExpense = Expense(
      id: previousExpense?.id ?? now.microsecondsSinceEpoch.toString(),
      amount: _amount,
      categoryName: _selectedCategory.trim(),
      description: _normalizedText(_descriptionController.text),
      notes: _normalizedText(_notesController.text),
      date: _selectedDateTime,
      paymentMethod: previousExpense?.paymentMethod,
      isRecurring: previousExpense?.isRecurring ?? false,
      createdAt: previousExpense?.createdAt ?? now,
      updatedAt: now,
    );

    setState(() {
      _isSaving = true;
    });

    try {
      if (_isEditing) {
        await _repository.updateExpense(savedExpense);
      } else {
        await _repository.insertExpense(savedExpense);
      }

      expenseNotifier.value++;

      if (mounted) {
        navigator.pop();
      }

      _showSuccessMessage(
        messenger: messenger,
        savedExpense: savedExpense,
        previousExpense: previousExpense,
      );
    } catch (error) {
      _showErrorMessage(messenger, _friendlyErrorMessage(error));
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _showSuccessMessage({
    required ScaffoldMessengerState messenger,
    required Expense savedExpense,
    required Expense? previousExpense,
  }) {
    final String formattedAmount = _currencyFormatter.format(
      savedExpense.amount,
    );

    final String message = _isEditing
        ? '$formattedAmount atualizado em ${savedExpense.categoryName}.'
        : '$formattedAmount salvo em ${savedExpense.categoryName}.';

    messenger.clearSnackBars();

    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 5),
        persist: false,
        showCloseIcon: false,
        dismissDirection: DismissDirection.down,

        // Impede que o botão "Desfazer" seja jogado para outra linha.
        actionOverflowThreshold: 1,

        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),

        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.check_circle_rounded,
              color: Colors.white,
              size: 22,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                message,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        action: SnackBarAction(
          label: 'Desfazer',
          textColor: Theme.of(messenger.context).colorScheme.primary,
          onPressed: () {
            _undoSave(
              messenger: messenger,
              savedExpense: savedExpense,
              previousExpense: previousExpense,
            );
          },
        ),
      ),
    );
  }

  Future<void> _undoSave({
    required ScaffoldMessengerState messenger,
    required Expense savedExpense,
    required Expense? previousExpense,
  }) async {
    messenger.hideCurrentSnackBar();

    try {
      if (previousExpense == null) {
        await _repository.deleteExpense(savedExpense.id);
      } else {
        await _repository.updateExpense(previousExpense);
      }

      expenseNotifier.value++;

      messenger.showSnackBar(
        const SnackBar(
          content: Row(
            children: <Widget>[
              Icon(Icons.undo_rounded, color: Colors.white),
              SizedBox(width: AppSpacing.sm),
              Expanded(child: Text('Alteração desfeita.')),
            ],
          ),
        ),
      );
    } catch (_) {
      _showErrorMessage(messenger, 'Não foi possível desfazer a alteração.');
    }
  }

  void _showErrorMessage(ScaffoldMessengerState messenger, String message) {
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

  String _friendlyErrorMessage(Object error) {
    final String errorText = error.toString().toLowerCase();

    if (errorText.contains('database') || errorText.contains('sqlite')) {
      return 'Não foi possível acessar os dados do aplicativo.';
    }

    if (errorText.contains('not found') ||
        errorText.contains('não foi encontrado')) {
      return 'O gasto não foi encontrado. Atualize a tela e tente novamente.';
    }

    return _isEditing
        ? 'Não foi possível atualizar o gasto.'
        : 'Não foi possível salvar o gasto.';
  }

  String? _normalizedText(String value) {
    final String normalizedValue = value.trim();

    if (normalizedValue.isEmpty) {
      return null;
    }

    return normalizedValue;
  }

  String _formattedDate() {
    final DateTime now = DateTime.now();
    final DateTime yesterday = now.subtract(const Duration(days: 1));

    if (DateUtils.isSameDay(_selectedDateTime, now)) {
      return 'Hoje';
    }

    if (DateUtils.isSameDay(_selectedDateTime, yesterday)) {
      return 'Ontem';
    }

    return DateFormat('dd/MM/yyyy').format(_selectedDateTime);
  }

  String _formattedTime() {
    return DateFormat('HH:mm').format(_selectedDateTime);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    final Color primaryColor = theme.colorScheme.primary;
    final Color surfaceColor = AppColors.surface(context);
    final Color secondarySurface = AppColors.surfaceSecondary(context);
    final Color borderColor = AppColors.border(context);
    final Color textPrimary = AppColors.textPrimary(context);
    final Color textSecondary = AppColors.textSecondary(context);
    final Color textMuted = AppColors.textMuted(context);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.92,
      ),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppSpacing.modalRadius),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.sm,
            AppSpacing.xl,
            AppSpacing.xl,
          ),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: borderColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      _isEditing ? 'Editar gasto' : 'Novo gasto',
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _isSaving ? null : _showDetailsWithoutFocus,
                    icon: Icon(
                      Icons.schedule_rounded,
                      size: 17,
                      color: primaryColor,
                    ),
                    label: Text(
                      '${_formattedDate()}, ${_formattedTime()}',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: primaryColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.md,
                  horizontal: AppSpacing.lg,
                ),
                decoration: BoxDecoration(
                  color: secondarySurface,
                  borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
                  border: Border.all(
                    color: _amountInCents > 0
                        ? primaryColor.withValues(alpha: 0.45)
                        : borderColor,
                    width: _amountInCents > 0 ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Valor',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _currencyFormatter.format(_amount),
                        maxLines: 1,
                        style: theme.textTheme.displaySmall?.copyWith(
                          color: textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                'Categoria',
                style: theme.textTheme.titleSmall?.copyWith(color: textPrimary),
              ),
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                height: 94,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _categories.length,
                  separatorBuilder: (_, _) {
                    return const SizedBox(width: AppSpacing.sm);
                  },
                  itemBuilder: (BuildContext context, int index) {
                    final String categoryName = _categories[index];

                    final CategoryStyle categoryStyle = CategoryStyles.fromName(
                      categoryName,
                    );

                    final bool isSelected = categoryName == _selectedCategory;

                    return _CategoryButton(
                      name: categoryName,
                      style: categoryStyle,
                      selected: isSelected,
                      primaryColor: primaryColor,
                      surfaceColor: secondarySurface,
                      borderColor: borderColor,
                      textColor: textSecondary,
                      onTap: () {
                        _selectCategory(categoryName);
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              if (!_showDetails)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _isSaving
                        ? null
                        : _showDetailsAndFocusDescription,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Adicionar detalhes'),
                  ),
                )
              else
                _buildDetailsSection(
                  theme: theme,
                  primaryColor: primaryColor,
                  secondarySurface: secondarySurface,
                  borderColor: borderColor,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  textMuted: textMuted,
                ),
              const SizedBox(height: AppSpacing.lg),
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: secondarySurface,
                  borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  children: <Widget>[
                    _buildKeypadRow(
                      <String>['1', '2', '3'],
                      textPrimary,
                      surfaceColor,
                      borderColor,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    _buildKeypadRow(
                      <String>['4', '5', '6'],
                      textPrimary,
                      surfaceColor,
                      borderColor,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    _buildKeypadRow(
                      <String>['7', '8', '9'],
                      textPrimary,
                      surfaceColor,
                      borderColor,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: _buildNumberButton(
                            value: '00',
                            textColor: textPrimary,
                            surfaceColor: surfaceColor,
                            borderColor: borderColor,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: _buildNumberButton(
                            value: '0',
                            textColor: textPrimary,
                            surfaceColor: surfaceColor,
                            borderColor: borderColor,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: Semantics(
                            button: true,
                            label: 'Apagar número',
                            hint: 'Mantenha pressionado para limpar o valor',
                            child: Material(
                              color: surfaceColor,
                              borderRadius: BorderRadius.circular(
                                AppSpacing.inputRadius,
                              ),
                              child: InkWell(
                                onTap: _onBackspacePressed,
                                onLongPress: _clearAmount,
                                borderRadius: BorderRadius.circular(
                                  AppSpacing.inputRadius,
                                ),
                                child: Container(
                                  height: 54,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(
                                      AppSpacing.inputRadius,
                                    ),
                                    border: Border.all(color: borderColor),
                                  ),
                                  child: Icon(
                                    Icons.backspace_rounded,
                                    color: textPrimary,
                                    size: 21,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _canSave ? _saveExpense : null,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 160),
                    child: _isSaving
                        ? SizedBox(
                            key: const ValueKey<String>('loading'),
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              color: theme.colorScheme.onPrimary,
                            ),
                          )
                        : Text(
                            key: const ValueKey<String>('label'),
                            _isEditing ? 'Salvar alterações' : 'Salvar gasto',
                          ),
                  ),
                ),
              ),
              if (_amountInCents == 0) ...<Widget>[
                const SizedBox(height: AppSpacing.xs),
                Center(
                  child: Text(
                    'Informe um valor maior que R\$ 0,00.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: textMuted,
                    ),
                  ),
                ),
              ],
              if (!isDark) const SizedBox(height: AppSpacing.xxs),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailsSection({
    required ThemeData theme,
    required Color primaryColor,
    required Color secondarySurface,
    required Color borderColor,
    required Color textPrimary,
    required Color textSecondary,
    required Color textMuted,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: secondarySurface,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Detalhes opcionais',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: textPrimary,
                  ),
                ),
              ),
              IconButton(
                onPressed: _isSaving ? null : _hideDetails,
                tooltip: 'Ocultar detalhes',
                icon: const Icon(Icons.expand_less_rounded),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          TextField(
            controller: _descriptionController,
            focusNode: _descriptionFocusNode,
            enabled: !_isSaving,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.next,
            maxLength: 80,
            decoration: const InputDecoration(
              labelText: 'Descrição ou local',
              hintText: 'Ex.: almoço, mercado, farmácia',
              prefixIcon: Icon(Icons.edit_note_rounded),
              counterText: '',
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _notesController,
            enabled: !_isSaving,
            textCapitalization: TextCapitalization.sentences,
            keyboardType: TextInputType.multiline,
            minLines: 2,
            maxLines: 4,
            maxLength: 300,
            decoration: const InputDecoration(
              labelText: 'Observação',
              hintText: 'Informações adicionais sobre o gasto',
              alignLabelWithHint: true,
              prefixIcon: Icon(Icons.notes_rounded),
              counterText: '',
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isSaving ? null : _pickDate,
                  icon: const Icon(Icons.calendar_today_rounded, size: 18),
                  label: Text(
                    _formattedDate(),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isSaving ? null : _pickTime,
                  icon: const Icon(Icons.schedule_rounded, size: 18),
                  label: Text(_formattedTime()),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Descrição, observação, data e horário podem ser '
            'alterados sem deixar o registro principal mais lento.',
            style: theme.textTheme.bodySmall?.copyWith(color: textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildKeypadRow(
    List<String> values,
    Color textColor,
    Color surfaceColor,
    Color borderColor,
  ) {
    return Row(
      children: <Widget>[
        for (int index = 0; index < values.length; index++) ...<Widget>[
          if (index > 0) const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: _buildNumberButton(
              value: values[index],
              textColor: textColor,
              surfaceColor: surfaceColor,
              borderColor: borderColor,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildNumberButton({
    required String value,
    required Color textColor,
    required Color surfaceColor,
    required Color borderColor,
  }) {
    return Semantics(
      button: true,
      label: 'Número $value',
      child: Material(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
        child: InkWell(
          onTap: () {
            _onNumberPressed(value);
          },
          borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
          child: Container(
            height: 54,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
              border: Border.all(color: borderColor),
            ),
            child: Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: textColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryButton extends StatelessWidget {
  const _CategoryButton({
    required this.name,
    required this.style,
    required this.selected,
    required this.primaryColor,
    required this.surfaceColor,
    required this.borderColor,
    required this.textColor,
    required this.onTap,
  });

  final String name;
  final CategoryStyle style;
  final bool selected;
  final Color primaryColor;
  final Color surfaceColor;
  final Color borderColor;
  final Color textColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Semantics(
      button: true,
      selected: selected,
      label: 'Categoria $name',
      child: Material(
        color: selected ? primaryColor.withValues(alpha: 0.13) : surfaceColor,
        borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 170),
            width: 82,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xs,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
              border: Border.all(
                color: selected ? primaryColor : borderColor,
                width: selected ? 2 : 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Stack(
                  clipBehavior: Clip.none,
                  children: <Widget>[
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: style.color.withValues(alpha: 0.14),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(style.icon, color: style.color, size: 23),
                    ),
                    if (selected)
                      Positioned(
                        right: -3,
                        top: -3,
                        child: Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            color: primaryColor,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Theme.of(context).colorScheme.surface,
                              width: 2,
                            ),
                          ),
                          child: Icon(
                            Icons.check_rounded,
                            size: 11,
                            color: theme.colorScheme.onPrimary,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: selected ? primaryColor : textColor,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
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
