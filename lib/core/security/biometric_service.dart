import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

/// Situação da biometria disponível no aparelho.
enum BiometricAvailabilityStatus {
  available,
  unsupported,
  noHardware,
  notEnrolled,
  temporarilyUnavailable,
  error,
}

/// Resultado da verificação da biometria do aparelho.
class BiometricAvailabilityResult {
  const BiometricAvailabilityResult({
    required this.status,
    required this.availableTypes,
    required this.message,
  });

  final BiometricAvailabilityStatus status;
  final List<BiometricType> availableTypes;
  final String message;

  bool get isAvailable {
    return status == BiometricAvailabilityStatus.available;
  }

  /// Nome amigável do método biométrico disponível.
  String get biometricLabel {
    final bool hasFingerprint = availableTypes.contains(
      BiometricType.fingerprint,
    );

    final bool hasFace = availableTypes.contains(BiometricType.face);

    final bool hasIris = availableTypes.contains(BiometricType.iris);

    if (hasFingerprint && hasFace) {
      return 'Digital ou reconhecimento facial';
    }

    if (hasFingerprint) {
      return 'Impressão digital';
    }

    if (hasFace) {
      return 'Reconhecimento facial';
    }

    if (hasIris) {
      return 'Reconhecimento de íris';
    }

    if (availableTypes.isNotEmpty) {
      return 'Biometria do aparelho';
    }

    return 'Biometria';
  }
}

/// Situação final de uma tentativa de autenticação.
enum BiometricAuthenticationStatus {
  authenticated,
  canceled,
  failed,
  unavailable,
  notEnrolled,
  lockedOut,
  error,
}

/// Resultado de uma tentativa de autenticação biométrica.
class BiometricAuthenticationResult {
  const BiometricAuthenticationResult({
    required this.status,
    required this.message,
  });

  final BiometricAuthenticationStatus status;
  final String message;

  bool get authenticated {
    return status == BiometricAuthenticationStatus.authenticated;
  }

  bool get wasCanceled {
    return status == BiometricAuthenticationStatus.canceled;
  }
}

/// Centraliza todas as operações de autenticação biométrica.
class BiometricService {
  BiometricService._();

  static final BiometricService instance = BiometricService._();

  final LocalAuthentication _localAuthentication = LocalAuthentication();

  bool _authenticationInProgress = false;

  bool get authenticationInProgress {
    return _authenticationInProgress;
  }

  /// Verifica se o celular possui biometria cadastrada e disponível.
  Future<BiometricAvailabilityResult> checkAvailability() async {
    try {
      final bool deviceSupported = await _localAuthentication
          .isDeviceSupported();

      if (!deviceSupported) {
        return const BiometricAvailabilityResult(
          status: BiometricAvailabilityStatus.unsupported,
          availableTypes: <BiometricType>[],
          message: 'Este aparelho não oferece autenticação local compatível.',
        );
      }

      final bool canCheckBiometrics =
          await _localAuthentication.canCheckBiometrics;

      if (!canCheckBiometrics) {
        return const BiometricAvailabilityResult(
          status: BiometricAvailabilityStatus.noHardware,
          availableTypes: <BiometricType>[],
          message: 'Nenhum sensor biométrico compatível foi encontrado.',
        );
      }

      final List<BiometricType> availableTypes = await _localAuthentication
          .getAvailableBiometrics();

      if (availableTypes.isEmpty) {
        return const BiometricAvailabilityResult(
          status: BiometricAvailabilityStatus.notEnrolled,
          availableTypes: <BiometricType>[],
          message:
              'Cadastre uma digital ou reconhecimento facial nas configurações do celular.',
        );
      }

      final BiometricAvailabilityResult result = BiometricAvailabilityResult(
        status: BiometricAvailabilityStatus.available,
        availableTypes: List<BiometricType>.unmodifiable(availableTypes),
        message: 'Biometria disponível.',
      );

      return BiometricAvailabilityResult(
        status: result.status,
        availableTypes: result.availableTypes,
        message:
            '${result.biometricLabel} disponível para proteger o aplicativo.',
      );
    } on LocalAuthException catch (error) {
      return _availabilityResultFromLocalAuthException(error);
    } on PlatformException catch (error, stackTrace) {
      debugPrint(
        'Erro de plataforma ao verificar biometria: '
        '${error.code} - ${error.message}\n'
        '$stackTrace',
      );

      return const BiometricAvailabilityResult(
        status: BiometricAvailabilityStatus.error,
        availableTypes: <BiometricType>[],
        message: 'Não foi possível verificar a biometria deste aparelho.',
      );
    } catch (error, stackTrace) {
      debugPrint(
        'Erro inesperado ao verificar biometria: '
        '$error\n$stackTrace',
      );

      return const BiometricAvailabilityResult(
        status: BiometricAvailabilityStatus.error,
        availableTypes: <BiometricType>[],
        message: 'Ocorreu um problema ao verificar a biometria.',
      );
    }
  }

