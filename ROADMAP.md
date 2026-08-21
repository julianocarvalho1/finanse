# Roadmap do Finanse

Este documento acompanha a evolução do Finanse de um controlador de gastos para
um planejador financeiro pessoal, com dados informados manualmente e sem acesso
a contas bancárias.

## Legenda

- [ ] Não iniciado
- [~] Em andamento
- [x] Concluído
- **P0**: necessário antes da produção
- **P1**: próxima entrega principal
- **P2**: evolução posterior

## Visão do produto

O Finanse deve ajudar a pessoa a responder cinco perguntas:

1. Quanto entrou neste mês?
2. Quanto decidi que posso gastar?
3. Quanto já gastei?
4. Quanto ainda posso gastar dentro do meu limite?
5. Quanto estou conseguindo preservar e acumular ao longo do tempo?

O aplicativo não representa o saldo real de uma conta bancária. Os números são
calculados a partir dos dados cadastrados manualmente e devem ser apresentados
como planejamento, estimativa ou resultado registrado no Finanse.

## Regras financeiras iniciais

- A renda é cadastrada manualmente e pode ter uma ou várias fontes.
- O limite de gastos é independente da renda.
- A renda é opcional; quem não quiser cadastrá-la continua usando o controle de
  gastos atual normalmente.
- Cada mês guarda seu próprio limite para preservar o histórico.
- Transferir uma sobra para `Minha reserva` não é uma despesa. É apenas uma
  destinação do resultado do mês.
- Uma despesa recorrente só entra no cálculo quando for efetivamente registrada
  como despesa no mês.
- Alterações retroativas recalculam o resultado do mês correspondente.
- Valores monetários novos devem ser persistidos em centavos inteiros para
  evitar erros de arredondamento.

### Cálculos principais

```text
renda total          = soma das rendas do mês
gastos realizados    = soma das despesas do mês
disponível no limite = máximo(limite - gastos, 0)
excesso do limite    = máximo(gastos - limite, 0)
sobra planejada      = renda total - limite
resultado atual      = renda total - gastos realizados
taxa de economia     = resultado atual / renda total
```

Exemplo:

```text
renda total:          R$ 5.000
limite de gastos:     R$ 2.000
gastos realizados:   R$ 1.800
disponível no limite: R$   200
sobra planejada:      R$ 3.000
resultado atual:      R$ 3.200
taxa de economia:          64%
```

Se o resultado for negativo, o aplicativo deve mostrar o déficit claramente e
nunca transformar esse valor em zero apenas para melhorar a apresentação.

---

## Fase 0 — Preparação segura para produção (P0)

Objetivo: corrigir riscos já encontrados e deixar uma base confiável para as
novas funcionalidades. Versão planejada: `1.0.2+3`.

### Segurança e privacidade

- [x] Fazer o PIN bloquear o aplicativo na abertura e ao retornar do segundo
  plano.
- [x] Definir o tempo de tolerância antes de pedir o PIN novamente (30 segundos).
- [x] Bloquear ou desacelerar tentativas repetidas de PIN.
- [x] Proteger o backup com criptografia ou deixar explícito que o arquivo não é
  criptografado e contém dados financeiros legíveis.
- [x] Remover o arquivo de backup de exemplo da versão atual do repositório.
- [x] Confirmar se o backup de exemplo continha dados reais; se continha,
  removê-lo também do histórico público do Git com uma operação coordenada.
- [x] Atualizar a política de privacidade para refletir PIN, foto de perfil,
  backup manual, exportação e notificações.
- [ ] Conferir as declarações de Segurança de dados e Recursos financeiros na
  Play Console.

### Código e repositório

- [x] Corrigir os dois avisos atuais do `flutter analyze`.
- [x] Remover arquivos acidentais do repositório (`-Path`, relatório do Gradle e
  outros artefatos gerados).
- [x] Incluir os arquivos do Gradle Wrapper necessários para builds em máquinas
  novas e no GitHub Actions.
- [x] Organizar as branches: preservar a política publicada, integrar a versão
  atual do aplicativo e atualizar a `main`.
- [x] Atualizar o README com instalação, arquitetura, privacidade e processo de
  release.
- [x] Adicionar validação automática de análise, testes e build no GitHub.

### Critério de conclusão

- [x] `flutter analyze` sem problemas.
- [x] Todos os testes aprovados.
- [x] AAB release assinado e versão release instalada no emulador Android.
- [x] PIN realmente exigido nos cenários definidos.
- [x] Política compatível publicada pelo repositório do GitHub Pages.
- [x] Repositório remoto contém exatamente o código usado para gerar a versão.

---

## Fase 1 — Rendas e planejamento mensal (P1 / v1.1)

Objetivo: apresentar a relação entre renda, limite de gastos e sobra esperada.

### Modelo de dados

- [x] Criar o cadastro de renda com valor, descrição/fonte, data e recorrência
  opcional.
- [x] Criar o planejamento mensal com mês, limite de gastos e data de criação.
- [x] Migrar o limite atual para o planejamento do mês correspondente.
- [x] Persistir os novos valores monetários em centavos inteiros.
- [x] Preparar migrações de banco com testes de atualização e reversão em caso
  de erro.

### Experiência do usuário

