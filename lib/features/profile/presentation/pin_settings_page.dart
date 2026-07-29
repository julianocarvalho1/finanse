import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/security/pin_security_service.dart';

class PinSettingsPage extends StatefulWidget {
  const PinSettingsPage({super.key});

  @override
  State<PinSettingsPage> createState() {
    return _PinSettingsPageState();
  }
}

class _PinSettingsPageState extends State<PinSettingsPage> {
  final TextEditingController _currentPinController = TextEditingController();

  final TextEditingController _newPinController = TextEditingController();

  final TextEditingController _confirmPinController = TextEditingController();

  bool _isLoading = true;
  bool _isSavingPin = false;
  bool _isRemovingPin = false;

  bool get _isBusy {
    return _isSavingPin || _isRemovingPin;
  }

  bool _hasPin = false;

  @override
  void initState() {
    super.initState();
    _loadPinStatus();
  }

  Future<void> _loadPinStatus() async {
    try {
      final bool hasPin = await PinSecurityService.instance.hasPin();

      if (!mounted) {
        return;
      }

      setState(() {
        _hasPin = hasPin;
        _isLoading = false;
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
        _isLoading = false;
      });

      _showMessage(
        'Não foi possível verificar a proteção por PIN.',
        isError: true,
      );
    }
  }

  void _showMessage(String message, {required bool isError}) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: isError ? Colors.red.shade700 : null,
        ),
      );
  }

  Future<void> _savePin() async {
    if (_isBusy) {
      return;
    }

    final String currentPin = _currentPinController.text.trim();
    final String newPin = _newPinController.text.trim();
    final String confirmation = _confirmPinController.text.trim();

    if (!PinSecurityService.instance.isValidPinFormat(newPin)) {
      _showMessage('O PIN deve conter entre 4 e 6 números.', isError: true);
      return;
    }

    if (newPin != confirmation) {
      _showMessage('A confirmação do PIN não corresponde.', isError: true);
      return;
    }

    if (_hasPin && currentPin.isEmpty) {
      _showMessage('Digite o PIN atual.', isError: true);
      return;
    }

    setState(() {
      _isSavingPin = true;
    });

    try {
      if (_hasPin) {
        final bool currentPinIsValid = await PinSecurityService.instance
            .verifyPin(currentPin);

        if (!currentPinIsValid) {
          if (!mounted) {
            return;
          }

          setState(() {
            _isSavingPin = false;
          });

          _showMessage('O PIN atual está incorreto.', isError: true);
          return;
        }
      }

      await PinSecurityService.instance.savePin(newPin);

      HapticFeedback.mediumImpact();

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(true);
    } catch (error, stackTrace) {
      debugPrint(
        'Erro ao salvar o PIN: '
        '$error\n$stackTrace',
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _isSavingPin = false;
      });

      _showMessage('Não foi possível salvar o PIN.', isError: true);
    }
  }

  Future<void> _removePin() async {
    if (_isBusy || !_hasPin) {
      return;
    }

    final String currentPin = _currentPinController.text.trim();

    if (currentPin.isEmpty) {
      _showMessage(
        'Digite o PIN atual para remover a proteção.',
        isError: true,
      );
      return;
    }

    setState(() {
      _isRemovingPin = true;
    });

    try {
      final bool currentPinIsValid = await PinSecurityService.instance
          .verifyPin(currentPin);

      if (!currentPinIsValid) {
        if (!mounted) {
          return;
        }

        setState(() {
          _isRemovingPin = false;
        });

        _showMessage('O PIN atual está incorreto.', isError: true);
        return;
      }

      if (!mounted) {
        return;
      }

      final bool confirmed =
          await showDialog<bool>(
            context: context,
            builder: (BuildContext dialogContext) {
              return AlertDialog(
                title: const Text('Remover PIN?'),
                content: const Text(
                  'O aplicativo deixará de aceitar o PIN como forma de desbloqueio.',
                ),
                actions: <Widget>[
                  TextButton(
                    onPressed: () {
                      Navigator.of(dialogContext).pop(false);
                    },
                    child: const Text('Cancelar'),
                  ),
                  FilledButton(
                    onPressed: () {
                      Navigator.of(dialogContext).pop(true);
                    },
                    child: const Text('Remover'),
                  ),
                ],
              );
            },
          ) ??
          false;

      if (!confirmed) {
        if (mounted) {
          setState(() {
            _isRemovingPin = false;
          });
        }

        return;
      }

      await PinSecurityService.instance.removePin();

      HapticFeedback.mediumImpact();

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(false);
    } catch (error, stackTrace) {
      debugPrint(
        'Erro ao remover o PIN: '
        '$error\n$stackTrace',
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _isRemovingPin = false;
      });

      _showMessage('Não foi possível remover o PIN.', isError: true);
    }
  }

  Widget _buildPinField({
    required TextEditingController controller,
    required String label,
    required TextInputAction textInputAction,
    VoidCallback? onSubmitted,
  }) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      textInputAction: textInputAction,
      obscureText: true,
      enableSuggestions: false,
      autocorrect: false,
      maxLength: 6,
      inputFormatters: <TextInputFormatter>[
        FilteringTextInputFormatter.digitsOnly,
      ],
      onSubmitted: (_) {
        onSubmitted?.call();
      },
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.pin_outlined),
        border: const OutlineInputBorder(),
        counterText: '',
      ),
    );
  }

  @override
  void dispose() {
    _currentPinController.dispose();
    _newPinController.dispose();
    _confirmPinController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color primaryColor = theme.colorScheme.primary;

    return Scaffold(
      appBar: AppBar(title: const Text('PIN de acesso')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: <Widget>[
                  Center(
                    child: Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.14),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.password_rounded,
                        size: 42,
                        color: primaryColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _hasPin ? 'PIN ativo' : 'Criar PIN',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _hasPin
                        ? 'Digite o PIN atual para alterá-lo ou removê-lo.'
                        : 'Crie um PIN de 4 a 6 números para proteger o Finanse.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 32),
                  if (_hasPin) ...<Widget>[
                    _buildPinField(
                      controller: _currentPinController,
                      label: 'PIN atual',
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 16),
                  ],
                  _buildPinField(
                    controller: _newPinController,
                    label: _hasPin ? 'Novo PIN' : 'PIN',
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 16),
                  _buildPinField(
                    controller: _confirmPinController,
                    label: 'Confirmar PIN',
                    textInputAction: TextInputAction.done,
                    onSubmitted: _savePin,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 52,
                    child: FilledButton.icon(
                      onPressed: _isBusy ? null : _savePin,
                      icon: _isSavingPin
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.save_rounded),
                      label: Text(
                        _isSavingPin
                            ? _hasPin
                                  ? 'Alterando...'
                                  : 'Criando...'
                            : _hasPin
                            ? 'Alterar PIN'
                            : 'Criar PIN',
                      ),
                    ),
                  ),
                  if (_hasPin) ...<Widget>[
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 52,
                      child: OutlinedButton.icon(
                        onPressed: _isBusy ? null : _removePin,
                        icon: _isRemovingPin
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.delete_outline_rounded),
                        label: Text(
                          _isRemovingPin ? 'Removendo...' : 'Remover PIN',
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Text(
                    'O PIN não será salvo em texto puro e não será incluído no backup.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
    );
  }
}
