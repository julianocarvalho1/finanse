import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../security/pin_security_service.dart';

class PinLockGate extends StatefulWidget {
  const PinLockGate({
    required this.child,
    this.pinService,
    this.gracePeriod = const Duration(seconds: 30),
    this.nowProvider,
    super.key,
  });

  final Widget child;
  final PinSecurityService? pinService;
  final Duration gracePeriod;
  final DateTime Function()? nowProvider;

  @override
  State<PinLockGate> createState() => _PinLockGateState();
}

class _PinLockGateState extends State<PinLockGate> with WidgetsBindingObserver {
  late final PinSecurityService _pinService;
  late final DateTime Function() _nowProvider;

  bool _isChecking = true;
  bool _isLocked = false;
  bool _hasLoadError = false;
  DateTime? _leftAppAt;

  @override
  void initState() {
    super.initState();
    _pinService = widget.pinService ?? PinSecurityService.instance;
    _nowProvider = widget.nowProvider ?? DateTime.now;
    WidgetsBinding.instance.addObserver(this);
    _refreshPinState(forceLock: true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        final DateTime? leftAppAt = _leftAppAt;
        _leftAppAt = null;

        if (leftAppAt == null) {
          return;
        }

        final Duration timeOutsideApp = _nowProvider().difference(leftAppAt);

        if (timeOutsideApp >= widget.gracePeriod) {
          _refreshPinState(forceLock: true);
        }
        return;
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _leftAppAt ??= _nowProvider();
        return;
    }
  }

  Future<void> _refreshPinState({required bool forceLock}) async {
    if (mounted) {
      setState(() {
        _isChecking = true;
        _hasLoadError = false;
      });
    }

    try {
      final bool hasPin = await _pinService.hasPin();

      if (!mounted) {
        return;
      }

      setState(() {
        _isLocked = hasPin && (forceLock || _isLocked);
        _isChecking = false;
      });
    } catch (error, stackTrace) {
      debugPrint('Erro ao carregar bloqueio por PIN: $error\n$stackTrace');

      if (!mounted) {
        return;
      }

      setState(() {
        _isChecking = false;
        _hasLoadError = true;
        _isLocked = true;
      });
    }
  }

  void _handleUnlocked() {
    setState(() {
      _isLocked = false;
      _leftAppAt = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_hasLoadError) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(Icons.lock_reset_rounded, size: 48),
                  const SizedBox(height: 16),
                  const Text(
                    'Não foi possível verificar a proteção por PIN.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: () {
                      _refreshPinState(forceLock: true);
                    },
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Tentar novamente'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (_isLocked) {
      return PinUnlockPage(
        pinService: _pinService,
        onUnlocked: _handleUnlocked,
      );
    }

    return widget.child;
  }
}

class PinUnlockPage extends StatefulWidget {
  const PinUnlockPage({
    required this.pinService,
    required this.onUnlocked,
    super.key,
  });

  final PinSecurityService pinService;
  final VoidCallback onUnlocked;

  @override
  State<PinUnlockPage> createState() => _PinUnlockPageState();
}

class _PinUnlockPageState extends State<PinUnlockPage> {
  final TextEditingController _pinController = TextEditingController();
  final FocusNode _pinFocusNode = FocusNode();

  Timer? _lockoutTimer;
  bool _isVerifying = false;
  bool _hidePin = true;
  int _lockoutSeconds = 0;
  String? _errorMessage;

  bool get _canVerify {
    return !_isVerifying &&
        _lockoutSeconds == 0 &&
        widget.pinService.isValidPinFormat(_pinController.text);
  }

  @override
  void initState() {
    super.initState();
    _pinController.addListener(_handlePinChanged);
    _loadLockoutState();
  }

  @override
  void dispose() {
    _lockoutTimer?.cancel();
    _pinController
      ..removeListener(_handlePinChanged)
      ..dispose();
    _pinFocusNode.dispose();
    super.dispose();
  }

