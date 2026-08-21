import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../data/export_service.dart';

class ExportPage extends StatefulWidget {
  const ExportPage({super.key});

  @override
  State<ExportPage> createState() {
    return _ExportPageState();
  }
}

class _ExportPageState extends State<ExportPage> {
  ExportFileFormat _selectedFormat = ExportFileFormat.csv;

  bool _isExporting = false;

  Future<void> _exportData() async {
    if (_isExporting) {
      return;
    }

    HapticFeedback.selectionClick();

    setState(() {
      _isExporting = true;
    });

    try {
      final ExportedExpenseFile exportedFile = await ExportService.instance
          .generate(_selectedFormat);

      if (!mounted) {
        return;
      }

      HapticFeedback.mediumImpact();

      await ExportService.instance.share(exportedFile);

      if (!mounted) {
        return;
      }

      final String recordLabel = exportedFile.recordCount == 1
          ? 'despesa'
          : 'despesas';

      _showMessage(
        '${exportedFile.format.label} gerado com '
        '${exportedFile.recordCount} $recordLabel.',
      );
    } on ExportException catch (error) {
      if (!mounted) {
        return;
      }

      HapticFeedback.vibrate();

      _showMessage(error.message, isError: true);
    } catch (error, stackTrace) {
      debugPrint(
        'Erro inesperado ao exportar relatório: '
        '$error\n$stackTrace',
      );

      if (!mounted) {
        return;
      }

      HapticFeedback.vibrate();

      _showMessage('Não foi possível gerar o relatório.', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    final Color backgroundColor = isError
        ? AppColors.error
        : Theme.of(context).colorScheme.primary;

    final IconData icon = isError
        ? Icons.error_outline_rounded
        : Icons.check_circle_outline_rounded;

    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: <Widget>[
              Icon(icon, color: Colors.white),
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
          backgroundColor: backgroundColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color primaryColor = theme.colorScheme.primary;
    final Color textSecondary = AppColors.textSecondary(context);
    final Color textMuted = AppColors.textMuted(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Exportar relatório'),
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
                border: Border.all(color: primaryColor.withValues(alpha: 0.24)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(
                    Icons.file_download_outlined,
                    color: primaryColor,
                    size: 29,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Gere um arquivo com todas as despesas '
                      'cadastradas no Finanse. Depois você poderá '
                      'salvar, enviar ou abrir em outro aplicativo.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: textSecondary,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            Text(
              'FORMATO DO ARQUIVO',
              style: theme.textTheme.labelMedium?.copyWith(
                color: textMuted,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 14),
            _buildFormatOption(
              context: context,
              format: ExportFileFormat.csv,
              title: 'CSV',
              description: 'Compatível com Excel e Google Planilhas',
              icon: Icons.table_chart_outlined,
            ),
            const SizedBox(height: 12),
            _buildFormatOption(
              context: context,
              format: ExportFileFormat.xlsx,
              title: 'Excel',
              description: 'Planilha editável no formato XLSX',
              icon: Icons.grid_on_rounded,
            ),
            const SizedBox(height: 12),
            _buildFormatOption(
              context: context,
              format: ExportFileFormat.pdf,
              title: 'PDF',
              description: 'Relatório organizado para leitura e impressão',
              icon: Icons.picture_as_pdf_outlined,
            ),
            const SizedBox(height: 30),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceSecondary(context),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border(context)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(
                    Icons.privacy_tip_outlined,
                    color: textSecondary,
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'O arquivo é produzido no seu aparelho. '
                      'O Finanse não envia automaticamente seus '
                      'dados financeiros para a internet.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 34),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isExporting ? null : _exportData,
                icon: _isExporting
                    ? SizedBox(
                        width: 21,
                        height: 21,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: theme.colorScheme.onPrimary,
                        ),
                      )
                    : const Icon(Icons.ios_share_rounded),
                label: Text(
                  _isExporting
                      ? 'Gerando arquivo...'
                      : 'Gerar e compartilhar '
                            '${_selectedFormat.label}',
                ),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(54),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'A tela de compartilhamento do Android será aberta '
              'depois que o arquivo estiver pronto.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(color: textMuted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormatOption({
    required BuildContext context,
    required ExportFileFormat format,
    required String title,
    required String description,
    required IconData icon,
  }) {
    final ThemeData theme = Theme.of(context);
    final Color primaryColor = theme.colorScheme.primary;
    final Color textPrimary = AppColors.textPrimary(context);
    final Color textSecondary = AppColors.textSecondary(context);

    final bool isSelected = _selectedFormat == format;

    return Semantics(
      button: true,
      selected: isSelected,
      label: '$title. $description',
      child: InkWell(
        onTap: _isExporting
            ? null
            : () {
                HapticFeedback.selectionClick();

                setState(() {
                  _selectedFormat = format;
                });
              },
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(
            color: isSelected
                ? primaryColor.withValues(alpha: 0.11)
                : AppColors.surface(context),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isSelected ? primaryColor : AppColors.border(context),
              width: isSelected ? 1.8 : 1,
            ),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isSelected
                      ? primaryColor.withValues(alpha: 0.15)
                      : AppColors.surfaceSecondary(context),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  color: isSelected ? primaryColor : textSecondary,
                  size: 27,
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: isSelected ? primaryColor : textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: textSecondary,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: isSelected
                    ? Icon(
                        Icons.check_circle_rounded,
                        key: ValueKey<ExportFileFormat>(format),
                        color: primaryColor,
                      )
                    : Icon(
                        Icons.circle_outlined,
                        key: ValueKey<String>('unselected-${format.name}'),
                        color: AppColors.border(context),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
