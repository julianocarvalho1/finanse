import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class PinSecurityService {
  PinSecurityService({
    FlutterSecureStorage? secureStorage,
    Pbkdf2? pbkdf2,
    Random? secureRandom,
  }) : _secureStorage = secureStorage ?? FlutterSecureStorage(),
       _pbkdf2 =
           pbkdf2 ??
           Pbkdf2(
             macAlgorithm: Hmac.sha256(),
             iterations: _defaultIterations,
             bits: 256,
           ),
       _secureRandom = secureRandom ?? Random.secure();

  static final PinSecurityService instance = PinSecurityService();

  static const String _pinHashKey = 'finansePinHash';
  static const String _pinSaltKey = 'finansePinSalt';
  static const String _pinIterationsKey = 'finansePinIterations';

  static const int _defaultIterations = 120000;
  static const int _saltLength = 16;

  final FlutterSecureStorage _secureStorage;
  final Pbkdf2 _pbkdf2;
  final Random _secureRandom;

  bool isValidPinFormat(String pin) {
    return RegExp(r'^\d{4,6}$').hasMatch(pin);
  }

  Future<bool> hasPin() async {
    final String? storedHash = await _secureStorage.read(key: _pinHashKey);

    final String? storedSalt = await _secureStorage.read(key: _pinSaltKey);

    return storedHash != null &&
        storedHash.isNotEmpty &&
        storedSalt != null &&
        storedSalt.isNotEmpty;
  }

  Future<void> savePin(String pin) async {
    if (!isValidPinFormat(pin)) {
      throw const FormatException('O PIN deve conter entre 4 e 6 números.');
    }

    final List<int> salt = List<int>.generate(
      _saltLength,
      (_) => _secureRandom.nextInt(256),
      growable: false,
    );

    final List<int> hash = await _derivePinHash(
      pin: pin,
      salt: salt,
      iterations: _defaultIterations,
    );

    await _secureStorage.write(key: _pinHashKey, value: base64Encode(hash));

    await _secureStorage.write(key: _pinSaltKey, value: base64Encode(salt));

    await _secureStorage.write(
      key: _pinIterationsKey,
      value: _defaultIterations.toString(),
    );
  }

  Future<bool> verifyPin(String pin) async {
    if (!isValidPinFormat(pin)) {
      return false;
    }

    final String? storedHashText = await _secureStorage.read(key: _pinHashKey);

    final String? storedSaltText = await _secureStorage.read(key: _pinSaltKey);

    final String? storedIterationsText = await _secureStorage.read(
      key: _pinIterationsKey,
    );

    if (storedHashText == null ||
        storedHashText.isEmpty ||
        storedSaltText == null ||
        storedSaltText.isEmpty) {
      return false;
    }

    try {
      final List<int> storedHash = base64Decode(storedHashText);
      final List<int> storedSalt = base64Decode(storedSaltText);

      final int iterations =
          int.tryParse(storedIterationsText ?? '') ?? _defaultIterations;

      final Pbkdf2 algorithm = iterations == _defaultIterations
          ? _pbkdf2
          : Pbkdf2(
              macAlgorithm: Hmac.sha256(),
              iterations: iterations,
              bits: 256,
            );

      final SecretKey derivedKey = await algorithm.deriveKeyFromPassword(
        password: pin,
        nonce: storedSalt,
      );

      final List<int> calculatedHash = await derivedKey.extractBytes();

      return _constantTimeEquals(storedHash, calculatedHash);
    } on FormatException {
      return false;
    }
  }

  Future<void> removePin() async {
    await _secureStorage.delete(key: _pinHashKey);
    await _secureStorage.delete(key: _pinSaltKey);
    await _secureStorage.delete(key: _pinIterationsKey);
  }

  Future<List<int>> _derivePinHash({
    required String pin,
    required List<int> salt,
    required int iterations,
  }) async {
    final Pbkdf2 algorithm = iterations == _defaultIterations
        ? _pbkdf2
        : Pbkdf2(
            macAlgorithm: Hmac.sha256(),
            iterations: iterations,
            bits: 256,
          );

    final SecretKey secretKey = await algorithm.deriveKeyFromPassword(
      password: pin,
      nonce: salt,
    );

    return secretKey.extractBytes();
  }

  bool _constantTimeEquals(List<int> first, List<int> second) {
    if (first.length != second.length) {
      return false;
    }

    int difference = 0;

    for (int index = 0; index < first.length; index++) {
      difference |= first[index] ^ second[index];
    }

    return difference == 0;
  }
}
