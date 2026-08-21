import 'package:finanse/features/onboarding/presentation/onboarding_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('conclui as três etapas do onboarding', (
    WidgetTester tester,
  ) async {
    int finishCount = 0;

    await tester.pumpWidget(_testApp(onFinished: () async => finishCount++));

    expect(find.text('Controle seus gastos'), findsOneWidget);
    expect(find.bySemanticsLabel('Etapa 1 de 3'), findsOneWidget);

    await tester.tap(find.text('Próximo'));
    await tester.pumpAndSettle();
    expect(find.text('Planeje seu mês'), findsOneWidget);
    expect(find.bySemanticsLabel('Etapa 2 de 3'), findsOneWidget);

    await tester.tap(find.text('Próximo'));
    await tester.pumpAndSettle();
    expect(find.text('Acompanhe sua reserva'), findsOneWidget);
    expect(find.bySemanticsLabel('Etapa 3 de 3'), findsOneWidget);

    await tester.tap(find.text('Começar a usar'));
    await tester.pumpAndSettle();

    expect(finishCount, 1);
  });

  testWidgets('permite pular o onboarding uma única vez', (
    WidgetTester tester,
  ) async {
    int finishCount = 0;

    await tester.pumpWidget(_testApp(onFinished: () async => finishCount++));
    await tester.tap(find.text('Pular'));
    await tester.pumpAndSettle();

    expect(finishCount, 1);
  });

  testWidgets('continua utilizável em tela pequena com fonte ampliada', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _testApp(onFinished: () async {}, textScaler: const TextScaler.linear(2)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Controle seus gastos'), findsOneWidget);
    expect(find.text('Próximo'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Widget _testApp({
  required Future<void> Function() onFinished,
  TextScaler textScaler = TextScaler.noScaling,
}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    builder: (BuildContext context, Widget? child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: textScaler),
      child: child!,
    ),
    home: OnboardingPage(onFinished: onFinished),
  );
}
