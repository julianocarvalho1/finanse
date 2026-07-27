import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/category_style.dart';
import '../../data/recurring_expense_repository.dart';
import '../../domain/recurring_expense.dart';
import '../recurring_expense_notifier.dart';

class RecurringExpenseForm extends StatefulWidget {
  const RecurringExpenseForm({super.key, this.recurringExpense});

  final RecurringExpense? recurringExpense;

  static Future<bool?> show(
    BuildContext context, {
    RecurringExpense? recurringExpense,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (BuildContext modalContext) {
        return RecurringExpenseForm(recurringExpense: recurringExpense);
      },
    );
  }

  @override
  State<RecurringExpenseForm> createState() {
    return _RecurringExpenseFormState();
  }
}

class _RecurringExpenseFormState extends State<RecurringExpenseForm> {
  static const String _customCategoryOption = 'Categoria personalizada';

  static const String _noPaymentMethod = '__not_informed__';

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

  static const List<String> _defaultPaymentMethods = <String>[
    'Pix',
    'Cartão de débito',
    'Cartão de crédito',
    'Dinheiro',
    'Boleto',
    'Transferência',
    'Débito automático',
  ];

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final RecurringExpenseRepository _repository = RecurringExpenseRepository();

  late final _BrazilianCurrencyInputFormatter _currencyInputFormatter;

  late final TextEditingController _amountController;
  late final TextEditingController _customCategoryController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _notesController;
  late final TextEditingController _customIntervalController;

  late String _selectedCategoryOption;
  late String _selectedPaymentMethod;

  late RecurringFrequency _frequency;
  late DateTime _nextDate;
  late bool _isActive;

  bool _isSaving = false;

  String? _categoryError;
  String? _saveError;

  bool get _isEditing {
    return widget.recurringExpense != null;
  }

  @override
  void initState() {
    super.initState();

    _currencyInputFormatter = _BrazilianCurrencyInputFormatter();

    final RecurringExpense? recurringExpense = widget.recurringExpense;

    final String existingCategory = recurringExpense?.categoryName.trim() ?? '';

    final bool hasDefaultCategory = _defaultCategories.contains(
      existingCategory,
    );

    _selectedCategoryOption = recurringExpense == null
        ? _defaultCategories.first
        : hasDefaultCategory
        ? existingCategory
        : _customCategoryOption;

    _amountController = TextEditingController(
      text: recurringExpense == null
          ? ''
          : _currencyInputFormatter.formatValue(recurringExpense.amount),
    );

    _customCategoryController = TextEditingController(
      text: hasDefaultCategory ? '' : existingCategory,
    );

    _descriptionController = TextEditingController(
      text: recurringExpense?.description ?? '',
    );

    _notesController = TextEditingController(
      text: recurringExpense?.notes ?? '',
    );

    _customIntervalController = TextEditingController(
      text: recurringExpense?.customIntervalDays?.toString() ?? '',
    );

    _selectedPaymentMethod =
        recurringExpense?.paymentMethod?.trim().isNotEmpty == true
        ? recurringExpense!.paymentMethod!.trim()
        : _noPaymentMethod;

    _frequency = recurringExpense?.frequency ?? RecurringFrequency.monthly;

    _nextDate =
        recurringExpense?.nextDate ??
        DateTime.now().add(const Duration(days: 1));

    _isActive = recurringExpense?.isActive ?? true;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _customCategoryController.dispose();
    _descriptionController.dispose();
    _notesController.dispose();
    _customIntervalController.dispose();

    super.dispose();
  }

  List<String> get _availablePaymentMethods {
    final List<String> paymentMethods = <String>[..._defaultPaymentMethods];

    if (_selectedPaymentMethod != _noPaymentMethod &&
        !paymentMethods.contains(_selectedPaymentMethod)) {
      paymentMethods.add(_selectedPaymentMethod);
    }

    return paymentMethods;
  }

  double _amountFromInput() {
    final String digits = _amountController.text.replaceAll(
      RegExp(r'[^0-9]'),
      '',
    );

    if (digits.isEmpty) {
      return 0;
    }

    final int valueInCents = int.tryParse(digits) ?? 0;

    return valueInCents / 100;
  }

  String _resolvedCategory() {
    if (_selectedCategoryOption != _customCategoryOption) {
      return _selectedCategoryOption.trim();
    }

    return _customCategoryController.text.trim();
  }

  String? _emptyToNull(String value) {
    final String normalizedValue = value.trim();

    if (normalizedValue.isEmpty) {
      return null;
    }

    return normalizedValue;
  }

