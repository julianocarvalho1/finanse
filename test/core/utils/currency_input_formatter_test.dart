import 'package:finanse/core/utils/currency_input_formatter.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CurrencyInputFormatter', () {
    test('formata os dígitos como moeda brasileira', () {
      final CurrencyInputFormatter formatter = CurrencyInputFormatter();

      final TextEditingValue result = formatter.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(
          text: '1234',
          selection: TextSelection.collapsed(offset: 4),
        ),
      );

      expect(result.text, '12,34');
      expect(result.selection.baseOffset, result.text.length);
    });

    test('permite limpar completamente o campo', () {
      final CurrencyInputFormatter formatter = CurrencyInputFormatter();

      final TextEditingValue result = formatter.formatEditUpdate(
        const TextEditingValue(
          text: '10,00',
          selection: TextSelection.collapsed(offset: 5),
        ),
        TextEditingValue.empty,
      );

      expect(result.text, isEmpty);
      expect(
        result.selection,
        const TextSelection.collapsed(offset: 0),
      );
    });

    test('mantém o valor anterior quando ultrapassa o máximo', () {
      final CurrencyInputFormatter formatter = CurrencyInputFormatter(
        maximumValueInCents: 9999,
      );

      const TextEditingValue oldValue = TextEditingValue(
        text: '99,99',
        selection: TextSelection.collapsed(offset: 5),
      );

      final TextEditingValue result = formatter.formatEditUpdate(
        oldValue,
        const TextEditingValue(
          text: '999,99',
          selection: TextSelection.collapsed(offset: 6),
        ),
      );

      expect(result, oldValue);
    });
  });
}
