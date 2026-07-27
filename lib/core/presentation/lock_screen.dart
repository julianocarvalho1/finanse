import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/theme/app_colors.dart'; // Ajuste o caminho das cores se necessário

class LockScreen extends StatefulWidget {
  final Widget child; // O aplicativo real que será liberado
  const LockScreen({super.key, required this.child});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  bool _isLocked = true;
  bool _isChecking = true;
  bool _useBiometrics = false;

  @override
  void initState() {
    super.initState();
    _checkSecuritySettings();
  }

  Future<void> _checkSecuritySettings() async {
    final prefs = await SharedPreferences.getInstance();
    final useBiometrics = prefs.getBool('useBiometrics') ?? false;

    if (!useBiometrics) {
      // Se não ativou nas configurações, libera o app direto!
      setState(() {
        _isLocked = false;
        _isChecking = false;
      });
    } else {
      setState(() {
        _useBiometrics = true;
        _isChecking = false;
      });
      // Tenta simular a leitura imediatamente
      _simulateBiometricScan();
    }
  }

  Future<void> _simulateBiometricScan() async {
    // Vibra o celular e faz uma pequena pausa fingindo ler o rosto/dedo
    HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 800));

    // Libera o acesso
    setState(() {
      _isLocked = false;
    });
    HapticFeedback.lightImpact();
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      return const Scaffold(
        backgroundColor: AppColors.darkBackground,
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    // Se estiver bloqueado, mostra a tela de segurança
    if (_isLocked && _useBiometrics) {
      return Scaffold(
        backgroundColor: AppColors.darkBackground,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_outline_rounded, size: 80, color: AppColors.primary),
              const SizedBox(height: 24),
              const Text(
                'Aplicativo Bloqueado',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 8),
              const Text(
                'Autentique-se para acessar suas finanças.',
                style: TextStyle(color: AppColors.darkTextSecondary),
              ),
              const SizedBox(height: 48),
              GestureDetector(
                onTap: _simulateBiometricScan, // Tenta ler de novo se clicar
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.darkSurfaceSecondary,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primary.withOpacity(0.3), width: 2),
                  ),
                  child: const Icon(Icons.fingerprint_rounded, size: 64, color: AppColors.primary),
                ),
              ),
              const SizedBox(height: 24),
              const Text('Toque para desbloquear', style: TextStyle(color: AppColors.darkTextMuted)),
            ],
          ),
        ),
      );
    }

    // Se passou pela segurança, mostra o app de verdade!
    return widget.child;
  }
}