import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../security/biometric_service.dart';
import '../security/pin_security_service.dart';
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
  final TextEditingController _pinController = TextEditingController();

  bool _isCheckingPreference = true;
  bool _isLocked = true;
  bool _isAuthenticating = false;
  bool _useBiometrics = false;
  bool _hasPin = false;
  bool _isVerifyingPin = false;
  String _userName = '';
  String _profilePhotoPath = '';

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

    _pinController.dispose();

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

    if ((_useBiometrics || _hasPin) && mounted) {
      setState(() {
        _isLocked = true;
      });
    }
  }

  Future<String> _loadProfilePhotoPath(SharedPreferences preferences) async {
    final String savedPhotoPath =
        preferences.getString('profilePhotoPath')?.trim() ?? '';

    if (savedPhotoPath.isEmpty) {
      return '';
    }

    final File photoFile = File(savedPhotoPath);

    if (await photoFile.exists()) {
      return savedPhotoPath;
    }

    await preferences.remove('profilePhotoPath');

    return '';
  }

  Future<void> _initializeSecurity() async {
    try {
      final SharedPreferences preferences =
          await SharedPreferences.getInstance();

      final bool useBiometrics =
          preferences.getBool(_biometricPreferenceKey) ?? false;

      final bool hasPin = await PinSecurityService.instance.hasPin();

      final String userName = preferences.getString('userName')?.trim() ?? '';

      final String profilePhotoPath = await _loadProfilePhotoPath(preferences);

      if (!mounted) {
        return;
      }

      setState(() {
        _useBiometrics = useBiometrics;
        _hasPin = hasPin;
        _userName = userName;
        _profilePhotoPath = profilePhotoPath;
        _isLocked = useBiometrics || hasPin;
        _isCheckingPreference = false;
      });

      if (!useBiometrics || hasPin) {
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

      final bool hasPin = await PinSecurityService.instance.hasPin();

      final String userName = preferences.getString('userName')?.trim() ?? '';

      final String profilePhotoPath = await _loadProfilePhotoPath(preferences);

      if (!mounted) {
        return;
      }

      final bool protectionEnabled = useBiometrics || hasPin;

      if (!protectionEnabled) {
        setState(() {
          _userName = userName;
          _profilePhotoPath = profilePhotoPath;
          _useBiometrics = false;
          _hasPin = false;
          _isLocked = false;
          _authenticateWhenResumed = false;
          _authenticationMessage = null;
        });

        return;
      }

      final bool protectionChanged =
          useBiometrics != _useBiometrics || hasPin != _hasPin;

      final bool shouldAuthenticate =
          protectionChanged || _authenticateWhenResumed || _isLocked;

      _authenticateWhenResumed = false;

      if (!shouldAuthenticate) {
        setState(() {
          _userName = userName;
          _profilePhotoPath = profilePhotoPath;
          _useBiometrics = useBiometrics;
          _hasPin = hasPin;
        });

        return;
      }

      setState(() {
        _userName = userName;
        _profilePhotoPath = profilePhotoPath;
        _useBiometrics = useBiometrics;
        _hasPin = hasPin;
        _isLocked = true;
        _authenticationMessage = null;
      });

      if (useBiometrics && !hasPin) {
        await _authenticate();
      }
    } catch (error, stackTrace) {
      debugPrint(
        'Erro ao verificar a proteção ao retornar: '
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

  Future<void> _verifyPin() async {
    if (_isVerifyingPin || !_hasPin) {
      return;
    }

    final String pin = _pinController.text.trim();

    if (!PinSecurityService.instance.isValidPinFormat(pin)) {
      setState(() {
        _authenticationMessage = 'Digite um PIN válido de 4 a 6 números.';
      });

      return;
    }

    HapticFeedback.selectionClick();

    setState(() {
      _isVerifyingPin = true;
      _authenticationMessage = null;
    });

    try {
      final bool pinIsValid = await PinSecurityService.instance.verifyPin(pin);

      if (!mounted) {
        return;
      }

      if (pinIsValid) {
        HapticFeedback.lightImpact();
        _pinController.clear();

        setState(() {
          _isVerifyingPin = false;
          _isLocked = false;
          _authenticationMessage = null;
        });

        return;
      }

      HapticFeedback.vibrate();

      setState(() {
        _isVerifyingPin = false;
        _authenticationMessage = 'PIN incorreto. Tente novamente.';
      });
    } catch (error, stackTrace) {
      debugPrint(
        'Erro ao verificar o PIN: '
        '$error\n$stackTrace',
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _isVerifyingPin = false;
        _authenticationMessage = 'Não foi possível verificar o PIN.';
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

    if ((!_useBiometrics && !_hasPin) || !_isLocked) {
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
    final ColorScheme colors = theme.colorScheme;
    final Color primaryColor = colors.primary;

    final String trimmedName = _userName.trim();

    final String firstName = trimmedName.isEmpty
        ? ''
        : trimmedName.split(RegExp(r'\s+')).first;

    final String initial = trimmedName.isEmpty
        ? 'F'
        : trimmedName.substring(0, 1).toUpperCase();

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: Stack(
          children: <Widget>[
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[
                      primaryColor.withValues(
                        alpha: theme.brightness == Brightness.dark
                            ? 0.18
                            : 0.10,
                      ),
                      theme.scaffoldBackgroundColor,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: -90,
              right: -70,
              child: IgnorePointer(
                child: Container(
                  width: 230,
                  height: 230,
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.pageHorizontal),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: AppSpacing.sm,
                          ),
                          decoration: BoxDecoration(
                            color: colors.surface.withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(100),
                            border: Border.all(
                              color: colors.outline.withValues(alpha: 0.18),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              ClipRRect(
                                borderRadius: BorderRadius.circular(7),
                                child: Image.asset(
                                  'assets/icon/finanse_icon.png',
                                  width: 26,
                                  height: 26,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Text(
                                'Finan\$e',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: primaryColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 28),
                        Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: primaryColor.withValues(alpha: 0.45),
                              width: 2,
                            ),
                            boxShadow: <BoxShadow>[
                              BoxShadow(
                                color: Colors.black.withValues(
                                  alpha: theme.brightness == Brightness.dark
                                      ? 0.22
                                      : 0.08,
                                ),
                                blurRadius: 22,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: CircleAvatar(
                            radius: 48,
                            backgroundColor: primaryColor.withValues(
                              alpha: 0.14,
                            ),
                            backgroundImage: _profilePhotoPath.isEmpty
                                ? null
                                : FileImage(File(_profilePhotoPath)),
                            child: _profilePhotoPath.isEmpty
                                ? Text(
                                    initial,
                                    style: theme.textTheme.headlineMedium
                                        ?.copyWith(
                                          color: primaryColor,
                                          fontWeight: FontWeight.w700,
                                        ),
                                  )
                                : null,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          firstName.isEmpty ? 'Bem-vindo' : 'Olá, $firstName',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'Seu espaço financeiro está protegido.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: colors.onSurface.withValues(alpha: 0.68),
                          ),
                        ),
                        const SizedBox(height: 28),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: colors.surface.withValues(alpha: 0.94),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: colors.outline.withValues(alpha: 0.16),
                            ),
                            boxShadow: <BoxShadow>[
                              BoxShadow(
                                color: Colors.black.withValues(
                                  alpha: theme.brightness == Brightness.dark
                                      ? 0.20
                                      : 0.07,
                                ),
                                blurRadius: 28,
                                offset: const Offset(0, 12),
                              ),
                            ],
                          ),
                          child: Column(
                            children: <Widget>[
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Container(
                                    width: 46,
                                    height: 46,
                                    decoration: BoxDecoration(
                                      color: primaryColor.withValues(
                                        alpha: 0.12,
                                      ),
                                      borderRadius: BorderRadius.circular(15),
                                    ),
                                    child: Icon(
                                      Icons.shield_outlined,
                                      color: primaryColor,
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.md),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: <Widget>[
                                        Text(
                                          'Confirme sua identidade',
                                          style: theme.textTheme.titleMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.w700,
                                              ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Desbloqueie para acessar seus dados financeiros.',
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                                color: colors.onSurface
                                                    .withValues(alpha: 0.65),
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              if (_authenticationMessage != null) ...<Widget>[
                                const SizedBox(height: AppSpacing.lg),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(AppSpacing.md),
                                  decoration: BoxDecoration(
                                    color: AppColors.error.withValues(
                                      alpha: 0.10,
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: AppColors.error.withValues(
                                        alpha: 0.32,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      const Icon(
                                        Icons.info_outline_rounded,
                                        color: AppColors.error,
                                        size: 21,
                                      ),
                                      const SizedBox(width: AppSpacing.sm),
                                      Expanded(
                                        child: Text(
                                          _authenticationMessage!,
                                          style: theme.textTheme.bodyMedium
                                              ?.copyWith(
                                                color: AppColors.error,
                                              ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              if (_hasPin) ...<Widget>[
                                const SizedBox(height: AppSpacing.xl),
                                TextField(
                                  controller: _pinController,
                                  autofocus: !_useBiometrics,
                                  enabled: !_isVerifyingPin,
                                  keyboardType: TextInputType.number,
                                  textInputAction: TextInputAction.done,
                                  textAlign: TextAlign.center,
                                  obscureText: true,
                                  enableSuggestions: false,
                                  autocorrect: false,
                                  maxLength: 6,
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    letterSpacing: 8,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  inputFormatters: <TextInputFormatter>[
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  onSubmitted: (_) {
                                    if (!_isVerifyingPin) {
                                      _verifyPin();
                                    }
                                  },
                                  decoration: InputDecoration(
                                    labelText: 'PIN de acesso',
                                    hintText: '••••',
                                    counterText: '',
                                    filled: true,
                                    fillColor: colors.surfaceContainerHighest
                                        .withValues(alpha: 0.42),
                                    prefixIcon: Icon(
                                      Icons.password_rounded,
                                      color: primaryColor,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide.none,
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide(
                                        color: colors.outline.withValues(
                                          alpha: 0.18,
                                        ),
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide(
                                        color: primaryColor,
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.md),
                                SizedBox(
                                  width: double.infinity,
                                  height: 54,
                                  child: FilledButton.icon(
                                    onPressed: _isVerifyingPin
                                        ? null
                                        : _verifyPin,
                                    icon: _isVerifyingPin
                                        ? SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.2,
                                              color: colors.onPrimary,
                                            ),
                                          )
                                        : const Icon(Icons.lock_open_rounded),
                                    label: Text(
                                      _isVerifyingPin
                                          ? 'Verificando...'
                                          : 'Entrar com PIN',
                                    ),
                                  ),
                                ),
                              ],
                              if (_useBiometrics) ...<Widget>[
                                SizedBox(
                                  height: _hasPin
                                      ? AppSpacing.lg
                                      : AppSpacing.xl,
                                ),
                                if (_hasPin) ...<Widget>[
                                  Row(
                                    children: <Widget>[
                                      Expanded(
                                        child: Divider(
                                          color: colors.outline.withValues(
                                            alpha: 0.24,
                                          ),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: AppSpacing.md,
                                        ),
                                        child: Text(
                                          'ou',
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                                color: colors.onSurface
                                                    .withValues(alpha: 0.55),
                                              ),
                                        ),
                                      ),
                                      Expanded(
                                        child: Divider(
                                          color: colors.outline.withValues(
                                            alpha: 0.24,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: AppSpacing.lg),
                                ],
                                SizedBox(
                                  width: double.infinity,
                                  height: 54,
                                  child: OutlinedButton.icon(
                                    onPressed: _isAuthenticating
                                        ? null
                                        : _authenticate,
                                    icon: _isAuthenticating
                                        ? SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.2,
                                              color: primaryColor,
                                            ),
                                          )
                                        : const Icon(Icons.fingerprint_rounded),
                                    label: Text(
                                      _isAuthenticating
                                          ? 'Verificando...'
                                          : 'Usar biometria',
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            Icon(
                              Icons.verified_user_outlined,
                              size: 16,
                              color: colors.onSurface.withValues(alpha: 0.50),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Flexible(
                              child: Text(
                                'Proteção local no seu dispositivo',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colors.onSurface.withValues(
                                    alpha: 0.55,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