  /// Solicita autenticação exclusivamente por biometria.
  ///
  /// PIN, senha e padrão do aparelho não serão utilizados como substitutos.
  Future<BiometricAuthenticationResult> authenticate({
    String reason =
        'Confirme sua biometria para acessar seus dados financeiros.',
  }) async {
    if (_authenticationInProgress) {
      return const BiometricAuthenticationResult(
        status: BiometricAuthenticationStatus.failed,
        message: 'Uma autenticação biométrica já está em andamento.',
      );
    }

    _authenticationInProgress = true;

    try {
      final BiometricAvailabilityResult availability =
          await checkAvailability();

      if (!availability.isAvailable) {
        return _authenticationResultFromAvailability(availability);
      }

      final bool authenticated = await _localAuthentication.authenticate(
        localizedReason: reason,
        biometricOnly: true,
        sensitiveTransaction: true,
        persistAcrossBackgrounding: true,
      );

      if (authenticated) {
        return const BiometricAuthenticationResult(
          status: BiometricAuthenticationStatus.authenticated,
          message: 'Autenticação concluída.',
        );
      }

      return const BiometricAuthenticationResult(
        status: BiometricAuthenticationStatus.failed,
        message: 'A biometria não foi reconhecida. Tente novamente.',
      );
    } on LocalAuthException catch (error) {
      return _authenticationResultFromLocalAuthException(error);
    } on PlatformException catch (error, stackTrace) {
      debugPrint(
        'Erro de plataforma durante autenticação: '
        '${error.code} - ${error.message}\n'
        '$stackTrace',
      );

      return const BiometricAuthenticationResult(
        status: BiometricAuthenticationStatus.error,
        message: 'Não foi possível iniciar a autenticação biométrica.',
      );
    } catch (error, stackTrace) {
      debugPrint(
        'Erro inesperado durante autenticação: '
        '$error\n$stackTrace',
      );

      return const BiometricAuthenticationResult(
        status: BiometricAuthenticationStatus.error,
        message: 'Ocorreu um problema durante a autenticação.',
      );
    } finally {
      _authenticationInProgress = false;
    }
  }

  /// Cancela uma autenticação que ainda esteja aberta.
  Future<bool> stopAuthentication() async {
    try {
      final bool stopped = await _localAuthentication.stopAuthentication();

      _authenticationInProgress = false;

      return stopped;
    } catch (error, stackTrace) {
      debugPrint(
        'Não foi possível cancelar a autenticação: '
        '$error\n$stackTrace',
      );

      _authenticationInProgress = false;

      return false;
    }
  }

  BiometricAvailabilityResult _availabilityResultFromLocalAuthException(
    LocalAuthException error,
  ) {
    switch (error.code) {
      case LocalAuthExceptionCode.noBiometricHardware:
        return const BiometricAvailabilityResult(
          status: BiometricAvailabilityStatus.noHardware,
          availableTypes: <BiometricType>[],
          message: 'Este aparelho não possui sensor biométrico compatível.',
        );

      case LocalAuthExceptionCode.noBiometricsEnrolled:
      case LocalAuthExceptionCode.noCredentialsSet:
        return const BiometricAvailabilityResult(
          status: BiometricAvailabilityStatus.notEnrolled,
          availableTypes: <BiometricType>[],
          message:
              'Cadastre uma digital ou reconhecimento facial nas configurações do celular.',
        );

      case LocalAuthExceptionCode.biometricHardwareTemporarilyUnavailable:
      case LocalAuthExceptionCode.temporaryLockout:
      case LocalAuthExceptionCode.biometricLockout:
        return const BiometricAvailabilityResult(
          status: BiometricAvailabilityStatus.temporarilyUnavailable,
          availableTypes: <BiometricType>[],
          message: 'A biometria está temporariamente indisponível.',
        );

      default:
        debugPrint(
          'Erro ao verificar biometria: '
          '${error.code} - ${error.description}',
        );

        return const BiometricAvailabilityResult(
          status: BiometricAvailabilityStatus.error,
          availableTypes: <BiometricType>[],
          message: 'Não foi possível verificar a biometria.',
        );
    }
  }

