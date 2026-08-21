import 'package:finanse/features/incomes/data/income_repository.dart';
import 'package:finanse/features/incomes/domain/income.dart';
import 'package:finanse/features/incomes/presentation/incomes_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _RecordingIncomeRepository repository;

  setUpAll(() async {
    await initializeDateFormatting('pt_BR');
  });

  setUp(() {
    repository = _RecordingIncomeRepository();
  });

  testWidgets('cadastra renda pelo formulário principal', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_host(repository));
    await tester.tap(find.text('Abrir renda'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), '500000');
    await tester.enterText(find.byType(TextField).at(1), 'Salário');
    await tester.pump();

    await tester.tap(find.text('Salvar renda'));
    await tester.pumpAndSettle();

    final Income savedIncome = repository.savedIncome!;
    expect(savedIncome.amountCents, 500000);
    expect(savedIncome.source, 'Salário');
    expect(savedIncome.id, hasLength(36));
  });

  testWidgets('formulário se mantém sem overflow com fonte ampliada', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _host(repository, textScaler: const TextScaler.linear(2)),
    );
    await tester.tap(find.text('Abrir renda'));
    await tester.pumpAndSettle();

    expect(find.text('Adicionar renda'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Widget _host(
  IncomeRepository repository, {
  TextScaler textScaler = TextScaler.noScaling,
}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    builder: (BuildContext context, Widget? child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: textScaler),
      child: child!,
    ),
    home: Builder(
      builder: (BuildContext context) {
        return Scaffold(
          body: Center(
            child: FilledButton(
              onPressed: () {
                IncomeFormSheet.show(
                  context,
                  repository: repository,
                  initialMonth: DateTime(2026, 8),
                );
              },
              child: const Text('Abrir renda'),
            ),
          ),
        );
      },
    ),
  );
}

class _RecordingIncomeRepository extends IncomeRepository {
  Income? savedIncome;

  @override
  Future<void> insertIncome(Income income) async {
    savedIncome = income;
  }
}
