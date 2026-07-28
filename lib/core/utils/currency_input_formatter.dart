import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.selection.baseOffset == 0) {
      return newValue;
    }

    // Remove tudo que não for número
    String numbersOnly = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');

    if (numbersOnly.isEmpty) {
      return newValue.copyWith(text: '');
    }

    // Converte para double dividindo por 100 (para ter os centavos)
    double value = double.parse(numbersOnly) / 100;

    // Formata no padrão brasileiro (ex: 2.500,00)
    final formatter = NumberFormat.currency(
      locale: 'pt_BR',
      symbol: '', // Deixamos sem símbolo pois o "R$" já está fixo na tela
      decimalDigits: 2,
    );

    String newText = formatter.format(value).trim();

    return newValue.copyWith(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
  }
}
