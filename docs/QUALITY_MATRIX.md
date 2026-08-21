# Matriz de qualidade do Finanse

Esta matriz é a referência contínua da Fase 4. Os itens automatizados são
executados no GitHub Actions; os itens de aparelho e Play Console precisam ser
repetidos antes de cada publicação.

## Cobertura automatizada

| Área | Verificação | Situação |
| --- | --- | --- |
| Onboarding | avançar, concluir, pular, semântica das etapas e fonte em 200% | Automatizada |
| Renda | cadastro manual, valor, fonte e tela pequena | Automatizada |
| Gasto | cadastro manual, categoria padrão, UUID e tela pequena | Automatizada |
| Navegação | troca de telas, ação central e fonte em 200% | Automatizada |
| PIN | criação, desbloqueio, tentativas, tolerância e fonte em 200% | Automatizada |
| Backup | criação completa, restauração e rejeição por checksum | Automatizada |
| Planejamento | renda, limite, gastos, reserva, metas e categorias | Automatizada |
| Migração | atualização com dados das versões 1, 2, 3, 4, 5 e 6 | Automatizada |
| Acessibilidade | contraste 4,5:1, área de toque e cores personalizáveis | Automatizada |
| Android | API mínima 24, permissões, backup e assinatura release | Automatizada |
| Build | análise, testes com cobertura e APK debug | CI |

O relatório `coverage/lcov.info` fica disponível como artefato do CI durante 14
dias. O piso inicial do CI é 25% de cobertura de linhas e deve subir conforme
novos estados de tela forem cobertos. A cobertura indica lacunas, mas não
substitui a validação dos fluxos.

Baseline local de 21 de agosto de 2026: 119 testes aprovados e 27% das linhas
executáveis cobertas (2.630 de 9.729). A inclusão do shell principal tornou a
medição mais abrangente ao incorporar as telas ainda não exercitadas.

## Dependências monitoradas

- O APK debug é gerado normalmente, mas o Flutter avisa que `flutter_timezone`
  e `share_plus` ainda aplicam o plugin Kotlin legado. Antes de atualizar o
  Flutter, conferir versões compatíveis desses pacotes e repetir toda a matriz.
- Atualizações de versão principal não entram automaticamente. Cada uma exige
  leitura do changelog, teste de migração e validação no Android.

## Matriz manual antes de publicar

| Ambiente | Tela/fonte | Fluxos mínimos | Situação atual |
| --- | --- | --- | --- |
| Android 7 / API 24 | telefone pequeno, 100% e 200% | instalar/atualizar, onboarding, renda, gasto, PIN, backup | Pendente |
| Android atual | telefone de 360–412 px, 100% e 200% | fluxo financeiro completo e notificações | Parcial: instalação, abertura e fonte |
| Android atual | tablet ou largura a partir de 600 px | navegação, modais, gráficos e relatórios | Pendente |
| Tema claro | todas as cores disponíveis | contraste, foco, estados vazio/erro | Parcialmente automatizada |
| Tema escuro | todas as cores disponíveis | contraste, foco, estados vazio/erro | Parcialmente automatizada |
| Leitor de tela | fonte padrão e ampliada | ordem de leitura, rótulos e botões | Pendente |

## Regra de encerramento

Uma versão só pode seguir ao teste interno quando não houver falhas no CI e toda
a matriz manual aplicável estiver registrada como aprovada no checklist da
entrega. O teste em Android 7 não pode ser substituído apenas pela declaração
`minSdk = 24`.
