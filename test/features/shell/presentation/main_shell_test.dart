import 'package:finanse/features/shell/presentation/main_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const List<Widget> pages = <Widget>[
    Text('Página inicial'),
    Text('Página histórica'),
    Text('Página de relatórios'),
    Text('Página de perfil'),
  ];

  testWidgets('navega entre os principais estados da barra inferior', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_testApp(pages: pages));

    expect(find.text('Página inicial'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Histórico'));
    await tester.pumpAndSettle();
    expect(find.text('Página histórica'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Relatórios'));
    await tester.pumpAndSettle();
    expect(find.text('Página de relatórios'), findsOneWidget);
  });

  testWidgets('fonte ampliada preserva rótulo selecionado e semântica', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _testApp(pages: pages, textScaler: const TextScaler.linear(2)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Início'), findsOneWidget);
    expect(find.text('Histórico'), findsNothing);
    expect(find.bySemanticsLabel('Histórico'), findsOneWidget);
    expect(find.bySemanticsLabel('Relatórios'), findsOneWidget);
    expect(find.bySemanticsLabel('Perfil'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('botão central mantém a ação de adicionar gasto', (
    WidgetTester tester,
  ) async {
    int addCount = 0;
    await tester.pumpWidget(
      _testApp(pages: pages, onAddExpense: () => addCount++),
    );

    await tester.tap(find.byTooltip('Adicionar gasto'));
    expect(addCount, 1);
  });
}

Widget _testApp({
  required List<Widget> pages,
  TextScaler textScaler = TextScaler.noScaling,
  VoidCallback? onAddExpense,
}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    builder: (BuildContext context, Widget? child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: textScaler),
      child: child!,
    ),
    home: MainShell(pages: pages, onAddExpense: onAddExpense),
  );
}
