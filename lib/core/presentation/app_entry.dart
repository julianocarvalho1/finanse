import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finanse/features/onboarding/presentation/onboarding_page.dart';
import 'package:finanse/features/shell/presentation/main_shell.dart';

class AppEntry extends StatefulWidget {
  const AppEntry({super.key});

  @override
  State<AppEntry> createState() => _AppEntryState();
}

class _AppEntryState extends State<AppEntry> {
  static const String _onboardingPreferenceKey = 'hasCompletedOnboarding';

  bool? _hasCompletedOnboarding;

  @override
  void initState() {
    super.initState();
    _loadOnboardingState();
  }

  Future<void> _loadOnboardingState() async {
    final SharedPreferences preferences =
        await SharedPreferences.getInstance();

    if (!mounted) {
      return;
    }

    setState(() {
      _hasCompletedOnboarding =
          preferences.getBool(_onboardingPreferenceKey) ?? false;
    });
  }

  Future<void> _finishOnboarding() async {
    final SharedPreferences preferences =
        await SharedPreferences.getInstance();

    await preferences.setBool(_onboardingPreferenceKey, true);

    if (!mounted) {
      return;
    }

    setState(() {
      _hasCompletedOnboarding = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool? hasCompletedOnboarding = _hasCompletedOnboarding;

    if (hasCompletedOnboarding == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!hasCompletedOnboarding) {
      return OnboardingPage(onFinished: _finishOnboarding);
    }

    return const MainShell();
  }
}
