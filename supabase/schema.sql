-- Estoque Casa — schema do Supabase.
-- Rode no SQL Editor do dashboard: https://supabase.com/dashboard → SQL Editor.
-- É idempotente: pode rodar de novo sem quebrar nada.

-- ── Tabelas ────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS items (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  nome        TEXT NOT NULL,
  categoria   TEXT NOT NULL,
  quantidade  NUMERIC(10,2) NOT NULL DEFAULT 0,
  unidade     TEXT NOT NULL DEFAULT 'un',
  minimo      NUMERIC(10,2) NOT NULL DEFAULT 0,
  emoji       TEXT NOT NULL DEFAULT '📦',
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- `item_id` é ON DELETE SET NULL, não CASCADE: apagar um item não pode
-- apagar o histórico de quando ele existiu.
CREATE TABLE IF NOT EXISTS historico (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  item_id             UUID REFERENCES items(id) ON DELETE SET NULL,
  item_nome           TEXT NOT NULL,
  acao                TEXT NOT NULL,
  quantidade_anterior NUMERIC(10,2),
  quantidade_nova     NUMERIC(10,2),
  usuario             TEXT NOT NULL,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS historico_created_at_idx
  ON historico (created_at DESC);
CREATE INDEX IF NOT EXISTS items_nome_idx ON items (nome);

-- ── Realtime ───────────────────────────────────────────────────────────

DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE items;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE historico;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- ── RLS ────────────────────────────────────────────────────────────────
-- ATENÇÃO: as políticas abaixo liberam leitura E escrita para qualquer um
-- que tenha a URL e a anon key do projeto. É o modelo "app doméstico sem
-- login" — simples, porém sem nenhuma proteção se a chave vazar.
-- Veja SEGURANCA.md para a alternativa com senha compartilhada.

ALTER TABLE items     ENABLE ROW LEVEL SECURITY;
ALTER TABLE historico ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Acesso público items"     ON items;
DROP POLICY IF EXISTS "Acesso público historico" ON historico;

CREATE POLICY "Acesso público items"
  ON items FOR ALL USING (true) WITH CHECK (true);

CREATE POLICY "Acesso público historico"
  ON historico FOR ALL USING (true) WITH CHECK (true);

-- ── updated_at automático ──────────────────────────────────────────────
-- O app manda `updated_at`, mas o trigger garante o valor se alguém
-- escrever direto pelo dashboard.

CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS items_set_updated_at ON items;
CREATE TRIGGER items_set_updated_at
  BEFORE UPDATE ON items
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