  BiometricAuthenticationResult _authenticationResultFromAvailability(
    BiometricAvailabilityResult availability,
  ) {
    switch (availability.status) {
      case BiometricAvailabilityStatus.notEnrolled:
        return BiometricAuthenticationResult(
          status: BiometricAuthenticationStatus.notEnrolled,
          message: availability.message,
        );

      case BiometricAvailabilityStatus.temporarilyUnavailable:
        return BiometricAuthenticationResult(
          status: BiometricAuthenticationStatus.lockedOut,
          message: availability.message,
        );

      case BiometricAvailabilityStatus.unsupported:
      case BiometricAvailabilityStatus.noHardware:
        return BiometricAuthenticationResult(
          status: BiometricAuthenticationStatus.unavailable,
          message: availability.message,
        );

      case BiometricAvailabilityStatus.error:
        return BiometricAuthenticationResult(
          status: BiometricAuthenticationStatus.error,
          message: availability.message,
        );

      case BiometricAvailabilityStatus.available:
        return const BiometricAuthenticationResult(
          status: BiometricAuthenticationStatus.failed,
          message: 'A autenticação biométrica não pôde ser iniciada.',
        );
    }
  }

  BiometricAuthenticationResult _authenticationResultFromLocalAuthException(
    LocalAuthException error,
  ) {
    switch (error.code) {
      case LocalAuthExceptionCode.userCanceled:
      case LocalAuthExceptionCode.systemCanceled:
      case LocalAuthExceptionCode.userRequestedFallback:
        return const BiometricAuthenticationResult(
          status: BiometricAuthenticationStatus.canceled,
          message: 'Autenticação cancelada.',
        );

      case LocalAuthExceptionCode.timeout:
        return const BiometricAuthenticationResult(
          status: BiometricAuthenticationStatus.failed,
          message: 'O tempo para autenticação terminou. Tente novamente.',
        );

      case LocalAuthExceptionCode.noBiometricsEnrolled:
      case LocalAuthExceptionCode.noCredentialsSet:
        return const BiometricAuthenticationResult(
          status: BiometricAuthenticationStatus.notEnrolled,
          message:
              'Cadastre uma digital ou reconhecimento facial nas configurações do celular.',
        );

      case LocalAuthExceptionCode.noBiometricHardware:
      case LocalAuthExceptionCode.biometricHardwareTemporarilyUnavailable:
      case LocalAuthExceptionCode.uiUnavailable:
        return const BiometricAuthenticationResult(
          status: BiometricAuthenticationStatus.unavailable,
          message:
              'A autenticação biométrica não está disponível neste momento.',
        );

      case LocalAuthExceptionCode.temporaryLockout:
        return const BiometricAuthenticationResult(
          status: BiometricAuthenticationStatus.lockedOut,
          message:
              'Muitas tentativas falharam. Aguarde um pouco e tente novamente.',
        );

      case LocalAuthExceptionCode.biometricLockout:
        return const BiometricAuthenticationResult(
          status: BiometricAuthenticationStatus.lockedOut,
          message:
              'A biometria foi bloqueada. Desbloqueie o celular com sua senha e tente novamente.',
        );

      case LocalAuthExceptionCode.authInProgress:
        return const BiometricAuthenticationResult(
          status: BiometricAuthenticationStatus.failed,
          message: 'Uma autenticação biométrica já está em andamento.',
        );

      case LocalAuthExceptionCode.deviceError:
      case LocalAuthExceptionCode.unknownError:
        debugPrint(
          'Erro na autenticação biométrica: '
          '${error.code} - ${error.description}',
        );

        return const BiometricAuthenticationResult(
          status: BiometricAuthenticationStatus.error,
          message: 'O aparelho não conseguiu concluir a autenticação.',
        );
    }
  }
}
