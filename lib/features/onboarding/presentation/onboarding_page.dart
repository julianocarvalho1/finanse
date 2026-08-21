import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:finanse/core/theme/app_colors.dart';
import 'package:finanse/core/theme/app_spacing.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({
    super.key,
    required this.onFinished,
    this.reviewMode = false,
  });

  final Future<void> Function() onFinished;
  final bool reviewMode;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  static const List<_OnboardingItem> _items = <_OnboardingItem>[
    _OnboardingItem(
      icon: Icons.receipt_long_rounded,
      title: 'Controle seus gastos',
      description:
          'Registre suas despesas em poucos segundos e acompanhe o que saiu do seu bolso hoje, na semana ou no mês.',
      tip: 'Use o botão + para adicionar um gasto a qualquer momento.',
    ),
    _OnboardingItem(
      icon: Icons.track_changes_rounded,
      title: 'Planeje seu mês',
      description:
          'Informe suas rendas, se quiser, e escolha um limite de gastos independente. O Finanse calcula a sobra planejada e o resultado atual.',
      tip:
          'As informações são manuais e você pode usar o app sem cadastrar renda.',
    ),
    _OnboardingItem(
      icon: Icons.savings_rounded,
      title: 'Acompanhe sua reserva',
      description:
          'Informe manualmente quanto conseguiu guardar. O valor fica separado dos gastos e pode permanecer oculto na tela inicial.',
      tip: 'Nada é conectado ao banco: os dados ficam no seu aparelho.',
    ),
  ];

  late final PageController _pageController;

  int _currentPage = 0;
  bool _isFinishing = false;

  bool get _isLastPage => _currentPage == _items.length - 1;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    if (_isFinishing) {
      return;
    }

    HapticFeedback.mediumImpact();

    setState(() {
      _isFinishing = true;
    });

    try {
      await widget.onFinished();
    } finally {
      if (mounted) {
        setState(() {
          _isFinishing = false;
        });
      }
    }
  }

  Future<void> _nextPage() async {
    if (_isLastPage) {
      await _finish();
      return;
    }

    HapticFeedback.selectionClick();

    await _pageController.nextPage(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color primaryColor = theme.colorScheme.primary;
    final Color textPrimary = AppColors.textPrimary(context);
    final Color textSecondary = AppColors.textSecondary(context);
    final Color surfaceColor = AppColors.surface(context);
    final Color borderColor = AppColors.border(context);

    return PopScope(
      canPop: widget.reviewMode,
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.pageHorizontal,
                  AppSpacing.sm,
                  AppSpacing.pageHorizontal,
                  0,
                ),
                child: Row(
                  children: <Widget>[
                    Text(
                      'Finan\$e',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: primaryColor,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: _isFinishing
                          ? null
                          : () async {
                              if (widget.reviewMode) {
                                Navigator.of(context).pop();
                                return;
                              }

                              await _finish();
                            },
                      child: Text(widget.reviewMode ? 'Fechar' : 'Pular'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _items.length,
                  onPageChanged: (int page) {
                    setState(() {
                      _currentPage = page;
                    });
                  },
                  itemBuilder: (BuildContext context, int index) {
                    final _OnboardingItem item = _items[index];

                    return SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.pageHorizontal,
                        AppSpacing.lg,
                        AppSpacing.pageHorizontal,
                        AppSpacing.lg,
                      ),
                      child: Column(
                        children: <Widget>[
                          const SizedBox(height: AppSpacing.md),
                          _OnboardingIllustration(
                            icon: item.icon,
                            primaryColor: primaryColor,
                            surfaceColor: surfaceColor,
                            borderColor: borderColor,
                          ),
                          const SizedBox(height: AppSpacing.xxl),
                          Text(
                            item.title,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              color: textPrimary,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.4,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            item.description,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: textSecondary,
                              height: 1.45,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xl),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(AppSpacing.md),
                            decoration: BoxDecoration(
                              color: primaryColor.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(
                                AppSpacing.inputRadius,
                              ),
                              border: Border.all(
                                color: primaryColor.withValues(alpha: 0.20),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Icon(
                                  Icons.lightbulb_outline_rounded,
                                  size: 21,
                                  color: primaryColor,
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: Text(
                                    item.tip,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: textPrimary,
                                      height: 1.35,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.pageHorizontal,
                  AppSpacing.sm,
                  AppSpacing.pageHorizontal,
                  MediaQuery.paddingOf(context).bottom + AppSpacing.lg,
                ),
                child: Column(
                  children: <Widget>[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List<Widget>.generate(_items.length, (
                        int index,
                      ) {
                        final bool selected = index == _currentPage;

                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOut,
                          width: selected ? 24 : 8,
                          height: 8,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            color: selected ? primaryColor : borderColor,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _isFinishing ? null : _nextPage,
                        child: _isFinishing
                            ? const SizedBox.square(
                                dimension: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.4,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                _isLastPage
                                    ? widget.reviewMode
                                          ? 'Concluir'
                                          : 'Começar a usar'
                                    : 'Próximo',
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardingIllustration extends StatelessWidget {
  const _OnboardingIllustration({
    required this.icon,
    required this.primaryColor,
    required this.surfaceColor,
    required this.borderColor,
  });

  final IconData icon;
  final Color primaryColor;
  final Color surfaceColor;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 224,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          Positioned(
            top: 12,
            right: 8,
            child: Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: 4,
            left: 10,
            child: Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.06),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Container(
            width: 172,
            height: 172,
            decoration: BoxDecoration(
              color: surfaceColor,
              shape: BoxShape.circle,
              border: Border.all(color: borderColor),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 28,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: Center(
              child: Container(
                width: 104,
                height: 104,
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(32),
                ),
                child: Icon(icon, size: 52, color: primaryColor),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingItem {
  const _OnboardingItem({
    required this.icon,
    required this.title,
    required this.description,
    required this.tip,
  });

  final IconData icon;
  final String title;
  final String description;
  final String tip;
}
