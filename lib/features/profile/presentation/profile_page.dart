import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/expense_notifier.dart';
import '../../../../core/utils/theme_notifier.dart';

import 'backup_page.dart';
import 'export_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  double _monthlyLimit = 2000.0;
  bool _useBiometrics = false;
  bool _notificationsEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _monthlyLimit = prefs.getDouble('monthlyLimit') ?? 2000.0;
      _useBiometrics = prefs.getBool('useBiometrics') ?? false;
      _notificationsEnabled = prefs.getBool('notificationsEnabled') ?? true;
    });
  }

  void _openRecurringExpenses() {
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tela de Lançamentos Recorrentes em breve!'))
    );
  }

  void _openExport() {
    Navigator.push(context, MaterialPageRoute(builder: (context) => const ExportPage()));
  }

  void _openBackup() {
    Navigator.push(context, MaterialPageRoute(builder: (context) => const BackupPage()));
  }

  void _editMonthlyLimit() {
    final TextEditingController limitController = TextEditingController(text: _monthlyLimit.toStringAsFixed(0));

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkSurface : Colors.white;
    final textPrimary = isDark ? AppColors.darkTextPrimary : const Color(0xFF1A1D1F);
    final textSecondary = isDark ? AppColors.darkTextSecondary : const Color(0xFF535F66);
    final primaryColor = Theme.of(context).colorScheme.primary;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: bgColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Limite Mensal', style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Defina o valor máximo que você planeja gastar por mês.', style: TextStyle(color: textSecondary, fontSize: 14)),
            const SizedBox(height: 16),
            TextField(
              controller: limitController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textPrimary),
              decoration: InputDecoration(
                prefixText: 'R\$ ',
                prefixStyle: TextStyle(fontSize: 24, color: isDark ? AppColors.darkTextMuted : const Color(0xFF8A959D)),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: primaryColor)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: primaryColor, width: 2)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar', style: TextStyle(color: textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              final newValue = double.tryParse(limitController.text);
              if (newValue != null && newValue > 0) {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setDouble('monthlyLimit', newValue);
                setState(() => _monthlyLimit = newValue);
                expenseNotifier.value++;
                if (mounted) Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('Salvar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildColorOption(Color color) {
    return ValueListenableBuilder<ThemeState>(
        valueListenable: themeNotifier,
        builder: (context, themeState, child) {
          final isSelected = themeState.color.value == color.value;
          final isDark = Theme.of(context).brightness == Brightness.dark;

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
                    color: isSelected ? (isDark ? Colors.white : const Color(0xFF1A1D1F)) : Colors.transparent,
                    width: 3,
                  ),
                  boxShadow: [
                    if (isSelected) BoxShadow(color: color.withOpacity(0.4), blurRadius: 10, spreadRadius: 2)
                  ]
              ),
              child: isSelected ? const Icon(Icons.check_rounded, color: Colors.white) : null,
            ),
          );
        }
    );
  }

  Widget _buildThemeModeButton(ThemeMode mode, String label, ThemeMode currentMode, Color primaryColor, bool isDark) {
    final isSelected = mode == currentMode;

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
            boxShadow: isSelected && !isDark ? [BoxShadow(color: primaryColor.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))] : [],
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? Colors.white : (isDark ? AppColors.darkTextSecondary : const Color(0xFF535F66)),
            ),
          ),
        ),
      ),
    );
  }

  // --- O SEGREDO DO DESIGN PREMIUM NO CLARO ---
  Widget _buildSettingsGroup(List<Widget> children, bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurfaceSecondary : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: isDark ? Colors.transparent : const Color(0xFFE2E6E9)),
          boxShadow: isDark ? [] : [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))]
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textMuted = isDark ? AppColors.darkTextMuted : const Color(0xFF8A959D);

    return Padding(
      padding: const EdgeInsets.only(left: 32, bottom: 8, top: 32),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: textMuted, letterSpacing: 1.2),
      ),
    );
  }

  Widget _buildListTile({required IconData icon, required String title, String? subtitle, required VoidCallback onTap, Color? iconColor}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppColors.darkTextPrimary : const Color(0xFF1A1D1F);
    final textSecondary = isDark ? AppColors.darkTextSecondary : const Color(0xFF535F66);
    final textMuted = isDark ? AppColors.darkTextMuted : const Color(0xFF8A959D);
    final iconBgColor = isDark ? AppColors.darkSurface : const Color(0xFFF0F3F5);
    final finalIconColor = iconColor ?? (isDark ? AppColors.darkTextSecondary : const Color(0xFF535F66));

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: iconBgColor, borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: finalIconColor, size: 22),
      ),
      title: Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textPrimary)),
      subtitle: subtitle != null ? Text(subtitle, style: TextStyle(fontSize: 13, color: textSecondary)) : null,
      trailing: Icon(Icons.arrow_forward_ios_rounded, color: textMuted, size: 16),
      onTap: onTap,
    );
  }

  Widget _buildSwitchTile({required IconData icon, required String title, required String subtitle, required bool value, required ValueChanged<bool> onChanged}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppColors.darkTextPrimary : const Color(0xFF1A1D1F);
    final textSecondary = isDark ? AppColors.darkTextSecondary : const Color(0xFF535F66);
    final iconBgColor = isDark ? AppColors.darkSurface : const Color(0xFFF0F3F5);
    final primaryColor = Theme.of(context).colorScheme.primary;

    return SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      secondary: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: iconBgColor, borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: isDark ? AppColors.darkTextSecondary : const Color(0xFF535F66), size: 22),
      ),
      title: Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textPrimary)),
      subtitle: Text(subtitle, style: TextStyle(fontSize: 13, color: textSecondary)),
      value: value,
      activeColor: primaryColor,
      inactiveTrackColor: isDark ? AppColors.darkSurface : const Color(0xFFE2E6E9),
      onChanged: (val) async {
        onChanged(val);
        HapticFeedback.lightImpact();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppColors.darkTextPrimary : const Color(0xFF1A1D1F);
    final textSecondary = isDark ? AppColors.darkTextSecondary : const Color(0xFF535F66);
    final textMuted = isDark ? AppColors.darkTextMuted : const Color(0xFF8A959D);
    final primaryColor = Theme.of(context).colorScheme.primary;
    final dividerColor = isDark ? AppColors.darkBorder : const Color(0xFFE2E6E9);

    // MÁGICA: Protegendo contra a barra de status sem o corte seco!
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFF8F9FA),
      body: ListView(
        padding: EdgeInsets.only(top: topPadding + 24, bottom: 120),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: primaryColor.withOpacity(0.15),
                  child: Text('L', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: primaryColor)),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Lucas', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textPrimary)),
                    const SizedBox(height: 4),
                    Text('Membro desde 2026', style: TextStyle(fontSize: 14, color: textSecondary)),
                  ],
                ),
              ],
            ),
          ),

          _buildSectionHeader('Personalização'),
          _buildSettingsGroup([
            ValueListenableBuilder<ThemeState>(
              valueListenable: themeNotifier,
              builder: (context, themeState, child) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Aparência', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textPrimary)),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkSurface : const Color(0xFFE2E6E9),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            _buildThemeModeButton(ThemeMode.light, 'Claro', themeState.mode, primaryColor, isDark),
                            _buildThemeModeButton(ThemeMode.dark, 'Escuro', themeState.mode, primaryColor, isDark),
                            _buildThemeModeButton(ThemeMode.system, 'Auto', themeState.mode, primaryColor, isDark),
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
                children: [
                  Text('Cor de Destaque', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textPrimary)),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
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
          _buildSettingsGroup([
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
          _buildSettingsGroup([
            _buildSwitchTile(
              icon: Icons.notifications_active_rounded,
              title: 'Notificações',
              subtitle: 'Lembretes de registro e alertas de limite',
              value: _notificationsEnabled,
              onChanged: (val) async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('notificationsEnabled', val);
                setState(() => _notificationsEnabled = val);
              },
            ),
          ], isDark),

          _buildSectionHeader('Segurança e Biometria'),
          _buildSettingsGroup([
            _buildSwitchTile(
              icon: Icons.fingerprint_rounded,
              title: 'Bloqueio por Biometria',
              subtitle: 'Exigir digital/Face ID ao abrir o app',
              value: _useBiometrics,
              onChanged: (val) async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('useBiometrics', val);
                setState(() => _useBiometrics = val);
              },
            ),
          ], isDark),

          _buildSectionHeader('Dados e Backup'),
          _buildSettingsGroup([
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
          Center(child: Text('Finanse App v1.0.0', style: TextStyle(color: textMuted, fontSize: 12))),
        ],
      ),
    );
  }
}