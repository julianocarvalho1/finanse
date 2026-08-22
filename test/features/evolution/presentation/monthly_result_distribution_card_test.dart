import 'package:finanse/features/evolution/domain/financial_evolution.dart';
import 'package:finanse/features/evolution/presentation/widgets/monthly_result_distribution_card.dart';
import 'package:finanse/core/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('mostra resultado, metas, reserva e valor livre', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _testApp(
        MonthlyEvolutionSnapshot(
          month: DateTime(2026, 8),
          incomeCents: 500000,
          spentCents: 140000,
          spendingLimitCents: 200000,
          allocatedToGoalsCents: 150000,
          allocatedToReserveCents: 70000,
        ),
      ),
    );

    expect(find.text('Distribuição da sobra'), findsOneWidget);
    expect(find.text('Resultado do mês'), findsOneWidget);
    expect(find.text('Metas'), findsOneWidget);
    expect(find.text('Reserva'), findsOneWidget);
    expect(find.text('Livre'), findsOneWidget);
    expect(find.textContaining('3.600,00'), findsOneWidget);
    expect(find.textContaining('1.500,00'), findsOneWidget);
    expect(find.textContaining('700,00'), findsOneWidget);
    expect(find.textContaining('1.400,00'), findsOneWidget);
    expect(find.text('42%'), findsOneWidget);
    expect(find.text('19%'), findsOneWidget);
    expect(find.text('39%'), findsOneWidget);

    for (final Color color in <Color>[
      AppColors.purple,
      AppColors.information,
      AppColors.success,
    ]) {
      final Finder segment = find.byWidgetPredicate(
        (Widget widget) => widget is ColoredBox && widget.color == color,
      );
      expect(segment, findsOneWidget);
      expect(tester.getSize(segment).height, 12);
    }
  });

  testWidgets('alerta quando correções deixam destinações acima do resultado', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _testApp(
        MonthlyEvolutionSnapshot(
          month: DateTime(2026, 8),
          incomeCents: 500000,
          spentCents: 420000,
          allocatedToGoalsCents: 60000,
          allocatedToReserveCents: 50000,
        ),
      ),
    );

    expect(find.text('Livre'), findsOneWidget);
    expect(find.textContaining('superam o resultado atual'), findsOneWidget);
    expect(find.textContaining('300,00'), findsOneWidget);
  });
}

Widget _testApp(MonthlyEvolutionSnapshot snapshot) {
  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: MonthlyResultDistributionCard(
          snapshot: snapshot,
          monthLabel: 'Agosto de 2026',
        ),
      ),
    ),
  );
}