  void _handlePinChanged() {
    if (mounted) {
      setState(() {
        _errorMessage = null;
      });
    }
  }

  Future<void> _loadLockoutState() async {
    final Duration remaining = await widget.pinService.getLockoutRemaining();

    if (!mounted) {
      return;
    }

    _startLockoutCountdown(remaining);
  }

  void _startLockoutCountdown(Duration duration) {
    _lockoutTimer?.cancel();

    final int seconds = (duration.inMilliseconds / 1000).ceil();

    setState(() {
      _lockoutSeconds = seconds;
      if (seconds > 0) {
        _errorMessage = null;
      }
    });

    if (seconds <= 0) {
      return;
    }

    _lockoutTimer = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_lockoutSeconds <= 1) {
        timer.cancel();
        setState(() {
          _lockoutSeconds = 0;
        });
        _pinFocusNode.requestFocus();
        return;
      }

      setState(() {
        _lockoutSeconds -= 1;
      });
    });
  }

  Future<void> _verifyPin() async {
    if (!_canVerify) {
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    try {
      final PinVerificationResult result = await widget.pinService
          .verifyPinWithProtection(_pinController.text);

      if (!mounted) {
        return;
      }

      if (result.isValid) {
        HapticFeedback.mediumImpact();
        widget.onUnlocked();
        return;
      }

      _pinController.clear();

      if (result.isLocked) {
        _startLockoutCountdown(result.retryAfter);
      } else {
        setState(() {
          _errorMessage = result.attemptsRemaining == 1
              ? 'PIN incorreto. Resta 1 tentativa.'
              : 'PIN incorreto. Restam ${result.attemptsRemaining} tentativas.';
        });
        _pinFocusNode.requestFocus();
      }
    } catch (error, stackTrace) {
      debugPrint('Erro ao verificar PIN: $error\n$stackTrace');

      if (mounted) {
        setState(() {
          _errorMessage = 'Não foi possível verificar o PIN. Tente novamente.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isVerifying = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color primaryColor = theme.colorScheme.primary;
    final bool isLockedOut = _lockoutSeconds > 0;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: AutofillGroup(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.lock_rounded,
                        color: primaryColor,
                        size: 46,
                      ),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      'Finanse bloqueado',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isLockedOut
                          ? 'Aguarde $_lockoutSeconds segundos para tentar novamente.'
                          : 'Digite seu PIN para acessar seus dados financeiros.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 28),
                    TextField(
                      key: const ValueKey<String>('pin-unlock-field'),
                      controller: _pinController,
                      focusNode: _pinFocusNode,
                      autofocus: !isLockedOut,
                      enabled: !isLockedOut && !_isVerifying,
                      obscureText: _hidePin,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      autofillHints: const <String>[AutofillHints.password],
                      enableSuggestions: false,
                      autocorrect: false,
                      maxLength: 6,
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      onSubmitted: (_) {
                        _verifyPin();
                      },
                      decoration: InputDecoration(
                        labelText: 'PIN',
                        hintText: '4 a 6 números',
                        counterText: '',
                        errorText: _errorMessage,
                        prefixIcon: const Icon(Icons.password_rounded),
                        suffixIcon: IconButton(
                          tooltip: _hidePin ? 'Mostrar PIN' : 'Ocultar PIN',
                          onPressed: isLockedOut
                              ? null
                              : () {
                                  setState(() {
                                    _hidePin = !_hidePin;
                                  });
                                },
                          icon: Icon(
                            _hidePin
                                ? Icons.visibility_rounded
                                : Icons.visibility_off_rounded,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton.icon(
                        key: const ValueKey<String>('pin-unlock-button'),
                        onPressed: _canVerify ? _verifyPin : null,
                        icon: _isVerifying
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.lock_open_rounded),
                        label: Text(
                          _isVerifying ? 'Verificando...' : 'Desbloquear',
                        ),
                      ),
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