  Future<void> _pickNextDate() async {
    HapticFeedback.selectionClick();

    final DateTime now = DateTime.now();

    final DateTime? selectedDate = await showDatePicker(
      context: context,
      initialDate: _nextDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 20, 12, 31),
      helpText: 'Selecionar próxima data',
      cancelText: 'Cancelar',
      confirmText: 'Confirmar',
    );

    if (selectedDate == null || !mounted) {
      return;
    }

    setState(() {
      _nextDate = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
        _nextDate.hour,
        _nextDate.minute,
      );
    });
  }

  Future<void> _pickNextTime() async {
    HapticFeedback.selectionClick();

    final TimeOfDay initialTime = TimeOfDay.fromDateTime(_nextDate);

    final TimeOfDay? selectedTime = await showTimePicker(
      context: context,
      initialTime: initialTime,
      helpText: 'Selecionar horário',
      cancelText: 'Cancelar',
      confirmText: 'Confirmar',
    );

    if (selectedTime == null || !mounted) {
      return;
    }

    setState(() {
      _nextDate = DateTime(
        _nextDate.year,
        _nextDate.month,
        _nextDate.day,
        selectedTime.hour,
        selectedTime.minute,
      );
    });
  }

  Future<void> _save() async {
    if (_isSaving) {
      return;
    }

    FocusScope.of(context).unfocus();

    final bool formIsValid = _formKey.currentState?.validate() ?? false;

    final String categoryName = _resolvedCategory();

    if (categoryName.isEmpty) {
      setState(() {
        _categoryError = 'Informe o nome da categoria personalizada.';
      });
    } else {
      setState(() {
        _categoryError = null;
      });
    }

    if (!formIsValid || categoryName.isEmpty) {
      return;
    }

    final double amount = _amountFromInput();

    final int? customIntervalDays = _frequency == RecurringFrequency.custom
        ? int.tryParse(_customIntervalController.text.trim())
        : null;

    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);

    final NavigatorState navigator = Navigator.of(context);

    setState(() {
      _isSaving = true;
      _saveError = null;
    });

    try {
      final DateTime now = DateTime.now();

      final String? paymentMethod = _selectedPaymentMethod == _noPaymentMethod
          ? null
          : _selectedPaymentMethod;

      final RecurringExpense? existingExpense = widget.recurringExpense;

      if (existingExpense == null) {
        final RecurringExpense recurringExpense = RecurringExpense(
          id: 'recurring_${now.microsecondsSinceEpoch}',
          amount: amount,
          categoryName: categoryName,
          description: _emptyToNull(_descriptionController.text),
          notes: _emptyToNull(_notesController.text),
          paymentMethod: paymentMethod,
          frequency: _frequency,
          customIntervalDays: customIntervalDays,
          nextDate: _nextDate,
          isActive: _isActive,
          registeredCount: 0,
          createdAt: now,
          updatedAt: now,
        );

        await _repository.insertRecurringExpense(recurringExpense);
      } else {
        final RecurringExpense updatedExpense = existingExpense.copyWith(
          amount: amount,
          categoryName: categoryName,
          description: _emptyToNull(_descriptionController.text),
          notes: _emptyToNull(_notesController.text),
          paymentMethod: paymentMethod,
          frequency: _frequency,
          customIntervalDays: customIntervalDays,
          nextDate: _nextDate,
          isActive: _isActive,
          updatedAt: now,
        );

        await _repository.updateRecurringExpense(updatedExpense);
      }

      recurringExpenseNotifier.notify();

      if (!mounted) {
        return;
      }

      navigator.pop(true);

      messenger.clearSnackBars();

      messenger.showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 4),
          persist: false,
          dismissDirection: DismissDirection.down,
          content: Row(
            children: <Widget>[
              const Icon(
                Icons.check_circle_rounded,
                color: Colors.white,
                size: 22,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  _isEditing
                      ? 'Despesa recorrente atualizada.'
                      : 'Despesa recorrente criada.',
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

      setState(() {
        _isSaving = false;
        _saveError = _isEditing
            ? 'Não foi possível atualizar a recorrência.'
            : 'Não foi possível criar a recorrência.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    final double keyboardHeight = MediaQuery.viewInsetsOf(context).bottom;

    return PopScope(
      canPop: !_isSaving,
      child: SafeArea(
        top: false,
        child: AnimatedPadding(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: EdgeInsets.only(bottom: keyboardHeight),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.pageHorizontal,
              AppSpacing.sm,
              AppSpacing.pageHorizontal,
              AppSpacing.xl,
            ),
            child: Form(
              key: _formKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    _isEditing
                        ? 'Editar despesa recorrente'
                        : 'Nova despesa recorrente',
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    _isEditing
                        ? 'Altere os dados e salve as mudanças.'
                        : 'O gasto será registrado somente quando você confirmar o pagamento.',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  _SectionTitle(icon: Icons.payments_rounded, title: 'Valor'),
                  const SizedBox(height: AppSpacing.sm),
                  TextFormField(
                    controller: _amountController,
                    autofocus: !_isEditing,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: false,
                    ),
                    textInputAction: TextInputAction.next,
                    inputFormatters: <TextInputFormatter>[
                      _currencyInputFormatter,
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Valor da recorrência',
                      hintText: '0,00',
                      prefixText: 'R\$ ',
                      prefixIcon: Icon(Icons.attach_money_rounded),
                    ),
                    validator: (String? value) {
                      if (_amountFromInput() <= 0) {
                        return 'Informe um valor maior que zero.';
                      }

                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  _SectionTitle(
                    icon: Icons.category_rounded,
                    title: 'Categoria',
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: <Widget>[
                      ..._defaultCategories.map((String category) {
                        final CategoryStyle categoryStyle =
                            CategoryStyles.fromName(category);

                        return ChoiceChip(
                          selected: _selectedCategoryOption == category,
                          avatar: Icon(
                            categoryStyle.icon,
                            size: 18,
                            color: _selectedCategoryOption == category
                                ? theme.colorScheme.onPrimary
                                : categoryStyle.color,
                          ),
                          label: Text(category),
                          onSelected: (_) {
                            HapticFeedback.selectionClick();

                            setState(() {
                              _selectedCategoryOption = category;
                              _categoryError = null;
                            });
                          },
                        );
                      }),
                      ChoiceChip(
                        selected:
                            _selectedCategoryOption == _customCategoryOption,
                        avatar: Icon(
                          Icons.add_rounded,
                          size: 18,
                          color:
                              _selectedCategoryOption == _customCategoryOption
                              ? theme.colorScheme.onPrimary
                              : theme.colorScheme.primary,
                        ),
                        label: const Text('Personalizada'),
                        onSelected: (_) {
                          HapticFeedback.selectionClick();

                          setState(() {
                            _selectedCategoryOption = _customCategoryOption;
                            _categoryError = null;
                          });
                        },
                      ),
                    ],
                  ),
                  if (_selectedCategoryOption ==
                      _customCategoryOption) ...<Widget>[
                    const SizedBox(height: AppSpacing.md),
                    TextFormField(
                      controller: _customCategoryController,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.next,
                      maxLength: 30,
                      decoration: InputDecoration(
                        labelText: 'Nome da categoria',
                        hintText: 'Ex.: Assinaturas',
                        prefixIcon: const Icon(Icons.label_rounded),
                        errorText: _categoryError,
                      ),
                      onChanged: (_) {
                        if (_categoryError != null) {
                          setState(() {
                            _categoryError = null;
                          });
                        }
                      },
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xl),
                  _SectionTitle(icon: Icons.repeat_rounded, title: 'Repetição'),
                  const SizedBox(height: AppSpacing.sm),
                  DropdownButtonFormField<RecurringFrequency>(
                    value: _frequency,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Frequência',
                      prefixIcon: Icon(Icons.autorenew_rounded),
                    ),
                    items: RecurringFrequency.values
                        .map((RecurringFrequency frequency) {
                          return DropdownMenuItem<RecurringFrequency>(
                            value: frequency,
                            child: Text(frequency.label),
                          );
                        })
                        .toList(growable: false),
                    onChanged: (RecurringFrequency? frequency) {
                      if (frequency == null) {
                        return;
                      }

                      HapticFeedback.selectionClick();

                      setState(() {
                        _frequency = frequency;
                      });
                    },
                  ),
                  if (_frequency == RecurringFrequency.custom) ...<Widget>[
                    const SizedBox(height: AppSpacing.md),
                    TextFormField(
                      controller: _customIntervalController,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(4),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Intervalo em dias',
                        hintText: 'Ex.: 10',
                        prefixIcon: Icon(Icons.timelapse_rounded),
                        suffixText: 'dias',
                      ),
                      validator: (String? value) {
                        if (_frequency != RecurringFrequency.custom) {
                          return null;
                        }

                        final int interval =
                            int.tryParse(value?.trim() ?? '') ?? 0;

                        if (interval <= 0) {
                          return 'Informe um intervalo maior que zero.';
                        }

                        return null;
                      },
                    ),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  _DateTimeSelector(
                    icon: Icons.event_rounded,
                    label: 'Próxima data',
                    value: DateFormat(
                      "dd 'de' MMMM 'de' yyyy",
                      'pt_BR',
                    ).format(_nextDate),
                    onTap: _pickNextDate,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _DateTimeSelector(
                    icon: Icons.schedule_rounded,
                    label: 'Horário',
                    value: DateFormat('HH:mm').format(_nextDate),
                    onTap: _pickNextTime,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  _SectionTitle(
                    icon: Icons.description_rounded,
                    title: 'Detalhes',
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextFormField(
                    controller: _descriptionController,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.next,
                    maxLength: 80,
                    decoration: const InputDecoration(
                      labelText: 'Descrição',
                      hintText: 'Ex.: Internet residencial',
                      prefixIcon: Icon(Icons.edit_note_rounded),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextFormField(
                    controller: _notesController,
                    textCapitalization: TextCapitalization.sentences,
                    keyboardType: TextInputType.multiline,
                    minLines: 2,
                    maxLines: 4,
                    maxLength: 250,
                    decoration: const InputDecoration(
                      labelText: 'Observação',
                      hintText: 'Informação adicional opcional',
                      alignLabelWithHint: true,
                      prefixIcon: Icon(Icons.notes_rounded),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  DropdownButtonFormField<String>(
                    value: _selectedPaymentMethod,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Forma de pagamento',
                      prefixIcon: Icon(Icons.account_balance_wallet_rounded),
                    ),
                    items: <DropdownMenuItem<String>>[
                      const DropdownMenuItem<String>(
                        value: _noPaymentMethod,
                        child: Text('Não informado'),
                      ),
                      ..._availablePaymentMethods.map((String paymentMethod) {
                        return DropdownMenuItem<String>(
                          value: paymentMethod,
                          child: Text(paymentMethod),
                        );
                      }),
                    ],
                    onChanged: (String? paymentMethod) {
                      if (paymentMethod == null) {
                        return;
                      }

                      setState(() {
                        _selectedPaymentMethod = paymentMethod;
                      });
                    },
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surfaceSecondary(context),
                      borderRadius: BorderRadius.circular(
                        AppSpacing.inputRadius,
                      ),
                      border: Border.all(color: AppColors.border(context)),
                    ),
                    child: SwitchListTile.adaptive(
                      value: _isActive,
                      title: Text(
                        _isActive ? 'Recorrência ativa' : 'Recorrência pausada',
                        style: theme.textTheme.titleSmall,
                      ),
                      subtitle: Text(
                        _isActive
                            ? 'Ela aparecerá entre os próximos pagamentos.'
                            : 'Ela continuará salva, mas não ficará pendente.',
                      ),
                      secondary: Icon(
                        _isActive
                            ? Icons.notifications_active_rounded
                            : Icons.pause_circle_outline_rounded,
                        color: _isActive
                            ? theme.colorScheme.primary
                            : AppColors.textMuted(context),
                      ),
                      onChanged: (bool value) {
                        HapticFeedback.selectionClick();

                        setState(() {
                          _isActive = value;
                        });
                      },
                    ),
                  ),
                  if (_saveError != null) ...<Widget>[
                    const SizedBox(height: AppSpacing.lg),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(
                          AppSpacing.inputRadius,
                        ),
                        border: Border.all(
                          color: AppColors.error.withValues(alpha: 0.40),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const Icon(
                            Icons.error_outline_rounded,
                            color: AppColors.error,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              _saveError!,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: AppColors.error,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xl),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _isSaving ? null : _save,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.3,
                                color: Colors.white,
                              ),
                            )
                          : Icon(
                              _isEditing
                                  ? Icons.save_rounded
                                  : Icons.add_rounded,
                            ),
                      label: Text(
                        _isSaving
                            ? 'Salvando...'
                            : _isEditing
                            ? 'Salvar alterações'
                            : 'Criar recorrência',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Row(
      children: <Widget>[
        Icon(icon, size: 21, color: theme.colorScheme.primary),
        const SizedBox(width: AppSpacing.xs),
        Text(title, style: theme.textTheme.titleMedium),
      ],
    );
  }
}

class _DateTimeSelector extends StatelessWidget {
  const _DateTimeSelector({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Material(
      color: AppColors.surfaceSecondary(context),
      borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
            border: Border.all(color: AppColors.border(context)),
          ),
          child: Row(
            children: <Widget>[
              Icon(icon, color: theme.colorScheme.primary),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(label, style: theme.textTheme.labelMedium),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      value,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _BrazilianCurrencyInputFormatter extends TextInputFormatter {
  _BrazilianCurrencyInputFormatter()
    : _formatter = NumberFormat.currency(
        locale: 'pt_BR',
        symbol: '',
        decimalDigits: 2,
      );

  final NumberFormat _formatter;

  String formatValue(double value) {
    return _formatter.format(value).trim();
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final String digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');

    if (digits.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }

    final int valueInCents = int.tryParse(digits) ?? 0;

    final double value = valueInCents / 100;

    final String formattedValue = _formatter.format(value).trim();

    return TextEditingValue(
      text: formattedValue,
      selection: TextSelection.collapsed(offset: formattedValue.length),
    );
  }
}
