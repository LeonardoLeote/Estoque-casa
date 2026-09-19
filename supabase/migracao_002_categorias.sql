-- Migração 002 — categorias e ícones editáveis pelo app.
--
-- Rode ANTES de instalar o APK. Sem a tabela o app continua abrindo (cai
-- nas categorias embutidas), mas o menu "Categorias" não salva nada.
--
-- As categorias ficam no Supabase, não no aparelho: são compartilhadas
-- pela casa toda. Categoria criada num celular aparece no outro.

CREATE TABLE IF NOT EXISTS categorias (
  nome       TEXT PRIMARY KEY,
  emoji      TEXT NOT NULL DEFAULT '📦',
  -- Ícones oferecidos ao cadastrar um item desta categoria.
  emojis     TEXT[] NOT NULL DEFAULT ARRAY['📦'],
  ordem      INT NOT NULL DEFAULT 100,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE categorias ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Acesso público categorias" ON categorias;
CREATE POLICY "Acesso público categorias"
  ON categorias FOR ALL USING (true) WITH CHECK (true);

DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE categorias;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- Semente. ON CONFLICT DO NOTHING preserva o que você já tiver editado.
INSERT INTO categorias (nome, emoji, emojis, ordem) VALUES
  ('Hortifruti', '🥬', ARRAY[
     '🥬','🥕','🍅','🥑','🍌','🍎','🍏','🍐','🍊','🍋','🍇','🍓','🫐','🍉',
     '🍈','🍒','🍑','🥭','🍍','🥥','🥦','🧅','🧄','🌽','🥒','🫑','🌶️','🍆',
     '🥔','🍠','🫒','🥗','🍄','🥜'], 10),
  ('Carnes', '🥩', ARRAY[
     '🥩','🍗','🍖','🐟','🦐','🥓','🍤','🦑','🦀','🦞','🥚','🍳','🌭','🧆'], 20),
  ('Laticínios', '🥛', ARRAY[
     '🥛','🧀','🧈','🍦','🥣','🍶','🧊'], 30),
  ('Grãos', '🌾', ARRAY[
     '🌾','🫘','🍚','🌰','🥜','🍝','🍜','🫓','🥫','🧂','🍯','🥣'], 40),
  ('Padaria', '🥖', ARRAY[
     '🥖','🍞','🥐','🥯','🫓','🧇','🥞','🥨','🍪','🎂','🧁','🥧','🍰'], 50),
  ('Besteiras', '🍕', ARRAY[
     '🍕','🍔','🌭','🥪','🌮','🌯','🍟','🍿','🍫','🍬','🍭','🍩','🍪','🧁',
     '🎂','🍰','🥧','🍦','🍨','🍧','🥤','🧋','🍺','🍻','🥟','🍣','🍱','🧇'], 60),
  ('Bebidas', '💧', ARRAY[
     '💧','🧃','☕','🍵','🥤','🧋','🍺','🍷','🍾','🥂','🥃','🍹','🧉','🫗'], 70),
  ('Limpeza', '🧴', ARRAY[
     '🧴','🧹','🧽','🪣','🧼','🫧','🧺','🧻','🪥','🧯','🪒','🗑️'], 80),
  ('Higiene', '🪥', ARRAY[
     '🪥','🧼','🧻','🧴','💊','🩹','💈','🧷'], 90),
  ('Casa', '🏠', ARRAY[
     '🏠','🔋','💡','🕯️','🔌','🪫','📦','🧰','🔦','🪴'], 95)
ON CONFLICT (nome) DO NOTHING;
