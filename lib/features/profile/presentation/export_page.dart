import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_colors.dart';

class ExportPage extends StatefulWidget {
  const ExportPage({super.key});

  @override
  State<ExportPage> createState() => _ExportPageState();
}

class _ExportPageState extends State<ExportPage> {
  bool _isExporting = false;
  String _selectedFormat = 'CSV';

  Future<void> _exportData() async {
    setState(() => _isExporting = true);
    await Future.delayed(const Duration(seconds: 2));
    setState(() => _isExporting = false);
    HapticFeedback.heavyImpact();

    if (mounted) {
      final primaryColor = Theme.of(context).colorScheme.primary;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white),
              const SizedBox(width: 12),
              Text('Relatório $_selectedFormat exportado com sucesso!'),
            ],
          ),
          backgroundColor: primaryColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // --- LÓGICA DE CORES DINÂMICAS ---
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkBackground : const Color(0xFFF8F9FA);
    final textPrimary = isDark ? AppColors.darkTextPrimary : const Color(0xFF1A1D1F);
    final textSecondary = isDark ? AppColors.darkTextSecondary : const Color(0xFF535F66);
    final textMuted = isDark ? AppColors.darkTextMuted : const Color(0xFF8A959D);
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textPrimary),
        title: Text('Exportar Relatório', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20, color: textPrimary)),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Baixe um arquivo contendo todos os seus registros financeiros para abrir no Excel, enviar para o seu contador ou imprimir.',
            style: TextStyle(color: textSecondary, fontSize: 15, height: 1.5),
          ),
          const SizedBox(height: 32),

          Text('FORMATO DO ARQUIVO', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: textMuted, letterSpacing: 1.2)),
          const SizedBox(height: 16),

          _buildFormatOption('CSV', 'Ideal para planilhas (Excel, Sheets)', Icons.table_chart_rounded, isDark, textPrimary, textSecondary, primaryColor),
          const SizedBox(height: 12),
          _buildFormatOption('PDF', 'Ideal para leitura e impressão', Icons.picture_as_pdf_rounded, isDark, textPrimary, textSecondary, primaryColor),

          const SizedBox(height: 48),

          ElevatedButton(
            onPressed: _isExporting ? null : _exportData,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: _isExporting
                ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
            // A CORREÇÃO FOI FEITA AQUI NESTA LINHA: adicionamos o style:
                : Text('Gerar Arquivo $_selectedFormat', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _buildFormatOption(String format, String desc, IconData icon, bool isDark, Color textPrimary, Color textSecondary, Color primaryColor) {
    final isSelected = _selectedFormat == format;
    final surfaceColor = isDark ? AppColors.darkSurfaceSecondary : Colors.white;
    final borderColor = isDark ? AppColors.darkBorder : const Color(0xFFE2E6E9);

    return InkWell(
      onTap: () => setState(() => _selectedFormat = format),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: isSelected ? primaryColor.withOpacity(0.15) : surfaceColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isSelected ? primaryColor : borderColor, width: 2),
            boxShadow: isDark ? [] : [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2))]
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? primaryColor : textSecondary, size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(format, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: isSelected ? primaryColor : textPrimary)),
                  const SizedBox(height: 4),
                  Text(desc, style: TextStyle(fontSize: 13, color: textSecondary)),
                ],
              ),
            ),
            if (isSelected) Icon(Icons.check_circle_rounded, color: primaryColor),
          ],
        ),
      ),
    );
  }
}