- [x] Criar a área `Rendas` para adicionar, editar e excluir entradas.
- [x] Permitir múltiplas fontes, como salário, trabalho extra e outras rendas.
- [x] Permitir repetir automaticamente uma renda nos próximos meses.
- [x] Manter o limite de gastos independente da renda cadastrada.
- [x] Exibir na tela inicial:
  - renda total do mês;
  - limite definido;
  - gastos realizados;
  - valor disponível dentro do limite;
  - sobra planejada;
  - resultado atual do mês.
- [x] Mostrar estados claros para resultado positivo, atenção, limite excedido e
  déficit.
- [x] Informar que os resultados são baseados nos registros manuais do Finanse.

### Integração com a reserva

- [x] Oferecer `Destinar para a reserva` a partir do resultado positivo.
- [x] Impedir que a destinação seja contabilizada como despesa.
- [x] Registrar o mês de origem da destinação.
- [x] Impedir destinação superior ao resultado disponível, salvo confirmação
  explícita do usuário.

### Critério de conclusão

- [x] O exemplo de R$ 5.000 de renda e R$ 2.000 de limite produz os cálculos
  definidos neste documento.
- [x] Usuários sem renda cadastrada continuam usando todos os recursos atuais.
- [x] Editar ou excluir uma renda atualiza os totais imediatamente.
- [x] Gastos e rendas de meses diferentes nunca se misturam.
- [x] Transferir para a reserva não altera o total de gastos.
- [x] Cálculos cobertos por testes unitários e de banco de dados.

---

## Fase 2 — Evolução financeira mensal (P1 / v1.2)

Objetivo: mostrar o que a pessoa conseguiu preservar ao longo do tempo.

### Histórico

- [x] Criar resumo de cada mês com renda, limite, gastos e resultado final.
- [x] Exibir comparação com o mês anterior.
- [x] Criar gráfico dos últimos 6 e 12 meses com:
  - renda;
  - gastos;
  - resultado;
  - taxa de economia.
- [x] Mostrar resultado acumulado no período selecionado.
- [x] Destacar melhor mês, pior mês e média mensal sem linguagem punitiva.
- [x] Permitir consultar e corrigir meses anteriores.

### Fechamento mensal

- [x] Tratar o mês encerrado como histórico, mas permitir correções manuais.
- [x] Recalcular automaticamente o histórico após uma correção retroativa.
- [x] Sugerir o novo planejamento usando o limite anterior, sem alterá-lo sem
  autorização.
- [x] Oferecer a destinação do resultado positivo para a reserva.

### Critério de conclusão

- [x] O histórico permanece correto após mudança de mês e reinicialização do
  aplicativo.
- [x] Um resultado negativo é mostrado corretamente nos cartões e gráficos.
- [x] Correções retroativas não duplicam renda, despesa ou reserva.
- [x] Gráficos possuem rótulos e alternativa textual acessível.

---

## Fase 3 — Metas e limites por categoria (P2 / v1.3)

Objetivo: ajudar a pessoa a decidir para onde direcionar a sobra.

- [ ] Criar metas manuais com nome, valor-alvo e prazo opcional.
- [ ] Permitir destinar parte da sobra para uma ou várias metas.
- [ ] Mostrar progresso nominal e percentual de cada meta.
- [ ] Criar limites opcionais por categoria.
- [ ] Avisar ao atingir faixas configuráveis do limite geral ou por categoria.
- [ ] Mostrar comparações úteis, como redução de gastos por categoria.
- [ ] Evitar recomendações financeiras personalizadas ou promessas de resultado.

### Critério de conclusão

- [ ] A soma destinada às metas e à reserva é rastreável e não altera os gastos.
- [ ] Metas podem ser pausadas, editadas e concluídas sem perder o histórico.
- [ ] Limites por categoria não substituem nem contradizem o limite geral.

---

## Fase 4 — Qualidade contínua e publicação (contínua)

- [ ] Adicionar testes de widgets para os principais estados das telas.
- [ ] Adicionar testes de integração para onboarding, renda, gasto, PIN, backup e
  restauração.
- [ ] Verificar acessibilidade, contraste, tamanhos de fonte e leitores de tela.
- [ ] Testar migração com dados de versões anteriores.
- [ ] Testar aparelhos com Android 7 ou superior e diferentes tamanhos de tela.
- [ ] Monitorar tamanho do AAB e atualizar dependências com segurança.
- [ ] Manter política de privacidade, ficha da Play Store e comportamento do app
  sincronizados.
- [ ] Fazer teste interno antes de cada envio à produção.

## Definição de pronto para cada entrega

Uma tarefa só pode ser marcada como concluída quando:

- [ ] comportamento e textos foram revisados;
- [ ] cenários de erro e estados vazios foram tratados;
- [ ] testes relevantes foram criados ou atualizados;
- [ ] `flutter analyze` e `flutter test` foram aprovados;
- [ ] a funcionalidade foi verificada no Android;
- [ ] migrações preservam os dados existentes;
- [ ] privacidade e declarações da Play Store continuam corretas;
- [ ] código e versão publicada estão sincronizados no GitHub.

## Ordem recomendada de execução

1. Concluir toda a Fase 0.
2. Entregar a Fase 1 como o primeiro MVP da evolução financeira.
3. Validar os cálculos e a compreensão dos textos em teste interno.
4. Entregar a Fase 2 com histórico e gráficos.
5. Avaliar o uso antes de iniciar metas e limites por categoria.
