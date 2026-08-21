import 'package:finanse/features/expenses/data/expense_repository.dart';
import 'package:finanse/features/expenses/domain/expense.dart';
import 'package:finanse/features/expenses/presentation/widgets/add_expense_modal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _RecordingExpenseRepository repository;

  setUpAll(() async {
    await initializeDateFormatting('pt_BR');
  });

  setUp(() {
    repository = _RecordingExpenseRepository();
  });

  testWidgets('cadastra gasto pelo modal principal', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_host(repository));
    await tester.tap(find.text('Abrir gasto'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, '12345');
    await tester.pump();
    await tester.tap(find.text('Salvar gasto'));
    await tester.pumpAndSettle();

    final Expense savedExpense = repository.savedExpense!;
    expect(savedExpense.amount, 123.45);
    expect(savedExpense.categoryName, 'Alimentação');
    expect(savedExpense.id, hasLength(36));
  });

  testWidgets('modal se mantém sem overflow com fonte ampliada', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _host(repository, textScaler: const TextScaler.linear(2)),
    );
    await tester.tap(find.text('Abrir gasto'));
    await tester.pumpAndSettle();

    expect(find.text('Novo gasto'), findsOneWidget);
    expect(find.text('Salvar gasto'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Widget _host(
  ExpenseRepository repository, {
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
                AddExpenseModal.show(context, repository: repository);
              },
              child: const Text('Abrir gasto'),
            ),
          ),
        );
      },
    ),
  );
}

class _RecordingExpenseRepository extends ExpenseRepository {
  Expense? savedExpense;

  @override
  Future<void> insertExpense(Expense expense) async {
    savedExpense = expense;
  }

  @override
  Future<void> deleteExpense(String id) async {
    savedExpense = null;
  }
}
