# Finanse

Aplicativo Flutter de planejamento financeiro pessoal para Android. Todos os
registros são informados manualmente e permanecem no dispositivo; o Finanse não
se conecta a bancos nem exige uma conta de usuário.

## Recursos atuais

- registro, edição e exclusão de despesas;
- despesas recorrentes e lembretes locais;
- limite mensal e acompanhamento do valor utilizado;
- reserva financeira com histórico de movimentações;
- relatórios e exportações em PDF, Excel e CSV;
- backup e restauração manual;
- perfil local com nome e foto opcionais;
- bloqueio de acesso por PIN;
- temas claro, escuro e cores personalizáveis.

> Os backups e relatórios exportados não são criptografados. Eles podem conter
> dados financeiros legíveis e devem ser mantidos em destinos confiáveis.

Consulte a [Política de Privacidade](docs/index.md) e o
[Roadmap do produto](ROADMAP.md).

## Requisitos de desenvolvimento

- Flutter compatível com o SDK indicado em `pubspec.yaml`;
- Android SDK;
- Java 17;
- Android 7.0 (API 24) ou superior para execução no aparelho.

## Executar localmente

```bash
flutter pub get
flutter run
```

## Qualidade

Antes de enviar uma alteração:

```bash
flutter analyze
flutter test
flutter build apk --debug
```

O GitHub Actions executa essas verificações automaticamente em pushes e pull
requests.

## Gerar uma versão de produção

A assinatura fica fora do Git. Crie `android/key.properties` localmente com:

```properties
storePassword=SENHA_DO_ARQUIVO
keyPassword=SENHA_DA_CHAVE
keyAlias=NOME_DA_CHAVE
storeFile=CAMINHO_ABSOLUTO_DO_ARQUIVO_JKS
```

Depois execute:

```bash
flutter build appbundle --release
```

O AAB será criado em
`build/app/outputs/bundle/release/app-release.aab`. A geração release falha de
forma explícita quando a configuração de assinatura está ausente ou incompleta.

Nunca envie `key.properties`, arquivos `.jks`, `.keystore` ou senhas para o
repositório.
