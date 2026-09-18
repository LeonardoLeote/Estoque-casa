# Segurança — leia antes de usar

## O que o modelo atual significa

O app não tem login. As políticas RLS do `schema.sql` são:

```sql
CREATE POLICY "Acesso público items" ON items FOR ALL USING (true) WITH CHECK (true);
```

`FOR ALL ... USING (true)` libera **SELECT, INSERT, UPDATE e DELETE** para
qualquer requisição que traga a URL do projeto e a anon key.

Consequência prática: quem tiver essas duas strings pode ler todo o estoque,
alterar quantidades e **apagar tudo**. Não existe recuperação, exceto backup do
Supabase.

A anon key é feita para ir no cliente — isso é normal. O que não é normal é
combiná-la com RLS totalmente aberta.

## Por que as chaves não estão no código

Este repositório é **público**. Chave commitada em repositório público é
encontrada por scanners automáticos em minutos. Por isso elas entram no build
via `--dart-define` e ficam nos Secrets do GitHub.

**Isso protege o repositório, não o APK.** Qualquer pessoa com o arquivo `.apk`
consegue extrair as chaves dele — `--dart-define` embute a string no binário,
não criptografa. Distribua o APK só para quem mora na casa.

## Se alguma chave já vazou

- **Gemini**: revogue e gere outra em <https://aistudio.google.com/apikey>.
- **Supabase**: rotacione as chaves em Settings → API. Isso invalida os APKs já
  instalados — todos precisam ser recompilados.

## Como fechar o acesso de verdade

Em ordem de esforço:

### 1. Senha compartilhada da casa (mais simples)

Ative o Supabase Auth, crie **um** usuário por e-mail/senha para a casa toda e
troque as políticas por:

```sql
DROP POLICY "Acesso público items" ON items;
CREATE POLICY "Somente autenticados" ON items
  FOR ALL TO authenticated USING (true) WITH CHECK (true);
```

No app, chame `signInWithPassword` na tela de setup. Assim a anon key sozinha
deixa de dar acesso.

### 2. Um usuário por pessoa

Mesmo esquema, mas cada morador tem login próprio — e o campo `usuario` do
histórico passa a vir de `auth.uid()` em vez de um texto que qualquer um digita.

### 3. Proteger contra apagar tudo

Mesmo com login, vale remover o DELETE das políticas e usar exclusão lógica
(`deleted_at`), para que um toque errado não seja definitivo.

## Detalhe do histórico

O `item_id` do histórico é `ON DELETE SET NULL`, e não `CASCADE`. Se fosse
cascade, apagar um item apagaria junto todo o registro de que ele existiu — o
histórico perderia exatamente o evento mais importante.
