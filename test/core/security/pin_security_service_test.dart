import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finanse/core/security/pin_security_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DateTime now;
  late FlutterSecureStorage storage;
  late PinSecurityService service;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
    now = DateTime.utc(2026, 8, 21, 12);
    storage = const FlutterSecureStorage();
    service = PinSecurityService(
      secureStorage: storage,
      pbkdf2: Pbkdf2(macAlgorithm: Hmac.sha256(), iterations: 1, bits: 256),
      secureRandom: Random(42),
      nowProvider: () => now,
    );
  });

  test('salva o PIN como hash e valida o valor correto', () async {
    await service.savePin('1234');

    final Map<String, String> storedValues = await storage.readAll();

    expect(await service.hasPin(), isTrue);
    expect(storedValues.values, isNot(contains('1234')));
    expect(await service.verifyPin('1234'), isTrue);
    expect(await service.verifyPin('4321'), isFalse);
  });

  test('bloqueia por 30 segundos depois de cinco erros', () async {
    await service.savePin('1234');

    for (int attempt = 1; attempt < 5; attempt++) {
      final PinVerificationResult result = await service
          .verifyPinWithProtection('9999');

      expect(result.isValid, isFalse);
      expect(result.isLocked, isFalse);
      expect(
        result.attemptsRemaining,
        PinSecurityService.maxFailedAttempts - attempt,
      );
    }

    final PinVerificationResult blocked = await service.verifyPinWithProtection(
      '9999',
    );

    expect(blocked.isLocked, isTrue);
    expect(blocked.attemptsRemaining, 0);

    final PinVerificationResult correctDuringLockout = await service
        .verifyPinWithProtection('1234');

    expect(correctDuringLockout.isValid, isFalse);
    expect(correctDuringLockout.isLocked, isTrue);

    now = now.add(const Duration(seconds: 31));

    final PinVerificationResult correctAfterLockout = await service
        .verifyPinWithProtection('1234');

    expect(correctAfterLockout.isValid, isTrue);
    expect(correctAfterLockout.isLocked, isFalse);
  });

  test('remover o PIN também limpa o bloqueio', () async {
    await service.savePin('1234');

    for (int attempt = 0; attempt < 5; attempt++) {
      await service.verifyPinWithProtection('9999');
    }

    expect(await service.getLockoutRemaining(), isNot(Duration.zero));

    await service.removePin();

    expect(await service.hasPin(), isFalse);
    expect(await service.getLockoutRemaining(), Duration.zero);
  });
}
