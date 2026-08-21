import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:finanse/core/theme/app_colors.dart';
import 'package:finanse/core/theme/app_spacing.dart';
import 'package:finanse/features/onboarding/presentation/onboarding_page.dart';

class HowToUsePage extends StatelessWidget {
  const HowToUsePage({super.key});

  static const List<_GuideItem> _guideItems = <_GuideItem>[
    _GuideItem(
      icon: Icons.person_outline_rounded,
      title: 'Personalize seu perfil',
      summary: 'Cadastre seu nome e escolha uma foto.',
      steps: <String>[
        'Abra Perfil e toque em Dados pessoais.',
        'Digite o nome que deseja ver na saudação da tela inicial.',
        'Toque na foto para escolher uma imagem da galeria ou usar a câmera.',
      ],
    ),
    _GuideItem(
      icon: Icons.payments_outlined,
      title: 'Cadastre suas rendas',
      summary: 'Informe salário, extras e outras fontes manualmente.',
      steps: <String>[
        'Abra Perfil e toque em Rendas, ou use o atalho da tela inicial.',
        'Escolha o mês, informe o valor, a fonte e a data.',
        'Ative Repetir mensalmente para uma renda que se repete.',
        'A renda é opcional e não possui conexão com bancos.',
      ],
    ),
    _GuideItem(
      icon: Icons.track_changes_rounded,
      title: 'Defina o limite mensal',
      summary: 'Escolha quanto pretende gastar durante o mês.',
      steps: <String>[
        'Abra Perfil e toque em Limite mensal ou escolha o mês na área Rendas.',
        'Informe o valor planejado e toque em Salvar.',
        'O limite é independente da renda e cada mês preserva seu próprio valor.',
        'A tela inicial mostrará renda, gastos, sobra planejada e resultado atual.',
      ],
    ),
    _GuideItem(
      icon: Icons.add_circle_outline_rounded,
      title: 'Registre um gasto',
      summary: 'Use o botão + disponível na barra inferior.',
      steps: <String>[
        'Toque no botão + no centro da barra inferior.',
        'Toque no campo de valor e use o teclado numérico do celular.',
        'Escolha a categoria e adicione detalhes, se desejar.',
        'Salve para atualizar automaticamente o resumo e os relatórios.',
      ],
    ),
    _GuideItem(
      icon: Icons.savings_outlined,
      title: 'Acompanhe sua reserva',
      summary: 'Registre manualmente o valor aproximado que guardou.',
      steps: <String>[
        'Na tela inicial, toque no cartão Minha reserva.',
        'Use Adicionar valor para somar uma nova economia.',
        'Use Retirar valor quando utilizar parte da reserva.',
        'Use Ajustar total para corrigir o saldo quando necessário.',
        'Abra Ver histórico para consultar todas as movimentações.',
        'Toque no olho para mostrar ou ocultar o total.',
      ],
    ),
    _GuideItem(
      icon: Icons.flag_outlined,
      title: 'Crie metas financeiras',
      summary: 'Direcione a sobra do mês para objetivos escolhidos por você.',
      steps: <String>[
        'Abra Perfil e toque em Metas financeiras.',
        'Informe o nome, o valor desejado e, se quiser, um prazo.',
        'Use Destinar na meta ou o atalho da tela inicial para registrar um aporte.',
        'O aporte reduz apenas a sobra ainda disponível e não entra como gasto.',
        'Você pode editar, pausar, reativar ou concluir a meta sem perder o histórico.',
      ],
    ),
    _GuideItem(
      icon: Icons.category_outlined,
      title: 'Defina limites por categoria',
      summary: 'Acompanhe áreas específicas dentro do seu limite geral.',
      steps: <String>[
        'Abra Perfil e toque em Limites por categoria.',
        'Escolha o mês, a categoria, o valor e a faixa em que deseja ser avisado.',
        'A soma das categorias não pode ultrapassar o limite geral do mês.',
        'Compare cada categoria com o mês anterior para entender sua evolução.',
      ],
    ),
    _GuideItem(
      icon: Icons.history_rounded,
      title: 'Consulte e corrija registros',
      summary: 'Encontre gastos antigos no Histórico.',
      steps: <String>[
        'Abra Histórico para visualizar todos os lançamentos.',
        'Use os filtros para encontrar um período ou categoria.',
        'Toque em um gasto para editar ou excluir o registro.',
      ],
    ),
    _GuideItem(
      icon: Icons.autorenew_rounded,
      title: 'Cadastre despesas recorrentes',
      summary: 'Organize assinaturas e contas fixas.',
      steps: <String>[
        'Abra Perfil e toque em Despesas recorrentes.',
        'Cadastre o valor, a categoria e o dia previsto da cobrança.',
        'Ative as notificações para receber lembretes quando disponíveis.',
      ],
    ),
    _GuideItem(
      icon: Icons.bar_chart_rounded,
      title: 'Entenda seus relatórios',
      summary: 'Veja seus gastos e acompanhe a evolução mensal.',
      steps: <String>[
        'Abra Relatórios na barra inferior.',
        'Compare totais e categorias no período selecionado.',
        'Toque em Evolução mensal para alternar entre os últimos 6 e 12 meses.',
        'Compare renda, gastos, resultado e taxa de economia nos gráficos.',
        'Toque em um mês para corrigir rendas, limite ou gastos antigos.',
        'Meses encerrados são recalculados quando um registro é corrigido.',
      ],
    ),
    _GuideItem(
      icon: Icons.cloud_done_outlined,
      title: 'Proteja e exporte seus dados',
      summary: 'Crie arquivos de relatório e cópias de segurança.',
      steps: <String>[
        'Em Perfil, use Exportar relatório para gerar PDF, Excel ou CSV.',
        'Use Backup e restauração para guardar uma cópia manual dos dados.',
        'Os arquivos gerados não são criptografados. Compartilhe e mantenha '
            'essas cópias somente em locais confiáveis.',
      ],
    ),
    _GuideItem(
      icon: Icons.password_rounded,
      title: 'Proteja o acesso com PIN',
      summary: 'Crie uma senha numérica para abrir o Finanse.',
      steps: <String>[
        'Abra Perfil e toque em PIN de acesso.',
        'Crie um PIN de 4 a 6 números e confirme.',
        'O PIN será solicitado ao abrir o Finanse e depois de 30 segundos '
            'fora do aplicativo.',
        'Guarde o PIN em segurança para não perder o acesso ao aplicativo.',
      ],
    ),
  ];

