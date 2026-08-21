import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finanse/core/presentation/pin_lock_gate.dart';
import 'package:finanse/core/security/pin_security_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DateTime now;
  late PinSecurityService service;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
    now = DateTime.utc(2026, 8, 21, 12);
    service = PinSecurityService(
      secureStorage: const FlutterSecureStorage(),
      pbkdf2: Pbkdf2(macAlgorithm: Hmac.sha256(), iterations: 1, bits: 256),
      secureRandom: Random(42),
      nowProvider: () => now,
    );
  });

  Widget buildGate({
    Duration gracePeriod = const Duration(seconds: 30),
    TextScaler textScaler = TextScaler.noScaling,
  }) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      builder: (BuildContext context, Widget? child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: textScaler),
        child: child!,
      ),
      home: PinLockGate(
        pinService: service,
        gracePeriod: gracePeriod,
        nowProvider: () => now,
        child: const Scaffold(body: Text('Conteúdo financeiro')),
      ),
    );
  }

  testWidgets('libera o conteúdo quando não existe PIN', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(buildGate());
    await tester.pumpAndSettle();

    expect(find.text('Conteúdo financeiro'), findsOneWidget);
    expect(find.text('Finanse bloqueado'), findsNothing);
  });

  testWidgets('exige e valida o PIN na abertura', (WidgetTester tester) async {
    await service.savePin('1234');
    await tester.pumpWidget(buildGate());
    await tester.pumpAndSettle();

    expect(find.text('Finanse bloqueado'), findsOneWidget);
    expect(find.text('Conteúdo financeiro'), findsNothing);

    await tester.enterText(
      find.byKey(const ValueKey<String>('pin-unlock-field')),
      '1234',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey<String>('pin-unlock-button')));
    await tester.pumpAndSettle();

    expect(find.text('Conteúdo financeiro'), findsOneWidget);
    expect(find.text('Finanse bloqueado'), findsNothing);
  });

  testWidgets('bloqueia novamente depois do período de tolerância', (
    WidgetTester tester,
  ) async {
    await service.savePin('1234');
    await tester.pumpWidget(buildGate());
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey<String>('pin-unlock-field')),
      '1234',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey<String>('pin-unlock-button')));
    await tester.pumpAndSettle();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    now = now.add(const Duration(seconds: 31));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(find.text('Finanse bloqueado'), findsOneWidget);
    expect(find.text('Conteúdo financeiro'), findsNothing);
  });

  testWidgets('não soma períodos curtos passados fora do aplicativo', (
    WidgetTester tester,
  ) async {
    await service.savePin('1234');
    await tester.pumpWidget(buildGate());
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey<String>('pin-unlock-field')),
      '1234',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey<String>('pin-unlock-button')));
    await tester.pumpAndSettle();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    now = now.add(const Duration(seconds: 10));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(find.text('Conteúdo financeiro'), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    now = now.add(const Duration(seconds: 21));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(find.text('Conteúdo financeiro'), findsOneWidget);
    expect(find.text('Finanse bloqueado'), findsNothing);
  });

  testWidgets('tela de bloqueio aceita fonte ampliada em tela pequena', (
    WidgetTester tester,
  ) async {
    await service.savePin('1234');
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(buildGate(textScaler: const TextScaler.linear(2)));
    await tester.pumpAndSettle();

    expect(find.text('Finanse bloqueado'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('pin-unlock-field')), findsOne);
    expect(tester.takeException(), isNull);
  });
}
