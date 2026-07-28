import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/expense_notifier.dart';
import '../../../../core/utils/theme_notifier.dart';
import '../../recurring_expenses/data/recurring_notification_scheduler.dart';
import '../data/backup_service.dart';

class BackupPage extends StatefulWidget {
  const BackupPage({super.key});

  @override
  State<BackupPage> createState() {
    return _BackupPageState();
  }
}

class _BackupPageState extends State<BackupPage> {
  final DateFormat _dateFormat = DateFormat("dd/MM/yyyy 'às' HH:mm");

  bool _isLoadingLastBackup = true;
  bool _isCreatingBackup = false;
  bool _isRestoring = false;

  DateTime? _lastBackupDate;

  bool get _isBusy {
    return _isCreatingBackup || _isRestoring;
  }

  @override
  void initState() {
    super.initState();

    _loadLastBackupDate();
  }

  Future<void> _loadLastBackupDate() async {
    try {
      final DateTime? lastBackupDate = await BackupService.instance
          .getLastBackupDate();

      if (!mounted) {
        return;
      }

      setState(() {
        _lastBackupDate = lastBackupDate;
        _isLoadingLastBackup = false;
      });
    } catch (error, stackTrace) {
      debugPrint(
        'Erro ao carregar a data do último backup: '
        '$error\n$stackTrace',
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _isLoadingLastBackup = false;
      });
    }
  }

  Future<void> _createBackup() async {
    if (_isBusy) {
      return;
    }

    HapticFeedback.selectionClick();

    setState(() {
      _isCreatingBackup = true;
    });

    CreatedBackup? createdBackup;

    try {
      createdBackup = await BackupService.instance.createBackup();

      if (!mounted) {
        return;
      }

      setState(() {
        _lastBackupDate = createdBackup!.createdAt;
      });

      await BackupService.instance.shareBackup(createdBackup);

      if (!mounted) {
        return;
      }

      HapticFeedback.mediumImpact();

      final String recordLabel = createdBackup.totalRecordCount == 1
          ? 'registro'
          : 'registros';

      _showMessage(
        'Backup criado com '
        '${createdBackup.totalRecordCount} $recordLabel.',
      );
    } on BackupException catch (error) {
      if (!mounted) {
        return;
      }

      HapticFeedback.vibrate();

      _showMessage(error.message, isError: true);
    } catch (error, stackTrace) {
      debugPrint(
        'Erro inesperado ao criar backup: '
        '$error\n$stackTrace',
      );

      if (!mounted) {
        return;
      }

      HapticFeedback.vibrate();

      _showMessage(
        createdBackup == null
            ? 'Não foi possível criar o backup.'
            : 'O backup foi criado, mas não foi possível compartilhá-lo.',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isCreatingBackup = false;
        });
      }
    }
  }

  Future<void> _selectAndRestoreBackup() async {
    if (_isBusy) {
      return;
    }

    HapticFeedback.selectionClick();

    try {
      final SelectedBackup? selectedBackup = await BackupService.instance
          .selectBackupFile();

      if (selectedBackup == null || !mounted) {
        return;
      }

      final bool confirmed = await _confirmRestore(selectedBackup);

      if (!confirmed || !mounted) {
        return;
      }

      setState(() {
        _isRestoring = true;
      });

      final BackupRestoreResult result = await BackupService.instance
          .restoreBackup(selectedBackup);

      // Atualiza Início, Histórico e Relatórios.
      expenseNotifier.value++;

      // Atualiza a cor e o modo visual restaurados.
      await _applyRestoredTheme();

      // Recria ou cancela os lembretes das recorrências restauradas.
      try {
        await RecurringNotificationScheduler.instance
            .synchronizeAllRecurringExpenses();
      } catch (error, stackTrace) {
        debugPrint(
          'O backup foi restaurado, mas os lembretes '
          'não puderam ser sincronizados: '
          '$error\n$stackTrace',
        );
      }

      if (!mounted) {
        return;
      }

      HapticFeedback.heavyImpact();

      final String expenseLabel = result.expenseCount == 1
          ? 'despesa'
          : 'despesas';

      final String recurringLabel = result.recurringExpenseCount == 1
          ? 'recorrência'
          : 'recorrências';

      _showMessage(
        'Backup restaurado: '
        '${result.expenseCount} $expenseLabel e '
        '${result.recurringExpenseCount} $recurringLabel.',
      );
    } on BackupException catch (error) {
      if (!mounted) {
        return;
      }

      HapticFeedback.vibrate();

      _showMessage(error.message, isError: true);
    } catch (error, stackTrace) {
      debugPrint(
        'Erro inesperado ao restaurar backup: '
        '$error\n$stackTrace',
      );

      if (!mounted) {
        return;
      }

      HapticFeedback.vibrate();

      _showMessage('Não foi possível restaurar o backup.', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isRestoring = false;
        });
      }
    }
  }

  Future<void> _applyRestoredTheme() async {
    try {
      final SharedPreferences preferences =
          await SharedPreferences.getInstance();

      final int? savedColor = preferences.getInt('themeColor');

      final String? savedMode = preferences.getString('themeMode');

      final Color restoredColor = savedColor == null
          ? const Color(0xFF22C55E)
          : Color(savedColor);

      ThemeMode restoredMode = ThemeMode.system;

      if (savedMode == 'light') {
        restoredMode = ThemeMode.light;
      } else if (savedMode == 'dark') {
        restoredMode = ThemeMode.dark;
      }

      await themeNotifier.updateColor(restoredColor);

      await themeNotifier.updateMode(restoredMode);
    } catch (error, stackTrace) {
      debugPrint(
        'Não foi possível aplicar o tema restaurado: '
        '$error\n$stackTrace',
      );
    }
  }

  Future<bool> _confirmRestore(SelectedBackup backup) async {
    final ThemeData theme = Theme.of(context);

    final bool? confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Row(
            children: <Widget>[
              Icon(Icons.warning_amber_rounded, color: AppColors.warning),
              SizedBox(width: 12),
              Expanded(child: Text('Restaurar backup?')),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Os dados atuais do Finanse serão substituídos '
                'pelos dados deste arquivo.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 18),
              _buildConfirmationInformation(
                context: dialogContext,
                label: 'Arquivo',
                value: backup.fileName,
              ),
              const SizedBox(height: 10),
              _buildConfirmationInformation(
                context: dialogContext,
                label: 'Criado em',
                value: _dateFormat.format(backup.createdAt),
              ),
              const SizedBox(height: 10),
              _buildConfirmationInformation(
                context: dialogContext,
                label: 'Despesas',
                value: backup.expenseCount.toString(),
              ),
              const SizedBox(height: 10),
              _buildConfirmationInformation(
                context: dialogContext,
                label: 'Recorrências',
                value: backup.recurringExpenseCount.toString(),
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.warning.withValues(alpha: 0.35),
                  ),
                ),
                child: Text(
                  'Esta operação não pode ser desfeita. '
                  'Crie um backup dos dados atuais antes de continuar.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.warning,
                    height: 1.4,
                  ),
                ),
              ),
            ],
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
              style: FilledButton.styleFrom(backgroundColor: AppColors.error),
              child: const Text('Restaurar'),
            ),
          ],
        );
      },
    );

    return confirmed ?? false;
  }

  Widget _buildConfirmationInformation({
    required BuildContext context,
    required String label,
    required String value,
  }) {
    final ThemeData theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: 92,
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textMuted(context),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textPrimary(context),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  void _showMessage(String message, {bool isError = false}) {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: <Widget>[
              Icon(
                isError
                    ? Icons.error_outline_rounded
                    : Icons.check_circle_outline_rounded,
                color: Colors.white,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: isError
              ? AppColors.error
              : Theme.of(context).colorScheme.primary,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color primaryColor = theme.colorScheme.primary;

    final Color textPrimary = AppColors.textPrimary(context);

    final Color textSecondary = AppColors.textSecondary(context);

    final Color textMuted = AppColors.textMuted(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Backup e restauração'),
        centerTitle: true,
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: primaryColor.withValues(alpha: 0.25)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(Icons.shield_outlined, color: primaryColor, size: 29),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Crie uma cópia das despesas, recorrências '
                      'e configurações do Finanse para guardar '
                      'em um local seguro.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: textSecondary,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            Text(
              'CRIAR BACKUP',
              style: theme.textTheme.labelMedium?.copyWith(
                color: textMuted,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface(context),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border(context)),
              ),
              child: Column(
                children: <Widget>[
                  Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.cloud_upload_outlined,
                      color: primaryColor,
                      size: 34,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Último backup',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: textMuted,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (_isLoadingLastBackup)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    Text(
                      _lastBackupDate == null
                          ? 'Ainda não realizado'
                          : _dateFormat.format(_lastBackupDate!),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _isBusy ? null : _createBackup,
                      icon: _isCreatingBackup
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: theme.colorScheme.onPrimary,
                              ),
                            )
                          : const Icon(Icons.ios_share_rounded),
                      label: Text(
                        _isCreatingBackup
                            ? 'Criando backup...'
                            : 'Criar e compartilhar backup',
                      ),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            Text(
              'RESTAURAR DADOS',
              style: theme.textTheme.labelMedium?.copyWith(
                color: textMuted,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface(context),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border(context)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceSecondary(context),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          Icons.restore_rounded,
                          color: textSecondary,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              'Restaurar arquivo',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              'Selecione um arquivo .finanse '
                              'criado anteriormente.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: textSecondary,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _isBusy ? null : _selectAndRestoreBackup,
                      icon: _isRestoring
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                              ),
                            )
                          : const Icon(Icons.folder_open_rounded),
                      label: Text(
                        _isRestoring
                            ? 'Restaurando dados...'
                            : 'Selecionar backup',
                      ),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.09),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.warning.withValues(alpha: 0.30),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Icon(
                    Icons.info_outline_rounded,
                    color: AppColors.warning,
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'A restauração substitui os dados atuais. '
                      'A biometria deste aparelho não será alterada.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
