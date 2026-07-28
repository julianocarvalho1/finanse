import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/expense_notifier.dart';
import '../../../../core/utils/theme_notifier.dart';
import '../../recurring_expenses/presentation/recurring_expenses_page.dart';
import 'backup_page.dart';
import 'export_page.dart';
import '../../../../core/notifications/notification_service.dart';
import '../../recurring_expenses/data/recurring_notification_scheduler.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../../../../core/security/biometric_service.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() {
    return _ProfilePageState();
  }
}

class _ProfilePageState extends State<ProfilePage> {
  double _monthlyLimit = 2000.0;

  bool _useBiometrics = false;
  bool _notificationsEnabled = false;

  bool _isUpdatingNotifications = false;
  bool _isUpdatingBiometrics = false;

  @override
  void initState() {
    super.initState();

    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();

    final bool notificationsSavedAsEnabled =
        preferences.getBool('notificationsEnabled') ?? false;

    bool notificationsAllowed = false;

    try {
      notificationsAllowed = await NotificationService.instance
          .areNotificationsAllowed();
    } catch (_) {
      notificationsAllowed = false;
    }

    final bool notificationsActuallyEnabled =
        notificationsSavedAsEnabled && notificationsAllowed;

    if (notificationsSavedAsEnabled && !notificationsAllowed) {
      await preferences.setBool('notificationsEnabled', false);
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _monthlyLimit = preferences.getDouble('monthlyLimit') ?? 2000.0;

      _useBiometrics = preferences.getBool('useBiometrics') ?? false;

      _notificationsEnabled = notificationsActuallyEnabled;
    });
  }

  Future<void> _changeNotifications(bool newValue) async {
    if (_isUpdatingNotifications) {
      return;
    }

    setState(() {
      _isUpdatingNotifications = true;
    });

    try {
      final SharedPreferences preferences =
          await SharedPreferences.getInstance();

      if (!newValue) {
        await NotificationService.instance.cancelAllScheduledNotifications();

        await preferences.setBool('notificationsEnabled', false);

        if (!mounted) {
          return;
        }

        setState(() {
          _notificationsEnabled = false;
        });

        _showProfileMessage(
          'Notificações desativadas e lembretes futuros cancelados.',
        );

        return;
      }

      final NotificationPermissionResult permissionResult =
          await NotificationService.instance.requestPermissions(
            requestExactAlarms: true,
          );

      if (!permissionResult.notificationsAllowed) {
        await preferences.setBool('notificationsEnabled', false);

        if (!mounted) {
          return;
        }

        setState(() {
          _notificationsEnabled = false;
        });

        _showProfileMessage(
          'A permissão para notificações não foi concedida.',
          isError: true,
        );

        return;
      }

      await preferences.setBool('notificationsEnabled', true);

      if (!mounted) {
        return;
      }

      setState(() {
        _notificationsEnabled = true;
      });

      await NotificationService.instance.showTestNotification();

      if (!mounted) {
        return;
      }

      if (permissionResult.exactAlarmsAllowed) {
        _showProfileMessage(
          'Notificações ativadas. Uma notificação de teste foi enviada.',
        );
      } else {
        _showProfileMessage(
          'Notificações ativadas. Os horários poderão ser aproximados.',
        );
      }
    } catch (_) {
      if (!mounted) {
        return;
      }

      _showProfileMessage(
        'Não foi possível alterar as notificações.',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingNotifications = false;
        });
      }
    }
  }

  Future<void> _changeBiometrics(bool newValue) async {
    if (_isUpdatingBiometrics || newValue == _useBiometrics) {
      return;
    }

    HapticFeedback.selectionClick();

    setState(() {
      _isUpdatingBiometrics = true;
    });

    try {
      final SharedPreferences preferences =
          await SharedPreferences.getInstance();

      if (newValue) {
        final BiometricAvailabilityResult availability = await BiometricService
            .instance
            .checkAvailability();

        if (!availability.isAvailable) {
          if (!mounted) {
            return;
          }

          _showProfileMessage(availability.message, isError: true);

          return;
        }

        final BiometricAuthenticationResult result = await BiometricService
            .instance
            .authenticate(
              reason:
                  'Confirme sua biometria para ativar a proteção do Finanse.',
            );

        if (!result.authenticated) {
          if (!mounted) {
            return;
          }

          if (!result.wasCanceled) {
            _showProfileMessage(result.message, isError: true);
          }

          return;
        }

        await preferences.setBool('useBiometrics', true);

        if (!mounted) {
          return;
        }

        setState(() {
          _useBiometrics = true;
        });

        _showProfileMessage('Bloqueio por biometria ativado.');

        return;
      }

      final BiometricAuthenticationResult result = await BiometricService
          .instance
          .authenticate(
            reason:
                'Confirme sua biometria para desativar a proteção do Finanse.',
          );

      if (!result.authenticated) {
        if (!mounted) {
          return;
        }

        if (!result.wasCanceled) {
          _showProfileMessage(result.message, isError: true);
        }

        return;
      }

      await preferences.setBool('useBiometrics', false);

      if (!mounted) {
        return;
      }

      setState(() {
        _useBiometrics = false;
      });

      _showProfileMessage('Bloqueio por biometria desativado.');
    } catch (error, stackTrace) {
      debugPrint(
        'Erro ao alterar a biometria: '
        '$error\n$stackTrace',
      );

      if (!mounted) {
        return;
      }

      _showProfileMessage(
        'Não foi possível alterar o bloqueio biométrico.',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingBiometrics = false;
        });
      }
    }
  }

  Future<void> _sendNotificationTest() async {
    if (_isUpdatingNotifications) {
      return;
    }

    setState(() {
      _isUpdatingNotifications = true;
    });

    try {
      final SharedPreferences preferences =
          await SharedPreferences.getInstance();

      final NotificationPermissionResult permissionResult =
          await NotificationService.instance.requestPermissions(
            requestExactAlarms: true,
          );

      if (!permissionResult.notificationsAllowed) {
        await preferences.setBool('notificationsEnabled', false);

        if (!mounted) {
          return;
        }

        setState(() {
          _notificationsEnabled = false;
        });

        _showProfileMessage(
          'A permissão para mostrar notificações não foi concedida.',
          isError: true,
        );

        return;
      }

      if (!permissionResult.exactAlarmsAllowed) {
        await preferences.setBool('notificationsEnabled', true);

        if (!mounted) {
          return;
        }

        setState(() {
          _notificationsEnabled = true;
        });

        _showProfileMessage(
          'Autorize o Finanse em “Alarmes e lembretes”. '
          'Depois volte ao aplicativo e toque novamente em testar.',
          isError: true,
        );

        return;
      }

      await preferences.setBool('notificationsEnabled', true);

      if (!mounted) {
        return;
      }

      setState(() {
        _notificationsEnabled = true;
      });

      await RecurringNotificationScheduler.instance
          .synchronizeAllRecurringExpenses();

      final DateTime scheduledDate = await NotificationService.instance
          .scheduleTestNotification(delay: const Duration(seconds: 15));

      final List<PendingNotificationRequest> pendingNotifications =
          await NotificationService.instance.getPendingNotifications();

      if (!mounted) {
        return;
      }

      final String scheduledTime = DateFormat('HH:mm:ss').format(scheduledDate);

      _showProfileMessage(
        'Teste agendado para $scheduledTime. '
        '${pendingNotifications.length} '
        '${pendingNotifications.length == 1 ? 'lembrete pendente' : 'lembretes pendentes'}.',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showProfileMessage(
        'Não foi possível agendar a notificação de teste.',
        isError: true,
      );

      debugPrint('Erro ao testar notificação agendada: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingNotifications = false;
        });
      }
    }
  }

  void _showProfileMessage(String message, {bool isError = false}) {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);

    messenger.clearSnackBars();

    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 5),
        persist: false,
        dismissDirection: DismissDirection.down,
        backgroundColor: isError ? AppColors.error : null,
        content: Row(
          children: <Widget>[
            Icon(
              isError
                  ? Icons.error_outline_rounded
                  : Icons.check_circle_rounded,
              color: Colors.white,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(message, style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openRecurringExpenses() async {
    HapticFeedback.selectionClick();

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) {
          return const RecurringExpensesPage();
        },
      ),
    );
  }

  void _openExport() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) {
          return const ExportPage();
        },
      ),
    );
  }

  void _openBackup() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) {
          return const BackupPage();
        },
      ),
    );
  }

  void _editMonthlyLimit() {
    final TextEditingController limitController = TextEditingController(
      text: _monthlyLimit.toStringAsFixed(0),
    );

    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    final Color backgroundColor = isDark ? AppColors.darkSurface : Colors.white;

    final Color textPrimary = isDark
        ? AppColors.darkTextPrimary
        : const Color(0xFF1A1D1F);

    final Color textSecondary = isDark
        ? AppColors.darkTextSecondary
        : const Color(0xFF535F66);

    final Color primaryColor = Theme.of(context).colorScheme.primary;

    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: backgroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Text(
            'Limite Mensal',
            style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Defina o valor máximo que você planeja gastar por mês.',
                style: TextStyle(color: textSecondary, fontSize: 14),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: limitController,
                keyboardType: TextInputType.number,
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.digitsOnly,
                ],
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: textPrimary,
                ),
                decoration: InputDecoration(
                  prefixText: 'R\$ ',
                  prefixStyle: TextStyle(
                    fontSize: 24,
                    color: isDark
                        ? AppColors.darkTextMuted
                        : const Color(0xFF8A959D),
                  ),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: primaryColor),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: primaryColor, width: 2),
                  ),
                ),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: Text('Cancelar', style: TextStyle(color: textSecondary)),
            ),
            ElevatedButton(
              onPressed: () async {
                final double? newValue = double.tryParse(limitController.text);

                if (newValue == null || newValue <= 0) {
                  return;
                }

                final SharedPreferences preferences =
                    await SharedPreferences.getInstance();

                await preferences.setDouble('monthlyLimit', newValue);

                if (!mounted) {
                  return;
                }

                setState(() {
                  _monthlyLimit = newValue;
                });

                expenseNotifier.value++;

                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Salvar',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    ).whenComplete(limitController.dispose);
  }

  Widget _buildColorOption(Color color) {
    return ValueListenableBuilder<ThemeState>(
      valueListenable: themeNotifier,
      builder: (BuildContext context, ThemeState themeState, Widget? child) {
        final bool isSelected = themeState.color.value == color.value;

        final bool isDark = Theme.of(context).brightness == Brightness.dark;

        return GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            themeNotifier.updateColor(color);
          },
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected
                    ? isDark
                          ? Colors.white
                          : const Color(0xFF1A1D1F)
                    : Colors.transparent,
                width: 3,
              ),
              boxShadow: <BoxShadow>[
                if (isSelected)
                  BoxShadow(
                    color: color.withOpacity(0.4),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
              ],
            ),
            child: isSelected
                ? const Icon(Icons.check_rounded, color: Colors.white)
                : null,
          ),
        );
      },
    );
  }

  Widget _buildThemeModeButton(
    ThemeMode mode,
    String label,
    ThemeMode currentMode,
    Color primaryColor,
    bool isDark,
  ) {
    final bool isSelected = mode == currentMode;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          themeNotifier.updateMode(mode);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? primaryColor : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected && !isDark
                ? <BoxShadow>[
                    BoxShadow(
                      color: primaryColor.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : <BoxShadow>[],
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected
                  ? Colors.white
                  : isDark
                  ? AppColors.darkTextSecondary
                  : const Color(0xFF535F66),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsGroup(List<Widget> children, bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceSecondary : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? Colors.transparent : const Color(0xFFE2E6E9),
        ),
        boxShadow: isDark
            ? <BoxShadow>[]
            : <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildSectionHeader(String title) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    final Color textMuted = isDark
        ? AppColors.darkTextMuted
        : const Color(0xFF8A959D);

    return Padding(
      padding: const EdgeInsets.only(left: 32, bottom: 8, top: 32),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: textMuted,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildListTile({
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
    Color? iconColor,
  }) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    final Color textPrimary = isDark
        ? AppColors.darkTextPrimary
        : const Color(0xFF1A1D1F);

    final Color textSecondary = isDark
        ? AppColors.darkTextSecondary
        : const Color(0xFF535F66);

    final Color textMuted = isDark
        ? AppColors.darkTextMuted
        : const Color(0xFF8A959D);

    final Color iconBackgroundColor = isDark
        ? AppColors.darkSurface
        : const Color(0xFFF0F3F5);

    final Color finalIconColor =
        iconColor ??
        (isDark ? AppColors.darkTextSecondary : const Color(0xFF535F66));

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: iconBackgroundColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: finalIconColor, size: 22),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
      ),
      subtitle: subtitle != null
          ? Text(subtitle, style: TextStyle(fontSize: 13, color: textSecondary))
          : null,
      trailing: Icon(
        Icons.arrow_forward_ios_rounded,
        color: textMuted,
        size: 16,
      ),
      onTap: onTap,
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    final Color textPrimary = isDark
        ? AppColors.darkTextPrimary
        : const Color(0xFF1A1D1F);

    final Color textSecondary = isDark
        ? AppColors.darkTextSecondary
        : const Color(0xFF535F66);

    final Color iconBackgroundColor = isDark
        ? AppColors.darkSurface
        : const Color(0xFFF0F3F5);

    final Color primaryColor = Theme.of(context).colorScheme.primary;

    return SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      secondary: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: iconBackgroundColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          color: isDark ? AppColors.darkTextSecondary : const Color(0xFF535F66),
          size: 22,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 13, color: textSecondary),
      ),
      value: value,

      // Estado ativado: trilho colorido e bolinha branca.
      activeThumbColor: Colors.white,
      activeTrackColor: primaryColor,

      // Estado desativado: contraste visível em ambos os temas.
      inactiveThumbColor: isDark ? AppColors.darkTextMuted : Colors.white,
      inactiveTrackColor: isDark
          ? AppColors.darkSurface
          : const Color(0xFFB8C0C7),

      onChanged: (bool newValue) {
        onChanged(newValue);
        HapticFeedback.lightImpact();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final NumberFormat currencyFormatter = NumberFormat.currency(
      locale: 'pt_BR',
      symbol: 'R\$',
    );

    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    final Color textPrimary = isDark
        ? AppColors.darkTextPrimary
        : const Color(0xFF1A1D1F);

    final Color textSecondary = isDark
        ? AppColors.darkTextSecondary
        : const Color(0xFF535F66);

    final Color textMuted = isDark
        ? AppColors.darkTextMuted
        : const Color(0xFF8A959D);

    final Color primaryColor = Theme.of(context).colorScheme.primary;

    final Color dividerColor = isDark
        ? AppColors.darkBorder
        : const Color(0xFFE2E6E9);

    final double topPadding = MediaQuery.paddingOf(context).top;

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.darkBackground
          : const Color(0xFFF8F9FA),
      body: ListView(
        padding: EdgeInsets.only(top: topPadding + 24, bottom: 120),
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: <Widget>[
                CircleAvatar(
                  radius: 32,
                  backgroundColor: primaryColor.withOpacity(0.15),
                  child: Text(
                    'L',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Lucas',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Membro desde 2026',
                      style: TextStyle(fontSize: 14, color: textSecondary),
                    ),
                  ],
                ),
              ],
            ),
          ),
          _buildSectionHeader('Personalização'),
          _buildSettingsGroup(<Widget>[
            ValueListenableBuilder<ThemeState>(
              valueListenable: themeNotifier,
              builder:
                  (BuildContext context, ThemeState themeState, Widget? child) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Aparência',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: textPrimary,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppColors.darkSurface
                                  : const Color(0xFFE2E6E9),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: <Widget>[
                                _buildThemeModeButton(
                                  ThemeMode.light,
                                  'Claro',
                                  themeState.mode,
                                  primaryColor,
                                  isDark,
                                ),
                                _buildThemeModeButton(
                                  ThemeMode.dark,
                                  'Escuro',
                                  themeState.mode,
                                  primaryColor,
                                  isDark,
                                ),
                                _buildThemeModeButton(
                                  ThemeMode.system,
                                  'Auto',
                                  themeState.mode,
                                  primaryColor,
                                  isDark,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
            ),
            Divider(height: 1, color: dividerColor, indent: 20, endIndent: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Cor de Destaque',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      _buildColorOption(const Color(0xFF22C55E)),
                      _buildColorOption(const Color(0xFF3B82F6)),
                      _buildColorOption(const Color(0xFF8B5CF6)),
                      _buildColorOption(const Color(0xFFF97316)),
                      _buildColorOption(const Color(0xFFEC4899)),
                    ],
                  ),
                ],
              ),
            ),
          ], isDark),
          _buildSectionHeader('Controle Financeiro'),
          _buildSettingsGroup(<Widget>[
            _buildListTile(
              icon: Icons.track_changes_rounded,
              title: 'Limite Mensal',
              subtitle: 'Atual: ${currencyFormatter.format(_monthlyLimit)}',
              iconColor: primaryColor,
              onTap: _editMonthlyLimit,
            ),
            Divider(height: 1, color: dividerColor, indent: 20, endIndent: 20),
            _buildListTile(
              icon: Icons.autorenew_rounded,
              title: 'Despesas Recorrentes',
              subtitle: 'Assinaturas e contas fixas',
              onTap: _openRecurringExpenses,
            ),
          ], isDark),
          _buildSectionHeader('Preferências'),
          _buildSettingsGroup(<Widget>[
            _buildSwitchTile(
              icon: Icons.notifications_active_rounded,
              title: 'Notificações',
              subtitle: _isUpdatingNotifications
                  ? 'Verificando permissões...'
                  : 'Lembretes de registro e alertas de limite',
              value: _notificationsEnabled,
              onChanged: _changeNotifications,
            ),
            Divider(height: 1, color: dividerColor, indent: 20, endIndent: 20),
            _buildListTile(
              icon: Icons.notification_add_rounded,
              title: 'Testar notificação',
              subtitle: 'Enviar uma notificação agora',
              iconColor: primaryColor,
              onTap: () {
                if (!_isUpdatingNotifications) {
                  _sendNotificationTest();
                }
              },
            ),
          ], isDark),
          _buildSectionHeader('Segurança e Biometria'),
          _buildSettingsGroup(<Widget>[
            _buildSwitchTile(
              icon: Icons.fingerprint_rounded,
              title: 'Bloqueio por Biometria',
              subtitle: _isUpdatingBiometrics
                  ? 'Verificando sua identidade...'
                  : _useBiometrics
                  ? 'Proteção ativa ao abrir o aplicativo'
                  : 'Exigir digital ou reconhecimento facial',
              value: _useBiometrics,
              onChanged: (bool newValue) {
                if (!_isUpdatingBiometrics) {
                  _changeBiometrics(newValue);
                }
              },
            ),
          ], isDark),
          _buildSectionHeader('Dados e Backup'),
          _buildSettingsGroup(<Widget>[
            _buildListTile(
              icon: Icons.import_export_rounded,
              title: 'Exportar Relatório',
              subtitle: 'Salvar resumo em PDF, Excel ou CSV',
              onTap: _openExport,
            ),
            Divider(height: 1, color: dividerColor, indent: 20, endIndent: 20),
            _buildListTile(
              icon: Icons.cloud_done_rounded,
              title: 'Backup e Restauração',
              subtitle: 'Faça backup seguro dos seus dados',
              onTap: _openBackup,
            ),
          ], isDark),
          const SizedBox(height: 32),
          Center(
            child: Text(
              'Finanse App v1.0.0',
              style: TextStyle(color: textMuted, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