  Future<void> _reviewOnboarding(BuildContext context) async {
    HapticFeedback.selectionClick();

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext onboardingContext) {
          return OnboardingPage(
            reviewMode: true,
            onFinished: () async {
              Navigator.of(onboardingContext).pop();
            },
          );
        },
      ),
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

    return Scaffold(
      appBar: AppBar(title: const Text('Como usar o Finanse')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.pageHorizontal,
          AppSpacing.md,
          AppSpacing.pageHorizontal,
          MediaQuery.paddingOf(context).bottom + AppSpacing.xxl,
        ),
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
              border: Border.all(color: primaryColor.withValues(alpha: 0.20)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(
                          AppSpacing.inputRadius,
                        ),
                      ),
                      child: Icon(
                        Icons.auto_awesome_rounded,
                        color: primaryColor,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'Comece pelo essencial',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Defina seu limite, registre os gastos pelo botão + e, se quiser, cadastre suas rendas. A tela inicial relaciona esses valores sem acessar sua conta bancária.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      _reviewOnboarding(context);
                    },
                    icon: const Icon(Icons.slideshow_rounded),
                    label: const Text('Rever apresentação inicial'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            'Guia rápido',
            style: theme.textTheme.titleLarge?.copyWith(
              color: textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Toque em um assunto para ver o passo a passo.',
            style: theme.textTheme.bodyMedium?.copyWith(color: textSecondary),
          ),
          const SizedBox(height: AppSpacing.md),
          ..._guideItems.map((_GuideItem item) {
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Card(
                margin: EdgeInsets.zero,
                color: surfaceColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                  side: BorderSide(color: borderColor),
                ),
                clipBehavior: Clip.antiAlias,
                child: ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.xs,
                  ),
                  childrenPadding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    0,
                    AppSpacing.md,
                    AppSpacing.md,
                  ),
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(
                        AppSpacing.inputRadius,
                      ),
                    ),
                    child: Icon(item.icon, color: primaryColor, size: 22),
                  ),
                  title: Text(
                    item.title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xxs),
                    child: Text(
                      item.summary,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: textSecondary,
                      ),
                    ),
                  ),
                  children: <Widget>[
                    const Divider(),
                    const SizedBox(height: AppSpacing.xs),
                    ...List<Widget>.generate(item.steps.length, (int index) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Container(
                              width: 24,
                              height: 24,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: primaryColor.withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '${index + 1}',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: primaryColor,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                item.steps[index],
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: textSecondary,
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.informationSoft,
              borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Icon(
                  Icons.info_outline_rounded,
                  color: AppColors.information,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'O Finanse funciona sem conexão bancária. Os registros são inseridos por você e permanecem armazenados localmente no aparelho.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: textPrimary,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GuideItem {
  const _GuideItem({
    required this.icon,
    required this.title,
    required this.summary,
    required this.steps,
  });

  final IconData icon;
  final String title;
  final String summary;
  final List<String> steps;
}
