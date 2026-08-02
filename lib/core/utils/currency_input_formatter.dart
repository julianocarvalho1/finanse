import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class CurrencyInputFormatter extends TextInputFormatter {
  CurrencyInputFormatter({this.maximumValueInCents});

  final int? maximumValueInCents;

  final NumberFormat _formatter = NumberFormat.currency(
    locale: 'pt_BR',
    symbol: '',
    decimalDigits: 2,
  );

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final String numbersOnly = newValue.text.replaceAll(
      RegExp(r'[^0-9]'),
      '',
    );

    if (numbersOnly.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }

    final int? valueInCents = int.tryParse(numbersOnly);

    if (valueInCents == null) {
      return oldValue;
    }

    final int? maximum = maximumValueInCents;
    if (maximum != null && valueInCents > maximum) {
      return oldValue;
    }

    final String formattedText = _formatter
        .format(valueInCents / 100)
        .trim();

    return TextEditingValue(
      text: formattedText,
      selection: TextSelection.collapsed(offset: formattedText.length),
    );
  }
}
