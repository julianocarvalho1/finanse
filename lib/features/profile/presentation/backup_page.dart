import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';

class BackupPage extends StatefulWidget {
  const BackupPage({super.key});

  @override
  State<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends State<BackupPage> {
  bool _isBackingUp = false;
  String _lastBackupDate = 'Ainda não realizado';

  Future<void> _createBackup() async {
    setState(() => _isBackingUp = true);
    await Future.delayed(const Duration(seconds: 3));

    final now = DateFormat("dd/MM/yyyy 'às' HH:mm").format(DateTime.now());

    setState(() {
      _isBackingUp = false;
      _lastBackupDate = now;
    });
    HapticFeedback.heavyImpact();

    if (mounted) {
      final primaryColor = Theme.of(context).colorScheme.primary;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.cloud_done_rounded, color: Colors.white),
              SizedBox(width: 12),
              Text('Backup salvo em segurança na nuvem!'),
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
    final surfaceColor = isDark ? AppColors.darkSurfaceSecondary : Colors.white;
    final textPrimary = isDark
        ? AppColors.darkTextPrimary
        : const Color(0xFF1A1D1F);
    final textSecondary = isDark
        ? AppColors.darkTextSecondary
        : const Color(0xFF535F66);
    final textMuted = isDark
        ? AppColors.darkTextMuted
        : const Color(0xFF8A959D);
    final borderColor = isDark ? AppColors.darkBorder : const Color(0xFFE2E6E9);

    // AQUI O SEGREDO: Puxando a cor principal atual!
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textPrimary),
        title: Text(
          'Backup e Restauração',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 20,
            color: textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Proteja seus dados salvando uma cópia de segurança. O backup guarda suas despesas, configurações, biometria e limites.',
            style: TextStyle(color: textSecondary, fontSize: 15, height: 1.5),
          ),
          const SizedBox(height: 32),

          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark ? primaryColor.withOpacity(0.3) : borderColor,
              ),
              boxShadow: isDark
                  ? []
                  : [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
            ),
            child: Column(
              children: [
                Icon(Icons.cloud_sync_rounded, color: primaryColor, size: 56),
                const SizedBox(height: 16),
                Text(
                  'Último backup realizado:',
                  style: TextStyle(color: textMuted, fontSize: 14),
                ),
                const SizedBox(height: 8),
                Text(
                  _lastBackupDate,
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 32),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isBackingUp ? null : _createBackup,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isBackingUp
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Fazer backup agora',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          OutlinedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Buscando backups antigos...')),
              );
            },
            icon: Icon(Icons.restore_rounded, color: textSecondary),
            label: Text(
              'Restaurar backup antigo',
              style: TextStyle(color: textSecondary),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              side: BorderSide(color: borderColor, width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
