import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/expense_repository.dart';
import '../../domain/expense.dart';
import '../../../../core/utils/expense_notifier.dart';

class AddExpenseModal extends StatefulWidget {
  final Expense? expenseToEdit;

  const AddExpenseModal({super.key, this.expenseToEdit});

  static void show(BuildContext context, {Expense? expense}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: AddExpenseModal(expenseToEdit: expense),
      ),
    );
  }

  @override
  State<AddExpenseModal> createState() => _AddExpenseModalState();
}

class _AddExpenseModalState extends State<AddExpenseModal> {
  double _amount = 0.0;
  String _selectedCategory = 'Alimentação';
  String _description = '';
  bool _showDescriptionField = false;
  DateTime _selectedDate = DateTime.now();

  final List<Map<String, dynamic>> _categories = [
    {'name': 'Alimentação', 'icon': Icons.restaurant_rounded, 'color': AppColors.primary},
    {'name': 'Transporte', 'icon': Icons.directions_car_rounded, 'color': AppColors.blue},
    {'name': 'Moradia', 'icon': Icons.home_rounded, 'color': AppColors.orange},
    {'name': 'Compras', 'icon': Icons.shopping_bag_rounded, 'color': AppColors.pink},
    {'name': 'Saúde', 'icon': Icons.favorite_rounded, 'color': AppColors.red},
    {'name': 'Lazer', 'icon': Icons.sports_esports_rounded, 'color': AppColors.purple},
    {'name': 'Contas', 'icon': Icons.receipt_rounded, 'color': AppColors.blue},
  ];

  @override
  void initState() {
    super.initState();
    if (widget.expenseToEdit != null) {
      _amount = widget.expenseToEdit!.amount;
      _selectedCategory = widget.expenseToEdit!.categoryName;
      _description = widget.expenseToEdit!.description ?? '';
      _selectedDate = widget.expenseToEdit!.date;
      if (_description.isNotEmpty) {
        _showDescriptionField = true;
      }
    }
  }

  void _onKeyPressed(String value) {
    HapticFeedback.lightImpact();
    setState(() {
      if (value == 'backspace') {
        _amount = (_amount / 10).floor() / 100;
      } else {
        final intDigit = int.parse(value);
        if (_amount < 1000000) {
          _amount = (_amount * 10) + (intDigit / 100);
        }
      }
    });
  }

