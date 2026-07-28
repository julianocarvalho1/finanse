import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../security/biometric_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

class LockScreen extends StatefulWidget {
  const LockScreen({super.key, required this.child});

  final Widget child;

  @override
  State<LockScreen> createState() {
    return _LockScreenState();
  }
}

class _LockScreenState extends State<LockScreen> with WidgetsBindingObserver {
  static const String _biometricPreferenceKey = 'useBiometrics';

  bool _isCheckingPreference = true;
  bool _isLocked = true;
  bool _isAuthenticating = false;
  bool _useBiometrics = false;

  bool _authenticateWhenResumed = false;

  String? _authenticationMessage;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    _initializeSecurity();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    unawaited(BiometricService.instance.stopAuthentication());

    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_handleAppResumed());

      return;
    }

    final bool appLeftForeground =
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached;

    if (!appLeftForeground || _isAuthenticating) {
      return;
    }

    _authenticateWhenResumed = true;

    if (_useBiometrics && mounted) {
      setState(() {
        _isLocked = true;
      });
    }
  }

  Future<void> _initializeSecurity() async {
    try {
      final SharedPreferences preferences =
          await SharedPreferences.getInstance();

      final bool useBiometrics =
          preferences.getBool(_biometricPreferenceKey) ?? false;

      if (!mounted) {
        return;
      }

      setState(() {
        _useBiometrics = useBiometrics;
        _isLocked = useBiometrics;
        _isCheckingPreference = false;
      });

      if (!useBiometrics) {
        return;
      }

      // Pequeno intervalo para permitir que a primeira tela termine
      // de ser montada antes de abrir o diálogo nativo.
      await Future<void>.delayed(const Duration(milliseconds: 300));

      if (!mounted) {
        return;
      }

      await _authenticate();
    } catch (error, stackTrace) {
      debugPrint(
        'Erro ao carregar a configuração biométrica: '
        '$error\n$stackTrace',
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _isCheckingPreference = false;
        _isLocked = true;
        _useBiometrics = true;
        _authenticationMessage =
            'Não foi possível verificar a proteção do aplicativo.';
      });
    }
  }

  Future<void> _handleAppResumed() async {
    if (_isCheckingPreference || _isAuthenticating) {
      return;
    }

    try {
      final SharedPreferences preferences =
          await SharedPreferences.getInstance();

      final bool useBiometrics =
          preferences.getBool(_biometricPreferenceKey) ?? false;

      if (!mounted) {
        return;
      }

      if (!useBiometrics) {
        setState(() {
          _useBiometrics = false;
          _isLocked = false;
          _authenticateWhenResumed = false;
          _authenticationMessage = null;
        });

        return;
      }

      final bool shouldAuthenticate =
          !_useBiometrics || _authenticateWhenResumed || _isLocked;

      _authenticateWhenResumed = false;

      // O aplicativo já foi autenticado e apenas recebeu outro evento
      // "resumed" causado pelo fechamento do diálogo biométrico.
      // Nesse caso, não deve bloquear novamente.
      if (!shouldAuthenticate) {
        if (!_useBiometrics) {
          setState(() {
            _useBiometrics = true;
          });
        }

        return;
      }

      setState(() {
        _useBiometrics = true;
        _isLocked = true;
        _authenticationMessage = null;
      });

      await _authenticate();
    } catch (error, stackTrace) {
      debugPrint(
        'Erro ao verificar a biometria ao retornar: '
        '$error\n$stackTrace',
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _isLocked = true;
        _authenticationMessage =
            'Não foi possível verificar a proteção do aplicativo.';
      });
    }
  }

  Future<void> _authenticate() async {
    if (_isAuthenticating || !_useBiometrics) {
      return;
    }

    HapticFeedback.selectionClick();

    setState(() {
      _isAuthenticating = true;
      _isLocked = true;
      _authenticationMessage = null;
    });

    final BiometricAuthenticationResult result = await BiometricService.instance
        .authenticate(
          reason: 'Confirme sua biometria para acessar seus dados financeiros.',
        );

    if (!mounted) {
      return;
    }

    if (result.authenticated) {
      HapticFeedback.lightImpact();

      setState(() {
        _isAuthenticating = false;
        _isLocked = false;
        _authenticationMessage = null;
      });

      return;
    }

    setState(() {
      _isAuthenticating = false;
      _isLocked = true;
      _authenticationMessage = result.wasCanceled
          ? 'Autenticação cancelada. Toque abaixo para tentar novamente.'
          : result.message;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingPreference) {
      return _buildLoadingScreen(context);
    }

    if (!_useBiometrics || !_isLocked) {
      return widget.child;
    }

    return _buildLockedScreen(context);
  }

  Widget _buildLoadingScreen(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: const Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildLockedScreen(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    final Color primaryColor = theme.colorScheme.primary;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: SafeArea(
          minimum: const EdgeInsets.all(AppSpacing.pageHorizontal),
          child: Center(
            child: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Container(
                      width: 104,
                      height: 104,
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.13),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: primaryColor.withValues(alpha: 0.32),
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        Icons.lock_outline_rounded,
                        size: 50,
                        color: primaryColor,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Text(
                      'Finanse bloqueado',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Confirme sua identidade para acessar '
                      'seus dados financeiros.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium,
                    ),
                    if (_authenticationMessage != null) ...<Widget>[
                      const SizedBox(height: AppSpacing.lg),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(
                            AppSpacing.inputRadius,
                          ),
                          border: Border.all(
                            color: AppColors.error.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            const Icon(
                              Icons.info_outline_rounded,
                              color: AppColors.error,
                              size: 22,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                _authenticationMessage!,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: AppColors.error,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.xl),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _isAuthenticating ? null : _authenticate,
                        icon: _isAuthenticating
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.fingerprint_rounded),
                        label: Text(
                          _isAuthenticating
                              ? 'Verificando...'
                              : 'Desbloquear com biometria',
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Se a leitura for cancelada, toque no botão '
                      'para tentar novamente.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
