# Checklist de publicação do Finanse

Crie uma cópia deste checklist para cada versão. Ele não autoriza gerar ou
enviar um AAB; essas ações só devem ocorrer quando a versão estiver fechada.

## 1. Fechamento do código

- [ ] O escopo e os textos da versão foram revisados.
- [ ] Estados vazio, carregando e erro foram conferidos.
- [ ] Não existem dados de teste incluídos no aplicativo.
- [ ] As migrações preservam os dados da versão disponível na Play Store.
- [ ] `flutter analyze` foi aprovado.
- [ ] `flutter test --coverage` foi aprovado.
- [ ] `flutter build apk --debug` foi aprovado.
- [ ] Avisos de build e dependências monitoradas na matriz foram reavaliados.
- [ ] A PR está aprovada e o CI está verde.

## 2. Matriz de aparelhos e acessibilidade

- [ ] Instalação nova validada no Android 7 / API 24.
- [ ] Atualização sobre a versão publicada validada no Android 7 / API 24.
- [ ] Android atual validado em telefone pequeno e telefone normal.
- [ ] Layout validado em largura a partir de 600 px.
- [ ] Temas claro e escuro validados.
- [ ] Fonte padrão e fonte em 200% validadas.
- [ ] Ordem, rótulos e ações foram conferidos com leitor de tela.
- [ ] Notificações recorrentes foram conferidas após reiniciar o aparelho.
- [ ] Criação e restauração de backup foram testadas com dados reais de teste.

Consulte a [matriz de qualidade](QUALITY_MATRIX.md) para os fluxos mínimos.

## 3. Privacidade e Play Store

- [ ] A [política de privacidade](index.md) descreve o comportamento da versão.
- [ ] A descrição da Play Store corresponde às funções disponíveis.
- [ ] A seção Segurança dos dados informa armazenamento local e ações manuais de
  exportação/compartilhamento.
- [ ] Está declarado que não há conexão bancária, conta obrigatória, publicidade,
  rastreamento ou análise comportamental.
- [ ] Está declarado que backups e relatórios exportados não são criptografados.
- [ ] As permissões do AAB correspondem a notificações, reinicialização, arquivos,
  câmera/galeria e compartilhamento usados pelo app.
- [ ] Capturas de tela e contato de suporte continuam atuais.

## 4. Pacote de produção

- [ ] A versão e o código foram incrementados em `pubspec.yaml` somente depois de
  fechar o escopo.
- [ ] A assinatura release local está completa e fora do Git.
- [ ] `flutter build appbundle --release` foi executado.
- [ ] O tamanho do AAB foi comparado com a versão anterior e a variação registrada.
- [ ] O SHA-256 do AAB foi registrado junto à entrega.
- [ ] O AAB corresponde exatamente ao commit aprovado no GitHub.

Registro da entrega:

- Versão/código:
- Commit:
- Tamanho do AAB:
- Variação:
- SHA-256:

## 5. Teste interno e produção

- [ ] O AAB foi enviado primeiro para a faixa de teste interno.
- [ ] Instalação e atualização pela Play Store foram aprovadas.
- [ ] Os fluxos críticos foram repetidos usando o pacote distribuído pela Play.
- [ ] Avisos do relatório de pré-lançamento foram analisados.
- [ ] Falhas e ANRs foram verificados.
- [ ] A publicação em produção foi autorizada.
- [ ] Após publicar, a versão da Play Store e o código no GitHub foram conferidos.

Em caso de falha material, interrompa a promoção, registre o problema e corrija
em uma nova versão. Não reutilize um código de versão já enviado à Play Store.
