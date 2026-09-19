# 🏠 Estoque Casa

Controle de estoque doméstico compartilhado entre os celulares da casa.
Flutter + Supabase (com realtime) + leitura de nota fiscal pelo Gemini.

## O que faz

- Estoque com nome, categoria, emoji, quantidade, unidade e nível mínimo de alerta.
- Status automático por item: **OK** / **Baixo** / **Faltando**.
- Ajuste rápido com `+` / `-` direto na lista (aplica na hora e desfaz se a rede falhar).
- Sincronização em tempo real: o que um celular muda aparece no outro.
- Histórico das últimas 100 alterações, assinado com o nome de quem mexeu.
- Lista de compras gerada sozinha, agrupada por categoria e compartilhável no WhatsApp.
- Notificação local quando algo entra em nível baixo ou acaba.
- Preço unitário por item, lido da nota fiscal ou digitado à mão.
- Leitura de nota fiscal por foto, com tela de revisão onde dá para corrigir
  nome, quantidade, categoria, ícone e preço antes de importar.
- Estimativa de gasto na lista de compras, com base nos preços conhecidos.
- Tela "Sobre" com a versão instalada, o commit que gerou o APK e o valor
  total do estoque.
- Abre e mostra o estoque mesmo sem internet (leitura do cache local).

## Configuração

### 1. Banco de dados

No dashboard do Supabase → **SQL Editor**, rode [`supabase/schema.sql`](supabase/schema.sql).

**Já tinha o banco criado antes da coluna de preço?** Rode
[`supabase/migracao_001_preco.sql`](supabase/migracao_001_preco.sql) **antes**
de instalar o APK novo — sem a coluna `preco`, salvar item passa a dar erro.
Leia [`SEGURANCA.md`](SEGURANCA.md) antes: as políticas padrão deixam o banco
aberto para quem tiver a chave.

### 2. Chaves

As chaves **não ficam no código** — este repositório é público. Elas entram no
build via `--dart-define`.

Localmente, copie o exemplo e preencha:

```bash
cp env.example.json env.json
# edite env.json com suas chaves — ele está no .gitignore
```

No GitHub, cadastre em **Settings → Secrets and variables → Actions**:

| Secret | Obrigatório |
|---|---|
| `SUPABASE_URL` | sim |
| `SUPABASE_ANON_KEY` | sim |
| `GEMINI_API_KEY` | só para ler nota fiscal |

Sem as duas primeiras o app abre numa tela explicando o que faltou, em vez de
travar.

## Gerar o APK

### Pelo GitHub Actions (recomendado)

O workflow [`build-apk.yml`](.github/workflows/build-apk.yml) roda a cada push:
analisa, testa e compila. Baixe o APK em **Actions → o run → Artifacts →
`estoque-casa-apk`**.

### Localmente

Precisa de Flutter 3.47.5+ e do Android SDK instalados.

```bash
flutter pub get
flutter build apk --release --dart-define-from-file=env.json
```

Saída em `build/app/outputs/flutter-apk/app-release.apk`.

> O APK sai assinado com a **chave de debug** — instala normalmente via
> "fontes desconhecidas", mas não serve para a Play Store. Para publicar, crie
> uma signing config própria em `android/app/build.gradle.kts`.

## Modelo do Gemini

`gemini-1.5-flash` foi descontinuado. O padrão é `gemini-flash-latest`, que
aponta sempre para o flash estável atual. Para fixar outro, defina
`GEMINI_MODEL` no `env.json`.

## Rodar os testes

```bash
flutter test
flutter analyze
```

## Estrutura

```
lib/
  constants.dart                 configuração e paleta
  main.dart                      bootstrap + SnackBars padronizados
  models/                        ItemModel, HistoricoModel
  services/
    supabase_service.dart        CRUD, realtime, histórico
    gemini_service.dart          leitura de nota fiscal (REST)
    notification_service.dart    notificações locais com deduplicação
    local_cache.dart             cache offline
    user_service.dart            nome do usuário deste aparelho
  screens/                       setup, home, add/edit, histórico,
                                 lista de compras, revisão da nota
  widgets/                       item_card, stat_card, filtros, estado vazio
```

## Limitações conhecidas

- **Offline é só leitura.** Sem rede o app mostra o último estado salvo; qualquer
  alteração falha com aviso. Não há fila de sincronização.
- **Sem login.** Qualquer pessoa com a URL e a anon key lê e escreve tudo. Veja
  [`SEGURANCA.md`](SEGURANCA.md).
- **A leitura de nota erra.** Por isso existe a tela de revisão — nada entra no
  estoque sem você confirmar.
- **Itens importados entram com alerta mínimo 0**, ou seja, sem aviso de estoque
  baixo até você definir um.
- **O preço é o último informado**, não um histórico. Reimportar uma nota com
  preço novo sobrescreve o antigo, e a estimativa da lista de compras assume
  que o preço de hoje é o de amanhã.