  // --- NOVA FUNÇÃO _saveExpense COM A NOTIFICAÇÃO DINÂMICA ---
  Future<void> _saveExpense() async {
    if (_amount <= 0) return;

    final repository = ExpenseRepository();
    final isEditing = widget.expenseToEdit != null;

    final expense = Expense(
      id: widget.expenseToEdit?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      amount: _amount,
      categoryName: _selectedCategory,
      date: _selectedDate,
      description: _description.isNotEmpty ? _description : null,
      createdAt: widget.expenseToEdit?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    if (isEditing) {
      await repository.deleteExpense(widget.expenseToEdit!.id);
      await repository.insertExpense(expense);
    } else {
      await repository.insertExpense(expense);
    }

    expenseNotifier.value++;

    // Prepara a mensagem dinâmica
    final placeOrCategory = _description.isNotEmpty ? _description : _selectedCategory;
    final successMessage = isEditing
        ? 'Gasto em $placeOrCategory atualizado!'
        : 'Gasto em $placeOrCategory adicionado!';

    // Guarda referências antes de fechar o modal
    final messenger = ScaffoldMessenger.of(context);
    final primaryColor = Theme.of(context).colorScheme.primary;

    if (mounted) Navigator.pop(context);

    // Mostra o Popup (SnackBar)
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                successMessage,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
              ),
            ),
          ],
        ),
        backgroundColor: primaryColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.only(bottom: 24, left: 24, right: 24),
        duration: const Duration(seconds: 3),
      ),
    );
  }
  // ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final bgColor = isDark ? AppColors.darkSurface : Colors.white;
    final textPrimary = isDark ? AppColors.darkTextPrimary : const Color(0xFF1A1D1F);
    final textSecondary = isDark ? AppColors.darkTextSecondary : const Color(0xFF535F66);
    final textMuted = isDark ? AppColors.darkTextMuted : const Color(0xFF8A959D);
    final surfaceSecondary = isDark ? AppColors.darkSurfaceSecondary : const Color(0xFFF0F3F5);
    final borderColor = isDark ? AppColors.darkBorder : const Color(0xFFE2E6E9);
    final keypadBg = isDark ? AppColors.darkSurfaceSecondary : const Color(0xFFF8F9FA);

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: borderColor, borderRadius: BorderRadius.circular(4)),
                ),
              ),
              const SizedBox(height: 16),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.expenseToEdit != null ? 'Editar Gasto' : 'Novo Gasto',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textPrimary),
                  ),
                  TextButton.icon(
                    onPressed: () async {
                      final DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        setState(() => _selectedDate = picked);
                      }
                    },
                    icon: Icon(Icons.calendar_today_rounded, size: 16, color: primaryColor),
                    label: Text(
                      DateFormat('dd/MM/yyyy').format(_selectedDate),
                      style: TextStyle(color: primaryColor, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                decoration: BoxDecoration(
                  color: surfaceSecondary,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: primaryColor.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Valor', style: TextStyle(fontSize: 12, color: textMuted, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(
                      currencyFormatter.format(_amount),
                      style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: textPrimary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              Text('Categoria', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textPrimary)),
              const SizedBox(height: 12),
              SizedBox(
                height: 90,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _categories.length,
                  itemBuilder: (context, index) {
                    final cat = _categories[index];
                    final isSelected = _selectedCategory == cat['name'];
                    return GestureDetector(
                      onTap: () => setState(() => _selectedCategory = cat['name']),
                      child: Container(
                        width: 76,
                        margin: const EdgeInsets.only(right: 12),
                        decoration: BoxDecoration(
                          color: isSelected ? primaryColor.withOpacity(0.15) : surfaceSecondary,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: isSelected ? primaryColor : borderColor, width: 2),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(cat['icon'], color: isSelected ? primaryColor : cat['color'], size: 28),
                            const SizedBox(height: 6),
                            Text(
                              cat['name'],
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                color: isSelected ? primaryColor : textSecondary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),

              if (!_showDescriptionField)
                TextButton.icon(
                  onPressed: () => setState(() => _showDescriptionField = true),
                  icon: Icon(Icons.add_rounded, color: primaryColor),
                  label: Text('Adicionar descrição ou local', style: TextStyle(color: primaryColor, fontWeight: FontWeight.w600)),
                )
              else ...[
                TextField(
                  onChanged: (val) => _description = val,
                  controller: TextEditingController(text: _description),
                  style: TextStyle(color: textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Descrição (opcional)',
                    labelStyle: TextStyle(color: textMuted),
                    filled: true,
                    fillColor: surfaceSecondary,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              const SizedBox(height: 16),

              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: keypadBg, borderRadius: BorderRadius.circular(20)),
                child: Column(
                  children: [
                    _buildKeypadRow(['1', '2', '3'], textPrimary),
                    const SizedBox(height: 8),
                    _buildKeypadRow(['4', '5', '6'], textPrimary),
                    const SizedBox(height: 8),
                    _buildKeypadRow(['7', '8', '9'], textPrimary),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: _buildKeyButton('00', textPrimary),
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: _buildKeyButton('0', textPrimary),
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: InkWell(
                              onTap: () => _onKeyPressed('backspace'),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                height: 52,
                                decoration: BoxDecoration(
                                  color: isDark ? AppColors.darkSurface : Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: isDark ? [] : [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2))],
                                ),
                                child: Center(child: Icon(Icons.backspace_rounded, color: textPrimary, size: 20)),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _amount > 0 ? _saveExpense : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    disabledBackgroundColor: surfaceSecondary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(
                    widget.expenseToEdit != null ? 'Salvar Alterações' : 'Salvar Gasto',
                    style: TextStyle(
                      color: _amount > 0 ? Colors.white : textMuted,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKeypadRow(List<String> keys, Color textColor) {
    return Row(
      children: keys.map((key) => Expanded(child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: _buildKeyButton(key, textColor),
      ))).toList(),
    );
  }

  Widget _buildKeyButton(String text, Color textColor) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppColors.darkSurface : Colors.white;

    return InkWell(
      onTap: () => _onKeyPressed(text),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isDark ? [] : [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2))],
        ),
        child: Center(
          child: Text(
            text,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor),
          ),
        ),
      ),
    );
  }
}